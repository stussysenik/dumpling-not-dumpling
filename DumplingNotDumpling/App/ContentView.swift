import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
#endif

/// Main camera + classification screen (iOS layout).
///
/// Layout stack (top → bottom):
///   1. Camera viewfinder with corner bracket overlays
///   2. Mode toggle (Party / Full)
///   3. Bottom controls: photo picker, capture button, LIVE toggle
///
/// State machine:
///   • `.camera`   — live preview, awaiting capture or photo pick
///   • `.result`   — classification complete, showing ResultView or FullModeResultView
///
/// LIVE mode streams continuous classifications via `onFrameCaptured`, throttled to
/// ~5 fps so the CPU stays cool and the UI stays responsive.
struct ContentView: View {

    // MARK: - Services

    @State private var cameraService = CameraService()
    @State private var classificationService = ClassificationService()

    // MARK: - UI State

    @State private var mode: AppMode = .party
    @State private var isLive = false
    @State private var capturedImage: CGImage?
    @State private var classificationResult: ClassificationResult?
    @State private var showResult = false

    // MARK: - Photo Picker

    @State private var selectedPhotoItem: PhotosPickerItem?

    // MARK: - Live Classification Throttle

    @State private var lastLiveClassificationTime: CFAbsoluteTime = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            CarbonColor.background
                .ignoresSafeArea()

            if showResult, let result = classificationResult {
                resultView(for: result)
                    .transition(.opacity)
            } else {
                cameraScreen
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showResult)
        .task {
            await cameraService.requestPermission()
            if cameraService.permissionGranted {
                cameraService.startSession()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await handlePhotoPick(newItem)
            }
        }
        .onChange(of: isLive) { _, live in
            if live {
                startLiveClassification()
            } else {
                stopLiveClassification()
            }
        }
    }

    // MARK: - Camera Screen

    private var cameraScreen: some View {
        VStack(spacing: 0) {
            // Camera viewfinder
            CameraView(cameraService: cameraService)
                .padding(.horizontal, CarbonSpacing.spacing05)
                .padding(.top, CarbonSpacing.spacing05)

            // Live classification overlay — shows inline confidence while LIVE is on
            if isLive, let liveResult = classificationService.latestResult {
                HStack(spacing: CarbonSpacing.spacing03) {
                    Text(liveResult.displayLabel)
                        .font(DumplingFont.medium(14))
                        .foregroundStyle(CarbonColor.textPrimary)
                    ConfidenceLabel(
                        mode == .party ? liveResult.partyConfidence : liveResult.confidence,
                        color: liveResult.isDumpling ? CarbonColor.supportSuccess : CarbonColor.supportError,
                        showPrefix: false
                    )
                }
                .padding(.top, CarbonSpacing.spacing04)
            }

            Spacer()

            // Mode toggle
            ModeToggle(mode: $mode)
                .padding(.bottom, CarbonSpacing.spacing06)

            // Bottom controls
            bottomControls
                .padding(.horizontal, CarbonSpacing.spacing05)
                .padding(.bottom, CarbonSpacing.spacing08)
        }
    }

    // MARK: - Bottom Controls

    /// Photo picker | Capture button | LIVE toggle
    private var bottomControls: some View {
        HStack {
            // Photo library picker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 24))
                    .foregroundStyle(CarbonColor.textSecondary)
                    .frame(width: CarbonSpacing.spacing09, height: CarbonSpacing.spacing09)
            }

            Spacer()

            // Capture button — large circular shutter
            Button {
                Task {
                    await captureAndClassify()
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(CarbonColor.textPrimary, lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(CarbonColor.textPrimary)
                        .frame(width: 60, height: 60)
                }
            }
            .disabled(classificationService.isClassifying)
            .accessibilityLabel("Capture photo for classification")

            Spacer()

            // LIVE toggle
            Button {
                isLive.toggle()
            } label: {
                Text("LIVE")
                    .font(DumplingFont.medium(13))
                    .foregroundStyle(isLive ? Color.white : CarbonColor.textSecondary)
                    .padding(.horizontal, CarbonSpacing.spacing04)
                    .padding(.vertical, CarbonSpacing.spacing03)
                    .background {
                        if isLive {
                            Capsule().fill(CarbonColor.supportSuccess)
                        } else {
                            Capsule().strokeBorder(CarbonColor.borderSubtle, lineWidth: 1)
                        }
                    }
            }
            .frame(width: CarbonSpacing.spacing09, height: CarbonSpacing.spacing09)
        }
    }

    // MARK: - Result View Dispatch

    @ViewBuilder
    private func resultView(for result: ClassificationResult) -> some View {
        switch mode {
        case .party:
            ResultView(
                result: result,
                image: capturedImage,
                onTryAgain: { returnToCamera() }
            )
        case .full:
            FullModeResultView(
                result: result,
                image: capturedImage,
                onTryAgain: { returnToCamera() }
            )
        }
    }

    // MARK: - Actions

    /// Captures the current camera frame, runs classification, and shows the result.
    private func captureAndClassify() async {
        // Stop live mode if active
        if isLive {
            isLive = false
        }

        guard let frame = cameraService.captureCurrentFrame() else { return }
        capturedImage = frame

        if let result = await classificationService.classify(cgImage: frame, mode: mode) {
            classificationResult = result
            showResult = true
            triggerHaptic(for: result)
        }
    }

    /// Loads an image from the photo picker and classifies it.
    private func handlePhotoPick(_ item: PhotosPickerItem) async {
        // Stop live mode if active
        if isLive {
            isLive = false
        }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return }
        #else
        // macOS fallback — not the focus of this task but keeps the build clean
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        #endif

        capturedImage = cgImage

        if let result = await classificationService.classify(cgImage: cgImage, mode: mode) {
            classificationResult = result
            showResult = true
            triggerHaptic(for: result)
        }

        // Clear the picker selection so the same photo can be re-selected
        selectedPhotoItem = nil
    }

    /// Returns to the camera screen, clearing the captured result.
    private func returnToCamera() {
        showResult = false
        classificationResult = nil
        capturedImage = nil
        classificationService.latestResult = nil
    }

    // MARK: - Live Classification

    /// Hooks into `onFrameCaptured` to run continuous classification.
    /// Uses CGImage (Sendable) and manual throttle at ~5 fps.
    private func startLiveClassification() {
        classificationService.latestResult = nil
        cameraService.onFrameCaptured = { [classificationService] cgImage in
            Task { @MainActor in
                let now = CFAbsoluteTimeGetCurrent()
                guard now - lastLiveClassificationTime >= 0.2 else { return }
                lastLiveClassificationTime = now
                classificationService.latestResult = await classificationService.classify(cgImage: cgImage, mode: mode)
            }
        }
    }

    /// Disconnects the live classification callback.
    private func stopLiveClassification() {
        cameraService.onFrameCaptured = nil
        classificationService.latestResult = nil
    }

    // MARK: - Haptics

    /// Fires a haptic notification on classification result.
    /// `.success` for dumpling, `.error` for not dumpling.
    private func triggerHaptic(for result: ClassificationResult) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(result.isDumpling ? .success : .error)
        #endif
    }
}
