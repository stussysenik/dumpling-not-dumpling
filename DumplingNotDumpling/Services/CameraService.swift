@preconcurrency import AVFoundation
import Foundation
import CoreImage

#if canImport(UIKit)
import UIKit
#endif

/// Manages an AVCaptureSession for live camera feed.
///
/// Swift 6.0 concurrency notes:
/// - The class is `@MainActor` so observable state (isRunning, currentFrame, etc.) is
///   main-actor isolated and safe to bind directly in SwiftUI.
/// - `captureSession`, `previewLayer`, `sessionQueue`, and `outputQueue` are stored as
///   `nonisolated(unsafe)` `let` constants. They are all set once in `init` and never
///   mutated — we accept responsibility for their thread-safety:
///     • AVCaptureSession is internally thread-safe for configuration / start / stop.
///     • DispatchQueue is safe to call from any thread.
///     • AVCaptureVideoPreviewLayer is accessed only from the main thread (UIKit).
/// - `captureOutput` is `nonisolated` because AVFoundation calls it on `outputQueue`.
/// - CVPixelBuffer is not Sendable, so it is consumed on `outputQueue` without crossing
///   actor boundaries. Only CGImage (which is Sendable) is passed to the MainActor.
/// - `@preconcurrency` on AVFoundation silences Sendable warnings for AVCaptureSession
///   that pre-date Swift 6 concurrency annotations in the SDK.
@Observable
@MainActor
final class CameraService: NSObject {

    // MARK: - Public State

    /// True while the capture session is actively running.
    var isRunning = false

    /// The most recent camera frame as a CGImage (updated on every frame capture).
    var currentFrame: CGImage?

    /// True after the user has granted camera access.
    var permissionGranted = false

    /// Called on the main actor with each new CGImage frame.
    var onFrameCaptured: ((CGImage) -> Void)?

    /// Called on `outputQueue` (background thread) with the raw CVPixelBuffer.
    /// Use this for ML inference — Vision/CoreML pipelines are internally thread-safe.
    /// Do NOT touch any @MainActor state inside this closure.
    ///
    /// `@ObservationIgnored` prevents the `@Observable` macro from wrapping this property
    /// in observation tracking infrastructure. `nonisolated(unsafe)` lets the delegate method
    /// read it from `outputQueue` without a MainActor hop — we accept thread-safety
    /// responsibility (it is written once before the session starts, then only read).
    @ObservationIgnored
    nonisolated(unsafe) var onPixelBufferCaptured: ((CVPixelBuffer) -> Void)?

    // MARK: - Private Infrastructure (nonisolated let — set once in init, never mutated)

    nonisolated(unsafe) private let captureSession: AVCaptureSession
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let outputQueue = DispatchQueue(label: "camera.output")

    // MARK: - Preview Layer

    /// A single `AVCaptureVideoPreviewLayer` bound to `captureSession`.
    /// Stored as a `let` constant — a new layer on each call would appear blank.
    /// `nonisolated(unsafe)` lets UIKit read it on the main thread from a non-MainActor context.
    nonisolated(unsafe) let previewLayer: AVCaptureVideoPreviewLayer

    // MARK: - Init

    override init() {
        let session = AVCaptureSession()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.captureSession = session
        self.previewLayer = layer
        super.init()
    }

    // MARK: - Permission

    /// Requests camera permission if not already determined.
    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            permissionGranted = false
        }
    }

    // MARK: - Session Lifecycle

    /// Configures (if needed) and starts the capture session.
    /// Must be called after `requestPermission()` resolves `permissionGranted == true`.
    func startSession() {
        guard permissionGranted else { return }
        sessionQueue.async { [weak self] in
            self?.configureSessionIfNeeded()
            self?.captureSession.startRunning()
            Task { @MainActor in
                self?.isRunning = true
            }
        }
    }

    /// Stops the capture session and updates `isRunning` on the main actor.
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            Task { @MainActor in
                self?.isRunning = false
            }
        }
    }

    // MARK: - Frame Access

    /// Returns the most recently captured frame, or nil if no frame has arrived yet.
    func captureCurrentFrame() -> CGImage? {
        return currentFrame
    }

    // MARK: - Private Configuration

    /// Configures the session if it has no inputs yet. Called on sessionQueue.
    /// `nonisolated` so it can be called from the `@Sendable` sessionQueue closure without
    /// involving the MainActor. It accesses only `captureSession`, which is `nonisolated(unsafe)`.
    nonisolated private func configureSessionIfNeeded() {
        guard captureSession.inputs.isEmpty else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // iOS: rear wide-angle camera for best food classification quality.
        // macOS: system default (typically FaceTime HD / Continuity Camera).
        #if os(iOS)
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            captureSession.commitConfiguration()
            return
        }
        #elseif os(macOS)
        guard let device = AVCaptureDevice.default(for: .video) else {
            captureSession.commitConfiguration()
            return
        }
        #else
        captureSession.commitConfiguration()
        return
        #endif

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: outputQueue)
        // Drop late frames rather than queue them — keeps classification latency low.
        output.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        captureSession.commitConfiguration()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Called by AVFoundation on `outputQueue` (non-main thread) for each new frame.
    ///
    /// CVPixelBuffer is not Sendable — it cannot cross actor boundaries in a Task.
    /// Strategy:
    ///   1. Call `onPixelBufferCaptured` immediately on outputQueue with the raw buffer.
    ///   2. Convert the buffer to a CGImage (Sendable) on outputQueue.
    ///   3. Hop to MainActor to publish `currentFrame` and call `onFrameCaptured`.
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Deliver raw pixel buffer on background queue — no actor boundary crossing.
        onPixelBufferCaptured?(pixelBuffer)

        // Convert to CGImage so we can safely send it to the MainActor.
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task { @MainActor [weak self] in
            self?.currentFrame = cgImage
            self?.onFrameCaptured?(cgImage)
        }
    }
}
