import SwiftUI
import UIKit
import YouTubePlayerKit
import SafariServices
import AVKit
import UserNotifications
import Network

struct UITestPolicy {
    static var isSceneRestorationDisabled: Bool {
        ProcessInfo.processInfo.environment["UITEST_DISABLE_SCENE_RESTORATION"] == "1"
    }
}

struct MainView: View {
    private enum ViewConstants {
        static let minImageScale: CGFloat = 1
        static let maxImageScale: CGFloat = 5
        static let dateSelectionDebounceNanoseconds: UInt64 = 250_000_000
        static let shareExplanationMaxLength: Int = 100
        static let cardCornerRadius: CGFloat = 18
        static let selectedDateSceneStorageKey = "MainView.selectedAPODDate"
    }

    @EnvironmentObject var fetcher: NasaCollectionFetcher
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @State private var imageScale: CGFloat = ViewConstants.minImageScale
    @State private var imageOffset: CGSize = .zero
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    @State private var showFavoritesSheet = false
    @State private var isMediaAnimating = false
    @State private var isVideoLoading = false
    @State private var selectedDate = Date()
    @State private var isSyncingSelectedDateFromModel = false
    @State private var dateSelectionTask: Task<Void, Never>?
    @State private var randomizeFeedbackToken = 0
    @State private var favoriteFeedbackToken = 0
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var nextScheduledNotificationDate: Date?
    @SceneStorage(ViewConstants.selectedDateSceneStorageKey) private var storedSelectedDateValue: String?
    @StateObject private var networkStatus = NetworkStatusMonitor()
    
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @AppStorage("preferImages") private var preferImages: Bool = false
    @AppStorage("allowVideoPlayback") private var allowVideoPlayback: Bool = true
    @AppStorage("dailyNotificationsEnabled") private var dailyNotificationsEnabled: Bool = false
    @AppStorage("dailyNotificationHour") private var dailyNotificationHour: Int = 9
    @AppStorage("dailyNotificationMinute") private var dailyNotificationMinute: Int = 0
    @AppStorage("dataSaverMode") private var dataSaverMode: Bool = false
    @AppStorage("preferHDImages") private var preferHDImages: Bool = true
    @AppStorage("cacheItemLimit") private var cacheItemLimit: Int = 90
    @AppStorage("wifiOnlyVideoAutoplay") private var wifiOnlyVideoAutoplay: Bool = true
    private let sceneStorageDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()
    private func resetImageState() {
        let updates = {
            imageScale = ViewConstants.minImageScale
            imageOffset = .zero
        }
        if accessibilityReduceMotion {
            updates()
        } else {
            withAnimation(.spring()) {
                updates()
            }
        }
    }
    
    private func extractYouTubeID(from url: URL?) -> String? {
        guard let url = url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let youtubeHosts = ["youtube.com", "youtu.be", "www.youtube.com"]
        if youtubeHosts.contains(where: { url.host?.contains($0) == true }) {
            if url.host?.contains("youtu.be") == true || url.path.contains("/embed/") || url.path.contains("/v/"),
               let path = components.path.components(separatedBy: "/").last, !path.isEmpty {
                return path
            }
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }
        return nil
    }
    
    private func apodURL(for date: String?) -> URL? {
        APODSourceLinkPolicy.nasaPageURL(for: date, fallbackURL: fetcher.currentNasa.url)
    }
    
    private func videoThumbnailURL(for videoID: String) -> URL? {
        URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
    }
    
    private func truncateToWords(_ text: String, maxLength: Int) -> String {
        let words = text.split(separator: " ")
        var result = ""
        for word in words {
            if (result + " " + word).count <= maxLength {
                result += (result.isEmpty ? "" : " ") + word
            } else {
                break
            }
        }
        return result + (result.count < text.count ? "..." : "")
    }

    private func syncSelectedDateWithCurrentItem() {
        guard let dateString = fetcher.currentNasa.date, let modelDate = fetcher.date(from: dateString) else { return }
        guard !fetcher.isSameAPODDay(selectedDate, modelDate) else { return }
        isSyncingSelectedDateFromModel = true
        selectedDate = modelDate
    }

