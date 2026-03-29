import SwiftUI

struct MainHeaderBar: View {
    @ScaledMetric(relativeTo: .body) private var headerButtonSize = 38
    @ScaledMetric(relativeTo: .body) private var headerIconSize = 18
    @ScaledMetric(relativeTo: .body) private var datePickerWidth = 152
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @Binding var showSettingsSheet: Bool
    @Binding var selectedDate: Date
    let minimumDate: Date
    let maximumDate: Date
    let isFetching: Bool
    let hasApodData: Bool
    let favoritesCount: Int
    let isFavorite: Bool
    let preferImages: Bool
    let isShowingLatestDate: Bool
    let toggleFavoriteAction: () -> Void
    let shareAction: () -> Void
    let refreshAction: () -> Void
    let isShowingMinimumDate: Bool
    let previousDateAction: () -> Void
    let nextDateAction: () -> Void
    let jumpToLatestAction: () -> Void
    let randomizeAction: () -> Void
    let openArchiveAction: () -> Void
    let openSavedAction: () -> Void

    private var effectiveIsDarkMode: Bool {
        colorScheme == .dark
    }

    private var editorialTitle: String {
        L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day")
    }

    private var editorialSummary: String {
        if isShowingLatestDate {
            return L10n.text(
                "header.today_summary",
                default: "Open today's APOD story, jump across the timeline, and save favorites for later."
            )
        }

        return L10n.text(
            "header.archive_summary",
            default: "Review an earlier APOD date, compare entries, and open the wider archive whenever you want more context."
        )
    }

    private var dateContextLabel: String {
        isShowingLatestDate
            ? L10n.text("header.live_briefing", default: "Today")
            : L10n.text("header.archive_briefing", default: "Archive")
    }

    private var dateBackground: AnyShapeStyle {
        AppTheme.glassSurface(
            reduceTransparency: appRuntimeOverrides.resolvedReduceTransparency(systemValue: accessibilityReduceTransparency),
            isDarkMode: effectiveIsDarkMode
        )
    }

