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

enum AppShellContext {
    case compactTabs
    case premiumRegularShell
}

private struct AppShellContextKey: EnvironmentKey {
    static let defaultValue: AppShellContext = .compactTabs
}

extension EnvironmentValues {
    var appShellContext: AppShellContext {
        get { self[AppShellContextKey.self] }
        set { self[AppShellContextKey.self] = newValue }
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

struct PremiumShellStage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    let tone: AppTheme.SurfaceTone
    private let content: Content

    init(
        tone: AppTheme.SurfaceTone = .neutral,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.content = content()
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var effectiveReduceTransparency: Bool {
        appRuntimeOverrides.resolvedReduceTransparency(systemValue: accessibilityReduceTransparency)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(
                    cornerRadius: AppTheme.Metrics.shellStageCornerRadius,
                    style: .continuous
                )
                .fill(AppTheme.adaptiveSurface(
                    isDarkMode: isDarkMode,
                    reduceTransparency: effectiveReduceTransparency
                ))
                .overlay {
                    RoundedRectangle(
                        cornerRadius: AppTheme.Metrics.shellStageCornerRadius,
                        style: .continuous
                    )
                    .fill(AppTheme.panelOverlayGradient(isDarkMode: isDarkMode, tone: tone))
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: AppTheme.Metrics.shellStageCornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: 1)
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppTheme.Metrics.shellStageCornerRadius,
                    style: .continuous
                )
            )
            .shadow(
                color: AppTheme.panelShadow(isDarkMode: isDarkMode, tone: tone),
                radius: 26,
                y: 16
            )
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

struct MissionPanelHeader<Accessory: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let eyebrow: String
    let title: String
    let summary: String
    let tone: AppTheme.SurfaceTone
    private let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        summary: String,
        tone: AppTheme.SurfaceTone = .accent,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.summary = summary
        self.tone = tone
        self.accessory = accessory()
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var hasAccessory: Bool {
        !(Accessory.self == EmptyView.self)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                textContent
                if hasAccessory {
                    Spacer(minLength: 0)
                    accessory
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                textContent
                if hasAccessory {
                    accessory
                }
            }
        }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            SectionEyebrow(eyebrow, tone: tone)

            Text(title)
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .accessibilityAddTraits(.isHeader)

            Text(summary)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MissionSupportPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let eyebrow: String
    let title: String?
    let summary: String?
    let tone: AppTheme.SurfaceTone
    let padding: CGFloat
    private let content: Content

    init(
        eyebrow: String,
        title: String? = nil,
        summary: String? = nil,
        tone: AppTheme.SurfaceTone = .neutral,
        padding: CGFloat = AppTheme.Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.summary = summary
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        MissionPanel(tone: tone, padding: padding) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionEyebrow(eyebrow, tone: tone)

                if let title {
                    Text(title)
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let summary {
                    Text(summary)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                        .fixedSize(horizontal: false, vertical: true)
                }

                content
            }
        }
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
    let accessibilityIdentifier: String?
    private let actions: Actions

    init(
        eyebrow: String,
        title: String,
        message: String,
        systemImage: String,
        tone: AppTheme.SurfaceTone = .neutral,
        showsProgress: Bool = false,
        minHeight: CGFloat = 220,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tone = tone
        self.showsProgress = showsProgress
        self.minHeight = minHeight
        self.accessibilityIdentifier = accessibilityIdentifier
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
                            .accessibilityIdentifier(accessibilityIdentifier ?? "")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

struct LibrarySelectionPlaceholderView: View {
    let eyebrow: String
    let title: String
    let message: String
    let systemImage: String
    let tone: AppTheme.SurfaceTone

    var body: some View {
        MissionStateCard(
            eyebrow: eyebrow,
            title: title,
            message: message,
            systemImage: systemImage,
            tone: tone
        )
        .frame(maxWidth: 620, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SpaceBackdropView())
    }
}

struct AboutSourceRightsPanel: View {
    @Environment(\.colorScheme) private var colorScheme

    let sourceURL: URL?
    let sourceTitle: String
    let sourceSummary: String
    let tone: AppTheme.SurfaceTone

    init(
        sourceURL: URL?,
        sourceTitle: String = AppBrandingPolicy.officialSourceLinkTitle(),
        sourceSummary: String = AppBrandingPolicy.officialSourceLinkSummary(),
        tone: AppTheme.SurfaceTone = .neutral
    ) {
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.sourceSummary = sourceSummary
        self.tone = tone
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        MissionPanel(tone: tone, padding: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionEyebrow(AppBrandingPolicy.compliancePanelEyebrow(), tone: tone)

                Text(AppBrandingPolicy.compliancePanelTitle())
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(AppBrandingPolicy.independentNotice())
                    Text(AppBrandingPolicy.dataSourceNotice())
                    Text(AppBrandingPolicy.rightsGuidance())
                }
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                .fixedSize(horizontal: false, vertical: true)

                if let sourceURL {
                    Link(destination: sourceURL) {
                        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundStyle(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                Text(sourceTitle)
                                    .font(AppTheme.Typography.actionLabel)
                                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))

                                Text(sourceSummary)
                                    .font(AppTheme.Typography.footnote)
                                    .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                                .fill(AppTheme.toneColor(tone, isDarkMode: isDarkMode).opacity(isDarkMode ? 0.14 : 0.1))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                                .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: 1)
                        }
                    }
                    .accessibilityHint(
                        L10n.text(
                            "brand.source_link_hint",
                            default: "Opens the official APOD source in the browser."
                        )
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.aboutSourceRightsPanel)
        }
    }
}