    private func requestAPOD(for date: Date) {
        dateSelectionTask?.cancel()
        dateSelectionTask = Task {
            try? await Task.sleep(nanoseconds: ViewConstants.dateSelectionDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            fetcher.startLatestFetch(for: date)
        }
    }

    private func persistSelectedDate(_ date: Date) {
        storedSelectedDateValue = sceneStorageDateFormatter.string(from: date)
    }

    private var restoredSelectedDate: Date? {
        APODDateRestoration.restoredDate(
            storedValue: storedSelectedDateValue,
            parseDate: fetcher.date(from:),
            minimumDate: fetcher.minimumSelectableDate,
            maximumDate: fetcher.maximumSelectableDate
        )
    }

    private var hasLoadedContent: Bool {
        !fetcher.apodData.isEmpty
    }

    private var isShowingLatestDate: Bool {
        fetcher.isSameAPODDay(selectedDate, fetcher.maximumSelectableDate)
    }

    private var isShowingMinimumDate: Bool {
        fetcher.isSameAPODDay(selectedDate, fetcher.minimumSelectableDate)
    }

    private func retryLatestRequest() {
        fetcher.startLatestFetch()
    }

    private func jumpToLatestDate() {
        let latestDate = APODDateNavigationPolicy.latestDate(maximumDate: fetcher.maximumSelectableDate)
        if fetcher.isSameAPODDay(selectedDate, latestDate) {
            retryLatestRequest()
            return
        }
        selectedDate = latestDate
    }

    private func shiftSelectedDate(byDays dayOffset: Int) {
        let clampedDate = APODDateNavigationPolicy.shiftedDate(
            from: selectedDate,
            dayOffset: dayOffset,
            calendar: Calendar.current,
            minimumDate: fetcher.minimumSelectableDate,
            maximumDate: fetcher.maximumSelectableDate
        )
        guard !fetcher.isSameAPODDay(selectedDate, clampedDate) else { return }
        selectedDate = clampedDate
    }

    private func applyCurrentSelectionState(syncSelectedDate: Bool) {
        isVideoLoading = fetcher.currentNasa.mediaType == .video
        resetImageState()
        if syncSelectedDate {
            syncSelectedDateWithCurrentItem()
        }
    }

    private func restoreSceneSelectionIfNeeded() {
        guard !UITestPolicy.isSceneRestorationDisabled else { return }
        guard let restoredSelectedDate else { return }
        guard !fetcher.isSameAPODDay(selectedDate, restoredSelectedDate) else { return }
        isSyncingSelectedDateFromModel = false
        selectedDate = restoredSelectedDate
    }

    private func normalizedPreferHDImages(for proposedValue: Bool? = nil) -> Bool {
        DataSaverPreferencePolicy.resolvedPreferHDImages(
            dataSaverMode: dataSaverMode,
            preferHDImages: proposedValue ?? preferHDImages
        )
    }

    private func loadInitialContentIfNeeded() {
        guard fetcher.apodData.isEmpty, !fetcher.isFetching else {
            syncSelectedDateWithCurrentItem()
            return
        }

        if let restoredSelectedDate,
           !fetcher.isSameAPODDay(restoredSelectedDate, fetcher.maximumSelectableDate) {
            requestAPOD(for: restoredSelectedDate)
        } else {
            fetcher.startLatestFetch()
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            headerSection
            statusBannerSection
            mainContentSection
        }
        .padding(.top, 8)
        .background(backgroundLayer)
        .navigationTitle(L10n.text("NASA", default: "NASA"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView(
                preferImages: $preferImages,
                allowVideoPlayback: $allowVideoPlayback,
                dailyNotificationsEnabled: $dailyNotificationsEnabled,
                dailyNotificationHour: $dailyNotificationHour,
                dailyNotificationMinute: $dailyNotificationMinute,
                dataSaverMode: $dataSaverMode,
                preferHDImages: $preferHDImages,
                cacheItemLimit: $cacheItemLimit,
                wifiOnlyVideoAutoplay: $wifiOnlyVideoAutoplay,
                isPresented: $showSettingsSheet,
                lastStatusCode: fetcher.lastStatusCode,
                lastRequestDate: fetcher.lastRequestDate,
                isAPIKeyConfigured: fetcher.isAPIKeyConfigured,
                lastTransportError: fetcher.lastTransportError,
                isUsingCachedData: fetcher.isUsingCachedData,
                diagnosticsHistory: fetcher.requestDiagnostics,
                apiKeyWarning: fetcher.apiKeyWarning,
                rateLimitRetryDate: fetcher.rateLimitRetryDate,
                notificationPermissionStatus: notificationPermissionStatus,
                nextScheduledNotificationDate: nextScheduledNotificationDate,
                cachedItemCount: fetcher.cachedItemCount,
                appliedCacheItemLimit: fetcher.cacheItemLimit,
                networkConnectionLabel: networkStatus.connectionKind.displayName,
                networkReachable: networkStatus.isSatisfied,
                networkIsExpensive: networkStatus.isExpensive,
                networkIsConstrained: networkStatus.isConstrained,
                videoAutoplayEligible: !wifiOnlyVideoAutoplay || networkStatus.connectionKind == .wifi
            )
        }
        .sheet(isPresented: $showFavoritesSheet) {
            FavoritesSheetView(
                favorites: fetcher.favorites,
                isPresented: $showFavoritesSheet,
                selectAction: { favorite in
                    fetcher.selectFavorite(favorite)
                    applyCurrentSelectionState(syncSelectedDate: true)
                },
                removeAction: { favorite in
                    fetcher.removeFavorite(favorite)
                }
            )
        }
        .safeAreaInset(edge: .bottom) {
            if fetcher.currentNasa.mediaType == .image {
                controlView
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .contain)
        .overlay(alignment: .topLeading) {
            AccessibilityMarker(identifier: AccessibilityID.mainViewRoot)
        }
        .onDisappear {
            dateSelectionTask?.cancel()
            dateSelectionTask = nil
            fetcher.cancelLatestFetch()
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            if fetcher.shouldRefreshOnForeground() {
                retryLatestRequest()
            }
            Task {
                await refreshNotificationStatus()
            }
        }
        .task {
            fetcher.applyCacheItemLimit(cacheItemLimit)
            restoreSceneSelectionIfNeeded()
            preferHDImages = normalizedPreferHDImages()
            await synchronizeNotificationSchedule()
        }
        .onChange(of: dailyNotificationsEnabled) { _ in
            Task { await synchronizeNotificationSchedule() }
        }
        .onChange(of: dailyNotificationHour) { _ in
            Task { await synchronizeNotificationSchedule() }
        }
        .onChange(of: dailyNotificationMinute) { _ in
            Task { await synchronizeNotificationSchedule() }
        }
        .onChange(of: cacheItemLimit) { newLimit in
            fetcher.applyCacheItemLimit(newLimit)
        }
        .onChange(of: selectedDate) { newDate in
            persistSelectedDate(newDate)
        }
        .onChange(of: dataSaverMode) { _ in
            preferHDImages = normalizedPreferHDImages()
        }
        .modifier(SensoryFeedbackModifier(
            randomizeFeedbackToken: randomizeFeedbackToken,
            favoriteFeedbackToken: favoriteFeedbackToken
        ))
    }

    private var headerSection: some View {
        MainHeaderBar(
            isDarkMode: $isDarkMode,
            showSettingsSheet: $showSettingsSheet,
            showFavoritesSheet: $showFavoritesSheet,
            selectedDate: $selectedDate,
            minimumDate: fetcher.minimumSelectableDate,
            maximumDate: fetcher.maximumSelectableDate,
            isFetching: fetcher.isFetching,
            hasApodData: hasLoadedContent,
            favoritesCount: fetcher.favorites.count,
            preferImages: preferImages,
            isShowingLatestDate: isShowingLatestDate,
            refreshAction: retryLatestRequest,
            isShowingMinimumDate: isShowingMinimumDate,
            previousDateAction: { shiftSelectedDate(byDays: -1) },
            nextDateAction: { shiftSelectedDate(byDays: 1) },
            jumpToLatestAction: jumpToLatestDate,
            randomizeAction: randomizeSelection
        )
    }

    private var statusBannerSection: some View {
        APIRequestStatusBanner(
            isFetching: fetcher.isFetching,
            error: fetcher.error,
            hasLoadedContent: hasLoadedContent,
            retryAction: retryLatestRequest,
            isOfflineMode: fetcher.isOfflineMode,
            apiKeyWarning: fetcher.apiKeyWarning,
            rateLimitRetryDate: fetcher.rateLimitRetryDate
        )
    }

    @ViewBuilder
    private var mainContentSection: some View {
        if !hasLoadedContent && fetcher.isFetching {
            APIRequestEmptyStateView(
                title: L10n.text("Loading APOD", default: "Loading APOD"),
                subtitle: L10n.text("Fetching the latest Astronomy Picture of the Day from NASA API.", default: "Fetching the latest Astronomy Picture of the Day from NASA API.")
            )
            Spacer()
        } else if !hasLoadedContent, let error = fetcher.error {
            APIRequestFailureView(error: error, retryAction: retryLatestRequest)
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    mediaSection
                    detailsSection
                    shareSection
                }
            }
            .accessibilityIdentifier(AccessibilityID.mainContentScrollView)
            .refreshable {
                retryLatestRequest()
            }
        }
    }

    private var mediaSection: some View {
        MediaView(
            nasa: fetcher.currentNasa,
            imageScale: $imageScale,
            imageOffset: $imageOffset,
            isVideoLoading: $isVideoLoading,
            allowVideoPlayback: allowVideoPlayback,
            wifiOnlyVideoAutoplay: wifiOnlyVideoAutoplay,
            isOnWiFiConnection: networkStatus.connectionKind == .wifi,
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages,
            reduceMotion: accessibilityReduceMotion,
            resetImageState: resetImageState,
            extractYouTubeID: extractYouTubeID,
            videoThumbnailURL: videoThumbnailURL
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.apodMediaSection)
        .opacity(isMediaAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 1)) { isMediaAnimating = true }
            loadInitialContentIfNeeded()
        }
        .onChange(of: selectedDate) { date in
            if isSyncingSelectedDateFromModel {
                isSyncingSelectedDateFromModel = false
                return
            }
            requestAPOD(for: date)
        }
        .onChange(of: fetcher.currentNasa.date) { _ in
            applyCurrentSelectionState(syncSelectedDate: true)
        }
    }

    private var detailsSection: some View {
        APODDetailsView(
            nasa: fetcher.currentNasa,
            isFavorite: fetcher.isFavorite(fetcher.currentNasa),
            favoriteAction: toggleFavorite,
            nasaPageURL: nasaPageURL,
            preferredMediaSourceURL: preferredMediaSourceURL,
            preferredMediaSourceTitle: preferredMediaSourceTitle,
            preferredMediaSourceSystemImage: preferredMediaSourceSystemImage
        )
        .accessibilityIdentifier(AccessibilityID.apodDetailsSection)
    }

    private var shareSection: some View {
        shareControl
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .accessibilityIdentifier(AccessibilityID.shareAPODButton)
            .accessibilityLabel(L10n.text("Share APOD", default: "Share APOD"))
            .accessibilityHint(L10n.text("Shares the current Astronomy Picture of the Day", default: "Shares the current Astronomy Picture of the Day"))
    }

    private func randomizeSelection() {
        fetcher.selectRandom(preferImagesOnly: preferImages)
        randomizeFeedbackToken += 1
        applyCurrentSelectionState(syncSelectedDate: true)
    }

    private func toggleFavorite() {
        fetcher.toggleFavorite(fetcher.currentNasa)
        favoriteFeedbackToken += 1
    }

    private var backgroundLayer: some View {
        ZStack {
            AppTheme.backgroundGradient(isDarkMode: isDarkMode)
            Circle()
                .fill(AppTheme.primaryOrbColor(isDarkMode: isDarkMode))
                .frame(width: 320, height: 320)
                .offset(x: 140, y: -260)
            Circle()
                .fill(AppTheme.secondaryOrbColor(isDarkMode: isDarkMode))
                .frame(width: 360, height: 360)
                .offset(x: -180, y: 260)
        }
        .ignoresSafeArea()
    }

    private var adaptiveMaterialBackground: AnyShapeStyle {
        AppTheme.adaptiveSurface(
            isDarkMode: isDarkMode,
            reduceTransparency: accessibilityReduceTransparency
        )
    }

    private var currentNotificationSettings: NotificationSettings {
        NotificationSettings(
            isEnabled: dailyNotificationsEnabled,
            hour: max(0, min(23, dailyNotificationHour)),
            minute: max(0, min(59, dailyNotificationMinute))
        )
    }

    private func refreshNotificationStatus() async {
        notificationPermissionStatus = await NotificationScheduler.shared.authorizationStatus()
        nextScheduledNotificationDate = await NotificationScheduler.shared.nextPendingNotificationDate()
    }

    private func synchronizeNotificationSchedule() async {
        await NotificationScheduler.shared.scheduleDailyAPODNotification(settings: currentNotificationSettings)
        await refreshNotificationStatus()
    }
    
    private var controlView: some View {
        HStack {
            Button {
                withAnimation(.spring()) {
                    if imageScale > ViewConstants.minImageScale { imageScale -= 1 }
                    if imageScale <= ViewConstants.minImageScale { resetImageState() }
                }
            } label: {
                ControlImageView(icon: "minus.magnifyingglass", accessibilityLabel: L10n.text("Zoom out", default: "Zoom out"))
            }
            
            Button {
                resetImageState()
            } label: {
                ControlImageView(icon: "arrow.up.left.and.down.right.magnifyingglass", accessibilityLabel: L10n.text("Reset zoom", default: "Reset zoom"))
            }
            
            Button {
                withAnimation(.spring()) {
                    if imageScale < ViewConstants.maxImageScale { imageScale += 1 }
                }
            } label: {
                ControlImageView(icon: "plus.magnifyingglass", accessibilityLabel: L10n.text("Zoom in", default: "Zoom in"))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(adaptiveMaterialBackground)
        .clipShape(RoundedRectangle(cornerRadius: ViewConstants.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .opacity(isMediaAnimating ? 1 : 0)
    }
    
    private var shareItems: [Any] {
        let title = shareTitle
        let explanation = shareExplanation
        let url = shareURL
        let media: Any? = {
            if fetcher.currentNasa.mediaType == .video,
               let id = extractYouTubeID(from: fetcher.currentNasa.url),
               let thumb = videoThumbnailURL(for: id) {
                return thumb
            }
            return fetcher.currentNasa.hdurl ?? fetcher.currentNasa.url
        }()
        return [title, explanation, url, media].compactMap { $0 }
    }

    private var shareTitle: String {
        fetcher.currentNasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture")
    }

    private var shareExplanation: String {
        truncateToWords(
            fetcher.currentNasa.explanation ?? "",
            maxLength: ViewConstants.shareExplanationMaxLength
        )
    }

    private var shareURL: URL? {
        nasaPageURL
    }

    private var nasaPageURL: URL? {
        apodURL(for: fetcher.currentNasa.date)
    }

    private var preferredMediaSourceURL: URL? {
        APODSourceLinkPolicy.preferredMediaURL(
            for: fetcher.currentNasa,
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private var preferredMediaSourceTitle: String {
        APODSourceLinkPolicy.preferredMediaTitle(
            for: fetcher.currentNasa,
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private var preferredMediaSourceSystemImage: String {
        APODSourceLinkPolicy.preferredMediaSystemImage(for: fetcher.currentNasa)
    }

    private var shareMessage: String {
        "\(shareTitle)\n\n\(shareExplanation)"
    }

    @ViewBuilder
    private var shareControl: some View {
            if #available(iOS 16.0, *) {
                if let shareURL {
                ShareLink(
                    item: shareURL,
                    subject: Text(shareTitle),
                    message: Text(shareMessage)
                ) {
                    Label(L10n.text("Share", default: "Share"), systemImage: "square.and.arrow.up")
                }
            } else {
                ShareLink(
                    item: shareMessage,
                    subject: Text(shareTitle)
                ) {
                    Label(L10n.text("Share", default: "Share"), systemImage: "square.and.arrow.up")
                }
            }
        } else {
            Button(L10n.text("Share", default: "Share")) {
                showShareSheet = true
            }
        }
    }
}

private struct SensoryFeedbackModifier: ViewModifier {
    let randomizeFeedbackToken: Int
    let favoriteFeedbackToken: Int

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .sensoryFeedback(.selection, trigger: randomizeFeedbackToken)
                .sensoryFeedback(.selection, trigger: favoriteFeedbackToken)
        } else {
            content
        }
    }
}

private struct MainHeaderBar: View {
    @ScaledMetric(relativeTo: .body) private var headerButtonSize = 34
    @ScaledMetric(relativeTo: .body) private var headerIconSize = 18
    @ScaledMetric(relativeTo: .body) private var datePickerWidth = 124
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Binding var isDarkMode: Bool
    @Binding var showSettingsSheet: Bool
    @Binding var showFavoritesSheet: Bool
    @Binding var selectedDate: Date
    let minimumDate: Date
    let maximumDate: Date
    let isFetching: Bool
    let hasApodData: Bool
    let favoritesCount: Int
    let preferImages: Bool
    let isShowingLatestDate: Bool
    let refreshAction: () -> Void
    let isShowingMinimumDate: Bool
    let previousDateAction: () -> Void
    let nextDateAction: () -> Void
    let jumpToLatestAction: () -> Void
    let randomizeAction: () -> Void

    private var iconColor: Color {
        AppTheme.accentColor(isDarkMode: isDarkMode)
    }

    private var headerBackground: AnyShapeStyle {
        AppTheme.adaptiveSurface(
            isDarkMode: isDarkMode,
            reduceTransparency: accessibilityReduceTransparency
        )
    }

    var body: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    headerIconControls
                    datePickerControl
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        headerIconControls
                    }
                    datePickerControl
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: 12) {
                Button {
                    refreshAction()
                } label: {
                    Label(L10n.text("Refresh", default: "Refresh"), systemImage: "arrow.clockwise")
                        .font(AppTheme.Typography.actionLabel)
                }
                .buttonStyle(.bordered)
                .disabled(isFetching)
                .accessibilityIdentifier(AccessibilityID.refreshAPODButton)
                .accessibilityLabel(L10n.text("Refresh APOD data", default: "Refresh APOD data"))
                .accessibilityHint(L10n.text("Fetches the latest APOD data", default: "Fetches the latest APOD data"))

                Button {
                    jumpToLatestAction()
                } label: {
                    Label(L10n.text("Today", default: "Today"), systemImage: "calendar")
                        .font(AppTheme.Typography.actionLabel)
                }
                .buttonStyle(.bordered)
                .disabled(isFetching && isShowingLatestDate)
                .accessibilityIdentifier(AccessibilityID.jumpToLatestAPODDateButton)
                .accessibilityLabel(L10n.text("Jump to latest APOD date", default: "Jump to latest APOD date"))
                .accessibilityHint(L10n.text("Returns the calendar selection to today", default: "Returns the calendar selection to today"))

                Button {
                    randomizeAction()
                } label: {
                    Label(
                        preferImages
                            ? L10n.text("Random Image", default: "Random Image")
                            : L10n.text("Random APOD", default: "Random APOD"),
                        systemImage: "arrow.clockwise.circle"
                    )
                        .font(AppTheme.Typography.actionLabel)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isFetching || !hasApodData)
                .accessibilityIdentifier(AccessibilityID.randomAPODButton)
                .accessibilityLabel(
                    preferImages
                        ? L10n.text("Select random image", default: "Select random image")
                        : L10n.text("Select random APOD", default: "Select random APOD")
                )
                .accessibilityHint(L10n.text("Loads a random Astronomy Picture of the Day", default: "Loads a random Astronomy Picture of the Day"))
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(headerBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var headerIconControls: some View {
        headerIconButton(
            icon: isDarkMode ? "sun.min.fill" : "moon.circle",
            identifier: AccessibilityID.toggleAppearanceButton,
            accessibilityLabel: isDarkMode
                ? L10n.text("Switch to light mode", default: "Switch to light mode")
                : L10n.text("Switch to dark mode", default: "Switch to dark mode"),
            accessibilityHint: L10n.text("Toggles the app's appearance mode", default: "Toggles the app's appearance mode"),
            action: { isDarkMode.toggle() }
        )

        headerIconButton(
            icon: "gearshape",
            identifier: AccessibilityID.openSettingsButton,
            accessibilityLabel: L10n.text("Open settings", default: "Open settings"),
            accessibilityHint: L10n.text("Adjust app preferences", default: "Adjust app preferences"),
            action: { showSettingsSheet = true }
        )

        headerIconButton(
            icon: favoritesCount == 0 ? "heart" : "heart.fill",
            identifier: AccessibilityID.openFavoritesButton,
            accessibilityLabel: L10n.text("Open favorites", default: "Open favorites"),
            accessibilityHint: L10n.text("Shows your saved APOD favorites", default: "Shows your saved APOD favorites"),
            action: { showFavoritesSheet = true }
        )
    }

    private var datePickerControl: some View {
        HStack(spacing: 8) {
            Button(action: previousDateAction) {
                Image(systemName: "chevron.left")
                    .font(AppTheme.Typography.actionLabel)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(isShowingMinimumDate)
            .accessibilityIdentifier(AccessibilityID.previousAPODDateButton)
            .accessibilityLabel(L10n.text("Previous APOD date", default: "Previous APOD date"))
            .accessibilityHint(L10n.text("Moves to the previous available Astronomy Picture of the Day", default: "Moves to the previous available Astronomy Picture of the Day"))

            DatePicker("", selection: $selectedDate, in: minimumDate...maximumDate, displayedComponents: .date)
                .labelsHidden()
                .frame(width: max(datePickerWidth, 120))
                .accessibilityLabel(L10n.text("Select APOD date", default: "Select APOD date"))
                .accessibilityHint(L10n.text("Choose a date to view a specific Astronomy Picture of the Day", default: "Choose a date to view a specific Astronomy Picture of the Day"))

            Button(action: nextDateAction) {
                Image(systemName: "chevron.right")
                    .font(AppTheme.Typography.actionLabel)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(isShowingLatestDate)
            .accessibilityIdentifier(AccessibilityID.nextAPODDateButton)
            .accessibilityLabel(L10n.text("Next APOD date", default: "Next APOD date"))
            .accessibilityHint(L10n.text("Moves to the next available Astronomy Picture of the Day", default: "Moves to the next available Astronomy Picture of the Day"))
        }
    }

    @ViewBuilder
    private func headerIconButton(
        icon: String,
        identifier: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: headerIconSize, weight: .semibold))
                .frame(width: max(headerButtonSize, 44), height: max(headerButtonSize, 44))
                .foregroundColor(iconColor)
                .background(AppTheme.glassSurface(reduceTransparency: accessibilityReduceTransparency))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
        }
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}

private struct APODDetailsView: View {
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExplanationExpanded = false
    let nasa: NASA
    let isFavorite: Bool
    let favoriteAction: () -> Void
    let nasaPageURL: URL?
    let preferredMediaSourceURL: URL?
    let preferredMediaSourceTitle: String
    let preferredMediaSourceSystemImage: String

    private var detailsBackground: AnyShapeStyle {
        AppTheme.adaptiveSurface(
            isDarkMode: colorScheme == .dark,
            reduceTransparency: accessibilityReduceTransparency
        )
    }

    private var formattedDate: String {
        APODDateDisplayPolicy.displayString(for: nasa.date)
    }

    private var explanationText: String {
        nasa.explanation ?? L10n.text("apod.explanation.unavailable", default: "No explanation available.")
    }

    private var shouldOfferExplanationExpansion: Bool {
        APODExplanationDisplayPolicy.shouldOfferExpansion(for: explanationText)
    }

    private var mediaTypeSystemImage: String {
        switch nasa.mediaType {
        case .image:
            return "photo"
        case .video:
            return "play.rectangle"
        case .other:
            return "questionmark.video"
        }
    }

    private var showsSeparateMediaAction: Bool {
        guard let preferredMediaSourceURL else { return false }
        return preferredMediaSourceURL != nasaPageURL
    }

    private var creditLine: String {
        APODAttributionPolicy.creditLine(for: nasa)
    }

    private var rightsNotice: String? {
        APODAttributionPolicy.rightsNotice(for: nasa)
    }

    private var shouldUseCompactHeaderLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(AppTheme.Typography.actionLabel)
                    .accessibilityIdentifier(AccessibilityID.apodDateText)
                    .accessibilityLabel(Text(L10n.format("date.label", default: "Date: %@", formattedDate)))
                Label(creditLine, systemImage: "c.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier(AccessibilityID.apodCreditText)
                    .accessibilityLabel(Text(L10n.format("credit.label", default: "Credit: %@", creditLine)))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    APODMetadataBadge(title: nasa.mediaType.localizedDisplayName, systemImage: mediaTypeSystemImage)
                    APODMetadataBadge(title: APODAttributionPolicy.sourceLabel(for: nasa), systemImage: "network")
                    if nasa.hdurl != nil {
                        APODMetadataBadge(title: L10n.text("HD Available", default: "HD Available"), systemImage: "sparkles.tv")
                    }
                    if nasa.url != nil {
                        APODMetadataBadge(title: L10n.text("Source Ready", default: "Source Ready"), systemImage: "link")
                    }
                }
                .padding(.vertical, 2)
            }

            if let rightsNotice {
                APODAttributionNotice(text: rightsNotice)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("About This APOD", default: "About This APOD"))
                    .font(AppTheme.Typography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(explanationText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .lineLimit(isExplanationExpanded ? nil : APODExplanationDisplayPolicy.collapsedLineLimit)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(AccessibilityID.apodExplanationText)
                    .accessibilityTextContentType(.narrative)
                    .accessibilityLabel(Text(L10n.format("explanation.label", default: "Explanation: %@", explanationText)))

                if shouldOfferExplanationExpansion {
                    Button(
                        isExplanationExpanded
                            ? L10n.text("Show Less", default: "Show Less")
                            : L10n.text("Read More", default: "Read More")
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExplanationExpanded.toggle()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(AppTheme.Typography.actionLabel)
                    .accessibilityIdentifier(AccessibilityID.apodExplanationToggleButton)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)

            if nasaPageURL != nil || showsSeparateMediaAction {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        quickActionButtons
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        quickActionButtons
                    }
                }
            }
        }
        .padding(14)
        .background(detailsBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        .padding(.horizontal, 16)
        .onChange(of: nasa.id) { _ in
            isExplanationExpanded = false
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        if shouldUseCompactHeaderLayout {
            VStack(alignment: .leading, spacing: 10) {
                titleView
                favoriteButton
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                titleView
                favoriteButton
            }
        }
    }

    private var titleView: some View {
        Text(nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture"))
            .font(AppTheme.Typography.screenTitle)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture"))
            .accessibilityIdentifier(AccessibilityID.apodTitleText)
            .accessibilityAddTraits(.isHeader)
    }

    private var favoriteButton: some View {
        Button(action: favoriteAction) {
            Label(
                isFavorite
                    ? L10n.text("Remove from favorites", default: "Remove from favorites")
                    : L10n.text("Add to favorites", default: "Add to favorites"),
                systemImage: isFavorite ? "heart.fill" : "heart"
            )
                .labelStyle(.iconOnly)
                .foregroundColor(isFavorite ? AppTheme.Palette.favorite : .secondary)
                .frame(minWidth: 44, minHeight: 44)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(AccessibilityID.favoriteAPODButton)
        .accessibilityLabel(
            isFavorite
                ? L10n.text("Remove from favorites", default: "Remove from favorites")
                : L10n.text("Add to favorites", default: "Add to favorites")
        )
        .accessibilityHint(L10n.text("Saves this APOD to your favorites list", default: "Saves this APOD to your favorites list"))
    }

    @ViewBuilder
    private var quickActionButtons: some View {
        if let nasaPageURL {
            Link(destination: nasaPageURL) {
                Label(L10n.text("NASA Page", default: "NASA Page"), systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(AccessibilityID.openNasaPageButton)
            .accessibilityHint(L10n.text("Opens the official APOD page in the browser", default: "Opens the official APOD page in the browser"))
        }

        if showsSeparateMediaAction, let preferredMediaSourceURL {
            Link(destination: preferredMediaSourceURL) {
                Label(preferredMediaSourceTitle, systemImage: preferredMediaSourceSystemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(AccessibilityID.openPreferredMediaButton)
            .accessibilityHint(L10n.text("Opens the best available media source for this APOD", default: "Opens the best available media source for this APOD"))
        }
    }
}

private struct APODMetadataBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AppTheme.Typography.metadata)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}

private struct APODAttributionNotice: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Palette.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct AccessibilityMarker: View {
    let identifier: String

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityIdentifier(identifier)
    }
}

private struct FavoritesSheetView: View {
    let favorites: [NASA]
    @Binding var isPresented: Bool
    let selectAction: (NASA) -> Void
    let removeAction: (NASA) -> Void
    @State private var searchQuery = ""

    private var filteredFavorites: [NASA] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return favorites }
        return favorites.filter { item in
            (item.title ?? "").localizedCaseInsensitiveContains(trimmed) ||
            (item.date ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        AdaptiveNavigationContainer {
            Group {
                if favorites.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            L10n.text("No Favorites Yet", default: "No Favorites Yet"),
                            systemImage: "heart.slash",
                            description: Text(L10n.text("Save APOD entries with the heart button to quickly revisit them.", default: "Save APOD entries with the heart button to quickly revisit them."))
                        )
                        .accessibilityIdentifier(AccessibilityID.favoritesEmptyState)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text(L10n.text("No Favorites Yet", default: "No Favorites Yet"))
                                .font(AppTheme.Typography.sectionTitle)
                            Text(L10n.text("Save APOD entries with the heart button to quickly revisit them.", default: "Save APOD entries with the heart button to quickly revisit them."))
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .accessibilityIdentifier(AccessibilityID.favoritesEmptyState)
                    }
                } else {
                    List {
                        ForEach(filteredFavorites) { item in
                            Button {
                                selectAction(item)
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title ?? L10n.text("Untitled", default: "Untitled"))
                                            .font(AppTheme.Typography.sectionTitle)
                                            .foregroundColor(.primary)
                                        Text(APODDateDisplayPolicy.displayString(for: item.date))
                                            .font(AppTheme.Typography.metadata)
                                            .foregroundColor(.secondary)
                                        Text(APODAttributionPolicy.creditLine(for: item))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Image(systemName: item.mediaType == .video ? "play.rectangle" : "photo")
                                            .foregroundColor(.secondary)
                                        Text(item.mediaType.localizedDisplayName)
                                            .font(AppTheme.Typography.metadata)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .accessibilityIdentifier(AccessibilityID.favoriteRowIdentifier(for: item))
                            .accessibilityHint(L10n.text("Open this saved APOD", default: "Open this saved APOD"))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    removeAction(item)
                                } label: {
                                    Label(L10n.text("Delete", default: "Delete"), systemImage: "trash")
                                }
                                .accessibilityIdentifier(AccessibilityID.favoriteDeleteActionIdentifier(for: item))
                            }
                        }
                    }
                    .overlay {
                        if filteredFavorites.isEmpty {
                            if #available(iOS 17.0, *) {
                                ContentUnavailableView.search(text: searchQuery)
                            } else {
                                Text(L10n.text("No favorites match your search.", default: "No favorites match your search."))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .searchable(text: $searchQuery, prompt: L10n.text("Search favorites", default: "Search favorites"))
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(L10n.text("Favorites", default: "Favorites"))
            .overlay(alignment: .topLeading) {
                AccessibilityMarker(identifier: AccessibilityID.favoritesSheetRoot)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Done", default: "Done")) { isPresented = false }
                        .accessibilityIdentifier(AccessibilityID.favoritesDoneButton)
                }
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let toggleIdentifier: String
    let accessibilityHint: String
    let isEnabled: Bool
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
                isOn.toggle()
            }

            Toggle(isOn: $isOn) {
                EmptyView()
            }
            .labelsHidden()
            .disabled(!isEnabled)
            .accessibilityIdentifier(toggleIdentifier)
            .accessibilityLabel(title)
            .accessibilityHint(accessibilityHint)
        }
        .opacity(isEnabled ? 1 : 0.65)
    }
}

private struct StatusBannerCard: View {
    let systemImage: String
    let message: String
    let tint: Color
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(message)
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTheme.Typography.footnoteStrong)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsSheetView: View {
    @Binding var preferImages: Bool
    @Binding var allowVideoPlayback: Bool
    @Binding var dailyNotificationsEnabled: Bool
    @Binding var dailyNotificationHour: Int
    @Binding var dailyNotificationMinute: Int
    @Binding var dataSaverMode: Bool
    @Binding var preferHDImages: Bool
    @Binding var cacheItemLimit: Int
    @Binding var wifiOnlyVideoAutoplay: Bool
    @Binding var isPresented: Bool
    let lastStatusCode: Int?
    let lastRequestDate: Date?
    let isAPIKeyConfigured: Bool
    let lastTransportError: String?
    let isUsingCachedData: Bool
    let diagnosticsHistory: [RequestDiagnostic]
    let apiKeyWarning: String?
    let rateLimitRetryDate: Date?
    let notificationPermissionStatus: UNAuthorizationStatus
    let nextScheduledNotificationDate: Date?
    let cachedItemCount: Int
    let appliedCacheItemLimit: Int
    let networkConnectionLabel: String
    let networkReachable: Bool
    let networkIsExpensive: Bool
    let networkIsConstrained: Bool
    let videoAutoplayEligible: Bool

    private func localizedDiagnosticResult(_ result: String) -> String {
        switch result.lowercased() {
        case "success":
            return L10n.text("Success", default: "Success")
        case "failure":
            return L10n.text("Failure", default: "Failure")
        default:
            return result
        }
    }

    private var notificationTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = dailyNotificationHour
                components.minute = dailyNotificationMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                dailyNotificationHour = components.hour ?? 9
                dailyNotificationMinute = components.minute ?? 0
            }
        )
    }

    private var notificationPermissionLabel: String {
        switch notificationPermissionStatus {
        case .authorized: return L10n.text("notification.authorized", default: "Authorized")
        case .provisional: return L10n.text("notification.provisional", default: "Provisional")
        case .ephemeral: return L10n.text("notification.ephemeral", default: "Ephemeral")
        case .denied: return L10n.text("notification.denied", default: "Denied")
        case .notDetermined: return L10n.text("notification.not_determined", default: "Not Determined")
        @unknown default: return L10n.text("notification.unknown", default: "Unknown")
        }
    }

    private var videoAutoplayPolicyLabel: String {
        guard allowVideoPlayback else { return L10n.text("video.playback_disabled", default: "Playback disabled") }
        guard wifiOnlyVideoAutoplay else { return L10n.text("video.autoplay_any_network", default: "Autoplay allowed on any network") }
        if !networkReachable { return L10n.text("video.waiting_for_network", default: "Waiting for network connection") }
        return videoAutoplayEligible
            ? L10n.text("video.autoplay_wifi", default: "Autoplay allowed on Wi-Fi")
            : L10n.text("video.manual_off_wifi", default: "Manual play required off Wi-Fi")
    }

    private var networkEfficiencyLabel: String {
        if !networkReachable {
            return L10n.text("network.offline_cached_preferred", default: "Offline. Cached APOD content is preferred.")
        }
        if dataSaverMode && networkIsConstrained {
            return L10n.text("network.maximum_savings", default: "Maximum savings. App data saver and Low Data Mode are both active.")
        }
        if dataSaverMode {
            return L10n.text("network.data_saver_active", default: "App data saver active. Lower-bandwidth images are preferred.")
        }
        if networkIsConstrained {
            return L10n.text("network.low_data_mode_active", default: "System Low Data Mode active. Prefer lighter media usage.")
        }
        if networkIsExpensive {
            return L10n.text("network.metered_detected", default: "Metered connection detected. HD media may increase data usage.")
        }
        return L10n.text("network.standard_delivery", default: "Standard media delivery.")
    }

    var body: some View {
        AdaptiveNavigationContainer {
            Form {
                Color.clear
                    .frame(height: 36)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityHidden(true)

                Section(L10n.text("Content Preferences", default: "Content Preferences")) {
                    Toggle(L10n.text("Prefer Images Only", default: "Prefer Images Only"), isOn: $preferImages)
                        .accessibilityLabel(L10n.text("Prefer images only for random selection", default: "Prefer images only for random selection"))
                        .accessibilityHint(L10n.text("Limits random selection to images only", default: "Limits random selection to images only"))
                    Toggle(L10n.text("Allow Video Playback", default: "Allow Video Playback"), isOn: $allowVideoPlayback)
                        .accessibilityLabel(L10n.text("Allow video playback", default: "Allow video playback"))
                        .accessibilityHint(L10n.text("Controls whether APOD videos play inside the app", default: "Controls whether APOD videos play inside the app"))
                }

                Section(L10n.text("API Diagnostics", default: "API Diagnostics")) {
                    LabeledContent(L10n.text("NASA_API_KEY Configured", default: "NASA_API_KEY Configured")) {
                        Text(isAPIKeyConfigured ? L10n.text("Yes", default: "Yes") : L10n.text("No (Using DEMO_KEY)", default: "No (Using DEMO_KEY)"))
                            .foregroundColor(isAPIKeyConfigured ? .green : .orange)
                    }
                    LabeledContent(L10n.text("Last Status Code", default: "Last Status Code")) {
                        Text(lastStatusCode.map(String.init) ?? L10n.notAvailable)
                            .accessibilityIdentifier(AccessibilityID.lastStatusCodeValue)
                    }
                    LabeledContent(L10n.text("Last Request Time", default: "Last Request Time")) {
                        Text(formattedRequestDate(lastRequestDate))
                    }
                    LabeledContent(L10n.text("Using Cached Data", default: "Using Cached Data")) {
                        Text(L10n.yesNo(isUsingCachedData))
                    }
                    if let rateLimitRetryDate {
                        LabeledContent(L10n.text("Rate Limit Retry Time", default: "Rate Limit Retry Time")) {
                            Text(formattedRequestDate(rateLimitRetryDate))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if let lastTransportError {
                        LabeledContent(L10n.text("Last Transport Error", default: "Last Transport Error")) {
                            Text(lastTransportError)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if let apiKeyWarning {
                        LabeledContent(L10n.text("API Key Warning", default: "API Key Warning")) {
                            Text(apiKeyWarning)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if !diagnosticsHistory.isEmpty {
                    Section(L10n.text("Recent Requests", default: "Recent Requests")) {
                        ForEach(diagnosticsHistory.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(localizedDiagnosticResult(item.result)) • \(item.statusCode.map(String.init) ?? L10n.notAvailable)")
                                    .font(.caption)
                                if let transportError = item.transportError, !transportError.isEmpty {
                                    Text(transportError)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                Section(L10n.text("Daily Notifications", default: "Daily Notifications")) {
                    Toggle(L10n.text("Enable Daily APOD Alerts", default: "Enable Daily APOD Alerts"), isOn: $dailyNotificationsEnabled)
                    DatePicker(
                        L10n.text("Alert Time", default: "Alert Time"),
                        selection: notificationTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!dailyNotificationsEnabled)
                    LabeledContent(L10n.text("Notification Permission", default: "Notification Permission")) {
                        Text(notificationPermissionLabel)
                    }
                    LabeledContent(L10n.text("Next Scheduled Alert", default: "Next Scheduled Alert")) {
                        Text(formattedRequestDate(nextScheduledNotificationDate))
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(L10n.text("Data Saver", default: "Data Saver")) {
                    SettingsToggleRow(
                        title: L10n.text("Enable Data Saver Mode", default: "Enable Data Saver Mode"),
                        subtitle: L10n.text("Favors lower-bandwidth image URLs and turns off HD image preference.", default: "Favors lower-bandwidth image URLs and turns off HD image preference."),
                        toggleIdentifier: AccessibilityID.dataSaverModeToggle,
                        accessibilityHint: L10n.text("Reduces network usage for APOD media.", default: "Reduces network usage for APOD media."),
                        isEnabled: true,
                        isOn: $dataSaverMode
                    )
                    SettingsToggleRow(
                        title: L10n.text("Prefer HD Images", default: "Prefer HD Images"),
                        subtitle: L10n.text("Uses the highest-resolution image when available.", default: "Uses the highest-resolution image when available."),
                        toggleIdentifier: AccessibilityID.preferHDImagesToggle,
                        accessibilityHint: L10n.text("Downloads higher resolution APOD images when data saver is off.", default: "Downloads higher resolution APOD images when data saver is off."),
                        isEnabled: !dataSaverMode,
                        isOn: $preferHDImages
                    )
                    Toggle(L10n.text("Autoplay Videos on Wi-Fi Only", default: "Autoplay Videos on Wi-Fi Only"), isOn: $wifiOnlyVideoAutoplay)
                        .disabled(!allowVideoPlayback)
                    Stepper(value: $cacheItemLimit, in: 30...365, step: 15) {
                        LabeledContent(L10n.text("Cache Item Limit", default: "Cache Item Limit")) {
                            Text(String(cacheItemLimit))
                        }
                    }
                    Text(L10n.text("Data Saver favors lower-bandwidth image URLs and can reduce media quality on slower connections.", default: "Data Saver favors lower-bandwidth image URLs and can reduce media quality on slower connections."))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(L10n.text("Storage Diagnostics", default: "Storage Diagnostics")) {
                    LabeledContent(L10n.text("Cached APOD Items", default: "Cached APOD Items")) {
                        Text(String(cachedItemCount))
                    }
                    LabeledContent(L10n.text("Applied Cache Limit", default: "Applied Cache Limit")) {
                        Text(String(appliedCacheItemLimit))
                    }
                    LabeledContent(L10n.text("Data Saver Active", default: "Data Saver Active")) {
                        Text(L10n.yesNo(dataSaverMode))
                    }
                    LabeledContent(L10n.text("HD Images Preferred", default: "HD Images Preferred")) {
                        Text(L10n.yesNo(preferHDImages))
                    }
                }

                Section(L10n.text("Network Diagnostics", default: "Network Diagnostics")) {
                    LabeledContent(L10n.text("Connection", default: "Connection")) {
                        Text(networkConnectionLabel)
                            .accessibilityIdentifier(AccessibilityID.networkConnectionValue)
                    }
                    LabeledContent(L10n.text("Network Reachable", default: "Network Reachable")) {
                        Text(L10n.yesNo(networkReachable))
                    }
                    LabeledContent(L10n.text("Metered Network", default: "Metered Network")) {
                        Text(L10n.yesNo(networkIsExpensive))
                            .accessibilityIdentifier(AccessibilityID.meteredNetworkValue)
                    }
                    LabeledContent(L10n.text("Low Data Mode", default: "Low Data Mode")) {
                        Text(L10n.yesNo(networkIsConstrained))
                            .accessibilityIdentifier(AccessibilityID.lowDataModeValue)
                    }
                    LabeledContent(L10n.text("Video Autoplay Eligible", default: "Video Autoplay Eligible")) {
                        Text(L10n.yesNo(videoAutoplayEligible))
                    }
                    LabeledContent(L10n.text("Autoplay Policy", default: "Autoplay Policy")) {
                        Text(videoAutoplayPolicyLabel)
                            .accessibilityIdentifier(AccessibilityID.autoplayPolicyValue)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent(L10n.text("Network Efficiency", default: "Network Efficiency")) {
                        Text(networkEfficiencyLabel)
                            .accessibilityIdentifier(AccessibilityID.networkEfficiencyValue)
                            .multilineTextAlignment(.trailing)
                    }
                    if wifiOnlyVideoAutoplay {
                        Text(L10n.text("Videos will wait for manual playback unless the device is on Wi-Fi.", default: "Videos will wait for manual playback unless the device is on Wi-Fi."))
                            .font(AppTheme.Typography.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.text("Settings", default: "Settings"))
            .overlay(alignment: .topLeading) {
                AccessibilityMarker(identifier: AccessibilityID.settingsSheetRoot)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Done", default: "Done")) { isPresented = false }
                        .accessibilityIdentifier(AccessibilityID.settingsCloseButton)
                        .accessibilityLabel(L10n.text("Close settings", default: "Close settings"))
                }
            }
        }
    }

    private func formattedRequestDate(_ date: Date?) -> String {
        guard let date else { return L10n.notAvailable }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}

private struct APIRequestStatusBanner: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var accessibilityDifferentiateWithoutColor
    let isFetching: Bool
    let error: NasaCollectionFetcher.FetchError?
    let hasLoadedContent: Bool
    let retryAction: () -> Void
    let isOfflineMode: Bool
    let apiKeyWarning: String?
    let rateLimitRetryDate: Date?

    var body: some View {
        VStack(spacing: 6) {
            if isOfflineMode {
                StatusBannerCard(
                    systemImage: "wifi.slash",
                    message: accessibilityDifferentiateWithoutColor
                        ? L10n.text("Offline mode. Showing cached APOD content.", default: "Offline mode. Showing cached APOD content.")
                        : L10n.text("Offline mode: showing cached APOD content.", default: "Offline mode: showing cached APOD content."),
                    tint: AppTheme.Palette.warning,
                    actionTitle: nil,
                    action: nil
                )
            }

            if let rateLimitRetryDate {
                let retryTime = rateLimitRetryDate.formatted(date: .omitted, time: .shortened)
                StatusBannerCard(
                    systemImage: "timer",
                    message: accessibilityDifferentiateWithoutColor
                        ? L10n.format("Rate limit warning. Try again at %@", default: "Rate limit warning. Try again at %@", retryTime)
                        : L10n.format("Rate limited. Try again at %@", default: "Rate limited. Try again at %@", retryTime),
                    tint: AppTheme.Palette.warning,
                    actionTitle: nil,
                    action: nil
                )
            }

            if let apiKeyWarning {
                StatusBannerCard(
                    systemImage: "key.fill",
                    message: accessibilityDifferentiateWithoutColor
                        ? L10n.format("API key warning. %@", default: "API key warning. %@", apiKeyWarning)
                        : apiKeyWarning,
                    tint: AppTheme.Palette.warning,
                    actionTitle: nil,
                    action: nil
                )
            }

            if isFetching && hasLoadedContent {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L10n.text("Refreshing APOD from NASA API...", default: "Refreshing APOD from NASA API..."))
                        .font(AppTheme.Typography.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            } else if let error, hasLoadedContent {
                StatusBannerCard(
                    systemImage: "exclamationmark.triangle.fill",
                    message: accessibilityDifferentiateWithoutColor
                        ? L10n.format("Error. %@", default: "Error. %@", error.localizedDescription)
                        : error.localizedDescription,
                    tint: AppTheme.Palette.warning,
                    actionTitle: L10n.text("Retry", default: "Retry"),
                    action: retryAction
                )
            }
        }
    }
}

private struct APIRequestEmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    title,
                    systemImage: "hourglass",
                    description: Text(subtitle)
                )
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(title)
                        .font(AppTheme.Typography.sectionTitle)
                    Text(subtitle)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct APIRequestFailureView: View {
    let error: NasaCollectionFetcher.FetchError
    let retryAction: () -> Void

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentUnavailableView {
                    Label(L10n.text("API Request Failed", default: "API Request Failed"), systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button(L10n.text("Retry", default: "Retry"), action: retryAction)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.Palette.warning)
                    Text(L10n.text("API Request Failed", default: "API Request Failed"))
                        .font(AppTheme.Typography.cardTitle)
                    Text(error.localizedDescription)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button(L10n.text("Retry", default: "Retry"), action: retryAction)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let fetcher = NasaCollectionFetcher()
        MainView()
            .environmentObject(fetcher)
            .previewDisplayName("Default")
        
        MainView()
            .environmentObject(fetcher)
            .environment(\.colorScheme, .dark)
            .previewDisplayName("Dark Mode")
    }
}

private struct MediaView: View {
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
    @State private var showWebVideoSheet = false
    @State private var directVideoPlayer: AVPlayer?
    @State private var magnificationStartScale: CGFloat?

    private var preferredImageURL: URL? {
        APODSourceLinkPolicy.preferredMediaURL(
            for: nasa,
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private var shouldAutoplayVideo: Bool {
        if !wifiOnlyVideoAutoplay {
            return true
        }
        return isOnWiFiConnection
    }

    var body: some View {
        @ViewBuilder var content: some View {
            if nasa.mediaType == .image {
                AsyncImage(url: preferredImageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(16)
                            .shadow(radius: 5)
                            .padding(.horizontal)
                            .offset(x: imageOffset.width, y: imageOffset.height)
                            .scaleEffect(imageScale)
                            .accessibilityIdentifier(AccessibilityID.apodImageView)
                            .accessibilityLabel(nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture"))
                            .accessibilityAddTraits(.isImage)
                            .onTapGesture(count: 2) {
                                if reduceMotion {
                                    imageScale = imageScale == 1 ? 2 : 1
                                    if imageScale == 1 {
                                        imageOffset = .zero
                                    }
                                } else {
                                    withAnimation(.spring()) {
                                        imageScale = imageScale == 1 ? 2 : 1
                                        if imageScale == 1 {
                                            imageOffset = .zero
                                        }
                                    }
                                }
                            }
                            .simultaneousGesture(DragGesture()
                                .onChanged { value in
                                    guard imageScale > 1 else { return }
                                    imageOffset = value.translation
                                }
                                .onEnded { _ in
                                    if imageScale <= 1 { resetImageState() }
                                }
                            )
                            .simultaneousGesture(MagnificationGesture()
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
                            )
                    } else if phase.error != nil {
                        MediaPlaceholderCard(
                            systemImage: "photo.badge.exclamationmark",
                            title: L10n.text("media.image_unavailable", default: "Image Unavailable"),
                            message: L10n.text(
                                "media.image_unavailable_message",
                                default: "This APOD image could not be loaded right now. You can still open the source directly."
                            )
                        ) {
                            if let preferredImageURL {
                                Button(L10n.text("media.open_source", default: "Open Source")) {
                                    openURL(preferredImageURL)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.horizontal)
                        .accessibilityIdentifier(AccessibilityID.apodImageUnavailableMessage)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
            } else if nasa.mediaType == .video {
                if !allowVideoPlayback {
                    MediaPlaceholderCard(
                        systemImage: "play.slash.fill",
                        title: L10n.text("video.playback_disabled_title", default: "Video Playback Disabled"),
                        message: L10n.text(
                            "video.playback_disabled_message",
                            default: "Enable video playback in Settings to watch this APOD inside the app."
                        )
                    ) {
                        EmptyView()
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier(AccessibilityID.videoDisabledMessage)
                } else if let videoID = extractYouTubeID(nasa.url) {
                    let player = YouTubePlayer(source: .video(id: videoID))
                    YouTubePlayerView(player)
                        .frame(height: 300)
                        .cornerRadius(15)
                        .padding(.horizontal)
                        .overlay {
                            if isVideoLoading {
                                ProgressView()
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
                } else if let videoURL = nasa.url, supportsInlineDirectVideo(videoURL) {
                    ZStack(alignment: .bottomLeading) {
                        VideoPlayer(player: directVideoPlayer)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(height: 300)
                            .task(id: videoURL) {
                                configureDirectVideoPlayer(for: videoURL, autoplay: shouldAutoplayVideo)
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
                                shouldAutoplayVideo
                                    ? (wifiOnlyVideoAutoplay
                                        ? L10n.text("Autoplay allowed on Wi-Fi", default: "Autoplay allowed on Wi-Fi")
                                        : L10n.text("Autoplay allowed on any network", default: "Autoplay allowed on any network"))
                                    : L10n.text("Autoplay paused on non-Wi-Fi network.", default: "Autoplay paused on non-Wi-Fi network.")
                            )

                        if wifiOnlyVideoAutoplay && !isOnWiFiConnection {
                            Text(L10n.text("video.autoplay_paused_off_wifi", default: "Autoplay paused on non-Wi-Fi network."))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(10)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                } else {
                    MediaPlaceholderCard(
                        systemImage: "safari.fill",
                        title: L10n.text("video.browser_recommended_title", default: "Browser Playback Recommended"),
                        message: L10n.text(
                            "video.browser_recommended_message",
                            default: "This video source is better handled in the browser, but you can still open it from here."
                        )
                    ) {
                        if let videoURL = nasa.url {
                            Button(L10n.text("media.play_video", default: "Play Video")) {
                                showWebVideoSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(AccessibilityID.playVideoInAppButton)
                            .sheet(isPresented: $showWebVideoSheet) {
                                SafariView(url: videoURL)
                            }

                            Button(L10n.text("media.open_external_browser", default: "Open in External Browser")) {
                                openURL(videoURL)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(AccessibilityID.openVideoExternalButton)
                        }
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier(AccessibilityID.unsupportedVideoMessage)
                }
            } else {
                MediaPlaceholderCard(
                    systemImage: "questionmark.video",
                    title: L10n.text("media.unsupported_title", default: "Unsupported Media"),
                    message: L10n.text(
                        "media.unsupported_message",
                        default: "This APOD entry uses a media type the app cannot present yet."
                    )
                ) {
                    if let fallbackURL = nasa.url ?? nasa.hdurl {
                        Button(L10n.text("media.open_source", default: "Open Source")) {
                            openURL(fallbackURL)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }
        }

        return content
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
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let systemImage: String
    let title: String
    let message: String
    private let actions: Actions

    init(
        systemImage: String,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actions = actions()
    }

    private var backgroundStyle: AnyShapeStyle {
        AppTheme.glassSurface(reduceTransparency: accessibilityReduceTransparency)
    }

    private var actionsLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize || horizontalSizeClass == .compact {
            return AnyLayout(VStackLayout(spacing: 10))
        }
        return AnyLayout(HStackLayout(spacing: 10))
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(title)
                    .font(AppTheme.Typography.cardTitle)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !(Actions.self == EmptyView.self) {
                actionsLayout {
                    actions
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct AdaptiveNavigationContainer<Content: View>: View {
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

private struct NotificationSettings: Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}

@MainActor
private final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center: UNUserNotificationCenter
    private let requestIdentifier = "daily_apod_notification"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        if status == .authorized || status == .provisional || status == .ephemeral {
            return true
        }
        guard status == .notDetermined else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func cancelDailyNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    }

    func nextPendingNotificationDate() async -> Date? {
        let requests = await center.pendingNotificationRequests()
        guard
            let request = requests.first(where: { $0.identifier == requestIdentifier }),
            let trigger = request.trigger as? UNCalendarNotificationTrigger,
            let nextDate = trigger.nextTriggerDate()
        else {
            return nil
        }
        return nextDate
    }

    func scheduleDailyAPODNotification(settings: NotificationSettings) async {
        cancelDailyNotification()
        guard settings.isEnabled else { return }

        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.text("New NASA APOD", default: "New NASA APOD")
        content.body = L10n.text("A new Astronomy Picture of the Day is available.", default: "A new Astronomy Picture of the Day is available.")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: settings.dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}

private enum NetworkConnectionKind: Equatable {
    case wifi
    case cellular
    case wiredEthernet
    case loopback
    case other
    case unavailable

    var displayName: String {
        switch self {
        case .wifi:
            return L10n.text("Wi-Fi", default: "Wi-Fi")
        case .cellular:
            return L10n.text("Cellular", default: "Cellular")
        case .wiredEthernet:
            return L10n.text("Ethernet", default: "Ethernet")
        case .loopback:
            return L10n.text("Loopback", default: "Loopback")
        case .other:
            return L10n.text("Other", default: "Other")
        case .unavailable:
            return L10n.text("Unavailable", default: "Unavailable")
        }
    }
}

private struct NetworkFixtureState {
    let connectionKind: NetworkConnectionKind
    let isSatisfied: Bool
    let isExpensive: Bool
    let isConstrained: Bool

    static func fromEnvironment(_ environment: [String: String]) -> NetworkFixtureState? {
        guard environment["UITEST_USE_FIXTURE"] == "1" else { return nil }
        guard let rawKind = environment["UITEST_NETWORK_KIND"]?.lowercased() else { return nil }

        let connectionKind: NetworkConnectionKind
        switch rawKind {
        case "wifi":
            connectionKind = .wifi
        case "cellular":
            connectionKind = .cellular
        case "ethernet":
            connectionKind = .wiredEthernet
        case "loopback":
            connectionKind = .loopback
        case "other":
            connectionKind = .other
        case "offline", "unavailable":
            connectionKind = .unavailable
        default:
            return nil
        }

        return NetworkFixtureState(
            connectionKind: connectionKind,
            isSatisfied: connectionKind != .unavailable,
            isExpensive: environment["UITEST_NETWORK_EXPENSIVE"] == "1",
            isConstrained: environment["UITEST_NETWORK_CONSTRAINED"] == "1"
        )
    }
}

@MainActor
private final class NetworkStatusMonitor: ObservableObject {
    @Published private(set) var connectionKind: NetworkConnectionKind = .unavailable
    @Published private(set) var isSatisfied = false
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "NASA.NetworkStatusMonitor")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        if let fixtureState = NetworkFixtureState.fromEnvironment(ProcessInfo.processInfo.environment) {
            connectionKind = fixtureState.connectionKind
            isSatisfied = fixtureState.isSatisfied
            isExpensive = fixtureState.isExpensive
            isConstrained = fixtureState.isConstrained
            return
        }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path: path)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }

    private func apply(path: NWPath) {
        isSatisfied = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        guard isSatisfied else {
            connectionKind = .unavailable
            return
        }

        if path.usesInterfaceType(.wifi) {
            connectionKind = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionKind = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionKind = .wiredEthernet
        } else if path.usesInterfaceType(.loopback) {
            connectionKind = .loopback
        } else {
            connectionKind = .other
        }
    }
}
