import SwiftUI

struct APODReaderView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appShellContext) private var appShellContext

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

    private var usesWideEditorialLayout: Bool {
        let wideThreshold: CGFloat = appShellContext == .premiumRegularShell ? 1_260 : 940
        if availableWidth != nil {
            return effectiveAvailableWidth >= wideThreshold && !dynamicTypeSize.isAccessibilitySize
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

    private func readerStageWidths(for availableWidth: CGFloat) -> (media: CGFloat, details: CGFloat) {
        let usableWidth = min(max(availableWidth, 0), AppTheme.Metrics.readerStageMaxWidth)
        let spacing = AppTheme.Spacing.xxl
        let minimumMediaWidth: CGFloat = appShellContext == .premiumRegularShell ? 720 : 520
        let minimumDetailsWidth: CGFloat = appShellContext == .premiumRegularShell ? 360 : 320
        let idealDetailsWidth = min(
            max(usableWidth * 0.33, minimumDetailsWidth),
            detailsColumnMaxWidth
        )
        let idealMediaWidth = usableWidth - idealDetailsWidth - spacing

        if idealMediaWidth >= minimumMediaWidth {
            return (idealMediaWidth, idealDetailsWidth)
        }

        let adjustedDetailsWidth = min(
            max(usableWidth * 0.28, minimumDetailsWidth),
            min(detailsColumnMaxWidth, 460)
        )
        let adjustedMediaWidth = max(usableWidth - adjustedDetailsWidth - spacing, 480)
        let resolvedDetailsWidth = max(usableWidth - adjustedMediaWidth - spacing, minimumDetailsWidth)
        return (adjustedMediaWidth, resolvedDetailsWidth)
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
    }

    private var mediaSection: some View {
        APODReaderMediaSection(nasa: nasa)
    }

    private var detailsSection: some View {
        APODDetailsView(nasa: nasa, isFavorite: isFavorite)
        .accessibilityIdentifier(AccessibilityID.apodDetailsSection)
    }
}

struct APODRecordDetailView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.appShellContext) private var appShellContext
    let nasa: NASA
    let destination: AppDestination

    @State private var showShareSheet = false
    @AppStorage("dataSaverMode") private var dataSaverMode: Bool = false
    @AppStorage("preferHDImages") private var preferHDImages: Bool = true

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
        return APODSharePolicy.shareItems(
            for: nasa,
            sourceURL: APODReaderSourceContext(
                nasa: nasa,
                dataSaverMode: dataSaverMode,
                preferHDImages: DataSaverPreferencePolicy.resolvedPreferHDImages(
                    dataSaverMode: dataSaverMode,
                    preferHDImages: preferHDImages
                )
            ).nasaPageURL ?? nasa.url,
            mediaItem: APODMediaPresentationPolicy.shareMediaItem(for: nasa)
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
