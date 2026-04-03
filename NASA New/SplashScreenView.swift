import SwiftUI

struct SplashScreenView: View {
    private struct SplashLayout {
        let isWide: Bool
        let outerPadding: CGFloat
        let topInset: CGFloat
        let heroMaxWidth: CGFloat
        let heroMinimumHeight: CGFloat
        let panelPadding: CGFloat
        let columnSpacing: CGFloat
        let contentSpacing: CGFloat
        let copyMaxWidth: CGFloat
        let emblemSize: CGFloat
        let haloSize: CGFloat
        let logoSize: CGFloat
        let titleFont: Font
        let subtitleFont: Font

        init(size: CGSize) {
            let wide = size.width >= 900
            isWide = wide
            outerPadding = wide ? 40 : 24
            topInset = wide ? max(56, size.height * 0.14) : max(32, size.height * 0.12)
            heroMaxWidth = wide ? min(size.width - 80, 1120) : min(size.width - 48, 420)
            heroMinimumHeight = wide ? 420 : 344
            panelPadding = wide ? 40 : 28
            columnSpacing = wide ? 56 : 24
            contentSpacing = wide ? 20 : 14
            copyMaxWidth = wide ? 470 : 320
            emblemSize = wide ? 272 : 124
            haloSize = wide ? 360 : 168
            logoSize = wide ? 128 : 76
            titleFont = wide ? AppTheme.Typography.splashDisplayRegular : AppTheme.Typography.splashDisplayCompact
            subtitleFont = wide ? AppTheme.Typography.splashLeadRegular : AppTheme.Typography.splashLeadCompact
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
    @State private var size = 0.94
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
                    // Begin loading immediately without blocking splash timing.
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
                    HStack(alignment: .center, spacing: layout.columnSpacing) {
                        copyColumn(layout: layout, alignment: .leading)
                        Spacer(minLength: 0)
                        emblemStage(layout: layout)
                    }
                } else {
                    VStack(spacing: layout.contentSpacing) {
                        emblemStage(layout: layout)
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
    private func copyColumn(layout: SplashLayout, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: layout.contentSpacing) {
            SectionEyebrow(L10n.text("Space Briefing", default: "Space Briefing"), tone: .accent)

            Text(L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day"))
                .font(layout.titleFont)
                .foregroundStyle(primaryInk)
                .multilineTextAlignment(layout.isWide ? .leading : .center)
                .lineLimit(3)
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
    private func emblemStage(layout: SplashLayout) -> some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(isDarkMode ? 0.16 : 0.12))
                .frame(width: layout.haloSize, height: layout.haloSize)
                .blur(radius: 20)

            Circle()
                .stroke(accentColor.opacity(isDarkMode ? 0.24 : 0.18), lineWidth: 1.5)
                .frame(width: layout.haloSize * 0.92, height: layout.haloSize * 0.92)

            RoundedRectangle(cornerRadius: layout.isWide ? 46 : 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(isDarkMode ? 0.34 : 0.22),
                            AppTheme.panelFallbackColor(isDarkMode: isDarkMode).opacity(effectiveReduceTransparency ? 1.0 : 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: layout.isWide ? 46 : 30, style: .continuous)
                        .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode).opacity(0.9), lineWidth: 1)
                }
                .frame(width: layout.emblemSize, height: layout.emblemSize)
                .shadow(color: accentColor.opacity(isDarkMode ? 0.22 : 0.12), radius: 30, y: 16)

            Image("logo-swift-outlined")
                .resizable()
                .scaledToFit()
                .frame(width: layout.logoSize, height: layout.logoSize)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: layout.isWide ? layout.haloSize : .infinity)
        .padding(.vertical, layout.isWide ? 0 : AppTheme.Spacing.xs)
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

            Text(
                L10n.text(
                    "splash.status.detail",
                    default: "Loading the latest APOD, archive context, and source details."
                )
            )
            .font(AppTheme.Typography.footnote)
            .foregroundStyle(secondaryInk)
            .multilineTextAlignment(layout.isWide ? .leading : .center)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: layout.isWide ? 340 : .infinity, alignment: layout.isWide ? .leading : .center)
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
