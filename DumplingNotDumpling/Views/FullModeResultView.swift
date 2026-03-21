import SwiftUI

/// Full Mode result screen.
///
/// Displays detailed classification output: the specific dumpling type (e.g. "gyoza."),
/// per-class confidence, and secondary matches as glass-backed chips. When the image
/// is not a dumpling, falls back to the simple "not dumpling." label with error styling.
struct FullModeResultView: View {
    let result: ClassificationResult
    let image: CGImage?
    let onTryAgain: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Captured image — slightly shorter than party mode to leave room for chips
            if let image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, CarbonSpacing.spacing05)
                    .padding(.top, CarbonSpacing.spacing05)
            }

            Spacer()

            // Classification details
            VStack(spacing: CarbonSpacing.spacing05) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(CarbonColor.supportInfo)
                    .frame(width: 32, height: 3)

                if result.isDumpling {
                    Text("\(result.dumplingType ?? "dumpling").")
                        .font(DumplingFont.display(38))
                        .foregroundStyle(CarbonColor.textPrimary)

                    ConfidenceLabel(result.confidence, color: CarbonColor.supportInfo)

                    // Secondary match chips — show runner-up classes with their scores
                    HStack(spacing: CarbonSpacing.spacing03) {
                        ForEach(result.secondaryMatches(), id: \.label) { match in
                            Text("\(match.label) \u{00B7} \(String(format: "%.2f", match.confidence))")
                                .font(DumplingFont.body(12))
                                .foregroundStyle(CarbonColor.textSecondary)
                                .padding(.horizontal, CarbonSpacing.spacing05)
                                .padding(.vertical, CarbonSpacing.spacing03)
                                .glassEffect(.clear, in: .rect(cornerRadius: 8))
                        }
                    }
                } else {
                    Text("not dumpling.")
                        .font(DumplingFont.display(38))
                        .foregroundStyle(CarbonColor.textPrimary)

                    ConfidenceLabel(result.confidence, color: CarbonColor.supportError)
                }
            }
            .padding(.vertical, CarbonSpacing.spacing06)

            Spacer()

            // Action buttons
            HStack(spacing: CarbonSpacing.spacing04) {
                GlassButton("Try Again", action: onTryAgain)
                GlassButton("Share", color: result.isDumpling ? CarbonColor.supportInfo : CarbonColor.textSecondary, action: onShare)
            }
            .padding(.horizontal, CarbonSpacing.spacing05)
            .padding(.bottom, CarbonSpacing.spacing08)
        }
    }
}
