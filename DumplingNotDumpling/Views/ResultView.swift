import SwiftUI

/// Party Mode result screen.
///
/// Shows the captured image, a large "dumpling." / "not dumpling." label,
/// a party-mode confidence score (sum of all dumpling classes), and action buttons.
/// The accent colour flips green (dumpling) / red (not dumpling) to give instant
/// visual feedback before the user reads the text.
struct ResultView: View {
    let result: ClassificationResult
    let image: CGImage?
    let onTryAgain: () -> Void

    @State private var animateResult = false

    var accentColor: Color {
        result.isDumpling ? CarbonColor.supportSuccess : CarbonColor.supportError
    }

    var body: some View {
        VStack(spacing: 0) {
            // Captured image area
            if let image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, CarbonSpacing.spacing05)
                    .padding(.top, CarbonSpacing.spacing05)
            }

            Spacer()

            // Result label + confidence
            VStack(spacing: CarbonSpacing.spacing05) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor)
                    .frame(width: 32, height: 3)

                Text(result.displayLabel)
                    .font(DumplingFont.display(44))
                    .foregroundStyle(CarbonColor.textPrimary)
                    .scaleEffect(animateResult ? 1.0 : 0.9)
                    .opacity(animateResult ? 1.0 : 0)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            animateResult = true
                        }
                    }
                    .accessibilityLabel("Classification result: \(result.displayLabel) with \(Int(result.partyConfidence * 100)) percent confidence")

                ConfidenceLabel(result.partyConfidence, color: accentColor)
            }
            .padding(.vertical, CarbonSpacing.spacing06)

            Spacer()

            // Action buttons — positioned in the thumb zone
            HStack(spacing: CarbonSpacing.spacing04) {
                GlassButton("Try Again", color: CarbonColor.textSecondary, action: onTryAgain)
                if result.isDumpling, let image {
                    ShareLink(
                        item: Image(decorative: image, scale: 1.0),
                        preview: SharePreview(result.displayLabel)
                    ) {
                        Text("Share")
                            .font(DumplingFont.medium(14))
                            .foregroundStyle(CarbonColor.supportSuccess)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .padding(.horizontal, CarbonSpacing.spacing06)
                    }
                    .dumplingGlass(interactive: true)
                }
            }
            .padding(.horizontal, CarbonSpacing.spacing05)
            .padding(.bottom, CarbonSpacing.spacing08)
        }
    }
}