struct MonetizationPaywallView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    let context: PaywallPresentation

    private var priceLine: String {
        purchaseManager.proLifetimeProduct?.displayPrice
            ?? L10n.text("paywall.price_fallback", default: "One-time purchase")
    }

    private var productName: String {
        purchaseManager.proLifetimeProduct?.displayName ?? AppProduct.proLifetime.fallbackDisplayName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                MissionPanel(tone: .accent, padding: AppTheme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        MissionPanelHeader(
                            eyebrow: L10n.text("paywall.eyebrow", default: "Space Briefing Pro"),
                            title: L10n.text("paywall.title", default: "Unlock the full space experience"),
                            summary: L10n.text(
                                "paywall.subtitle",
                                default: "Get the full NASA archive, HD saves, beautiful widgets, favorites, and an ad-free experience."
                            ),
                            tone: .accent
                        ) {
                            MissionBadge(
                                title: productName,
                                systemImage: "sparkles",
                                tone: .accent
                            )
                        }

                        MissionBadge(
                            title: priceLine,
                            systemImage: "creditcard.fill",
                            tone: .favorite
                        )
                        .accessibilityIdentifier(AccessibilityID.paywallPriceText)

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            paywallBullet(
                                title: L10n.text("paywall.bullet.archive", default: "Full archive by date"),
                                systemImage: "books.vertical.fill"
                            )
                            paywallBullet(
                                title: L10n.text("paywall.bullet.hd_save", default: "Save in HD"),
                                systemImage: "arrow.down.circle.fill"
                            )
                            paywallBullet(
                                title: L10n.text("paywall.bullet.widgets", default: "All widgets unlocked"),
                                systemImage: "rectangle.3.group.fill"
                            )
                            paywallBullet(
                                title: L10n.text("paywall.bullet.favorites", default: "Unlimited favorites"),
                                systemImage: "bookmark.fill"
                            )
                            paywallBullet(
                                title: L10n.text("paywall.bullet.ads", default: "No ads"),
                                systemImage: "nosign"
                            )
                        }

                        if let paywallMessage = purchaseManager.paywallMessage, !paywallMessage.isEmpty {
                            Text(paywallMessage)
                                .font(AppTheme.Typography.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Button {
                                Task {
                                    await purchaseManager.purchaseLifetimeUnlock()
                                }
                            } label: {
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    if purchaseManager.isPurchasing {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "sparkles")
                                            .accessibilityHidden(true)
                                    }
                                    Text(L10n.text("paywall.cta.unlock", default: "Unlock Lifetime"))
                                        .font(AppTheme.Typography.buttonLabel)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.Palette.accentHighlight)
                            .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoring)
                            .accessibilityIdentifier(AccessibilityID.paywallUnlockButton)

                            Button {
                                Task {
                                    await purchaseManager.restorePurchases()
                                }
                            } label: {
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    if purchaseManager.isRestoring {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .accessibilityHidden(true)
                                    }
                                    Text(L10n.text("paywall.cta.restore", default: "Restore Purchases"))
                                        .font(AppTheme.Typography.buttonLabel)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoring)
                            .accessibilityIdentifier(AccessibilityID.paywallRestoreButton)

                            Button(L10n.text("paywall.cta.continue_free", default: "Continue with Free")) {
                                purchaseManager.dismissPaywall()
                            }
                            .buttonStyle(.plain)
                            .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoring)
                            .accessibilityIdentifier(AccessibilityID.paywallContinueButton)
                        }

                        Text(
                            L10n.text(
                                "paywall.footer",
                                default: "Images and metadata courtesy of NASA/APOD. This app is not affiliated with or endorsed by NASA."
                            )
                        )
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .background(SpaceBackdropView())
        .accessibilityIdentifier(AccessibilityID.paywallRoot)
        .interactiveDismissDisabled(purchaseManager.isPurchasing || purchaseManager.isRestoring)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private func paywallBullet(title: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.Palette.accentHighlight)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTheme.Typography.actionLabel)
                .foregroundStyle(.primary)
        }
    }
}
