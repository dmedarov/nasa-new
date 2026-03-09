import SwiftUI

struct SplashScreenView: View {
    private enum SplashTiming {
        static let holdForUITest: UInt64 = 4_000_000_000
        static let fixtureModeDelay: UInt64 = 250_000_000
        static let successDelay: UInt64 = 1_800_000_000
        static let errorDelay: UInt64 = 900_000_000
        static let fetchCompletionPollDelay: UInt64 = 50_000_000
        static let maxAdditionalFetchWait: UInt64 = 1_500_000_000
    }

    @EnvironmentObject var fetcher: NasaCollectionFetcher
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            MainView()
        } else {
            ZStack {
                Image("LaunchScreen")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                VStack {
                    Image("logo-swift-outlined")
                    Text("NASA - Picture of The Day")
                        .font(.custom("Baskerville-Bold", size: 26))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(1)
                    Text("by")
                        .font(.custom("Baskerville-Bold", size: 16))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Medarov 2022")
                        .font(.custom("Baskerville-Bold", size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        size = 0.9
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
                withAnimation { isActive = true }
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
