import SwiftUI
import UIKit
import YouTubePlayerKit
import SafariServices
import AVKit
import UserNotifications
import Network

struct APODDateRestoration {
    static func restoredDate(
        storedValue: String?,
        parseDate: (String?) -> Date?,
        minimumDate: Date,
        maximumDate: Date
    ) -> Date? {
        guard let restoredDate = parseDate(storedValue) else { return nil }
        return min(max(restoredDate, minimumDate), maximumDate)
    }
}

struct DataSaverPreferencePolicy {
    static func resolvedPreferHDImages(dataSaverMode: Bool, preferHDImages: Bool) -> Bool {
        dataSaverMode ? false : preferHDImages
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
        guard let date = date, date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            return fetcher.currentNasa.url
        }
        let formattedDate = date.replacingOccurrences(of: "-", with: "").dropFirst(2)
        return URL(string: "https://apod.nasa.gov/apod/ap\(formattedDate).html")
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
        let latestDate = fetcher.maximumSelectableDate
        if fetcher.isSameAPODDay(selectedDate, latestDate) {
            retryLatestRequest()
            return
        }
        selectedDate = latestDate
    }

    private func shiftSelectedDate(byDays dayOffset: Int) {
        let calendar = Calendar.current
        let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: selectedDate) ?? selectedDate
        let clampedDate = min(max(candidateDate, fetcher.minimumSelectableDate), fetcher.maximumSelectableDate)
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
        guard let restoredSelectedDate else { return }
        guard !fetcher.isSameAPODDay(selectedDate, restoredSelectedDate) else { return }
        isSyncingSelectedDateFromModel = false
        selectedDate = restoredSelectedDate
    }
    
    var body: some View {
        VStack(spacing: 10) {
            headerSection
            statusBannerSection
            mainContentSection
        }
        .padding(.top, 8)
        .background(backgroundLayer)
        .navigationTitle("NASA")
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
        .accessibilityIdentifier("mainViewRoot")
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
        .onChange(of: dataSaverMode) { enabled in
            preferHDImages = DataSaverPreferencePolicy.resolvedPreferHDImages(
                dataSaverMode: enabled,
                preferHDImages: preferHDImages
            )
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
                title: "Loading APOD",
                subtitle: "Fetching the latest Astronomy Picture of the Day from NASA API."
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
        .opacity(isMediaAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 1)) { isMediaAnimating = true }
            if fetcher.apodData.isEmpty && !fetcher.isFetching {
                fetcher.startLatestFetch()
            } else {
                syncSelectedDateWithCurrentItem()
            }
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
            favoriteAction: toggleFavorite
        )
    }

    private var shareSection: some View {
        shareControl
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .accessibilityLabel("Share APOD")
            .accessibilityHint("Shares the current Astronomy Picture of the Day")
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
            LinearGradient(
                colors: isDarkMode
                    ? [Color(red: 0.04, green: 0.05, blue: 0.12), Color(red: 0.09, green: 0.12, blue: 0.24)]
                    : [Color(red: 0.93, green: 0.97, blue: 1.0), Color(red: 0.86, green: 0.92, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill((isDarkMode ? Color.cyan : Color.blue).opacity(0.16))
                .frame(width: 320, height: 320)
                .offset(x: 140, y: -260)
            Circle()
                .fill((isDarkMode ? Color.indigo : Color.teal).opacity(0.14))
                .frame(width: 360, height: 360)
                .offset(x: -180, y: 260)
        }
        .ignoresSafeArea()
    }

    private var adaptiveMaterialBackground: AnyShapeStyle {
        if accessibilityReduceTransparency {
            let solidColor = isDarkMode
                ? Color(red: 0.12, green: 0.14, blue: 0.2).opacity(0.96)
                : Color.white.opacity(0.94)
            return AnyShapeStyle(solidColor)
        }
        return AnyShapeStyle(.ultraThinMaterial)
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
                ControlImageView(icon: "minus.magnifyingglass", accessibilityLabel: "Zoom out")
            }
            
            Button {
                resetImageState()
            } label: {
                ControlImageView(icon: "arrow.up.left.and.down.right.magnifyingglass", accessibilityLabel: "Reset zoom")
            }
            
            Button {
                withAnimation(.spring()) {
                    if imageScale < ViewConstants.maxImageScale { imageScale += 1 }
                }
            } label: {
                ControlImageView(icon: "plus.magnifyingglass", accessibilityLabel: "Zoom in")
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
        fetcher.currentNasa.title ?? "Astronomy Picture"
    }

    private var shareExplanation: String {
        truncateToWords(
            fetcher.currentNasa.explanation ?? "",
            maxLength: ViewConstants.shareExplanationMaxLength
        )
    }

    private var shareURL: URL? {
        apodURL(for: fetcher.currentNasa.date)
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
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } else {
                ShareLink(
                    item: shareMessage,
                    subject: Text(shareTitle)
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        } else {
            Button("Share") {
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
        isDarkMode ? .white : .indigo
    }

    private var headerBackground: AnyShapeStyle {
        if accessibilityReduceTransparency {
            return AnyShapeStyle(Color(.systemBackground).opacity(0.95))
        }
        return AnyShapeStyle(.ultraThinMaterial)
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
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(isFetching)
                .accessibilityLabel("Refresh APOD data")
                .accessibilityHint("Fetches the latest APOD data")

                Button {
                    jumpToLatestAction()
                } label: {
                    Label("Today", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(isFetching && isShowingLatestDate)
                .accessibilityLabel("Jump to latest APOD date")
                .accessibilityHint("Returns the calendar selection to today")

                Button {
                    randomizeAction()
                } label: {
                    Label(preferImages ? "Random Image" : "Random APOD", systemImage: "arrow.clockwise.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(isFetching || !hasApodData)
                .accessibilityLabel("Select random \(preferImages ? "image" : "APOD")")
                .accessibilityHint("Loads a random Astronomy Picture of the Day")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(headerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var headerIconControls: some View {
        headerIconButton(
            icon: isDarkMode ? "sun.min.fill" : "moon.circle",
            accessibilityLabel: isDarkMode ? "Switch to light mode" : "Switch to dark mode",
            accessibilityHint: "Toggles the app's appearance mode",
            action: { isDarkMode.toggle() }
        )

        headerIconButton(
            icon: "gearshape",
            accessibilityLabel: "Open settings",
            accessibilityHint: "Adjust app preferences",
            action: { showSettingsSheet = true }
        )

        headerIconButton(
            icon: favoritesCount == 0 ? "heart" : "heart.fill",
            accessibilityLabel: "Open favorites",
            accessibilityHint: "Shows your saved APOD favorites",
            action: { showFavoritesSheet = true }
        )
    }

    private var datePickerControl: some View {
        HStack(spacing: 8) {
            Button(action: previousDateAction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(isShowingMinimumDate)
            .accessibilityLabel("Previous APOD date")
            .accessibilityHint("Moves to the previous available Astronomy Picture of the Day")

            DatePicker("", selection: $selectedDate, in: minimumDate...maximumDate, displayedComponents: .date)
                .labelsHidden()
                .frame(width: max(datePickerWidth, 120))
                .accessibilityLabel("Select APOD date")
                .accessibilityHint("Choose a date to view a specific Astronomy Picture of the Day")

            Button(action: nextDateAction) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(isShowingLatestDate)
            .accessibilityLabel("Next APOD date")
            .accessibilityHint("Moves to the next available Astronomy Picture of the Day")
        }
    }

    @ViewBuilder
    private func headerIconButton(
        icon: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: headerIconSize, weight: .semibold))
                .frame(width: max(headerButtonSize, 44), height: max(headerButtonSize, 44))
                .foregroundColor(iconColor)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}

private struct APODDetailsView: View {
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    let nasa: NASA
    let isFavorite: Bool
    let favoriteAction: () -> Void

    private var detailsBackground: AnyShapeStyle {
        if accessibilityReduceTransparency {
            return AnyShapeStyle(Color(.systemBackground).opacity(0.95))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(nasa.title ?? "Astronomy Picture")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .secondary)
                }
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                .accessibilityHint("Saves this APOD to your favorites list")
            }

            VStack(alignment: .leading, spacing: 4) {
                if let copyright = nasa.copyright {
                    Label(copyright, systemImage: "c.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .accessibilityLabel("Copyright: \(copyright)")
                }
                Text(nasa.date ?? "")
                    .font(.subheadline)
                    .bold()
                    .accessibilityLabel("Date: \(nasa.date ?? "Unknown")")
            }

            Text(nasa.explanation ?? "No explanation available.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .accessibilityTextContentType(.narrative)
                .accessibilityLabel("Explanation: \(nasa.explanation ?? "No explanation available.")")
        }
        .padding(14)
        .background(detailsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
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
                            "No Favorites Yet",
                            systemImage: "heart.slash",
                            description: Text("Save APOD entries with the heart button to quickly revisit them.")
                        )
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No Favorites Yet")
                                .font(.headline)
                            Text("Save APOD entries with the heart button to quickly revisit them.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
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
                                        Text(item.title ?? "Untitled")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(item.date ?? "Unknown date")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: item.mediaType == .video ? "play.rectangle" : "photo")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    removeAction(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .overlay {
                        if filteredFavorites.isEmpty {
                            if #available(iOS 17.0, *) {
                                ContentUnavailableView.search(text: searchQuery)
                            } else {
                                Text("No favorites match your search.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .searchable(text: $searchQuery, prompt: "Search favorites")
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
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
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    private var videoAutoplayPolicyLabel: String {
        guard allowVideoPlayback else { return "Playback disabled" }
        guard wifiOnlyVideoAutoplay else { return "Autoplay allowed on any network" }
        if !networkReachable { return "Waiting for network connection" }
        return videoAutoplayEligible ? "Autoplay allowed on Wi-Fi" : "Manual play required off Wi-Fi"
    }

    private var networkEfficiencyLabel: String {
        if !networkReachable {
            return "Offline. Cached APOD content is preferred."
        }
        if dataSaverMode && networkIsConstrained {
            return "Maximum savings. App data saver and Low Data Mode are both active."
        }
        if dataSaverMode {
            return "App data saver active. Lower-bandwidth images are preferred."
        }
        if networkIsConstrained {
            return "System Low Data Mode active. Prefer lighter media usage."
        }
        if networkIsExpensive {
            return "Metered connection detected. HD media may increase data usage."
        }
        return "Standard media delivery."
    }

    var body: some View {
        AdaptiveNavigationContainer {
            Form {
                Section("Content Preferences") {
                    Toggle("Prefer Images Only", isOn: $preferImages)
                        .accessibilityLabel("Prefer images only for random selection")
                        .accessibilityHint("Limits random selection to images only")
                    Toggle("Allow Video Playback", isOn: $allowVideoPlayback)
                        .accessibilityLabel("Allow video playback")
                        .accessibilityHint("Controls whether APOD videos play inside the app")
                }

                Section("API Diagnostics") {
                    LabeledContent("NASA_API_KEY Configured") {
                        Text(isAPIKeyConfigured ? "Yes" : "No (Using DEMO_KEY)")
                            .foregroundColor(isAPIKeyConfigured ? .green : .orange)
                    }
                    LabeledContent("Last Status Code") {
                        Text(lastStatusCode.map(String.init) ?? "N/A")
                    }
                    LabeledContent("Last Request Time") {
                        Text(formattedRequestDate(lastRequestDate))
                    }
                    LabeledContent("Using Cached Data") {
                        Text(isUsingCachedData ? "Yes" : "No")
                    }
                    if let rateLimitRetryDate {
                        LabeledContent("Rate Limit Retry Time") {
                            Text(formattedRequestDate(rateLimitRetryDate))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if let lastTransportError {
                        LabeledContent("Last Transport Error") {
                            Text(lastTransportError)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if let apiKeyWarning {
                        LabeledContent("API Key Warning") {
                            Text(apiKeyWarning)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if !diagnosticsHistory.isEmpty {
                    Section("Recent Requests") {
                        ForEach(diagnosticsHistory.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(item.result.uppercased()) • \(item.statusCode.map(String.init) ?? "N/A")")
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

                Section("Daily Notifications") {
                    Toggle("Enable Daily APOD Alerts", isOn: $dailyNotificationsEnabled)
                    DatePicker(
                        "Alert Time",
                        selection: notificationTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!dailyNotificationsEnabled)
                    LabeledContent("Notification Permission") {
                        Text(notificationPermissionLabel)
                    }
                    LabeledContent("Next Scheduled Alert") {
                        Text(formattedRequestDate(nextScheduledNotificationDate))
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Data Saver") {
                    Toggle("Enable Data Saver Mode", isOn: $dataSaverMode)
                    Toggle("Prefer HD Images", isOn: $preferHDImages)
                        .disabled(dataSaverMode)
                    Toggle("Autoplay Videos on Wi-Fi Only", isOn: $wifiOnlyVideoAutoplay)
                        .disabled(!allowVideoPlayback)
                    Stepper(value: $cacheItemLimit, in: 30...365, step: 15) {
                        LabeledContent("Cache Item Limit") {
                            Text(String(cacheItemLimit))
                        }
                    }
                    Text("Data Saver favors lower-bandwidth image URLs and can reduce media quality on slower connections.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("Storage Diagnostics") {
                    LabeledContent("Cached APOD Items") {
                        Text(String(cachedItemCount))
                    }
                    LabeledContent("Applied Cache Limit") {
                        Text(String(appliedCacheItemLimit))
                    }
                    LabeledContent("Data Saver Active") {
                        Text(dataSaverMode ? "Yes" : "No")
                    }
                    LabeledContent("HD Images Preferred") {
                        Text(preferHDImages ? "Yes" : "No")
                    }
                }

                Section("Network Diagnostics") {
                    LabeledContent("Connection") {
                        Text(networkConnectionLabel)
                    }
                    LabeledContent("Network Reachable") {
                        Text(networkReachable ? "Yes" : "No")
                    }
                    LabeledContent("Metered Network") {
                        Text(networkIsExpensive ? "Yes" : "No")
                    }
                    LabeledContent("Low Data Mode") {
                        Text(networkIsConstrained ? "Yes" : "No")
                    }
                    LabeledContent("Video Autoplay Eligible") {
                        Text(videoAutoplayEligible ? "Yes" : "No")
                    }
                    LabeledContent("Autoplay Policy") {
                        Text(videoAutoplayPolicyLabel)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Network Efficiency") {
                        Text(networkEfficiencyLabel)
                            .multilineTextAlignment(.trailing)
                    }
                    if wifiOnlyVideoAutoplay {
                        Text("Videos will wait for manual playback unless the device is on Wi-Fi.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                        .accessibilityLabel("Close settings")
                }
            }
        }
    }

    private func formattedRequestDate(_ date: Date?) -> String {
        guard let date else { return "N/A" }
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
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                    Text(accessibilityDifferentiateWithoutColor
                         ? "Offline mode. Showing cached APOD content."
                         : "Offline mode: showing cached APOD content.")
                        .font(.footnote)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .cornerRadius(10)
                .padding(.horizontal)
            }

            if let rateLimitRetryDate {
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    Text(accessibilityDifferentiateWithoutColor
                         ? "Rate limit warning. Try again at \(rateLimitRetryDate.formatted(date: .omitted, time: .shortened))."
                         : "Rate limited. Try again at \(rateLimitRetryDate.formatted(date: .omitted, time: .shortened)).")
                        .font(.footnote)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .cornerRadius(10)
                .padding(.horizontal)
            }

            if let apiKeyWarning {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                    Text(accessibilityDifferentiateWithoutColor ? "API key warning. \(apiKeyWarning)" : apiKeyWarning)
                        .font(.footnote)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .cornerRadius(10)
                .padding(.horizontal)
            }

            if isFetching && hasLoadedContent {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Refreshing APOD from NASA API...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            } else if let error, hasLoadedContent {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(accessibilityDifferentiateWithoutColor
                         ? "Error. \(error.localizedDescription)"
                         : error.localizedDescription)
                        .font(.footnote)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry", action: retryAction)
                        .font(.footnote.bold())
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .cornerRadius(10)
                .padding(.horizontal)
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
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
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
                    Label("API Request Failed", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Retry", action: retryAction)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text("API Request Failed")
                        .font(.title3.bold())
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry", action: retryAction)
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
        if dataSaverMode {
            return nasa.url ?? nasa.hdurl
        }
        if preferHDImages {
            return nasa.hdurl ?? nasa.url
        }
        return nasa.url ?? nasa.hdurl
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
                            .accessibilityLabel(nasa.title ?? "Astronomy Picture")
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
                        VStack(spacing: 12) {
                            Image("pandaplaceholder")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 300)
                            Text("Failed to load image.")
                                .font(.title3)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
            } else if nasa.mediaType == .video {
                if !allowVideoPlayback {
                    VStack(spacing: 12) {
                        Image("pandaplaceholder")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                        Text("Video playback is disabled in Settings.")
                            .font(.title3)
                            .accessibilityIdentifier("videoDisabledMessage")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
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
                    VideoPlayer(player: directVideoPlayer)
                        .frame(height: 300)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .accessibilityIdentifier("directVideoPlayer")
                        .task(id: videoURL) {
                            configureDirectVideoPlayer(for: videoURL, autoplay: shouldAutoplayVideo)
                        }
                        .onDisappear {
                            directVideoPlayer?.pause()
                            directVideoPlayer = nil
                        }
                        .overlay(alignment: .bottomLeading) {
                            if wifiOnlyVideoAutoplay && !isOnWiFiConnection {
                                Text("Autoplay paused on non-Wi-Fi network.")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .padding(10)
                            }
                        }
                } else {
                    VStack(spacing: 10) {
                        Image("pandaplaceholder")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                        Text("Playing this source with in-app browser.")
                            .font(.title3)
                            .accessibilityIdentifier("unsupportedVideoMessage")
                        if let videoURL = nasa.url {
                            Button("Play Video") {
                                showWebVideoSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("playVideoInAppButton")
                            .sheet(isPresented: $showWebVideoSheet) {
                                SafariView(url: videoURL)
                            }

                            Button("Open in External Browser") {
                                openURL(videoURL)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("openVideoExternalButton")
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 12) {
                    Image("pandaplaceholder")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300)
                    Text("Unable to load video or unsupported media type.")
                        .font(.title3)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        content.title = "New NASA APOD"
        content.body = "A new Astronomy Picture of the Day is available."
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
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        case .unavailable:
            return "Unavailable"
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
