import SwiftUI
import UIKit
import YouTubePlayerKit

struct MainView: View {
    @EnvironmentObject var fetcher: NasaCollectionFetcher
    @State private var imageScale: CGFloat = 1
    @State private var imageOffset: CGSize = .zero
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    @State private var showFavoritesSheet = false
    @State private var isMediaAnimating = false
    @State private var isVideoLoading = false
    @State private var selectedDate = Date()
    @State private var isSyncingSelectedDateFromModel = false
    @State private var dateSelectionTask: Task<Void, Never>?
    
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @AppStorage("preferImages") private var preferImages: Bool = false
    @AppStorage("allowVideoPlayback") private var allowVideoPlayback: Bool = true
    private func resetImageState() {
        withAnimation(.spring()) {
            imageScale = 1
            imageOffset = .zero
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
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            fetcher.startLatestFetch(for: date)
        }
    }

    private var hasLoadedContent: Bool {
        !fetcher.apodData.isEmpty
    }

    private func retryLatestRequest() {
        fetcher.startLatestFetch()
    }
    
    var body: some View {
        VStack {
            MainHeaderBar(
                isDarkMode: $isDarkMode,
                showSettingsSheet: $showSettingsSheet,
                showFavoritesSheet: $showFavoritesSheet,
                selectedDate: $selectedDate,
                minimumDate: fetcher.minimumSelectableDate,
                maximumDate: fetcher.maximumSelectableDate,
                isFetching: fetcher.isFetching,
                hasApodData: !fetcher.apodData.isEmpty,
                favoritesCount: fetcher.favorites.count,
                preferImages: preferImages,
                refreshAction: { fetcher.startLatestFetch() },
                randomizeAction: {
                    fetcher.selectRandom(preferImagesOnly: preferImages)
                    resetImageState()
                    isVideoLoading = fetcher.currentNasa.mediaType == .video
                }
            )

            APIRequestStatusBanner(
                isFetching: fetcher.isFetching,
                error: fetcher.error,
                hasLoadedContent: hasLoadedContent,
                retryAction: retryLatestRequest
            )
            
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
                MediaView(
                    nasa: fetcher.currentNasa,
                    imageScale: $imageScale,
                    imageOffset: $imageOffset,
                    isVideoLoading: $isVideoLoading,
                    allowVideoPlayback: allowVideoPlayback,
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
                    isVideoLoading = fetcher.currentNasa.mediaType == .video
                    resetImageState()
                    syncSelectedDateWithCurrentItem()
                }
                
                APODDetailsView(
                    nasa: fetcher.currentNasa,
                    isFavorite: fetcher.isFavorite(fetcher.currentNasa),
                    favoriteAction: { fetcher.toggleFavorite(fetcher.currentNasa) }
                )
                
                Spacer()
                
                Button("Share") {
                    showShareSheet = true
                }
                .padding()
                .accessibilityLabel("Share APOD")
                .accessibilityHint("Shares the current Astronomy Picture of the Day")
            }
        }
        .navigationTitle("NASA")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView(
                preferImages: $preferImages,
                allowVideoPlayback: $allowVideoPlayback,
                isPresented: $showSettingsSheet,
                lastStatusCode: fetcher.lastStatusCode,
                lastRequestDate: fetcher.lastRequestDate,
                isAPIKeyConfigured: fetcher.isAPIKeyConfigured,
                lastTransportError: fetcher.lastTransportError,
                isUsingCachedData: fetcher.isUsingCachedData
            )
        }
        .sheet(isPresented: $showFavoritesSheet) {
            FavoritesSheetView(
                favorites: fetcher.favorites,
                isPresented: $showFavoritesSheet,
                selectAction: { favorite in
                    fetcher.selectFavorite(favorite)
                    resetImageState()
                    isVideoLoading = fetcher.currentNasa.mediaType == .video
                    syncSelectedDateWithCurrentItem()
                },
                removeAction: { favorite in
                    fetcher.removeFavorite(favorite)
                }
            )
        }
        .overlay(
            fetcher.currentNasa.mediaType == .image ? controlView.padding(.bottom, 5) : nil,
            alignment: .bottom
        )
        .accessibilityIdentifier("mainViewRoot")
        .onDisappear {
            dateSelectionTask?.cancel()
            dateSelectionTask = nil
            fetcher.cancelLatestFetch()
        }
    }
    
    private var controlView: some View {
        HStack {
            Button {
                withAnimation(.spring()) {
                    if imageScale > 1 { imageScale -= 1 }
                    if imageScale <= 1 { resetImageState() }
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
                    if imageScale < 5 { imageScale += 1 }
                }
            } label: {
                ControlImageView(icon: "plus.magnifyingglass", accessibilityLabel: "Zoom in")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .opacity(isMediaAnimating ? 1 : 0)
    }
    
    private var shareItems: [Any] {
        let title = fetcher.currentNasa.title ?? "Astronomy Picture"
        let explanation = truncateToWords(fetcher.currentNasa.explanation ?? "", maxLength: 100)
        let url = apodURL(for: fetcher.currentNasa.date)
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
}

private struct MainHeaderBar: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    let refreshAction: () -> Void
    let randomizeAction: () -> Void

    private var iconColor: Color {
        isDarkMode ? .white : .indigo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 10) {
                    Button {
                        isDarkMode.toggle()
                    } label: {
                        Image(systemName: isDarkMode ? "sun.min.fill" : "moon.circle")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundColor(iconColor)
                            .accessibilityLabel(isDarkMode ? "Switch to light mode" : "Switch to dark mode")
                            .accessibilityHint("Toggles the app's appearance mode")
                    }

                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundColor(iconColor)
                            .accessibilityLabel("Open settings")
                            .accessibilityHint("Adjust app preferences")
                    }

                    Button {
                        showFavoritesSheet = true
                    } label: {
                        Image(systemName: favoritesCount == 0 ? "heart" : "heart.fill")
                            .resizable()
                            .frame(width: 22, height: 20)
                            .foregroundColor(iconColor)
                            .accessibilityLabel("Open favorites")
                            .accessibilityHint("Shows your saved APOD favorites")
                    }

                    DatePicker("", selection: $selectedDate, in: minimumDate...maximumDate, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 120)
                        .accessibilityLabel("Select APOD date")
                        .accessibilityHint("Choose a date to view a specific Astronomy Picture of the Day")

                    Button {
                        refreshAction()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundColor(iconColor)
                            .accessibilityLabel("Refresh APOD data")
                            .accessibilityHint("Fetches the latest APOD data")
                    }
                    .disabled(isFetching)

                    Button {
                        randomizeAction()
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundColor(iconColor)
                            .accessibilityLabel("Select random \(preferImages ? "image" : "APOD")")
                            .accessibilityHint("Loads a random Astronomy Picture of the Day")
                    }
                    .disabled(isFetching || !hasApodData)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.12)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 22)
                .allowsHitTesting(false)
            }

            if horizontalSizeClass == .compact {
                Label("Swipe for more controls", systemImage: "arrow.left.and.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            }
        }
    }
}

