import SwiftUI

struct ControlImageView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title3) private var iconSize = 28
    let icon: String
    let accessibilityLabel: String
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: iconSize))
            .frame(width: 44, height: 44)
            .foregroundColor(colorScheme == .dark ? .white : .indigo)
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
