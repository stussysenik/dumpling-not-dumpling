import SwiftUI

struct ModeToggle: View {
    @Binding var mode: AppMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppMode.allCases, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        mode = option
                    }
                } label: {
                    Text(option.rawValue.capitalized)
                        .font(DumplingFont.medium(14))
                        .foregroundStyle(mode == option ? Color.white : CarbonColor.textSecondary)
                        .padding(.horizontal, CarbonSpacing.spacing06)
                        .padding(.vertical, 10)
                        .background {
                            if mode == option {
                                Capsule()
                                    .fill(CarbonColor.textPrimary)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .dumplingGlass(shape: .capsule)
    }
}
