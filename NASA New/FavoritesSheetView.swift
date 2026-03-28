import SwiftUI

private struct FavoritesSearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @Binding var text: String
    let placeholder: String

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(AccessibilityID.favoritesSearchField)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Clear search", default: "Clear search"))
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .fill(AppTheme.glassSurface(
                    reduceTransparency: appRuntimeOverrides.resolvedReduceTransparency(systemValue: accessibilityReduceTransparency),
                    isDarkMode: isDarkMode
                ))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.panelStroke(isDarkMode: isDarkMode), lineWidth: 1)
        }
    }
}

struct FavoritesSheetView: View {
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
                    favoritesEmptyState
                } else {
                    VStack(spacing: AppTheme.Spacing.md) {
                        FavoritesSearchField(
                            text: $searchQuery,
                            placeholder: L10n.text("Search favorites", default: "Search favorites")
                        )
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.xs)

                        List {
                            ForEach(filteredFavorites) { item in
                                Button {
                                    selectAction(item)
                                    isPresented = false
                                } label: {
                                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                            Text(item.title ?? L10n.text("Untitled", default: "Untitled"))
                                                .font(AppTheme.Typography.sectionTitle)
                                                .foregroundColor(.primary)
                                            Text(APODDateDisplayPolicy.displayString(for: item.date))
                                                .font(AppTheme.Typography.metadata)
                                                .foregroundColor(.secondary)
                                            Text(APODAttributionPolicy.creditLine(for: item))
                                                .font(AppTheme.Typography.footnote)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: AppTheme.Spacing.sm)

                                        VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxs) {
                                            Image(systemName: item.mediaType == .video ? "play.rectangle" : "photo")
                                                .foregroundColor(.secondary)
                                                .accessibilityHidden(true)
                                            Text(item.mediaType.localizedDisplayName)
                                                .font(AppTheme.Typography.metadata)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, AppTheme.Spacing.xxs)
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
                                searchEmptyState
                                    .padding(AppTheme.Spacing.lg)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
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

    private var favoritesEmptyState: some View {
        MissionStateCard(
            eyebrow: L10n.text("Saved Archive", default: "Saved Archive"),
            title: L10n.text("No favorites saved yet", default: "No favorites saved yet"),
            message: L10n.text(
                "Bookmark an APOD from the main briefing to build your personal archive.",
                default: "Bookmark an APOD from the main briefing to build your personal archive."
            ),
            systemImage: "heart.slash",
            tone: .favorite
        )
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.favoritesEmptyState)
    }

    private var searchEmptyState: some View {
        MissionStateCard(
            eyebrow: L10n.text("Favorites Search", default: "Favorites Search"),
            title: L10n.text("No matching favorites", default: "No matching favorites"),
            message: L10n.text(
                "Try a different title or date to find a saved APOD.",
                default: "Try a different title or date to find a saved APOD."
            ),
            systemImage: "magnifyingglass.circle",
            tone: .neutral,
            minHeight: 180
        )
    }
}
