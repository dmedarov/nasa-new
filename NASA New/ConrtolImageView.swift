import SwiftUI

struct ControlImageView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title3) private var iconSize = 28
    let icon: String
    let accessibilityLabel: String

    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: .semibold, design: .rounded))
            .frame(width: 44, height: 44)
            .foregroundStyle(AppTheme.accentColor(isDarkMode: isDarkMode))
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                    .fill(AppTheme.toneColor(.neutral, isDarkMode: isDarkMode).opacity(isDarkMode ? 0.12 : 0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: 1)
            }
            .accessibilityLabel(accessibilityLabel)
    }
}

struct ControlImageView_Previews: PreviewProvider {
    static var previews: some View {
        ControlImageView(icon: "minus.magnifyingglass", accessibilityLabel: "Zoom out")
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
