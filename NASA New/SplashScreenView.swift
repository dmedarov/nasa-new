import SwiftUI

struct SplashScreenView: View {
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
                    .edgesIgnoringSafeArea(.all)
                
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
            .task {
                guard !isActive else { return }
                let environment = ProcessInfo.processInfo.environment
                let holdSplashForUITest = environment["UITEST_HOLD_SPLASH"] == "1"
                let stayOnSplashForUITest = environment["UITEST_STAY_ON_SPLASH"] == "1"

                if !fetcher.isUsingFixtureData {
                    await fetcher.fetchData()
                }

                if stayOnSplashForUITest {
                    return
                }

                let delay: UInt64
                if holdSplashForUITest {
                    delay = 4_000_000_000
                } else {
                    delay = fetcher.isUsingFixtureData ? 250_000_000 : (fetcher.error == nil ? 1_800_000_000 : 900_000_000)
                }

                try? await Task.sleep(nanoseconds: delay)
                withAnimation { isActive = true }
            }
        }
    }
}
