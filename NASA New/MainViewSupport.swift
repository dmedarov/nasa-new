import SwiftUI
import UIKit
import SafariServices

struct AccessibilityMarker: View {
    let identifier: String

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityIdentifier(identifier)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct AdaptiveNavigationContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct AppEnvironmentOverrideContainer<Content: View>: View {
    let overrides: AppEnvironmentOverrides
    let preferredColorScheme: ColorScheme?
    private let content: Content

    init(
        overrides: AppEnvironmentOverrides,
        preferredColorScheme: ColorScheme? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.overrides = overrides
        self.preferredColorScheme = preferredColorScheme
        self.content = content()
    }

    var body: some View {
        applyOverrides(to: AnyView(content))
    }

    private func applyOverrides(to root: AnyView) -> AnyView {
        var view = AnyView(root.environment(\.appRuntimeOverrides, overrides))

        if let locale = overrides.locale {
            view = AnyView(view.environment(\.locale, locale))
        }
        if let dynamicTypeSize = overrides.dynamicTypeSize {
            view = AnyView(view.environment(\.dynamicTypeSize, dynamicTypeSize))
        }
        if let resolvedColorScheme = overrides.colorScheme ?? preferredColorScheme {
            view = AnyView(view.preferredColorScheme(resolvedColorScheme))
        }

        return view
    }
}

struct AppEnvironmentOverrides {
    let locale: Locale?
    let dynamicTypeSize: DynamicTypeSize?
    let colorScheme: ColorScheme?
    let increasedContrast: Bool?
    let reduceMotion: Bool?
    let reduceTransparency: Bool?
    let differentiateWithoutColor: Bool?

    static let none = AppEnvironmentOverrides()
    static let current = AppEnvironmentOverrides(environment: ProcessInfo.processInfo.environment)

    init(
        locale: Locale? = nil,
        dynamicTypeSize: DynamicTypeSize? = nil,
        colorScheme: ColorScheme? = nil,
        increasedContrast: Bool? = nil,
        reduceMotion: Bool? = nil,
        reduceTransparency: Bool? = nil,
        differentiateWithoutColor: Bool? = nil
    ) {
        self.locale = locale
        self.dynamicTypeSize = dynamicTypeSize
        self.colorScheme = colorScheme
        self.increasedContrast = increasedContrast
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.differentiateWithoutColor = differentiateWithoutColor
    }

    init(environment: [String: String]) {
        locale = environment["UITEST_LOCALE"].flatMap(Locale.init(identifier:))
        dynamicTypeSize = Self.dynamicTypeSize(from: environment["UITEST_DYNAMIC_TYPE_SIZE"])
        colorScheme = Self.colorScheme(from: environment["UITEST_FORCE_COLOR_SCHEME"])
        increasedContrast = Self.increasedContrast(from: environment["UITEST_COLOR_SCHEME_CONTRAST"])
        reduceMotion = Self.boolValue(from: environment["UITEST_REDUCE_MOTION"])
        reduceTransparency = Self.boolValue(from: environment["UITEST_REDUCE_TRANSPARENCY"])
        differentiateWithoutColor = Self.boolValue(from: environment["UITEST_DIFFERENTIATE_WITHOUT_COLOR"])
    }

    func resolvedReduceMotion(systemValue: Bool) -> Bool {
        reduceMotion ?? systemValue
    }

    func resolvedReduceTransparency(systemValue: Bool) -> Bool {
        reduceTransparency ?? systemValue
    }

    func resolvedDifferentiateWithoutColor(systemValue: Bool) -> Bool {
        differentiateWithoutColor ?? systemValue
    }

    func resolvedIncreasedContrast(systemValue: Bool = false) -> Bool {
        increasedContrast ?? systemValue
    }

    private static func boolValue(from rawValue: String?) -> Bool? {
        guard let rawValue else { return nil }
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }

    private static func colorScheme(from rawValue: String?) -> ColorScheme? {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    private static func increasedContrast(from rawValue: String?) -> Bool? {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "standard":
            return false
        case "increased", "high":
            return true
        default:
            return nil
        }
    }

    private static func dynamicTypeSize(from rawValue: String?) -> DynamicTypeSize? {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "xsmall":
            return .xSmall
        case "small":
            return .small
        case "medium":
            return .medium
        case "large":
            return .large
        case "xlarge":
            return .xLarge
        case "xxlarge":
            return .xxLarge
        case "xxxlarge":
            return .xxxLarge
        case "accessibility1":
            return .accessibility1
        case "accessibility2":
            return .accessibility2
        case "accessibility3":
            return .accessibility3
        case "accessibility4":
            return .accessibility4
        case "accessibility5":
            return .accessibility5
        default:
            return nil
        }
    }
}

