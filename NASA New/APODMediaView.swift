import SwiftUI
import AVKit
import YouTubePlayerKit

struct MediaView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appShellContext) private var appShellContext
    let nasa: NASA
    @Binding var imageScale: CGFloat
    @Binding var imageOffset: CGSize
    @Binding var isVideoLoading: Bool
    let allowVideoPlayback: Bool
    let wifiOnlyVideoAutoplay: Bool
    let isOnWiFiConnection: Bool
    let dataSaverMode: Bool
    let preferHDImages: Bool
    let reduceMotion: Bool
    let resetImageState: () -> Void
    let extractYouTubeID: (URL?) -> String?
    let videoThumbnailURL: (String) -> URL?
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @State private var showWebVideoSheet = false
    @State private var directVideoPlayer: AVPlayer?
    @State private var magnificationStartScale: CGFloat?

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var usesWidePresentation: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var heroMinimumHeight: CGFloat {
        usesWidePresentation
            ? AppTheme.Metrics.regularHeroMinimumHeight
            : AppTheme.Metrics.compactHeroMinimumHeight
    }

    private var videoHeroHeight: CGFloat {
        usesWidePresentation
            ? AppTheme.Metrics.regularVideoHeroHeight
            : AppTheme.Metrics.compactVideoHeroHeight
    }

    private var mediaHorizontalPadding: CGFloat {
        appShellContext == .premiumRegularShell ? AppTheme.Spacing.xs : AppTheme.Spacing.lg
    }

    private var preferredMediaURL: URL? {
        APODSourceLinkPolicy.preferredMediaURL(
            for: nasa,
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private var preferredImageURL: URL? {
        preferredMediaURL
    }

    private var archiveEntryURL: URL? {
        APODSourceLinkPolicy.nasaPageURL(for: nasa.date, fallbackURL: nasa.url)
    }

    private var archiveHostLabel: String? {
        APODSourceLinkPolicy.hostLabel(for: archiveEntryURL)
    }

    private var preferredMediaHostLabel: String? {
        APODSourceLinkPolicy.hostLabel(for: preferredMediaURL)
    }

    private var mediaIntegritySummary: String {
        APODSourceLinkPolicy.mediaIntegritySummary(
            for: nasa,
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private var mediaInteractionHint: String? {
        APODSourceLinkPolicy.mediaInteractionHint(for: nasa)
    }

    private var shouldAutoplayVideo: Bool {
        if !wifiOnlyVideoAutoplay {
            return true
        }
        return isOnWiFiConnection
    }

    private var isSaved: Bool {
        fetcher.isFavorite(nasa)
    }

    private var offlineMediaAsset: APODOfflineMediaAsset? {
        fetcher.offlineMediaAsset(for: nasa)
    }

    private var offlineStatusPresentation: APODOfflineMediaStatusPresentation? {
        APODOfflineMediaStatusPolicy.presentation(
            for: nasa,
            asset: offlineMediaAsset,
            isSaved: isSaved
        )
    }

    private var localImage: Image? {
        APODLocalMediaImageLoader.image(from: offlineMediaAsset?.localAssetURL)
    }

    private var localVideoURL: URL? {
        guard offlineMediaAsset?.availability == .availableOffline else { return nil }
        return offlineMediaAsset?.localAssetURL
    }

    private var imagePanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard APODMediaInteractionPolicy.allowsImagePanning(atScale: imageScale) else { return }
                imageOffset = value.translation
            }
            .onEnded { _ in
                if !APODMediaInteractionPolicy.allowsImagePanning(atScale: imageScale) {
                    resetImageState()
                }
            }
    }

    private var imageMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let startScale = magnificationStartScale ?? imageScale
                if magnificationStartScale == nil {
                    magnificationStartScale = startScale
                }
                imageScale = min(max(startScale * value, 1), 5)
            }
            .onEnded { _ in
                magnificationStartScale = nil
                if imageScale <= 1 { resetImageState() }
            }
    }

    private func toggleImageZoom() {
        let updates = {
            imageScale = imageScale == 1 ? 2 : 1
            if imageScale == 1 {
                imageOffset = .zero
            }
        }

        if let animation = AppTheme.Motion.emphasis(reduceMotion: reduceMotion) {
            withAnimation(animation, updates)
        } else {
            updates()
        }
    }

    @ViewBuilder
    private func interactiveImageView(_ image: Image) -> some View {
        let baseImage = image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
            .padding(AppTheme.Spacing.sm)
            .offset(x: imageOffset.width, y: imageOffset.height)
            .scaleEffect(imageScale)
            .accessibilityIdentifier(AccessibilityID.apodImageView)
            .accessibilityLabel(nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture"))
            .accessibilityAddTraits(.isImage)
            .onTapGesture(count: 2) {
                toggleImageZoom()
            }
            .simultaneousGesture(imageMagnificationGesture)

        if APODMediaInteractionPolicy.allowsImagePanning(atScale: imageScale) {
            baseImage.simultaneousGesture(imagePanGesture)
        } else {
            baseImage
        }
    }

    var body: some View {
        Group {
            if nasa.mediaType == .image {
                imageContent
            } else if nasa.mediaType == .video {
                videoContent
            } else {
                unsupportedMediaContent
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let localImage {
            mediaHero(tone: .accent) {
                interactiveImageView(localImage)
                    .frame(maxWidth: .infinity, minHeight: heroMinimumHeight)
            }
        } else if let preferredImageURL {
            AsyncImage(url: preferredImageURL) { phase in
                if let image = phase.image {
                    mediaHero(tone: .accent) {
                        interactiveImageView(image)
                            .frame(maxWidth: .infinity, minHeight: heroMinimumHeight)
                    }
                } else if phase.error != nil {
                    MediaPlaceholderCard(
                        eyebrow: L10n.text("Image Source", default: "Image Source"),
                        systemImage: "photo.badge.exclamationmark",
                        title: L10n.text("media.image_unavailable", default: "Image Unavailable"),
                        message: L10n.text(
                            "media.image_unavailable_message",
                            default: "This APOD image could not be loaded right now. You can still open the source directly."
                        ),
                        tone: .warning
                    ) {
                        Button(L10n.text("media.open_source", default: "Open Source")) {
                            openURL(preferredImageURL)
                        }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
                    }
                    .frame(minHeight: heroMinimumHeight)
                    .accessibilityIdentifier(AccessibilityID.apodImageUnavailableMessage)
                } else {
                    MediaPlaceholderCard(
                        eyebrow: L10n.text("NASA Imagery", default: "NASA Imagery"),
                        systemImage: "hourglass",
                        title: L10n.text("media.loading_title", default: "Receiving the image"),
                        message: L10n.text(
                            "media.loading_message",
                            default: "Fetching the best available APOD source and preparing it for reading."
                        ),
                        tone: .accent,
                        showsProgress: true,
                        minHeight: heroMinimumHeight
                    )
                }
            }
        } else {
            MediaPlaceholderCard(
                eyebrow: L10n.text("No Media Source", default: "No Media Source"),
                systemImage: "photo.on.rectangle.angled",
                title: L10n.text("media.no_source_title", default: "No image source available"),
                message: L10n.text(
                    "media.no_source_message",
                    default: "NASA did not provide an image URL for this APOD entry, but you can still open the source page when available."
                ),
                tone: .warning
            ) {
                if let fallbackURL = nasa.url ?? nasa.hdurl {
                    Button(L10n.text("media.open_source", default: "Open Source")) {
                        openURL(fallbackURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
                }
            }
            .frame(minHeight: heroMinimumHeight)
            .accessibilityIdentifier(AccessibilityID.apodImageUnavailableMessage)
        }
    }

    @ViewBuilder
    private var videoContent: some View {
        if !allowVideoPlayback {
            MediaPlaceholderCard(
                eyebrow: L10n.text("Video Playback", default: "Video Playback"),
                systemImage: "play.slash.fill",
                title: L10n.text("video.playback_disabled_title", default: "Video Playback Disabled"),
                message: L10n.text(
                    "video.playback_disabled_message",
                    default: "Enable video playback in Settings to watch this APOD inside the app."
                ),
                tone: .warning
            ) {
                EmptyView()
            }
            .frame(minHeight: heroMinimumHeight)
            .accessibilityIdentifier(AccessibilityID.videoDisabledMessage)
        } else if let localVideoURL, supportsInlineDirectVideo(localVideoURL) {
            directVideoHero(for: localVideoURL, autoplay: true, showsAutoplayBadge: false)
        } else if let videoID = extractYouTubeID(nasa.url) {
            let player = YouTubePlayer(source: .video(id: videoID))
            mediaHero(tone: .accent) {
                YouTubePlayerView(player)
                    .frame(height: videoHeroHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
                    .padding(AppTheme.Spacing.sm)
                    .overlay {
                        if isVideoLoading {
                            ProgressView()
                                .tint(AppTheme.accentColor(isDarkMode: isDarkMode))
                        }
                    }
                    .task(id: videoID) {
                        isVideoLoading = true
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        isVideoLoading = false
                    }
                    .onDisappear {
                        isVideoLoading = false
                    }
            }
        } else if let videoURL = nasa.url, supportsInlineDirectVideo(videoURL) {
            directVideoHero(for: videoURL, autoplay: shouldAutoplayVideo, showsAutoplayBadge: true)
        } else {
            MediaPlaceholderCard(
                eyebrow: L10n.text("Video Fallback", default: "Video Fallback"),
                systemImage: "safari.fill",
                title: L10n.text("video.browser_recommended_title", default: "Browser Playback Recommended"),
                message: L10n.text(
                    "video.browser_recommended_message",
                    default: "This video source is better handled in the browser, but you can still open it from here."
                ),
                tone: .accent
            ) {
                if let videoURL = nasa.url {
                    Button(L10n.text("media.play_video", default: "Play Video")) {
                        showWebVideoSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
                    .accessibilityIdentifier(AccessibilityID.playVideoInAppButton)
                    .sheet(isPresented: $showWebVideoSheet) {
                        SafariView(url: videoURL)
                    }

                    Button(L10n.text("media.open_external_browser", default: "Open in External Browser")) {
                        openURL(videoURL)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
                    .accessibilityIdentifier(AccessibilityID.openVideoExternalButton)
                }
            }
            .frame(minHeight: heroMinimumHeight)
            .accessibilityIdentifier(AccessibilityID.unsupportedVideoMessage)
        }
    }

    @ViewBuilder
    private func directVideoHero(
        for videoURL: URL,
        autoplay: Bool,
        showsAutoplayBadge: Bool
    ) -> some View {
        mediaHero(tone: .accent) {
            ZStack(alignment: .bottomLeading) {
                VideoPlayer(player: directVideoPlayer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: videoHeroHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
                    .padding(AppTheme.Spacing.sm)
                    .task(id: videoURL) {
                        configureDirectVideoPlayer(for: videoURL, autoplay: autoplay)
                    }
                    .onDisappear {
                        directVideoPlayer?.pause()
                        directVideoPlayer = nil
                    }

                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityIdentifier(AccessibilityID.directVideoPlayer)
                    .accessibilityLabel(nasa.title ?? L10n.text("Direct video player", default: "Direct video player"))
                    .accessibilityHint(L10n.text("Plays this APOD video inline in the app.", default: "Plays this APOD video inline in the app."))
                    .accessibilityValue(
                        autoplay
                            ? (showsAutoplayBadge && wifiOnlyVideoAutoplay
                                ? L10n.text("Autoplay allowed on Wi-Fi", default: "Autoplay allowed on Wi-Fi")
                                : L10n.text("Autoplay allowed on any network", default: "Autoplay allowed on any network"))
                            : L10n.text("Autoplay paused on non-Wi-Fi network.", default: "Autoplay paused on non-Wi-Fi network.")
                    )

                if showsAutoplayBadge && wifiOnlyVideoAutoplay && !isOnWiFiConnection {
                    MissionBadge(
                        title: L10n.text("video.autoplay_paused_off_wifi", default: "Autoplay paused on non-Wi-Fi network."),
                        systemImage: "pause.circle.fill",
                        tone: .warning
                    )
                    .padding(AppTheme.Spacing.md)
                    .accessibilityIdentifier(AccessibilityID.videoAutoplayPausedBadge)
                }
            }
        }
    }
    @ViewBuilder
    private var unsupportedMediaContent: some View {
        MediaPlaceholderCard(
            eyebrow: L10n.text("Unsupported Media", default: "Unsupported Media"),
            systemImage: "questionmark.video",
            title: L10n.text("media.unsupported_title", default: "Unsupported Media"),
            message: L10n.text(
                "media.unsupported_message",
                default: "This APOD entry uses a media type the app cannot present yet."
            ),
            tone: .warning
        ) {
            if let fallbackURL = nasa.url ?? nasa.hdurl {
                Button(L10n.text("media.open_source", default: "Open Source")) {
                    openURL(fallbackURL)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
            }
        }
        .frame(minHeight: heroMinimumHeight)
        .accessibilityIdentifier(AccessibilityID.unsupportedVideoMessage)
    }

    @ViewBuilder
    private func mediaHero<Content: View>(
        tone: AppTheme.SurfaceTone,
        @ViewBuilder content: () -> Content
    ) -> some View {
        MissionPanel(tone: tone, padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    content()
                        .frame(maxWidth: .infinity, minHeight: heroMinimumHeight)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        MissionBadge(
                            title: nasa.mediaType.localizedDisplayName,
                            systemImage: nasa.mediaType == .image ? "photo" : "play.rectangle",
                            tone: .accent
                        )

                        if nasa.mediaType == .image {
                            MissionBadge(
                                title: dataSaverMode
                                    ? L10n.text("media.standard_source", default: "Data Saver source")
                                    : (preferHDImages
                                        ? L10n.text("media.hd_preferred", default: "HD preferred")
                                        : L10n.text("media.standard_preferred", default: "Standard source")),
                                systemImage: dataSaverMode ? "gauge.with.dots.needle.33percent" : "sparkles.tv",
                                tone: dataSaverMode ? .warning : .neutral
                            )
                        } else {
                            MissionBadge(
                                title: shouldAutoplayVideo
                                    ? (wifiOnlyVideoAutoplay
                                        ? L10n.text("Autoplay allowed on Wi-Fi", default: "Autoplay allowed on Wi-Fi")
                                        : L10n.text("Autoplay allowed on any network", default: "Autoplay allowed on any network"))
                                    : L10n.text("video.manual_play_required", default: "Manual play required"),
                                systemImage: shouldAutoplayVideo ? "play.fill" : "pause.fill",
                                tone: shouldAutoplayVideo ? .neutral : .warning
                            )
                        }

                        if let offlineStatusPresentation {
                            MissionBadge(
                                title: offlineStatusPresentation.title,
                                systemImage: offlineStatusPresentation.systemImage,
                                tone: offlineStatusPresentation.tone
                            )
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous))

                Divider()
                    .overlay(AppTheme.panelStroke(isDarkMode: isDarkMode))

                mediaIntegrityFooter
            }
        }
        .padding(.horizontal, mediaHorizontalPadding)
    }

    private var mediaIntegrityFooter: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionEyebrow(L10n.text("Media Context", default: "Media Context"), tone: .neutral)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    mediaIntegrityBadges
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    mediaIntegrityBadges
                }
            }

            Text(mediaIntegritySummary)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                .fixedSize(horizontal: false, vertical: true)

            if let offlineStatusPresentation {
                Text(offlineStatusPresentation.detail)
                    .font(AppTheme.Typography.footnoteStrong)
                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let mediaInteractionHint {
                Text(mediaInteractionHint)
                    .font(AppTheme.Typography.footnoteStrong)
                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppTheme.Spacing.lg)
    }

    @ViewBuilder
    private var mediaIntegrityBadges: some View {
        MissionBadge(
            title: APODAttributionPolicy.rightsBadgeTitle(for: nasa),
            systemImage: APODAttributionPolicy.rightsSystemImage(for: nasa),
            tone: APODAttributionPolicy.rightsTone(for: nasa)
        )

        if let archiveHostLabel {
            MissionBadge(
                title: archiveHostLabel,
                systemImage: "doc.text.image",
                tone: .neutral
            )
        }

        if let preferredMediaHostLabel, preferredMediaHostLabel != archiveHostLabel {
            MissionBadge(
                title: preferredMediaHostLabel,
                systemImage: "globe",
                tone: .accent
            )
        }
    }

    private func supportsInlineDirectVideo(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = ["mp4", "m4v", "mov", "m3u8"]
        let fileExtension = url.pathExtension.lowercased()
        if supportedExtensions.contains(fileExtension) {
            return true
        }
        let urlString = url.absoluteString.lowercased()
        return supportedExtensions.contains(where: { urlString.contains(".\($0)") })
    }

    private func configureDirectVideoPlayer(for url: URL, autoplay: Bool) {
        if directVideoPlayer == nil {
            directVideoPlayer = AVPlayer(url: url)
        } else {
            directVideoPlayer?.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
        if autoplay {
            directVideoPlayer?.play()
        } else {
            directVideoPlayer?.pause()
        }
    }
}

private struct MediaPlaceholderCard<Actions: View>: View {
    let eyebrow: String
    let systemImage: String
    let title: String
    let message: String
    let tone: AppTheme.SurfaceTone
    let showsProgress: Bool
    let minHeight: CGFloat
    private let actions: Actions

    init(
        eyebrow: String,
        systemImage: String,
        title: String,
        message: String,
        tone: AppTheme.SurfaceTone = .neutral,
        showsProgress: Bool = false,
        minHeight: CGFloat = AppTheme.Metrics.compactHeroMinimumHeight,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.tone = tone
        self.showsProgress = showsProgress
        self.minHeight = minHeight
        self.actions = actions()
    }

    init(
        eyebrow: String,
        systemImage: String,
        title: String,
        message: String,
        tone: AppTheme.SurfaceTone = .neutral,
        showsProgress: Bool = false,
        minHeight: CGFloat = AppTheme.Metrics.compactHeroMinimumHeight
    ) where Actions == EmptyView {
        self.eyebrow = eyebrow
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.tone = tone
        self.showsProgress = showsProgress
        self.minHeight = minHeight
        self.actions = EmptyView()
    }

    var body: some View {
        MissionStateCard(
            eyebrow: eyebrow,
            title: title,
            message: message,
            systemImage: systemImage,
            tone: tone,
            showsProgress: showsProgress,
            minHeight: minHeight
        ) {
            actions
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}
