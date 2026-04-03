import SwiftUI

struct SplashScreenView: View {
    private struct SplashLayout {
        let isWide: Bool
        let outerPadding: CGFloat
        let topInset: CGFloat
        let heroMaxWidth: CGFloat
        let heroHeight: CGFloat
        let overlayPadding: CGFloat
        let copyMaxWidth: CGFloat
        let titleFont: Font
        let subtitleFont: Font
        let haloSize: CGFloat
        let emblemSize: CGFloat
        let logoSize: CGFloat

        init(size: CGSize) {
            let wide = size.width >= 900
            isWide = wide
            outerPadding = wide ? 36 : 18
            topInset = wide ? max(36, size.height * 0.08) : max(22, size.height * 0.08)
            heroMaxWidth = wide ? min(size.width - 72, 1_200) : min(size.width - 24, 430)
            heroHeight = wide ? 560 : 440
            overlayPadding = wide ? 32 : 22
            copyMaxWidth = wide ? 420 : 300
            titleFont = wide
                ? Font.system(size: 54, weight: .bold, design: .serif)
                : Font.system(size: 40, weight: .bold, design: .serif)
            subtitleFont = wide
                ? Font.system(size: 21, weight: .semibold, design: .rounded)
                : Font.system(size: 18, weight: .semibold, design: .rounded)
            haloSize = wide ? 280 : 190
            emblemSize = wide ? 136 : 88
            logoSize = wide ? 66 : 44
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
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @Environment(\.colorScheme) private var colorScheme
    @State private var isActive = false
    @State private var scale = 0.97
    @State private var opacity = 0.0

    private var effectiveReduceMotion: Bool {
        appRuntimeOverrides.resolvedReduceMotion(systemValue: accessibilityReduceMotion)
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

    private var featuredImageURL: URL? {
        let featuredEntry = fetcher.apodData.last ?? fetcher.currentNasa
        guard featuredEntry.mediaType == .image else { return nil }
        return featuredEntry.url ?? featuredEntry.hdurl
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
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    if let animation = AppTheme.Motion.reveal(reduceMotion: effectiveReduceMotion) {
                        withAnimation(animation) {
                            scale = 1.0
                            opacity = 1.0
                        }
                    } else {
                        scale = 1.0
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
        ZStack(alignment: .bottomLeading) {
            heroBackground(layout: layout)

            LinearGradient(
                colors: [
                    Color.black.opacity(isDarkMode ? 0.06 : 0.02),
                    Color.black.opacity(isDarkMode ? 0.18 : 0.08),
                    AppTheme.panelFallbackColor(isDarkMode: isDarkMode).opacity(isDarkMode ? 0.74 : 0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            splashCopy(layout: layout)
        }
        .frame(maxWidth: layout.heroMaxWidth)
        .frame(height: layout.heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode).opacity(0.85), lineWidth: 1)
        }
        .shadow(color: accentColor.opacity(isDarkMode ? 0.18 : 0.1), radius: 26, y: 16)
        .padding(.horizontal, layout.outerPadding)
    }

    @ViewBuilder
    private func heroBackground(layout: SplashLayout) -> some View {
        if let featuredImageURL {
            AsyncImage(url: featuredImageURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackHeroBackground(layout: layout)
                }
            }
        } else {
            fallbackHeroBackground(layout: layout)
        }
    }

    @ViewBuilder
    private func fallbackHeroBackground(layout: SplashLayout) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    accentColor.opacity(isDarkMode ? 0.22 : 0.12),
                    AppTheme.panelFallbackColor(isDarkMode: isDarkMode),
                    AppTheme.panelFallbackColor(isDarkMode: isDarkMode)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accentColor.opacity(isDarkMode ? 0.24 : 0.15))
                .frame(width: layout.haloSize, height: layout.haloSize)
                .blur(radius: 18)

            RoundedRectangle(cornerRadius: layout.isWide ? 38 : 26, style: .continuous)
                .fill(Color.white.opacity(isDarkMode ? 0.08 : 0.18))
                .frame(width: layout.emblemSize, height: layout.emblemSize)
                .overlay {
                    RoundedRectangle(cornerRadius: layout.isWide ? 38 : 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(isDarkMode ? 0.18 : 0.3), lineWidth: 1)
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
    private func splashCopy(layout: SplashLayout) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(L10n.text("Space Briefing", default: "Space Briefing").uppercased())
                .font(AppTheme.Typography.metadata)
                .foregroundStyle(accentColor)
                .tracking(1.1)

            Text(L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day"))
                .font(layout.titleFont)
                .foregroundStyle(Color.white)
                .lineLimit(layout.isWide ? 2 : 3)
                .minimumScaleFactor(0.86)

            Text(L10n.text("splash.subtitle", default: "Daily space imagery, editorial context, and source links from NASA's APOD archive."))
                .font(layout.subtitleFont)
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(layout.isWide ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppTheme.Spacing.sm) {
                ProgressView()
                    .controlSize(.small)
                    .tint(accentColor)

                Text(L10n.text("splash.status.preparing", default: "Preparing today's briefing"))
                    .font(AppTheme.Typography.splashStatus)
                    .foregroundStyle(Color.white)
            }
            .padding(.top, AppTheme.Spacing.xs)

            Text(statusDetail)
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(layout.isWide ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: layout.copyMaxWidth, alignment: .leading)
        .padding(layout.overlayPadding)
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
