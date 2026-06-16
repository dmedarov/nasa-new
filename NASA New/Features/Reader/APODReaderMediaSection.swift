import SwiftUI

struct APODReaderMediaSection: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @State private var imageScale: CGFloat = 1
    @State private var imageOffset: CGSize = .zero
    @State private var isVideoLoading = false
    @StateObject private var networkStatus = NetworkStatusMonitor()

    @AppStorage("allowVideoPlayback") private var allowVideoPlayback: Bool = true
    @AppStorage("dataSaverMode") private var dataSaverMode: Bool = false
    @AppStorage("preferHDImages") private var preferHDImages: Bool = true
    @AppStorage("wifiOnlyVideoAutoplay") private var wifiOnlyVideoAutoplay: Bool = true

    let presentation: APODReaderPresentation

    private var effectiveReduceMotion: Bool {
        appRuntimeOverrides.resolvedReduceMotion(systemValue: accessibilityReduceMotion)
    }

    private var effectivePreferHDImages: Bool {
        DataSaverPreferencePolicy.resolvedPreferHDImages(
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private func resetImageState() {
        imageScale = 1
        imageOffset = .zero
    }

    var body: some View {
        MediaView(
            presentation: presentation,
            imageScale: $imageScale,
            imageOffset: $imageOffset,
            isVideoLoading: $isVideoLoading,
            allowVideoPlayback: allowVideoPlayback,
            wifiOnlyVideoAutoplay: wifiOnlyVideoAutoplay,
            isOnWiFiConnection: networkStatus.connectionKind == .wifi,
            dataSaverMode: dataSaverMode,
            preferHDImages: effectivePreferHDImages,
            reduceMotion: effectiveReduceMotion,
            resetImageState: resetImageState,
            extractYouTubeID: APODMediaPresentationPolicy.embeddedYouTubeID(from:)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.apodMediaSection)
        .task(id: presentation.nasa.id) {
            resetImageState()
            isVideoLoading = presentation.nasa.mediaType == .video
        }
    }
}