private struct AppRuntimeOverridesKey: EnvironmentKey {
    static let defaultValue = AppEnvironmentOverrides.none
}

extension EnvironmentValues {
    var appRuntimeOverrides: AppEnvironmentOverrides {
        get { self[AppRuntimeOverridesKey.self] }
        set { self[AppRuntimeOverridesKey.self] = newValue }
    }
}

struct SpaceBackdropView: View {
    @Environment(\.colorScheme) private var colorScheme

    private struct StarPoint: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private static let starField: [StarPoint] = [
        StarPoint(x: 0.08, y: 0.11, size: 2.4, opacity: 0.8),
        StarPoint(x: 0.14, y: 0.21, size: 1.8, opacity: 0.55),
        StarPoint(x: 0.2, y: 0.07, size: 2.1, opacity: 0.72),
        StarPoint(x: 0.27, y: 0.18, size: 1.6, opacity: 0.48),
        StarPoint(x: 0.34, y: 0.09, size: 2.0, opacity: 0.62),
        StarPoint(x: 0.42, y: 0.26, size: 1.5, opacity: 0.45),
        StarPoint(x: 0.5, y: 0.12, size: 2.2, opacity: 0.66),
        StarPoint(x: 0.58, y: 0.19, size: 1.6, opacity: 0.52),
        StarPoint(x: 0.65, y: 0.08, size: 2.0, opacity: 0.62),
        StarPoint(x: 0.73, y: 0.24, size: 1.8, opacity: 0.54),
        StarPoint(x: 0.81, y: 0.14, size: 2.5, opacity: 0.78),
        StarPoint(x: 0.89, y: 0.21, size: 1.4, opacity: 0.44),
        StarPoint(x: 0.93, y: 0.09, size: 1.9, opacity: 0.52),
        StarPoint(x: 0.11, y: 0.39, size: 1.7, opacity: 0.4),
        StarPoint(x: 0.31, y: 0.34, size: 1.4, opacity: 0.38),
        StarPoint(x: 0.67, y: 0.37, size: 1.5, opacity: 0.42),
        StarPoint(x: 0.84, y: 0.31, size: 1.7, opacity: 0.46),
        StarPoint(x: 0.9, y: 0.42, size: 2.1, opacity: 0.58)
    ]

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.backgroundGradient(isDarkMode: isDarkMode)

                Circle()
                    .fill(AppTheme.primaryOrbColor(isDarkMode: isDarkMode))
                    .frame(width: min(proxy.size.width * 0.72, 420), height: min(proxy.size.width * 0.72, 420))
                    .offset(x: proxy.size.width * 0.28, y: -proxy.size.height * 0.2)
                    .blur(radius: 8)

                Circle()
                    .fill(AppTheme.secondaryOrbColor(isDarkMode: isDarkMode))
                    .frame(width: min(proxy.size.width * 0.9, 520), height: min(proxy.size.width * 0.9, 520))
                    .offset(x: -proxy.size.width * 0.32, y: proxy.size.height * 0.22)
                    .blur(radius: 10)

                Canvas { context, size in
                    let starColor = isDarkMode
                        ? AppTheme.Palette.accentHighlight
                        : AppTheme.Palette.accentLight

                    for star in Self.starField {
                        let rect = CGRect(
                            x: size.width * star.x,
                            y: size.height * star.y,
                            width: star.size,
                            height: star.size
                        )
                        context.opacity = star.opacity * (isDarkMode ? 1 : 0.55)
                        context.fill(Path(ellipseIn: rect), with: .color(starColor))
                    }
                }
                .blendMode(.screen)

                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(isDarkMode ? 0.16 : 0.04)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

#if DEBUG
enum MainViewPreviewScenario {
    case defaultImage
    case longExplanation
    case offlineCached
    case rateLimited
    case loadFailure
    case noMedia
}

enum MainViewPreviewFactory {
    @MainActor
    static func fetcher(for scenario: MainViewPreviewScenario) -> NasaCollectionFetcher {
        let fetcher = NasaCollectionFetcher()
        fetcher.favorites = []
        fetcher.apiKeyWarning = nil

        switch scenario {
        case .defaultImage:
            fetcher.applyFixtureScenario(.default)
        case .longExplanation:
            fetcher.applyFixtureScenario(.longExplanation)
        case .offlineCached:
            fetcher.applyFixtureScenario(.offlineCached)
        case .rateLimited:
            fetcher.applyFixtureScenario(.rateLimited)
        case .loadFailure:
            fetcher.applyFixtureScenario(.loadFailure)
        case .noMedia:
            fetcher.applyFixtureScenario(.noMedia)
        }

        return fetcher
    }
}

@MainActor
struct MainViewPreviewHost: View {
    @StateObject private var fetcher: NasaCollectionFetcher
    private let overrides: AppEnvironmentOverrides

