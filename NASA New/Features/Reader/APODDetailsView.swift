import SwiftUI

struct APODDetailsView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appShellContext) private var appShellContext
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @State private var isExplanationExpanded = false
    @State private var isSavingToPhotos = false
    @State private var photoExportNotice: PhotoExportNotice?
    @AppStorage("dataSaverMode") private var dataSaverMode: Bool = false
    @AppStorage("preferHDImages") private var preferHDImages: Bool = true
    let nasa: NASA
    let isFavorite: Bool

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var formattedDate: String {
        APODDateDisplayPolicy.displayString(for: nasa.date, locale: locale)
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
        guard let preferredMediaSourceURL = sourceContext.preferredMediaSourceURL else { return false }
        return preferredMediaSourceURL != sourceContext.nasaPageURL
    }

    private var effectiveReduceMotion: Bool {
        appRuntimeOverrides.resolvedReduceMotion(systemValue: accessibilityReduceMotion)
    }

    private var effectivePreferHDImages: Bool {
        DataSaverPreferencePolicy.resolvedPreferHDImages(
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
    }

    private var creditLine: String {
        APODAttributionPolicy.creditLine(for: nasa)
    }

    private var creditTitle: String {
        APODAttributionPolicy.creditTitle(for: nasa)
    }

    private var rightsNotice: String {
        APODAttributionPolicy.rightsNotice(for: nasa)
            ?? APODAttributionPolicy.rightsMessage(for: nasa)
    }

    private var rightsBadgeTitle: String {
        APODAttributionPolicy.rightsBadgeTitle(for: nasa)
    }

    private var rightsTitle: String {
        APODAttributionPolicy.rightsTitle(for: nasa)
    }

    private var rightsSystemImage: String {
        APODAttributionPolicy.rightsSystemImage(for: nasa)
    }

    private var rightsTone: AppTheme.SurfaceTone {
        APODAttributionPolicy.rightsTone(for: nasa)
    }

    private let photoExportService = PhotoExportService()

    private var sourceContext: APODReaderSourceContext {
        APODReaderSourceContext(
            nasa: nasa,
            dataSaverMode: dataSaverMode,
            preferHDImages: effectivePreferHDImages
        )
    }

    private var archiveEntryTitle: String {
        APODSourceLinkPolicy.archiveEntryTitle(for: nasa.date)
    }

    private var archiveHostLabel: String? {
        APODSourceLinkPolicy.hostLabel(for: sourceContext.nasaPageURL)
    }

    private var preferredMediaHostLabel: String? {
        APODSourceLinkPolicy.hostLabel(for: sourceContext.preferredMediaSourceURL)
    }

    private var aboutPanelSourceTitle: String {
        sourceContext.nasaPageURL == nil
            ? AppBrandingPolicy.officialSourceLinkTitle()
            : archiveEntryTitle
    }

    private var aboutPanelSourceSummary: String {
        sourceContext.nasaPageURL == nil
            ? AppBrandingPolicy.officialSourceLinkSummary()
            : AppBrandingPolicy.entrySourceLinkSummary()
    }

    private var offlineMediaState: APODOfflineMediaItemState {
        fetcher.offlineMediaState(for: nasa, isSaved: isFavorite)
    }

    private var offlineStatusPresentation: APODOfflineMediaStatusPresentation? {
        offlineMediaState.statusPresentation
    }

    private var canOfferPhotoExport: Bool {
        PhotoExportService.exportSourceURL(for: nasa) != nil
    }

    private var usesWideEditorialLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var detailPanelPadding: CGFloat {
        appShellContext == .premiumRegularShell && usesWideEditorialLayout
            ? AppTheme.Spacing.xxl
            : AppTheme.Spacing.xl
    }

    private var titleFont: Font {
        appShellContext == .premiumRegularShell && usesWideEditorialLayout
            ? AppTheme.Typography.heroTitle
            : AppTheme.Typography.screenTitle
    }

    private var explanationLineSpacing: CGFloat {
        usesWideEditorialLayout ? 6 : 4
    }

    var body: some View {
        MissionPanel(tone: .neutral, padding: detailPanelPadding) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                headerSection
                provenanceSection
                metadataStrip
                APODAttributionNotice(
                    title: rightsTitle,
                    text: rightsNotice,
                    systemImage: rightsSystemImage,
                    tone: rightsTone
                )

                explanationSection

                if sourceContext.nasaPageURL != nil || showsSeparateMediaAction {
                    sourceSection
                }

                AboutSourceRightsPanel(
                    sourceURL: sourceContext.nasaPageURL,
                    sourceTitle: aboutPanelSourceTitle,
                    sourceSummary: aboutPanelSourceSummary,
                    tone: .neutral
                )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .onChange(of: nasa.id) { _ in
            isExplanationExpanded = false
        }
        .alert(item: $photoExportNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(L10n.text("OK", default: "OK")))
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionEyebrow(L10n.text("Mission Story", default: "Mission Story"), tone: .accent)

            Text(nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture"))
                .font(titleFont)
                .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture"))
                .accessibilityIdentifier(AccessibilityID.apodTitleText)
                .accessibilityAddTraits(.isHeader)

            Text(L10n.text("Curated directly from NASA’s Astronomy Picture of the Day archive.", default: "Curated directly from NASA’s Astronomy Picture of the Day archive."))
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var provenanceSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(L10n.text("Attribution & Rights", default: "Attribution & Rights"))
                .font(AppTheme.Typography.sectionTitle)
                .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                .accessibilityAddTraits(.isHeader)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    APODFactCard(
                        title: L10n.text("Published", default: "Published"),
                        value: formattedDate,
                        systemImage: "calendar",
                        accessibilityIdentifier: AccessibilityID.apodDateText
                    )

                    APODFactCard(
                        title: creditTitle,
                        value: creditLine,
                        systemImage: "c.circle.fill",
                        accessibilityIdentifier: AccessibilityID.apodCreditText
                    )

                    APODFactCard(
                        title: L10n.text("Rights", default: "Rights"),
                        value: rightsBadgeTitle,
                        systemImage: rightsSystemImage
                    )
                }

                VStack(spacing: AppTheme.Spacing.sm) {
                    APODFactCard(
                        title: L10n.text("Published", default: "Published"),
                        value: formattedDate,
                        systemImage: "calendar",
                        accessibilityIdentifier: AccessibilityID.apodDateText
                    )

                    APODFactCard(
                        title: creditTitle,
                        value: creditLine,
                        systemImage: "c.circle.fill",
                        accessibilityIdentifier: AccessibilityID.apodCreditText
                    )

                    APODFactCard(
                        title: L10n.text("Rights", default: "Rights"),
                        value: rightsBadgeTitle,
                        systemImage: rightsSystemImage
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.apodProvenanceSection)
    }

    private var metadataStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.xs) {
                if isFavorite {
                    APODMetadataBadge(
                        title: L10n.text("Saved", default: "Saved"),
                        systemImage: "bookmark.fill",
                        tone: .favorite
                    )
                }

                if let offlineStatusPresentation {
                    APODMetadataBadge(
                        title: offlineStatusPresentation.title,
                        systemImage: offlineStatusPresentation.systemImage,
                        tone: offlineStatusPresentation.tone
                    )
                }

                APODMetadataBadge(title: nasa.mediaType.localizedDisplayName, systemImage: mediaTypeSystemImage, tone: .accent)
                APODMetadataBadge(title: APODAttributionPolicy.sourceLabel(for: nasa), systemImage: "network", tone: .neutral)

                if nasa.hdurl != nil {
                    APODMetadataBadge(
                        title: L10n.text("HD Available", default: "HD Available"),
                        systemImage: "sparkles.tv",
                        tone: .accent
                    )
                }

                if nasa.url != nil {
                    APODMetadataBadge(
                        title: L10n.text("Source Ready", default: "Source Ready"),
                        systemImage: "link",
                        tone: .neutral
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                SectionEyebrow(L10n.text("Mission Briefing", default: "Mission Briefing"), tone: .accent)

                Text(L10n.text("About this APOD", default: "About this APOD"))
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                    .accessibilityAddTraits(.isHeader)
            }

            Text(explanationText)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineSpacing(explanationLineSpacing)
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
                    let updates = {
                        isExplanationExpanded.toggle()
                    }

                    if let animation = AppTheme.Motion.standard(reduceMotion: effectiveReduceMotion) {
                        withAnimation(animation, updates)
                    } else {
                        updates()
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
                .tint(AppTheme.accentColor(isDarkMode: isDarkMode))
                .font(AppTheme.Typography.buttonLabel)
                .accessibilityIdentifier(AccessibilityID.apodExplanationToggleButton)
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionEyebrow(L10n.text("Source & Provenance", default: "Source & Provenance"), tone: .neutral)

            Text(L10n.text("Original Sources", default: "Original Sources"))
                .font(AppTheme.Typography.sectionTitle)
                .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                .accessibilityAddTraits(.isHeader)

            Text(
                L10n.text(
                    "source.review_note",
                    default: "Use the APOD story to review the original explanation, caption, and credit line before reusing or redistributing the media."
                )
            )
            .font(AppTheme.Typography.subheadline)
            .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
            .fixedSize(horizontal: false, vertical: true)

            if canOfferPhotoExport {
                saveToPhotosCard
                    .accessibilityIdentifier(AccessibilityID.saveToPhotosButton)
            }

            if let nasaPageURL = sourceContext.nasaPageURL {
                APODSourceCard(
                    title: archiveEntryTitle,
                    subtitle: APODSourceLinkPolicy.archiveEntrySummary(),
                    host: archiveHostLabel,
                    systemImage: "doc.text.magnifyingglass",
                    tone: .accent,
                    destination: nasaPageURL
                )
                .accessibilityIdentifier(AccessibilityID.openNasaPageButton)
                .accessibilityHint(L10n.text("Opens the official APOD page in the browser", default: "Opens the official APOD page in the browser"))
            }

            if showsSeparateMediaAction, let preferredMediaSourceURL = sourceContext.preferredMediaSourceURL {
                APODSourceCard(
                    title: sourceContext.preferredMediaSourceTitle,
                    subtitle: sourceContext.preferredMediaSourceDescription,
                    host: preferredMediaHostLabel,
                    systemImage: sourceContext.preferredMediaSourceSystemImage,
                    tone: .neutral,
                    destination: preferredMediaSourceURL
                )
                .accessibilityIdentifier(AccessibilityID.openPreferredMediaButton)
                .accessibilityHint(L10n.text("Opens the best available media source for this APOD", default: "Opens the best available media source for this APOD"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.apodSourceSection)
    }

    private var saveToPhotosCard: some View {
        Button {
            Task {
                await handleSaveToPhotos()
            }
        } label: {
            APODActionCard(
                title: L10n.text("media.save_to_photos", default: "Save to Photos"),
                subtitle: L10n.text(
                    "media.save_to_photos_summary",
                    default: "Download the original APOD image in the best available quality and save it to your photo library."
                ),
                systemImage: isSavingToPhotos ? "arrow.down.circle.fill" : "square.and.arrow.down",
                tone: .favorite,
                trailingContent: {
                    if isSavingToPhotos {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                            .accessibilityHidden(true)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(isSavingToPhotos)
    }

    private func handleSaveToPhotos() async {
        guard purchaseManager.canSaveOriginalMedia(apod: nasa) else {
            purchaseManager.presentPaywall(trigger: .hdSave, feature: .hdSave)
            return
        }

        isSavingToPhotos = true
        defer { isSavingToPhotos = false }

        do {
            try await photoExportService.exportOriginalImage(for: nasa)
            photoExportNotice = PhotoExportNotice(
                title: L10n.text("media.save_success_title", default: "Saved to Photos"),
                message: L10n.text(
                    "media.save_success_message",
                    default: "The original APOD image is now available in your photo library."
                )
            )
        } catch let error as PhotoExportService.ExportError {
            photoExportNotice = PhotoExportNotice(
                title: error.errorTitle,
                message: error.localizedDescription
            )
        } catch {
            photoExportNotice = PhotoExportNotice(
                title: L10n.text("media.save_failed_title", default: "Could not save image"),
                message: error.localizedDescription
            )
        }
    }
}

private struct APODFactCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let systemImage: String
    let accessibilityIdentifier: String?

    init(
        title: String,
        value: String,
        systemImage: String,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accentColor(isDarkMode: isDarkMode))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(AppTheme.Typography.sectionEyebrow)
                    .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                    .textCase(.uppercase)
                Text(value)
                    .font(AppTheme.Typography.actionLabel)
                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.toneColor(.neutral, isDarkMode: isDarkMode).opacity(isDarkMode ? 0.11 : 0.08))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

private struct APODMetadataBadge: View {
    let title: String
    let systemImage: String
    let tone: AppTheme.SurfaceTone

    var body: some View {
        MissionBadge(title: title, systemImage: systemImage, tone: tone)
    }
}

private struct APODSourceCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let host: String?
    let systemImage: String
    let tone: AppTheme.SurfaceTone
    let destination: URL

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        Link(destination: destination) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(title)
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))

                    Text(subtitle)
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                        .fixedSize(horizontal: false, vertical: true)

                    if let host {
                        MissionBadge(title: host, systemImage: "globe", tone: tone)
                    }
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                Image(systemName: "arrow.up.forward.square")
                    .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                    .accessibilityHidden(true)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.toneColor(tone, isDarkMode: isDarkMode).opacity(isDarkMode ? 0.12 : 0.08))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct APODActionCard<TrailingContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let systemImage: String
    let tone: AppTheme.SurfaceTone
    private let trailingContent: TrailingContent

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tone: AppTheme.SurfaceTone,
        @ViewBuilder trailingContent: () -> TrailingContent = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tone = tone
        self.trailingContent = trailingContent()
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))

                Text(subtitle)
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.saveToPhotosStatusText)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            trailingContent
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.toneColor(tone, isDarkMode: isDarkMode).opacity(isDarkMode ? 0.12 : 0.08))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct APODAttributionNotice: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let text: String
    let systemImage: String
    let tone: AppTheme.SurfaceTone

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))

                Text(text)
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.toneColor(tone, isDarkMode: isDarkMode).opacity(isDarkMode ? 0.12 : 0.08))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PhotoExportNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
