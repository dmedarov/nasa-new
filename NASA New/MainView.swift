import SwiftUI
import UIKit
import YouTubePlayerKit

struct MainView: View {
    @EnvironmentObject var fetcher: NasaCollectionFetcher
    @State private var imageScale: CGFloat = 1
    @State private var imageOffset: CGSize = .zero
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    @State private var isMediaAnimating = false
    @State private var isVideoLoading = false
    @State private var selectedDate = Date()
    
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @AppStorage("preferImages") private var preferImages: Bool = false
    private static let apodStartDate = Calendar.current.date(from: DateComponents(year: 1995, month: 6, day: 16)) ?? Date()
    private static let apodDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
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
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    isDarkMode.toggle()
                } label: {
                    Image(systemName: isDarkMode ? "sun.min.fill" : "moon.circle")
                        .resizable()
                        .frame(width: 23, height: 23)
                        .foregroundColor(isDarkMode ? .white : .indigo)
                        .accessibilityLabel(isDarkMode ? "Switch to light mode" : "Switch to dark mode")
                        .accessibilityHint("Toggles the app's appearance mode")
                }
                .padding(.horizontal, 15)
                
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .resizable()
                        .frame(width: 23, height: 23)
                        .foregroundColor(isDarkMode ? .white : .indigo)
                        .accessibilityLabel("Open settings")
                        .accessibilityHint("Adjust app preferences")
                }
                .padding(.horizontal, 15)
                
                DatePicker("", selection: $selectedDate, in: Self.apodStartDate...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .frame(maxWidth: 120)
                    .accessibilityLabel("Select APOD date")
                    .accessibilityHint("Choose a date to view a specific Astronomy Picture of the Day")
                
                Button {
                    Task { await fetcher.fetchData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .resizable()
                        .frame(width: 23, height: 23)
                        .foregroundColor(isDarkMode ? .white : .indigo)
                        .accessibilityLabel("Refresh APOD data")
                        .accessibilityHint("Fetches the latest APOD data")
                }
                .padding(.horizontal, 15)
                .disabled(fetcher.isFetching)
                
                Spacer()
                
                Button {
                    let candidates = preferImages ? fetcher.apodData.filter { $0.mediaType == .image } : fetcher.apodData
                    if let random = candidates.randomElement() {
                        fetcher.currentNasa = random
                        resetImageState()
                        isVideoLoading = random.mediaType == .video
                    }
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .resizable()
                        .frame(width: 23, height: 23)
                        .foregroundColor(isDarkMode ? .white : .indigo)
                        .accessibilityLabel("Select random \(preferImages ? "image" : "APOD")")
                        .accessibilityHint("Loads a random Astronomy Picture of the Day")
                }
                .padding(.horizontal, 15)
                .disabled(fetcher.isFetching)
            }
            .padding(.horizontal)
            
            MediaView(
                nasa: fetcher.currentNasa,
                imageScale: $imageScale,
                imageOffset: $imageOffset,
                isVideoLoading: $isVideoLoading,
                resetImageState: resetImageState,
                extractYouTubeID: extractYouTubeID,
                videoThumbnailURL: videoThumbnailURL
            )
            .opacity(isMediaAnimating ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 1)) { isMediaAnimating = true }
                if fetcher.apodData.isEmpty && !fetcher.isFetching {
                    Task { await fetcher.fetchData() }
                }
            }
            .onChange(of: selectedDate) { date in
                let dateString = Self.apodDateFormatter.string(from: date)
                Task { await fetcher.fetchData(for: dateString) }
            }
            .onChange(of: fetcher.currentNasa.date) { _ in
                isVideoLoading = fetcher.currentNasa.mediaType == .video
                resetImageState()
            }
            
            VStack {
                Text(fetcher.currentNasa.title ?? "Astronomy Picture")
                    .font(.title2)
                    .bold()
                    .padding(2)
                    .accessibilityAddTraits(.isHeader)
                
                VStack {
                    if let copyright = fetcher.currentNasa.copyright {
                        Label(copyright, systemImage: "c.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .accessibilityLabel("Copyright: \(copyright)")
                    }
                    Text(fetcher.currentNasa.date ?? "")
                        .font(.subheadline)
                        .bold()
                        .accessibilityLabel("Date: \(fetcher.currentNasa.date ?? "Unknown")")
                }
                
                ScrollView {
                    Text(fetcher.currentNasa.explanation ?? "No explanation available.")
                        .padding()
                        .accessibilityLabel("Explanation: \(fetcher.currentNasa.explanation ?? "No explanation available.")")
                }
            }
            
            Spacer()
            
            Button("Share") {
                showShareSheet = true
            }
            .padding()
            .accessibilityLabel("Share APOD")
            .accessibilityHint("Shares the current Astronomy Picture of the Day")
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            
            .sheet(isPresented: $showSettingsSheet) {
                NavigationView {
                    Form {
                        Toggle("Prefer Images Only", isOn: $preferImages)
                            .accessibilityLabel("Prefer images only for random selection")
                            .accessibilityHint("Limits random selection to images only")
                    }
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showSettingsSheet = false }
                                .accessibilityLabel("Close settings")
                        }
                    }
                }
            }
        }
        .navigationTitle("NASA")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .overlay(
            fetcher.currentNasa.mediaType == .image ? controlView.padding(.bottom, 5) : nil,
            alignment: .bottom
        )
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
    let resetImageState: () -> Void
    let extractYouTubeID: (URL?) -> String?
    let videoThumbnailURL: (String) -> URL?

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
            } else if nasa.mediaType == .video, let videoID = extractYouTubeID(nasa.url) {
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
