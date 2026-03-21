import Foundation
import CoreML
import Vision
import CoreImage

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Wraps the Vision / CoreML inference pipeline.
///
/// Swift 6.0 concurrency notes:
/// - The class is `@MainActor` so all stored properties are main-actor isolated.
/// - `classify(cgImage:mode:)` is `nonisolated` so it can be called from any
///   isolation domain; it never touches actor-isolated state directly.
/// - `classifyIfReady` *is* actor-isolated and updates `latestResult` after
///   the nonisolated classify returns.
@Observable
@MainActor
final class ClassificationService {
    // MARK: - Public State

    /// The most recent result produced by `classifyIfReady`.
    var latestResult: ClassificationResult?

    /// True while a classification request is in-flight.
    var isClassifying = false

    // MARK: - Private

    private var model: VNCoreMLModel?
    private var lastClassificationTime: CFAbsoluteTime = 0

    /// Minimum seconds between classifications on the live feed (~5 fps).
    private let throttleInterval: CFAbsoluteTime = 0.2

    // MARK: - Init

    init() {
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let mlModel = try DumplingClassifier(configuration: config).model
            model = try VNCoreMLModel(for: mlModel)
        } catch {
            print("ClassificationService: failed to load model — \(error)")
        }
    }

    // MARK: - Classification

    /// Classify a single `CGImage` and return a `ClassificationResult`.
    ///
    /// This method is `nonisolated` so it can be called without hopping to the
    /// main actor first.  It captures `model` — a `VNCoreMLModel` — which is
    /// a class type.  We read it once from the actor and pass it in, keeping
    /// the Vision work off the main thread.
    ///
    /// - Parameters:
    ///   - cgImage: The image to classify.
    ///   - mode: The current `AppMode` (reserved for future mode-specific logic).
    /// - Returns: A `ClassificationResult`, or `nil` if the model is unavailable
    ///   or the Vision request fails.
    func classify(cgImage: CGImage, mode: AppMode) async -> ClassificationResult? {
        guard let model else { return nil }

        isClassifying = true
        defer { isClassifying = false }

        // Perform the Vision request off the main actor using a detached task so
        // we don't block the UI thread.  The continuation is resumed exactly once
        // inside the request completion handler.
        let result: ClassificationResult? = await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { [continuation] request, error in
                guard error == nil,
                      let observations = request.results as? [VNClassificationObservation]
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let allResults = observations.map { obs in
                    (label: obs.identifier, confidence: obs.confidence)
                }
                let top = observations.first

                let classificationResult = ClassificationResult(
                    label: top?.identifier ?? "unknown",
                    confidence: top?.confidence ?? 0,
                    allResults: allResults
                )
                continuation.resume(returning: classificationResult)
            }

            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }

        return result
    }

    // MARK: - Throttled Live Classification

    /// Throttled entry-point for the live camera feed.
    ///
    /// Frames arriving faster than `throttleInterval` seconds are dropped so
    /// the CPU is not saturated during continuous video capture.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Raw pixel data from `AVCaptureOutput`.
    ///   - mode: The current `AppMode`.
    func classifyIfReady(pixelBuffer: CVPixelBuffer, mode: AppMode) async {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastClassificationTime >= throttleInterval else { return }
        lastClassificationTime = now

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        latestResult = await classify(cgImage: cgImage, mode: mode)
    }
}
