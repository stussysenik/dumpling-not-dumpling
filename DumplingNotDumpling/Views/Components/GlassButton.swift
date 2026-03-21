import SwiftUI

struct GlassButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    init(_ title: String, color: Color = CarbonColor.textSecondary, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DumplingFont.medium(14))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48) // Carbon min tap target
                .padding(.horizontal, CarbonSpacing.spacing06)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
    }
}
