import SwiftUI

struct SplashScreenView: View {
    private struct SplashLayout {
        let isWide: Bool
        let outerPadding: CGFloat
        let topInset: CGFloat
        let heroMaxWidth: CGFloat
        let heroMinimumHeight: CGFloat
        let panelPadding: CGFloat
        let splitSpacing: CGFloat
        let contentSpacing: CGFloat
        let copyMaxWidth: CGFloat
        let stageWidth: CGFloat
        let stageHeight: CGFloat
        let statusMaxWidth: CGFloat
        let haloSize: CGFloat
        let emblemSize: CGFloat
        let logoSize: CGFloat
        let titleFont: Font
        let subtitleFont: Font
        let stageTitleFont: Font

        init(size: CGSize) {
            let wide = size.width >= 980
            isWide = wide
            outerPadding = wide ? 32 : 18
            topInset = wide ? max(32, size.height * 0.07) : max(18, size.height * 0.06)
            heroMaxWidth = wide ? min(size.width - 64, 1_320) : min(size.width - 24, 430)
            heroMinimumHeight = wide ? 500 : 430
            panelPadding = wide ? 30 : 20
            splitSpacing = wide ? 28 : 18
            contentSpacing = wide ? 20 : 16
            copyMaxWidth = wide ? 360 : 320
            stageWidth = wide ? min(size.width * 0.58, 760) : min(size.width - 40, 360)
            stageHeight = wide ? 430 : 260
            statusMaxWidth = wide ? 320 : .infinity
            haloSize = wide ? 260 : 180
            emblemSize = wide ? 132 : 88
            logoSize = wide ? 64 : 44
            titleFont = wide ? AppTheme.Typography.splashDisplayRegular : AppTheme.Typography.splashDisplayCompact
            subtitleFont = wide ? AppTheme.Typography.splashLeadRegular : AppTheme.Typography.splashLeadCompact
            stageTitleFont = wide
                ? Font.system(size: 30, weight: .bold, design: .serif)
                : Font.system(size: 22, weight: .bold, design: .serif)
        }
    }

    private enum SplashTiming {
        static let holdForUITest: UInt64 = 4_000_000_000
        static let fixtureModeDelay: UInt64 = 150_000_000
        static let successDelay: UInt64 = 450_000_000
        static let errorDelay: UInt64 = 450_000_000
        static let fetchCompletionPollDelay: UInt64 = 50_000_000
        static let maxAdditionalFetchWait: UInt64 = 1_500_000_000
    }

    @EnvironmentObject var fetcher: NasaCollectionFetcher
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @Environment(\.colorScheme) private var colorScheme
    @State private var isActive = false
    @State private var size = 0.96
    @State private var opacity = 0.0

    private var effectiveReduceMotion: Bool {
        appRuntimeOverrides.resolvedReduceMotion(systemValue: accessibilityReduceMotion)
    }

    private var effectiveReduceTransparency: Bool {
        appRuntimeOverrides.resolvedReduceTransparency(systemValue: accessibilityReduceTransparency)
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var primaryInk: Color {
        AppTheme.inkPrimary(isDarkMode: isDarkMode)
    }

    private var secondaryInk: Color {
        AppTheme.inkSecondary(isDarkMode: isDarkMode)
    }

    private var accentColor: Color {
        AppTheme.accentColor(isDarkMode: isDarkMode)
    }

    private var featuredEntry: NASA? {
        if let latestCached = fetcher.apodData.last {
            return latestCached
        }
        let current = fetcher.currentNasa
        guard current.date != nil || current.title != NASA.default.title || current.url != nil else {
            return nil
        }
        return current
    }

    private var featuredImageURL: URL? {
        guard let featuredEntry, featuredEntry.mediaType == .image else { return nil }
        return featuredEntry.url ?? featuredEntry.hdurl
    }

    private var featuredDate: String {
        APODDateDisplayPolicy.displayString(for: featuredEntry?.date)
    }

    private var featuredTitle: String {
        guard let title = featuredEntry?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day")
        }
        return title
    }

    private var featuredSummary: String {
        guard let explanation = featuredEntry?.explanation?.trimmingCharacters(in: .whitespacesAndNewlines), !explanation.isEmpty else {
            return L10n.text(
                "splash.featured.summary_fallback",
                default: "Curated from NASA's Astronomy Picture of the Day archive with editorial context, source details, and quick archive access."
            )
        }

        if explanation.count > 140 {
            let prefix = explanation.prefix(137).trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(prefix)..."
        }

        return explanation
    }