    var body: some View {
        MissionPanel(tone: .accent, padding: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                MissionPanelHeader(
                    eyebrow: L10n.text("Space Briefing", default: "Space Briefing"),
                    title: editorialTitle,
                    summary: editorialSummary,
                    tone: .accent
                ) {
                    headerIconControlRow
                }

                datePickerControl

                adaptiveActionButtons
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    private var adaptiveActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppTheme.Spacing.sm) {
                refreshButton
                todayButton
                archiveButton
                randomButton
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    refreshButton
                    todayButton
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    archiveButton
                    randomButton
                }
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                refreshButton
                todayButton
                archiveButton
                randomButton
            }
            .padding(.vertical, 2)
        }
    }

    private var headerIconControlRow: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            headerIconControls
        }
    }

    private var refreshButton: some View {
        Button {
            refreshAction()
        } label: {
            Label(L10n.text("Refresh", default: "Refresh"), systemImage: "arrow.clockwise")
                .font(AppTheme.Typography.buttonLabel)
                .frame(minWidth: 104)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
        .tint(AppTheme.accentColor(isDarkMode: effectiveIsDarkMode))
        .disabled(isFetching)
        .controlSize(.regular)
        .accessibilityIdentifier(AccessibilityID.refreshAPODButton)
        .accessibilityLabel(L10n.text("Refresh APOD data", default: "Refresh APOD data"))
        .accessibilityHint(L10n.text("Fetches the latest APOD data", default: "Fetches the latest APOD data"))
    }

    private var todayButton: some View {
        Button {
            jumpToLatestAction()
        } label: {
            Label(L10n.text("Today", default: "Today"), systemImage: "calendar")
                .font(AppTheme.Typography.buttonLabel)
                .frame(minWidth: 104)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
        .tint(AppTheme.accentColor(isDarkMode: effectiveIsDarkMode))
        .disabled(isFetching && isShowingLatestDate)
        .controlSize(.regular)
        .accessibilityIdentifier(AccessibilityID.jumpToLatestAPODDateButton)
        .accessibilityLabel(L10n.text("Jump to latest APOD date", default: "Jump to latest APOD date"))
        .accessibilityHint(L10n.text("Returns the calendar selection to today", default: "Returns the calendar selection to today"))
    }

    private var archiveButton: some View {
        Button {
            openArchiveAction()
        } label: {
            Label(L10n.text("Archive", default: "Archive"), systemImage: "books.vertical")
                .font(AppTheme.Typography.buttonLabel)
                .frame(minWidth: 112)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
        .tint(AppTheme.accentColor(isDarkMode: effectiveIsDarkMode))
        .disabled(!hasApodData)
        .controlSize(.regular)
        .accessibilityIdentifier(AccessibilityID.openArchiveButton)
        .accessibilityLabel(L10n.text("Browse APOD archive", default: "Browse APOD archive"))
        .accessibilityHint(L10n.text("archive.accessibility.hint", default: "Opens the searchable archive of saved and cached APOD entries."))
    }

    private var randomButton: some View {
        Button {
            randomizeAction()
        } label: {
            Label(
                preferImages
                    ? L10n.text("Random Image", default: "Random Image")
                    : L10n.text("Random APOD", default: "Random APOD"),
                systemImage: "sparkles.rectangle.stack"
            )
            .font(AppTheme.Typography.buttonLabel)
            .frame(minWidth: 140)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
        .tint(AppTheme.accentColor(isDarkMode: effectiveIsDarkMode))
        .disabled(isFetching || !hasApodData)
        .controlSize(.regular)
        .accessibilityIdentifier(AccessibilityID.randomAPODButton)
        .accessibilityLabel(
            preferImages
                ? L10n.text("Random image APOD", default: "Random image APOD")
                : L10n.text("Random APOD", default: "Random APOD")
        )
        .accessibilityHint(L10n.text("Loads a random APOD from the available archive data", default: "Loads a random APOD from the available archive data"))
    }

    @ViewBuilder
    private var headerIconControls: some View {
        headerIconButton(
            icon: "square.and.arrow.up",
            identifier: AccessibilityID.shareAPODButton,
            accessibilityLabel: L10n.text("Share APOD", default: "Share APOD"),
            accessibilityHint: L10n.text("Shares the current Astronomy Picture of the Day", default: "Shares the current Astronomy Picture of the Day"),
            action: shareAction
        )

        headerIconButton(
            icon: isFavorite ? "bookmark.fill" : "bookmark",
            identifier: AccessibilityID.favoriteAPODButton,
            accessibilityLabel: isFavorite
                ? L10n.text("Remove from favorites", default: "Remove from favorites")
                : L10n.text("Add to favorites", default: "Add to favorites"),
            accessibilityHint: isFavorite
                ? L10n.text("Removes this APOD from your favorites list", default: "Removes this APOD from your favorites list")
                : L10n.text("Saves this APOD to your favorites list", default: "Saves this APOD to your favorites list"),
            foregroundColor: isFavorite ? AppTheme.Palette.favorite : AppTheme.accentColor(isDarkMode: effectiveIsDarkMode),
            tone: isFavorite ? .favorite : .accent,
            action: toggleFavoriteAction
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
            action: openSavedAction
        )
    }

    private var datePickerControl: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Text(dateContextLabel)
                .font(AppTheme.Typography.sectionEyebrow)
                .foregroundStyle(AppTheme.inkSecondary(isDarkMode: effectiveIsDarkMode))
                .textCase(.uppercase)
                .lineLimit(1)

            Spacer(minLength: AppTheme.Spacing.xs)

            Button(action: previousDateAction) {
                Image(systemName: "chevron.left")
                    .font(AppTheme.Typography.actionLabel)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
            .tint(AppTheme.accentColor(isDarkMode: effectiveIsDarkMode))
            .disabled(isShowingMinimumDate)
            .accessibilityIdentifier(AccessibilityID.previousAPODDateButton)
            .accessibilityLabel(L10n.text("Previous APOD date", default: "Previous APOD date"))
            .accessibilityHint(L10n.text("Moves to the previous available Astronomy Picture of the Day", default: "Moves to the previous available Astronomy Picture of the Day"))

            DatePicker("", selection: $selectedDate, in: minimumDate...maximumDate, displayedComponents: .date)
                .labelsHidden()
                .frame(width: max(datePickerWidth, 132))
                .accessibilityLabel(L10n.text("Select APOD date", default: "Select APOD date"))
                .accessibilityHint(L10n.text("Choose a date to view a specific Astronomy Picture of the Day", default: "Choose a date to view a specific Astronomy Picture of the Day"))

            Button(action: nextDateAction) {
                Image(systemName: "chevron.right")
                    .font(AppTheme.Typography.actionLabel)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
            .tint(AppTheme.accentColor(isDarkMode: effectiveIsDarkMode))
            .disabled(isShowingLatestDate)
            .accessibilityIdentifier(AccessibilityID.nextAPODDateButton)
            .accessibilityLabel(L10n.text("Next APOD date", default: "Next APOD date"))
            .accessibilityHint(L10n.text("Moves to the next available Astronomy Picture of the Day", default: "Moves to the next available Astronomy Picture of the Day"))
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(dateBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.panelStroke(isDarkMode: effectiveIsDarkMode), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func headerIconButton(
        icon: String,
        identifier: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        foregroundColor: Color? = nil,
        tone: AppTheme.SurfaceTone = .accent,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                    .fill(AppTheme.glassSurface(
                        reduceTransparency: appRuntimeOverrides.resolvedReduceTransparency(systemValue: accessibilityReduceTransparency),
                        isDarkMode: effectiveIsDarkMode
                    ))

                RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                    .fill(AppTheme.toneColor(tone, isDarkMode: effectiveIsDarkMode).opacity(effectiveIsDarkMode ? 0.12 : 0.08))

                Image(systemName: icon)
                    .font(.system(size: headerIconSize, weight: .semibold))
                    .foregroundStyle(foregroundColor ?? AppTheme.accentColor(isDarkMode: effectiveIsDarkMode))
            }
            .frame(width: max(headerButtonSize, 44), height: max(headerButtonSize, 44))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.panelStroke(isDarkMode: effectiveIsDarkMode), lineWidth: 1)
            }
        }
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}
