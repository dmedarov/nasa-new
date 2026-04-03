import SwiftUI

private struct AppScreenChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.thinMaterial, for: .navigationBar)
    }
}

struct ScreenPanelColumn<Content: View>: View {
    let spacing: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    private let content: Content

    init(
        spacing: CGFloat = AppTheme.Metrics.screenPanelSpacing,
        topPadding: CGFloat = AppTheme.Spacing.xs,
        bottomPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .frame(maxWidth: AppTheme.Metrics.screenContentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }
}

struct MissionSearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    @Binding var text: String
    let placeholder: String
    let accessibilityIdentifier: String

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
                .accessibilityIdentifier(accessibilityIdentifier)

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

struct AppScreenSurface<Content: View>: View {
    let title: String
    let showsBackdrop: Bool
    private let content: Content

    init(
        title: String,
        showsBackdrop: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsBackdrop = showsBackdrop
        self.content = content()
    }

    var body: some View {
        content
            .background {
                if showsBackdrop {
                    SpaceBackdropView()
                }
            }
            .navigationTitle(title)
            .appScreenChrome()
    }
}

struct LibraryPanelDeck<Content: View>: View {
    let spacing: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    private let content: Content

    init(
        spacing: CGFloat = AppTheme.Metrics.screenPanelSpacing,
        topPadding: CGFloat = AppTheme.Spacing.xs,
        bottomPadding: CGFloat = AppTheme.Metrics.libraryPanelBottomPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        ScreenPanelColumn(
            spacing: spacing,
            topPadding: topPadding,
            bottomPadding: bottomPadding
        ) {
            content
        }
    }
}

struct LibraryBrowserPanel<FilterControl: View, LayoutControl: View>: View {
    @Binding var searchText: String
    let eyebrow: String
    let summary: String
    let tone: AppTheme.SurfaceTone
    let searchPlaceholder: String
    let searchAccessibilityIdentifier: String
    private let filterControl: FilterControl
    private let layoutControl: LayoutControl

    init(
        eyebrow: String,
        summary: String,
        tone: AppTheme.SurfaceTone = .neutral,
        searchText: Binding<String>,
        searchPlaceholder: String,
        searchAccessibilityIdentifier: String,
        @ViewBuilder filterControl: () -> FilterControl,
        @ViewBuilder layoutControl: () -> LayoutControl = { EmptyView() }
    ) {
        self._searchText = searchText
        self.eyebrow = eyebrow
        self.summary = summary
        self.tone = tone
        self.searchPlaceholder = searchPlaceholder
        self.searchAccessibilityIdentifier = searchAccessibilityIdentifier
        self.filterControl = filterControl()
        self.layoutControl = layoutControl()
    }

    private var showsLayoutControl: Bool {
        !(LayoutControl.self == EmptyView.self)
    }

    var body: some View {
        MissionSupportPanel(
            eyebrow: eyebrow,
            summary: summary,
            tone: tone
        ) {
            MissionSearchField(
                text: $searchText,
                placeholder: searchPlaceholder,
                accessibilityIdentifier: searchAccessibilityIdentifier
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppTheme.Metrics.libraryControlsSpacing) {
                    filterControl
                    Spacer(minLength: 0)
                    if showsLayoutControl {
                        layoutControl
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.Metrics.libraryControlsSpacing) {
                    filterControl
                    if showsLayoutControl {
                        layoutControl
                    }
                }
            }
        }
    }
}

struct PremiumShellWorkspace<Sidebar: View, Content: View>: View {
    let railWidth: CGFloat
    private let sidebar: Sidebar
    private let content: Content

    init(
        railWidth: CGFloat,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content
    ) {
        self.railWidth = railWidth
        self.sidebar = sidebar()
        self.content = content()
    }

    var body: some View {
        HStack(spacing: AppTheme.Metrics.shellContentGap) {
            sidebar
                .frame(width: railWidth)

            content
                .frame(
                    maxWidth: AppTheme.Metrics.readerStageMaxWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, AppTheme.Metrics.shellWorkspaceHorizontalPadding)
        .padding(.vertical, AppTheme.Metrics.shellWorkspaceVerticalPadding)
        .background(SpaceBackdropView())
    }
}

struct PremiumDualPaneStage<Primary: View, Secondary: View>: View {
    let primaryWidth: CGFloat?
    let spacing: CGFloat
    private let primary: Primary
    private let secondary: Secondary

    init(
        primaryWidth: CGFloat? = nil,
        spacing: CGFloat = AppTheme.Metrics.shellContentGap,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.primaryWidth = primaryWidth
        self.spacing = spacing
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            primary
                .frame(width: primaryWidth)

            secondary
        }
    }
}

extension View {
    func appScreenChrome() -> some View {
        modifier(AppScreenChromeModifier())
    }

    func libraryHeaderRowStyle() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    func libraryStateRowStyle() -> some View {
        listRowInsets(
            EdgeInsets(
                top: AppTheme.Spacing.sm,
                leading: AppTheme.Spacing.lg,
                bottom: AppTheme.Spacing.sm,
                trailing: AppTheme.Spacing.lg
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    func libraryRowBackground(isSelected: Bool) -> some View {
        listRowInsets(
            EdgeInsets(
                top: AppTheme.Spacing.xs,
                leading: AppTheme.Spacing.lg,
                bottom: AppTheme.Spacing.xs,
                trailing: AppTheme.Spacing.lg
            )
        )
        .listRowBackground(
            isSelected
                ? AppTheme.Palette.accentLight.opacity(0.08)
                : Color.clear
        )
        .listRowSeparator(.hidden)
    }
}
