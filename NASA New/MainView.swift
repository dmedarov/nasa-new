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
        static let dateSelectionDebounceNanoseconds: UInt64 = 250_000_000
        static let shareExplanationMaxLength: Int = 100
        static let selectedDateSceneStorageKey = "MainView.selectedAPODDate"
    }

    @EnvironmentObject var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.appShellContext) private var appShellContext
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @State private var imageScale: CGFloat = ViewConstants.minImageScale
    @State private var imageOffset: CGSize = .zero
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
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
    
    @AppStorage(AppAppearancePolicy.storageKey) private var appearancePreferenceRawValue: String = AppAppearancePreference.system.rawValue
    @AppStorage("preferImages") private var preferImages: Bool = false
    @AppStorage("allowVideoPlayback") private var allowVideoPlayback: Bool = true
    @AppStorage("dailyNotificationsEnabled") private var dailyNotificationsEnabled: Bool = false
    @AppStorage("dailyNotificationHour") private var dailyNotificationHour: Int = 9
    @AppStorage("dailyNotificationMinute") private var dailyNotificationMinute: Int = 0
    @AppStorage("dataSaverMode") private var dataSaverMode: Bool = false
    @AppStorage("preferHDImages") private var preferHDImages: Bool = true
    @AppStorage(APODArchiveStoragePolicy.storageKey) private var cacheItemLimit: Int = APODArchiveStoragePolicy.defaultArchiveLimit
    @AppStorage("wifiOnlyVideoAutoplay") private var wifiOnlyVideoAutoplay: Bool = true
    private let openArchiveAction: () -> Void
    private let openSavedAction: () -> Void
    private let preferredAvailableWidth: CGFloat?

    init(
        preferredAvailableWidth: CGFloat? = nil,
        openArchiveAction: @escaping () -> Void = {},
        openSavedAction: @escaping () -> Void = {}
    ) {
        self.preferredAvailableWidth = preferredAvailableWidth
        self.openArchiveAction = openArchiveAction
        self.openSavedAction = openSavedAction
    }

    private var appearancePreference: AppAppearancePreference {
        AppAppearancePolicy.resolvedPreference(from: appearancePreferenceRawValue)
    }

    private var appearancePreferenceBinding: Binding<AppAppearancePreference> {
        Binding(
            get: { appearancePreference },
            set: { appearancePreferenceRawValue = $0.rawValue }
        )
    }

    private var effectiveIsDarkMode: Bool {
        AppAppearancePolicy.effectiveIsDarkMode(
            preference: appearancePreference,
            systemColorScheme: colorScheme
        )
    }

    private var effectiveReduceMotion: Bool {
        appRuntimeOverrides.resolvedReduceMotion(systemValue: accessibilityReduceMotion)
    }

    private var usesWideEditorialLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var usesPremiumShellWideLayout: Bool {
        appShellContext == .premiumRegularShell && usesWideEditorialLayout
    }

    private func usesPremiumShellSplitLayout(for availableWidth: CGFloat) -> Bool {
        usesPremiumShellWideLayout && availableWidth >= AppTheme.Metrics.premiumSplitLayoutMinimumWidth
    }

    private var shouldInlineStatusBannerInEditorialColumn: Bool {
        usesPremiumShellWideLayout && hasLoadedContent && fetcher.error == nil
    }

    private var wideEditorialContentMaxWidth: CGFloat {
        appShellContext == .premiumRegularShell
            ? AppTheme.Metrics.premiumEditorialStageMaxWidth
            : AppTheme.Metrics.readerStageMaxWidth
    }

    private func premiumStageWidths(for availableWidth: CGFloat) -> (media: CGFloat, editorial: CGFloat) {
        let usableWidth = min(
            max(availableWidth - (AppTheme.Spacing.xl * 2), 0),
            wideEditorialContentMaxWidth
        )
        let spacing = AppTheme.Spacing.xxl
        let idealEditorialWidth = min(
            max(usableWidth * 0.36, 320),
            AppTheme.Metrics.premiumEditorialColumnWidth
        )
        let minimumMediaWidth: CGFloat = 420
        let rawMediaWidth = usableWidth - idealEditorialWidth - spacing

        if rawMediaWidth >= minimumMediaWidth {
            return (rawMediaWidth, idealEditorialWidth)
        }

        let adjustedEditorialWidth = max(usableWidth - minimumMediaWidth - spacing, 300)
        let adjustedMediaWidth = max(usableWidth - adjustedEditorialWidth - spacing, 0)
        return (adjustedMediaWidth, adjustedEditorialWidth)
    }

    private var navigationTitleText: String {
        switch appShellContext {
        case .compactTabs:
            return L10n.text("Space Briefing", default: "Space Briefing")
        case .premiumRegularShell:
            return L10n.text("Today", default: "Today")
        }
    }

    private func resetImageState() {
        let updates = {
            imageScale = ViewConstants.minImageScale
            imageOffset = .zero
        }
        if effectiveReduceMotion {
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
        storedSelectedDateValue = fetcher.apodDateString(from: date)
    }

    private var restoredSelectedDate: Date? {
        APODDateRestoration.restoredDate(
            storedValue: storedSelectedDateValue,
            parseDate: fetcher.date(from:),
            minimumDate: fetcher.minimumSelectableDate,
            maximumDate: fetcher.maximumSelectableDate
        )
    }

    private var premiumReferenceDate: Date {
        fetcher.maximumSelectableDate
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
        attemptDateSelection(clampedDate, trigger: .todayDateSelection)
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
        guard canAccessArchiveDate(restoredSelectedDate) else {
            storedSelectedDateValue = fetcher.apodDateString(from: premiumReferenceDate)
            return
        }
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
           canAccessArchiveDate(restoredSelectedDate),
           !fetcher.isSameAPODDay(restoredSelectedDate, fetcher.maximumSelectableDate) {
            requestAPOD(for: restoredSelectedDate)
        } else {
            fetcher.startLatestFetch()
        }
    }

    private var gatedSelectedDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { proposedDate in
                attemptDateSelection(proposedDate, trigger: .todayDateSelection)
            }
        )
    }

    private func canAccessArchiveDate(_ date: Date) -> Bool {
        purchaseManager.canAccessArchive(
            date: fetcher.normalizedDate(date),
            referenceDate: premiumReferenceDate,
            calendar: fetcher.calendar
        )
    }

    private func attemptDateSelection(_ proposedDate: Date, trigger: PaywallTrigger) {
        let normalizedDate = fetcher.normalizedDate(proposedDate)

        guard canAccessArchiveDate(normalizedDate) else {
            purchaseManager.presentPaywall(trigger: trigger, feature: .fullArchive)
            return
        }

        selectedDate = normalizedDate
    }
    
    var body: some View {
        GeometryReader { proxy in
            let contentWidth = preferredAvailableWidth ?? proxy.size.width

            VStack(spacing: AppTheme.Spacing.sm) {
                if !shouldInlineStatusBannerInEditorialColumn {
                    statusBannerSection
                }
                mainContentSection(availableWidth: contentWidth)
            }
        }
        .padding(.top, AppTheme.Spacing.xs)
        .background(backgroundLayer)
        .navigationTitle(navigationTitleText)
        .appScreenChrome()
        .preferredColorScheme(appearancePreference.preferredColorScheme)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView(
                appearancePreference: appearancePreferenceBinding,
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
                videoAutoplayEligible: !wifiOnlyVideoAutoplay || networkStatus.connectionKind == .wifi,
                offlineMediaSummary: fetcher.offlineMediaStorageSummary,
                onClearOfflineMedia: {
                    await fetcher.clearOfflineMedia()
                },
                onRebuildOfflineMedia: {
                    await fetcher.rebuildOfflineMedia()
                }
            )
        }
        .accessibilityIdentifier(AccessibilityID.mainViewRoot)
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
        ScreenPanelColumn {
            headerPanelContent
        }
    }

    private var statusBannerSection: some View {
        ScreenPanelColumn(topPadding: 0) {
            statusBannerContent
            .accessibilitySortPriority(90)
        }
    }

    private var statusBannerContent: some View {
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

    private var headerPanelContent: some View {
        MainHeaderBar(
            showSettingsSheet: $showSettingsSheet,
            selectedDate: gatedSelectedDateBinding,
            minimumDate: fetcher.minimumSelectableDate,
            maximumDate: fetcher.maximumSelectableDate,
            isFetching: fetcher.isFetching,
            hasApodData: hasLoadedContent,
            favoritesCount: fetcher.favorites.count,
            isFavorite: fetcher.isFavorite(fetcher.currentNasa),
            preferImages: preferImages,
            isShowingLatestDate: isShowingLatestDate,
            toggleFavoriteAction: toggleFavorite,
            shareAction: { showShareSheet = true },
            refreshAction: retryLatestRequest,
            isShowingMinimumDate: isShowingMinimumDate,
            previousDateAction: { shiftSelectedDate(byDays: -1) },
            nextDateAction: { shiftSelectedDate(byDays: 1) },
            jumpToLatestAction: jumpToLatestDate,
            randomizeAction: randomizeSelection,
            openArchiveAction: openArchiveAction,
            openSavedAction: openSavedAction
        )
    }

    @ViewBuilder
    private func mainContentSection(availableWidth: CGFloat) -> some View {
        if !hasLoadedContent && fetcher.isFetching {
            APIRequestEmptyStateView(
                title: L10n.text("Loading APOD", default: "Loading APOD"),
                subtitle: L10n.text(
                    "loading.apod_public_service",
                    default: "Fetching today's APOD briefing from NASA's public Astronomy Picture of the Day service."
                )
            )
            Spacer()
        } else if !hasLoadedContent, let error = fetcher.error {
            APIRequestFailureView(error: error, retryAction: retryLatestRequest)
            Spacer()
        } else {
            ScrollView {
                if usesPremiumShellSplitLayout(for: availableWidth) {
                    let widths = premiumStageWidths(for: availableWidth)

                    HStack(alignment: .top, spacing: AppTheme.Spacing.xxl) {
                        mediaSection
                            .frame(width: widths.media, alignment: .topLeading)
                            .layoutPriority(1)

                        premiumEditorialColumn
                            .frame(width: widths.editorial, alignment: .topLeading)
                    }
                    .frame(width: widths.media + widths.editorial + AppTheme.Spacing.xxl, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.top, AppTheme.Spacing.sm)
                    .padding(.bottom, AppTheme.Spacing.xxl)
                } else if appShellContext == .premiumRegularShell {
                    VStack(spacing: AppTheme.Spacing.xl) {
                        mediaSection
                            .frame(maxWidth: wideEditorialContentMaxWidth, alignment: .topLeading)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, AppTheme.Spacing.xl)

                        premiumEditorialColumn
                            .frame(maxWidth: 860, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                    }
                    .padding(.top, AppTheme.Spacing.sm)
                    .padding(.bottom, AppTheme.Spacing.xxl)
                } else {
                    VStack(spacing: AppTheme.Spacing.xl) {
                        if usesWideEditorialLayout {
                            headerSection

                            HStack(alignment: .top, spacing: AppTheme.Spacing.xl) {
                                mediaSection
                                    .frame(maxWidth: .infinity, alignment: .top)

                                detailsSection
                                    .frame(maxWidth: AppTheme.Metrics.compactDetailsColumnMaxWidth, alignment: .top)
                            }
                            .frame(maxWidth: wideEditorialContentMaxWidth, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                        } else {
                            mediaSection
                            headerSection
                            detailsSection
                        }
                    }
                    .padding(.top, AppTheme.Spacing.xs)
                    .padding(.bottom, AppTheme.Spacing.xxl)
                }
            }
            .accessibilityIdentifier(AccessibilityID.mainContentScrollView)
            .refreshable {
                retryLatestRequest()
            }
        }
    }

    private var premiumEditorialColumn: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            statusBannerContent
                .accessibilitySortPriority(90)

            headerPanelContent

            detailsSection
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
            reduceMotion: effectiveReduceMotion,
            resetImageState: resetImageState,
            extractYouTubeID: extractYouTubeID,
            videoThumbnailURL: videoThumbnailURL
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.apodMediaSection)
        .opacity(effectiveReduceMotion ? 1 : (isMediaAnimating ? 1 : 0))
        .onAppear {
            if let animation = AppTheme.Motion.reveal(reduceMotion: effectiveReduceMotion) {
                withAnimation(animation) {
                    isMediaAnimating = true
                }
            } else {
                isMediaAnimating = true
            }
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
            nasaPageURL: nasaPageURL,
            preferredMediaSourceURL: preferredMediaSourceURL,
            preferredMediaSourceTitle: preferredMediaSourceTitle,
            preferredMediaSourceDescription: preferredMediaSourceDescription,
            preferredMediaSourceSystemImage: preferredMediaSourceSystemImage
        )
        .accessibilityIdentifier(AccessibilityID.apodDetailsSection)
        .accessibilitySortPriority(70)
    }

    private func randomizeSelection() {
        fetcher.selectRandom(preferImagesOnly: preferImages)
        randomizeFeedbackToken += 1
        applyCurrentSelectionState(syncSelectedDate: true)
    }

    private func toggleFavorite() {
        guard purchaseManager.canAddFavorite(
            currentCount: fetcher.favorites.count,
            isAlreadyFavorite: fetcher.isFavorite(fetcher.currentNasa)
        ) else {
            purchaseManager.presentPaywall(trigger: .favoriteLimit, feature: .unlimitedFavorites)
            return
        }

        fetcher.toggleFavorite(fetcher.currentNasa)
        favoriteFeedbackToken += 1
    }

    private var backgroundLayer: some View {
        SpaceBackdropView()
    }

    private var currentNotificationSettings: NotificationSettings {
        NotificationSettings(
            isEnabled: dailyNotificationsEnabled,
            hour: dailyNotificationHour,
            minute: dailyNotificationMinute
        )
        .normalized()
    }

    private func refreshNotificationStatus() async {
        notificationPermissionStatus = await NotificationScheduler.shared.authorizationStatus()
        nextScheduledNotificationDate = await NotificationScheduler.shared.nextPendingNotificationDate()
    }

    private func synchronizeNotificationSchedule() async {
        await NotificationScheduler.shared.scheduleDailyAPODNotification(settings: currentNotificationSettings)
        await refreshNotificationStatus()
    }
    
    private var shareItems: [Any] {
        let media: Any? = {
            if fetcher.currentNasa.mediaType == .video,
               let id = extractYouTubeID(from: fetcher.currentNasa.url),
               let thumb = videoThumbnailURL(for: id) {
                return thumb
            }
            return fetcher.currentNasa.hdurl ?? fetcher.currentNasa.url
        }()
        return APODSharePolicy.shareItems(
            for: fetcher.currentNasa,
            sourceURL: shareURL,
            mediaItem: media,
            explanationMaxLength: ViewConstants.shareExplanationMaxLength
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

    private var preferredMediaSourceDescription: String {
        APODSourceLinkPolicy.preferredMediaDescription(
            for: fetcher.currentNasa,
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private var preferredMediaSourceSystemImage: String {
        APODSourceLinkPolicy.preferredMediaSystemImage(for: fetcher.currentNasa)
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

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainViewPreviewHost(scenario: .defaultImage)
                .previewDisplayName("Default Light")

            MainViewPreviewHost(
                scenario: .defaultImage,
                overrides: AppEnvironmentOverrides(
                    colorScheme: .dark,
                    increasedContrast: true
                )
            )
            .previewDisplayName("Dark High Contrast")

            MainViewPreviewHost(
                scenario: .longExplanation,
                overrides: AppEnvironmentOverrides(
                    locale: Locale(identifier: "de_DE"),
                    dynamicTypeSize: .accessibility3,
                    colorScheme: .dark,
                    increasedContrast: true,
                    reduceMotion: true,
                    reduceTransparency: true,
                    differentiateWithoutColor: true
                )
            )
            .previewDisplayName("German Accessibility")

            MainViewPreviewHost(scenario: .offlineCached)
                .previewDisplayName("Offline Cached")

            MainViewPreviewHost(scenario: .rateLimited)
                .previewDisplayName("Rate Limited")

            MainViewPreviewHost(scenario: .loadFailure)
                .previewDisplayName("Initial Failure")

            MainViewPreviewHost(scenario: .noMedia)
                .previewDisplayName("No Media Source")
        }
    }
}
