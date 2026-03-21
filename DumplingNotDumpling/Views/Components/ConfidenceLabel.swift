import SwiftUI

struct ConfidenceLabel: View {
    let confidence: Float
    let color: Color
    let showPrefix: Bool

    init(_ confidence: Float, color: Color, showPrefix: Bool = true) {
        self.confidence = confidence
        self.color = color
        self.showPrefix = showPrefix
    }

    var body: some View {
        Text(showPrefix ? "confidence: \(String(format: "%.2f", confidence))" : String(format: "%.2f", confidence))
            .font(DumplingFont.mono(13))
            .foregroundStyle(color)
    }
}