    private var statusDetail: String {
        if fetcher.error != nil, fetcher.isUsingCachedData {
            return L10n.text(
                "splash.status.cached_ready",
                default: "Opening with cached APOD context while the latest briefing catches up."
            )
        }

        if fetcher.isUsingCachedData || !fetcher.apodData.isEmpty {
            return L10n.text(
                "splash.status.cached_refresh",
                default: "Loading the latest APOD while keeping archived context and source details ready."
            )
        }

        return L10n.text(
            "splash.status.detail",
            default: "Loading the latest APOD, archive context, and source details."
        )
    }

    var body: some View {
        if isActive {
            AppShellView()
        } else {
            GeometryReader { proxy in
                let layout = SplashLayout(size: proxy.size)

                ZStack {
                    SpaceBackdropView()
                        .accessibilityHidden(true)

                    VStack(spacing: 0) {
                        Spacer(minLength: layout.topInset)
                        heroSurface(layout: layout)
                        Spacer(minLength: AppTheme.Spacing.xl)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    if let animation = AppTheme.Motion.reveal(reduceMotion: effectiveReduceMotion) {
                        withAnimation(animation) {
                            size = 1.0
                            opacity = 1.0
                        }
                    } else {
                        size = 1.0
                        opacity = 1.0
                    }
                }
            }
            .accessibilityIdentifier("splashScreenRoot")
            .accessibilityElement(children: .contain)
            .task {
                guard !isActive else { return }
                let environment = ProcessInfo.processInfo.environment
                let holdSplashForUITest = environment["UITEST_HOLD_SPLASH"] == "1"
                let stayOnSplashForUITest = environment["UITEST_STAY_ON_SPLASH"] == "1"

                if !fetcher.isUsingFixtureData && fetcher.apodData.isEmpty {
                    fetcher.startLatestFetch()
                }

                if stayOnSplashForUITest {
                    return
                }

                let delay: UInt64
                if holdSplashForUITest {
                    delay = SplashTiming.holdForUITest
                } else {
                    delay = fetcher.isUsingFixtureData
                        ? SplashTiming.fixtureModeDelay
                        : (fetcher.error == nil ? SplashTiming.successDelay : SplashTiming.errorDelay)
                }

                try? await Task.sleep(nanoseconds: delay)
                if !fetcher.isUsingFixtureData {
                    await waitForFetchCompletion()
                }
                guard !Task.isCancelled else { return }
                if let animation = AppTheme.Motion.standard(reduceMotion: effectiveReduceMotion) {
                    withAnimation(animation) { isActive = true }
                } else {
                    isActive = true
                }
            }
        }
    }

    @ViewBuilder
    private func heroSurface(layout: SplashLayout) -> some View {
        MissionPanel(tone: .accent, padding: layout.panelPadding) {
            Group {
                if layout.isWide {
                    HStack(alignment: .center, spacing: layout.splitSpacing) {
                        heroStage(layout: layout)
                        copyColumn(layout: layout, alignment: .leading)
                    }
                } else {
                    VStack(spacing: layout.contentSpacing) {
                        heroStage(layout: layout)
                        copyColumn(layout: layout, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: layout.heroMinimumHeight, alignment: .center)
        }
        .frame(maxWidth: layout.heroMaxWidth)
        .padding(.horizontal, layout.outerPadding)
    }

    @ViewBuilder
    private func heroStage(layout: SplashLayout) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(isDarkMode ? 0.28 : 0.16),
                            AppTheme.panelFallbackColor(isDarkMode: isDarkMode).opacity(effectiveReduceTransparency ? 1.0 : 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let featuredImageURL {
                AsyncImage(url: featuredImageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: layout.stageWidth, height: layout.stageHeight)
                            .clipped()
                            .overlay {
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(isDarkMode ? 0.04 : 0.02),
                                        Color.black.opacity(isDarkMode ? 0.18 : 0.1),
                                        AppTheme.panelFallbackColor(isDarkMode: isDarkMode).opacity(isDarkMode ? 0.38 : 0.24)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                    default:
                        emblemFallbackStage(layout: layout)
                    }
                }
            } else {
                emblemFallbackStage(layout: layout)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    if featuredEntry != nil {
                        MissionBadge(
                            title: featuredEntry?.mediaType.localizedDisplayName ?? L10n.text("Image", default: "Image"),
                            systemImage: featuredStageSymbolName,
                            tone: .accent
                        )

                        MissionBadge(
                            title: featuredDate,
                            systemImage: "calendar",
                            tone: .neutral
                        )
                    } else {
                        SectionEyebrow(L10n.text("Space Briefing", default: "Space Briefing"), tone: .accent)
                    }
                }

                Text(featuredStageTitle)
                    .font(layout.stageTitleFont)
                    .foregroundStyle(Color.white)
                    .lineLimit(layout.isWide ? 3 : 2)
                    .minimumScaleFactor(0.84)

                Text(featuredSummary)
                    .font(AppTheme.Typography.footnoteStrong)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(layout.isWide ? 2 : 3)
            }
            .padding(layout.isWide ? 24 : 18)
        }
        .frame(width: layout.stageWidth, height: layout.stageHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode).opacity(0.9), lineWidth: 1)
        }
        .shadow(color: accentColor.opacity(isDarkMode ? 0.18 : 0.12), radius: 28, y: 16)
    }

    private var featuredStageTitle: String {
        featuredEntry != nil
            ? featuredTitle
            : L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day")
    }

    private var featuredStageSymbolName: String {
        switch featuredEntry?.mediaType {
        case .video:
            return "play.rectangle.fill"
        case .other:
            return "link"
        default:
            return "photo.on.rectangle.angled"
        }
    }

    @ViewBuilder
    private func emblemFallbackStage(layout: SplashLayout) -> some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(isDarkMode ? 0.24 : 0.16))
                .frame(width: layout.haloSize, height: layout.haloSize)
                .blur(radius: 18)

            Circle()
                .stroke(accentColor.opacity(isDarkMode ? 0.3 : 0.22), lineWidth: 1.5)
                .frame(width: layout.haloSize * 0.88, height: layout.haloSize * 0.88)

            RoundedRectangle(cornerRadius: layout.isWide ? 38 : 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDarkMode ? 0.08 : 0.18),
                            AppTheme.panelFallbackColor(isDarkMode: isDarkMode).opacity(effectiveReduceTransparency ? 1.0 : 0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: layout.emblemSize, height: layout.emblemSize)
                .overlay {
                    RoundedRectangle(cornerRadius: layout.isWide ? 38 : 26, style: .continuous)
                        .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode).opacity(0.85), lineWidth: 1)
                }

            Image("logo-swift-outlined")
                .resizable()
                .scaledToFit()
                .frame(width: layout.logoSize, height: layout.logoSize)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func copyColumn(layout: SplashLayout, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: layout.contentSpacing) {
            SectionEyebrow(L10n.text("Space Briefing", default: "Space Briefing"), tone: .accent)

            Text(L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day"))
                .font(layout.titleFont)
                .foregroundStyle(primaryInk)
                .multilineTextAlignment(layout.isWide ? .leading : .center)
                .lineLimit(layout.isWide ? 2 : 3)
                .minimumScaleFactor(0.86)

            Text(L10n.text("splash.subtitle", default: "Daily space imagery, editorial context, and source links from NASA's APOD archive."))
                .font(layout.subtitleFont)
                .foregroundStyle(secondaryInk)
                .multilineTextAlignment(layout.isWide ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)

            splashStatusCard(layout: layout)

            Text(AppBrandingPolicy.independentNotice())
                .font(AppTheme.Typography.metadata)
                .foregroundStyle(secondaryInk.opacity(0.82))
                .multilineTextAlignment(layout.isWide ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: layout.copyMaxWidth, alignment: layout.isWide ? .leading : .center)
    }

    @ViewBuilder
    private func splashStatusCard(layout: SplashLayout) -> some View {
        VStack(alignment: layout.isWide ? .leading : .center, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ProgressView()
                    .controlSize(.small)
                    .tint(accentColor)

                Text(L10n.text("splash.status.preparing", default: "Preparing today's briefing"))
                    .font(AppTheme.Typography.splashStatus)
                    .foregroundStyle(primaryInk)
            }

            Text(statusDetail)
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(secondaryInk)
                .multilineTextAlignment(layout.isWide ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: layout.statusMaxWidth, alignment: layout.isWide ? .leading : .center)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .fill(accentColor.opacity(isDarkMode ? 0.12 : 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                        .stroke(accentColor.opacity(isDarkMode ? 0.24 : 0.18), lineWidth: 1)
                }
        }
    }

    private func waitForFetchCompletion() async {
        var waited: UInt64 = 0
        while fetcher.isFetching && waited < SplashTiming.maxAdditionalFetchWait {
            try? await Task.sleep(nanoseconds: SplashTiming.fetchCompletionPollDelay)
            waited += SplashTiming.fetchCompletionPollDelay
            if Task.isCancelled { return }
        }
    }
}