private struct APODDetailsView: View {
    let nasa: NASA
    let isFavorite: Bool
    let favoriteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            ScrollView {
                Text(nasa.explanation ?? "No explanation available.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Explanation: \(nasa.explanation ?? "No explanation available.")")
            }
            .frame(maxWidth: .infinity)
        }
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
        NavigationView {
            Group {
                if favorites.isEmpty {
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
                            Text("No favorites match your search.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
    @Binding var isPresented: Bool
    let lastStatusCode: Int?
    let lastRequestDate: Date?
    let isAPIKeyConfigured: Bool
    let lastTransportError: String?
    let isUsingCachedData: Bool

    var body: some View {
        NavigationView {
            Form {
                Toggle("Prefer Images Only", isOn: $preferImages)
                    .accessibilityLabel("Prefer images only for random selection")
                    .accessibilityHint("Limits random selection to images only")
                Toggle("Allow Video Playback", isOn: $allowVideoPlayback)
                    .accessibilityLabel("Allow video playback")
                    .accessibilityHint("Controls whether APOD videos play inside the app")

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
                    if let lastTransportError {
                        LabeledContent("Last Transport Error") {
                            Text(lastTransportError)
                                .multilineTextAlignment(.trailing)
                        }
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
    let isFetching: Bool
    let error: NasaCollectionFetcher.FetchError?
    let hasLoadedContent: Bool
    let retryAction: () -> Void

    var body: some View {
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
                Text(error.localizedDescription)
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

private struct APIRequestEmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
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

private struct APIRequestFailureView: View {
    let error: NasaCollectionFetcher.FetchError
    let retryAction: () -> Void

    var body: some View {
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
    let resetImageState: () -> Void
    let extractYouTubeID: (URL?) -> String?
    let videoThumbnailURL: (String) -> URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        @ViewBuilder var content: some View {
            if nasa.mediaType == .image {
                AsyncImage(url: nasa.hdurl ?? nasa.url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(15)
                            .shadow(radius: 5)
                            .padding(.horizontal)
                            .offset(x: imageOffset.width, y: imageOffset.height)
                            .scaleEffect(imageScale)
                            .accessibilityLabel(nasa.title ?? "Astronomy Picture")
                            .accessibilityAddTraits(.isImage)
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) { imageScale = imageScale == 1 ? 2 : 1 }
                            }
                            .simultaneousGesture(DragGesture()
                                .onChanged { value in
                                    imageOffset = value.translation
                                }
                                .onEnded { _ in
                                    if imageScale <= 1 { resetImageState() }
                                }
                            )
                            .simultaneousGesture(MagnificationGesture()
                                .onChanged { value in
                                    imageScale = min(max(value, 1), 5)
                                }
                                .onEnded { _ in
                                    if imageScale <= 1 { resetImageState() }
                                }
                            )
                    } else if phase.error != nil {
                        VStack {
                            Image("pandaplaceholder")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 300)
                            Text("Failed to load image.")
                                .font(.title3)
                        }
                    } else {
                        ProgressView()
                    }
                }
            } else if nasa.mediaType == .video {
                if !allowVideoPlayback {
                    VStack {
                        Image("pandaplaceholder")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                        Text("Video playback is disabled in Settings.")
                            .font(.title3)
                    }
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
                } else {
                    VStack(spacing: 10) {
                        Image("pandaplaceholder")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                        Text("This video source is not supported in-app.")
                            .font(.title3)
                        if let videoURL = nasa.url {
                            Button("Open Video in Browser") {
                                openURL(videoURL)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } else {
                VStack {
                    Image("pandaplaceholder")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300)
                    Text("Unable to load video or unsupported media type.")
                        .font(.title3)
                }
            }
        }

        return content
    }
}
