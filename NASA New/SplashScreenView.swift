import SwiftUI

struct SplashScreenView: View {
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
    @State private var isActive = false
    @State private var size = 0.94
    @State private var opacity = 0.0

    private var effectiveReduceMotion: Bool {
        appRuntimeOverrides.resolvedReduceMotion(systemValue: accessibilityReduceMotion)
    }
    
    var body: some View {
        if isActive {
            AppShellView()
        } else {
            ZStack {
                SpaceBackdropView()
                    .accessibilityHidden(true)

                MissionPanel(tone: .accent, padding: AppTheme.Spacing.xxl) {
                    VStack(spacing: AppTheme.Spacing.md) {
                        SectionEyebrow(L10n.text("Space Briefing", default: "Space Briefing"), tone: .accent)

                        Image("logo-swift-outlined")
                            .accessibilityHidden(true)

                        Text(L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day"))
                            .font(AppTheme.Typography.splashTitle)
                            .foregroundColor(AppTheme.Palette.splashText)
                            .multilineTextAlignment(.center)

                        Text(L10n.text("Daily space imagery, editorial context, and source links from NASA’s APOD archive.", default: "Daily space imagery, editorial context, and source links from NASA’s APOD archive."))
                            .font(AppTheme.Typography.splashCaption)
                            .foregroundColor(AppTheme.Palette.splashText)
                            .multilineTextAlignment(.center)

                        Text(
                            L10n.text(
                                "brand.independent_notice",
                                default: "Independent app using NASA's public APOD service. Not affiliated with or endorsed by NASA."
                            )
                        )
                        .font(AppTheme.Typography.metadata)
                        .foregroundColor(AppTheme.Palette.splashText.opacity(0.78))
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 420)
                }
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

    private func waitForFetchCompletion() async {
        var waited: UInt64 = 0
        while fetcher.isFetching && waited < SplashTiming.maxAdditionalFetchWait {
            try? await Task.sleep(nanoseconds: SplashTiming.fetchCompletionPollDelay)
            waited += SplashTiming.fetchCompletionPollDelay
            if Task.isCancelled { return }
        }
    }
}
