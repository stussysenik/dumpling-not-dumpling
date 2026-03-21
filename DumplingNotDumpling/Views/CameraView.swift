import SwiftUI
import AVFoundation

// MARK: - Platform Camera Preview

// AVCaptureVideoPreviewLayer must be embedded in a native view (UIView / NSView) because
// SwiftUI's Canvas and drawingGroup layers don't support CALayer-backed previews.
// We use UIViewRepresentable on iOS and NSViewRepresentable on macOS.

#if os(iOS)

/// Wraps `AVCaptureVideoPreviewLayer` in a UIView for use in SwiftUI on iOS.
///
/// The preview layer is added as a sublayer of the view's backing CALayer. On every
/// `updateUIView` call we re-sync the frame to handle device rotation and layout changes.
struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        // Initial frame; will be corrected in updateUIView once layout resolves.
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Dispatch to main to ensure the view's bounds are finalised before resizing.
        DispatchQueue.main.async {
            self.previewLayer.frame = uiView.bounds
        }
    }
}

#elseif os(macOS)

/// Wraps `AVCaptureVideoPreviewLayer` in an NSView for use in SwiftUI on macOS.
///
/// NSView requires `wantsLayer = true` before a backing layer is available.
/// We assign the preview layer as the view's root layer rather than a sublayer so that
/// it fills the view correctly without needing explicit frame management.
struct CameraPreview: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = CALayer()
        view.layer?.addSublayer(previewLayer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        previewLayer.frame = nsView.bounds
    }
}

#endif

// MARK: - CameraView

/// The primary camera view shown in the classification flow.
///
/// On iOS and macOS it renders the live camera preview via `CameraPreview`,
/// clipped to a rounded rectangle and decorated with corner bracket overlays
/// (`CameraBrackets`) that hint at the scan target area.
///
/// On watchOS (no camera hardware) it degrades gracefully to a placeholder label.
struct CameraView: View {
    /// The shared camera service. Passed in rather than constructed here so that
    /// parent views can observe `isRunning` / `currentFrame` without a separate reference.
    let cameraService: CameraService

    var body: some View {
        #if os(iOS) || os(macOS)
        CameraPreview(previewLayer: cameraService.previewLayer)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                CameraBrackets()
            }
        #else
        // watchOS has no camera; show a placeholder that matches the design language.
        Text("No camera on Watch")
            .foregroundStyle(CarbonColor.textPlaceholder)
        #endif
    }
}

// MARK: - CameraBrackets

/// Four L-shaped corner brackets rendered as `Path` strokes over the camera preview.
///
/// The brackets indicate the area the user should frame their subject within, adding a
/// professional scanning-app aesthetic without blocking the live preview.
///
/// Design parameters are local constants for easy tuning:
/// - `size`: length of each bracket arm in points
/// - `inset`: distance from the view edges to bracket corner
/// - `thickness`: stroke weight
/// - `color`: uses `CarbonColor.textPrimary` at 15% opacity so it's visible on both
///   light (dumpling) and dark (not-dumpling / counter surface) backgrounds
struct CameraBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 28
            let inset: CGFloat = 20
            let thickness: CGFloat = 2.5
            // Subtle overlay: enough contrast to be legible, not enough to be distracting.
            let color = CarbonColor.textPrimary.opacity(0.15)

            // Top-left bracket (┌)
            Path { p in
                p.move(to: CGPoint(x: inset, y: inset + size))
                p.addLine(to: CGPoint(x: inset, y: inset))
                p.addLine(to: CGPoint(x: inset + size, y: inset))
            }
            .stroke(color, lineWidth: thickness)

            // Top-right bracket (┐)
            Path { p in
                p.move(to: CGPoint(x: geo.size.width - inset - size, y: inset))
                p.addLine(to: CGPoint(x: geo.size.width - inset, y: inset))
                p.addLine(to: CGPoint(x: geo.size.width - inset, y: inset + size))
            }
            .stroke(color, lineWidth: thickness)

            // Bottom-left bracket (└)
            Path { p in
                p.move(to: CGPoint(x: inset, y: geo.size.height - inset - size))
                p.addLine(to: CGPoint(x: inset, y: geo.size.height - inset))
                p.addLine(to: CGPoint(x: inset + size, y: geo.size.height - inset))
            }
            .stroke(color, lineWidth: thickness)

            // Bottom-right bracket (┘)
            Path { p in
                p.move(to: CGPoint(x: geo.size.width - inset - size, y: geo.size.height - inset))
                p.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset))
                p.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset - size))
            }
            .stroke(color, lineWidth: thickness)
        }
    }
}
