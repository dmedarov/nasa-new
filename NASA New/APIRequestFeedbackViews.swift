import SwiftUI

private struct StatusBannerCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let eyebrow: String
    let systemImage: String
    let message: String
    let tone: AppTheme.SurfaceTone
    let identifier: String?
    let actionTitle: String?
    let action: (() -> Void)?

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        MissionPanel(tone: tone, padding: AppTheme.Spacing.md) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(eyebrow.uppercased())
                        .font(AppTheme.Typography.sectionEyebrow)
                        .foregroundStyle(AppTheme.inkSecondary(isDarkMode: isDarkMode))
                    stateMessage
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
                        .tint(AppTheme.toneColor(tone, isDarkMode: isDarkMode))
                        .font(AppTheme.Typography.buttonLabel)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .accessibilityElement(children: .combine)
        .overlay(alignment: .topLeading) {
            if let identifier {
                AccessibilityMarker(identifier: identifier)
            }
        }
    }

    @ViewBuilder
    private var stateMessage: some View {
        if let identifier {
            Text(message)
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
        } else {
            Text(message)
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct APIRequestStatusBanner: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var accessibilityDifferentiateWithoutColor
    @Environment(\.appRuntimeOverrides) private var appRuntimeOverrides
    let isFetching: Bool
    let error: NasaCollectionFetcher.FetchError?
    let hasLoadedContent: Bool
    let retryAction: () -> Void
    let isOfflineMode: Bool
    let apiKeyWarning: String?
    let rateLimitRetryDate: Date?

    private var effectiveDifferentiateWithoutColor: Bool {
        appRuntimeOverrides.resolvedDifferentiateWithoutColor(systemValue: accessibilityDifferentiateWithoutColor)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if isOfflineMode {
                StatusBannerCard(
                    eyebrow: L10n.text("Offline Cache", default: "Offline Cache"),
                    systemImage: "wifi.slash",
                    message: effectiveDifferentiateWithoutColor
                        ? L10n.text("Offline mode. Showing cached APOD content.", default: "Offline mode. Showing cached APOD content.")
                        : L10n.text("Offline mode: showing cached APOD content.", default: "Offline mode: showing cached APOD content."),
                    tone: .warning,
                    identifier: AccessibilityID.apiOfflineBanner,
                    actionTitle: nil,
                    action: nil
                )
            }

            if let rateLimitRetryDate {
                let retryTime = rateLimitRetryDate.formatted(date: .omitted, time: .shortened)
                StatusBannerCard(
                    eyebrow: L10n.text("NASA API Rate Limit", default: "NASA API Rate Limit"),
                    systemImage: "timer",
                    message: effectiveDifferentiateWithoutColor
                        ? L10n.format("Rate limit warning. Try again at %@", default: "Rate limit warning. Try again at %@", retryTime)
                        : L10n.format("Rate limited. Try again at %@", default: "Rate limited. Try again at %@", retryTime),
                    tone: .warning,
                    identifier: AccessibilityID.apiRateLimitBanner,
                    actionTitle: nil,
                    action: nil
                )
            }

            if let apiKeyWarning {
                StatusBannerCard(
                    eyebrow: L10n.text("API Key", default: "API Key"),
                    systemImage: "key.fill",
                    message: effectiveDifferentiateWithoutColor
                        ? L10n.format("API key warning. %@", default: "API key warning. %@", apiKeyWarning)
                        : apiKeyWarning,
                    tone: .warning,
                    identifier: AccessibilityID.apiKeyBanner,
                    actionTitle: nil,
                    action: nil
                )
            }

            if isFetching && hasLoadedContent {
                StatusBannerCard(
                    eyebrow: L10n.text("Syncing Archive", default: "Syncing Archive"),
                    systemImage: "arrow.triangle.2.circlepath",
                    message: L10n.text("Refreshing APOD from NASA API...", default: "Refreshing APOD from NASA API..."),
                    tone: .accent,
                    identifier: AccessibilityID.apiSyncBanner,
                    actionTitle: nil,
                    action: nil
                )
            } else if let error, hasLoadedContent {
                StatusBannerCard(
                    eyebrow: L10n.text("Request Issue", default: "Request Issue"),
                    systemImage: "exclamationmark.triangle.fill",
                    message: effectiveDifferentiateWithoutColor
                        ? L10n.format("Error. %@", default: "Error. %@", error.localizedDescription)
                        : error.localizedDescription,
                    tone: .warning,
                    identifier: AccessibilityID.apiErrorBanner,
                    actionTitle: L10n.text("Retry", default: "Retry"),
                    action: retryAction
                )
            }
        }
    }
}

struct APIRequestEmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        MissionStateCard(
            eyebrow: L10n.text("NASA API", default: "NASA API"),
            title: title,
            message: subtitle,
            systemImage: "hourglass",
            tone: .accent,
            showsProgress: true,
            minHeight: 280,
            accessibilityIdentifier: AccessibilityID.apiRequestLoadingState
        )
        .padding(.horizontal, AppTheme.Spacing.lg)
        .overlay(alignment: .topLeading) {
            AccessibilityMarker(identifier: AccessibilityID.apiRequestLoadingState)
        }
    }
}

struct APIRequestFailureView: View {
    let error: NasaCollectionFetcher.FetchError
    let retryAction: () -> Void

    var body: some View {
        MissionStateCard(
            eyebrow: L10n.text("Mission Control", default: "Mission Control"),
            title: L10n.text("API Request Failed", default: "API Request Failed"),
            message: error.localizedDescription,
            systemImage: "wifi.exclamationmark",
            tone: .warning,
            minHeight: 280,
            accessibilityIdentifier: AccessibilityID.apiRequestFailureState
        ) {
            Button(L10n.text("Retry", default: "Retry"), action: retryAction)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.compactCornerRadius))
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .overlay(alignment: .topLeading) {
            AccessibilityMarker(identifier: AccessibilityID.apiRequestFailureState)
        }
    }
}
