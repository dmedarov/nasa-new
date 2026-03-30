import SwiftUI
import AVKit
import YouTubePlayerKit

struct APODReaderView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.appShellContext) private var appShellContext
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @State private var imageScale: CGFloat = 1
    @State private var imageOffset: CGSize = .zero
    @State private var isVideoLoading = false
    @StateObject private var networkStatus = NetworkStatusMonitor()

    @AppStorage("allowVideoPlayback") private var allowVideoPlayback: Bool = true
    @AppStorage("dataSaverMode") private var dataSaverMode: Bool = false
    @AppStorage("preferHDImages") private var preferHDImages: Bool = true
    @AppStorage("wifiOnlyVideoAutoplay") private var wifiOnlyVideoAutoplay: Bool = true

    let nasa: NASA
    let isFavorite: Bool
    let availableWidth: CGFloat?

    init(
        nasa: NASA,
        isFavorite: Bool,
        availableWidth: CGFloat? = nil
    ) {
        self.nasa = nasa
        self.isFavorite = isFavorite
        self.availableWidth = availableWidth
    }

    private var effectiveAvailableWidth: CGFloat {
        guard let availableWidth else { return 0 }
        return max(availableWidth, 0)
    }

    private var effectiveReduceMotion: Bool {
        appRuntimeOverrides.resolvedReduceMotion(systemValue: accessibilityReduceMotion)
    }

    private var usesWideEditorialLayout: Bool {
        if availableWidth != nil {
            return effectiveAvailableWidth >= 940 && !dynamicTypeSize.isAccessibilitySize
        }
        return horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var detailsColumnMaxWidth: CGFloat {
        switch appShellContext {
        case .compactTabs:
            return AppTheme.Metrics.compactDetailsColumnMaxWidth
        case .premiumRegularShell:
            return AppTheme.Metrics.regularDetailsColumnMaxWidth
        }
    }

    private var effectivePreferHDImages: Bool {
        DataSaverPreferencePolicy.resolvedPreferHDImages(
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private func readerStageWidths(for availableWidth: CGFloat) -> (media: CGFloat, details: CGFloat) {
        let usableWidth = min(max(availableWidth, 0), AppTheme.Metrics.readerStageMaxWidth)
        let detailsWidth = min(
            max(usableWidth * 0.34, 420),
            detailsColumnMaxWidth
        )
        let mediaWidth = max(usableWidth - detailsWidth - AppTheme.Spacing.xxl, 520)
        return (mediaWidth, detailsWidth)
    }

    private func resetImageState() {
        imageScale = 1
        imageOffset = .zero
    }

    var body: some View {
        Group {
            if usesWideEditorialLayout {
                let widths = readerStageWidths(for: effectiveAvailableWidth)

                HStack(alignment: .top, spacing: AppTheme.Spacing.xxl) {
                    mediaSection
                        .frame(width: widths.media, alignment: .topLeading)
                        .layoutPriority(1)

                    detailsSection
                        .frame(width: widths.details, alignment: .topLeading)
                }
                .frame(width: widths.media + widths.details + AppTheme.Spacing.xxl, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: AppTheme.Spacing.xl) {
                    mediaSection
                    detailsSection
                }
            }
        }
        .onChange(of: nasa.id) { _ in
            resetImageState()
            isVideoLoading = nasa.mediaType == .video
        }
    }

    private var mediaSection: some View {
        MediaView(
            nasa: nasa,
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
            extractYouTubeID: Self.extractYouTubeID,
            videoThumbnailURL: Self.videoThumbnailURL(for:)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.apodMediaSection)
    }

    private var detailsSection: some View {
        APODDetailsView(
            nasa: nasa,
            isFavorite: isFavorite,
            nasaPageURL: APODSourceLinkPolicy.nasaPageURL(for: nasa.date, fallbackURL: nasa.url),
            preferredMediaSourceURL: APODSourceLinkPolicy.preferredMediaURL(
                for: nasa,
                dataSaverMode: dataSaverMode,
                preferHDImages: effectivePreferHDImages
            ),
            preferredMediaSourceTitle: APODSourceLinkPolicy.preferredMediaTitle(
                for: nasa,
                dataSaverMode: dataSaverMode,
                preferHDImages: effectivePreferHDImages
            ),
            preferredMediaSourceDescription: APODSourceLinkPolicy.preferredMediaDescription(
                for: nasa,
                dataSaverMode: dataSaverMode,
                preferHDImages: effectivePreferHDImages
            ),
            preferredMediaSourceSystemImage: APODSourceLinkPolicy.preferredMediaSystemImage(for: nasa)
        )
        .accessibilityIdentifier(AccessibilityID.apodDetailsSection)
    }

    private static func extractYouTubeID(from url: URL?) -> String? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let youtubeHosts = ["youtube.com", "youtu.be", "www.youtube.com"]
        if youtubeHosts.contains(where: { url.host?.contains($0) == true }) {
            if url.host?.contains("youtu.be") == true || url.path.contains("/embed/") || url.path.contains("/v/"),
               let path = components.path.components(separatedBy: "/").last,
               !path.isEmpty {
                return path
            }

            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }

        return nil
    }

    private static func videoThumbnailURL(for videoID: String) -> URL? {
        URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
    }
}

struct APODRecordDetailView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.appShellContext) private var appShellContext
    let nasa: NASA
    let destination: AppDestination

    @State private var showShareSheet = false

    private var detailStageMaxWidth: CGFloat {
        appShellContext == .premiumRegularShell
            ? AppTheme.Metrics.readerStageMaxWidth
            : .infinity
    }

    private var detailHorizontalPadding: CGFloat {
        appShellContext == .premiumRegularShell ? AppTheme.Spacing.lg : AppTheme.Spacing.lg
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                APODReaderView(
                    nasa: nasa,
                    isFavorite: fetcher.isFavorite(nasa),
                    availableWidth: min(
                        max(proxy.size.width - (detailHorizontalPadding * 2), 0),
                        detailStageMaxWidth
                    )
                )
                .frame(maxWidth: detailStageMaxWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, detailHorizontalPadding)
                .padding(.top, AppTheme.Spacing.sm)
                .padding(.bottom, AppTheme.Spacing.xxl)
            }
        }
        .background(SpaceBackdropView())
        .navigationTitle(APODDateDisplayPolicy.displayString(for: nasa.date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: fetcher.isFavorite(nasa) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityIdentifier(AccessibilityID.favoriteAPODButton)
                .accessibilityLabel(
                    fetcher.isFavorite(nasa)
                        ? L10n.text("Remove from favorites", default: "Remove from favorites")
                        : L10n.text("Add to favorites", default: "Add to favorites")
                )

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityIdentifier(AccessibilityID.shareAPODButton)
                .accessibilityLabel(L10n.text("Share APOD", default: "Share APOD"))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .task(id: nasa.id) {
            fetcher.recordPresentedItem(nasa)
            AppDiscoveryCoordinator.refreshSearchIndex(archive: fetcher.archiveItems, favorites: fetcher.favorites)
        }
        .userActivity(SpaceBriefingUserActivityType.apod, isActive: true) { activity in
            AppDiscoveryCoordinator.configure(activity: activity, for: nasa, destination: destination)
        }
    }

    private var shareItems: [Any] {
        let primaryURL = APODSourceLinkPolicy.nasaPageURL(for: nasa.date, fallbackURL: nasa.url) ?? nasa.url
        return APODSharePolicy.shareItems(
            for: nasa,
            sourceURL: primaryURL
        )
    }

    private func toggleFavorite() {
        guard purchaseManager.canAddFavorite(
            currentCount: fetcher.favorites.count,
            isAlreadyFavorite: fetcher.isFavorite(nasa)
        ) else {
            purchaseManager.presentPaywall(trigger: .favoriteLimit, feature: .unlimitedFavorites)
            return
        }

        fetcher.toggleFavorite(nasa)
    }
}