    init(
        scenario: MainViewPreviewScenario,
        overrides: AppEnvironmentOverrides = .none
    ) {
        _fetcher = StateObject(wrappedValue: MainViewPreviewFactory.fetcher(for: scenario))
        self.overrides = overrides
    }

    var body: some View {
        AppEnvironmentOverrideContainer(overrides: overrides) {
            AdaptiveNavigationContainer {
                MainView()
            }
            .environmentObject(fetcher)
        }
    }
}
#endif

struct MissionPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    let tone: AppTheme.SurfaceTone
    let padding: CGFloat
    private let content: Content

    init(
        tone: AppTheme.SurfaceTone = .neutral,
        padding: CGFloat = AppTheme.Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var effectiveReduceTransparency: Bool {
        appRuntimeOverrides.resolvedReduceTransparency(systemValue: accessibilityReduceTransparency)
    }

    private var isIncreasedContrast: Bool {
        appRuntimeOverrides.resolvedIncreasedContrast()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.adaptiveSurface(
                        isDarkMode: isDarkMode,
                        reduceTransparency: effectiveReduceTransparency
                    ))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                            .fill(AppTheme.panelOverlayGradient(isDarkMode: isDarkMode, tone: tone))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                            .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: isIncreasedContrast ? 1.5 : 1)
                    }
            }
            .shadow(color: AppTheme.panelShadow(isDarkMode: isDarkMode, tone: tone), radius: 22, y: 12)
    }
}

struct MissionBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    let title: String
    let systemImage: String
    let tone: AppTheme.SurfaceTone

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var isIncreasedContrast: Bool {
        appRuntimeOverrides.resolvedIncreasedContrast()
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AppTheme.Typography.metadata)
            .foregroundStyle(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.toneColor(tone, isDarkMode: isDarkMode).opacity(isIncreasedContrast ? (isDarkMode ? 0.24 : 0.16) : (isDarkMode ? 0.16 : 0.1)))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(AppTheme.toneColor(tone, isDarkMode: isDarkMode).opacity(isIncreasedContrast ? (isDarkMode ? 0.58 : 0.34) : (isDarkMode ? 0.36 : 0.18)), lineWidth: isIncreasedContrast ? 1.5 : 1)
            }
            .lineLimit(1)
            .accessibilityElement(children: .combine)
    }
}

struct SectionEyebrow: View {
    let text: String
    let tone: AppTheme.SurfaceTone

    init(_ text: String, tone: AppTheme.SurfaceTone = .accent) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        MissionBadge(title: text.uppercased(), systemImage: "sparkles", tone: tone)
    }
}

struct MissionStateCard<Actions: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let eyebrow: String
    let title: String
    let message: String
    let systemImage: String
    let tone: AppTheme.SurfaceTone
    let showsProgress: Bool
    let minHeight: CGFloat
    private let actions: Actions

    init(
        eyebrow: String,
        title: String,
        message: String,
        systemImage: String,
        tone: AppTheme.SurfaceTone = .neutral,
        showsProgress: Bool = false,
        minHeight: CGFloat = 220,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tone = tone
        self.showsProgress = showsProgress
        self.minHeight = minHeight
        self.actions = actions()
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var actionsLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(spacing: AppTheme.Spacing.sm))
        }
        return AnyLayout(HStackLayout(spacing: AppTheme.Spacing.sm))
    }

    var body: some View {
        MissionPanel(tone: tone, padding: AppTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.toneColor(tone, isDarkMode: isDarkMode).opacity(isDarkMode ? 0.18 : 0.12))
                            .frame(width: 58, height: 58)
                        if showsProgress {
                            ProgressView()
                                .tint(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
                        } else {
                            Image(systemName: systemImage)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
                                .accessibilityHidden(true)
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        SectionEyebrow(eyebrow, tone: tone)
                        Text(title)
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                        Text(message)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !(Actions.self == EmptyView.self) {
                    actionsLayout {
                        actions
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }
}
