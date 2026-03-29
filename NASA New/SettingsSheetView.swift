import SwiftUI
import UserNotifications

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let toggleIdentifier: String
    let accessibilityHint: String
    let isEnabled: Bool
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
                isOn.toggle()
            }

            Toggle(isOn: $isOn) {
                EmptyView()
            }
            .labelsHidden()
            .disabled(!isEnabled)
            .accessibilityIdentifier(toggleIdentifier)
            .accessibilityLabel(title)
            .accessibilityHint(accessibilityHint)
        }
        .opacity(isEnabled ? 1 : 0.65)
    }
}

struct SettingsSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var appearancePreference: AppAppearancePreference
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

    private func localizedDiagnosticResult(_ result: String) -> String {
        switch result.lowercased() {
        case "success":
            return L10n.text("Success", default: "Success")
        case "failure":
            return L10n.text("Failure", default: "Failure")
        default:
            return result
        }
    }

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
        case .authorized: return L10n.text("notification.authorized", default: "Authorized")
        case .provisional: return L10n.text("notification.provisional", default: "Provisional")
        case .ephemeral: return L10n.text("notification.ephemeral", default: "Ephemeral")
        case .denied: return L10n.text("notification.denied", default: "Denied")
        case .notDetermined: return L10n.text("notification.not_determined", default: "Not Determined")
        @unknown default: return L10n.text("notification.unknown", default: "Unknown")
        }
    }

    private var videoAutoplayPolicyLabel: String {
        guard allowVideoPlayback else { return L10n.text("video.playback_disabled", default: "Playback disabled") }
        guard wifiOnlyVideoAutoplay else { return L10n.text("video.autoplay_any_network", default: "Autoplay allowed on any network") }
        if !networkReachable { return L10n.text("video.waiting_for_network", default: "Waiting for network connection") }
        return videoAutoplayEligible
            ? L10n.text("video.autoplay_wifi", default: "Autoplay allowed on Wi-Fi")
            : L10n.text("video.manual_off_wifi", default: "Manual play required off Wi-Fi")
    }

    private var networkEfficiencyLabel: String {
        if !networkReachable {
            return L10n.text("network.offline_cached_preferred", default: "Offline. Cached APOD content is preferred.")
        }
        if dataSaverMode && networkIsConstrained {
            return L10n.text("network.maximum_savings", default: "Maximum savings. App data saver and Low Data Mode are both active.")
        }
        if dataSaverMode {
            return L10n.text("network.data_saver_active", default: "App data saver active. Lower-bandwidth images are preferred.")
        }
        if networkIsConstrained {
            return L10n.text("network.low_data_mode_active", default: "System Low Data Mode active. Prefer lighter media usage.")
        }
        if networkIsExpensive {
            return L10n.text("network.metered_detected", default: "Metered connection detected. HD media may increase data usage.")
        }
        return L10n.text("network.standard_delivery", default: "Standard media delivery.")
    }

    private var followsSystemAppearance: Bool {
        appearancePreference == .system
    }

    private var followSystemAppearanceBinding: Binding<Bool> {
        Binding(
            get: { followsSystemAppearance },
            set: { newValue in
                if newValue {
                    appearancePreference = .system
                } else {
                    appearancePreference = AppAppearancePolicy.explicitPreference(matching: colorScheme)
                }
            }
        )
    }

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: {
                AppAppearancePolicy.effectiveIsDarkMode(
                    preference: appearancePreference,
                    systemColorScheme: colorScheme
                )
            },
            set: { isDarkMode in
                appearancePreference = AppAppearancePolicy.explicitPreference(forDarkMode: isDarkMode)
            }
        )
    }

    var body: some View {
        AdaptiveNavigationContainer {
            Form {
                Color.clear
                    .frame(height: 36)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityHidden(true)

                Section(L10n.text("appearance.section_title", default: "Appearance")) {
                    SettingsToggleRow(
                        title: L10n.text("appearance.follow_system", default: "Follow System Appearance"),
                        subtitle: L10n.text(
                            "appearance.follow_system_subtitle",
                            default: "Keeps the app matched to your iPhone or iPad appearance automatically."
                        ),
                        toggleIdentifier: AccessibilityID.followSystemAppearanceToggle,
                        accessibilityHint: L10n.text(
                            "appearance.follow_system_hint",
                            default: "Keeps the app aligned with the device appearance."
                        ),
                        isEnabled: true,
                        isOn: followSystemAppearanceBinding
                    )

                    SettingsToggleRow(
                        title: L10n.text("appearance.dark_mode", default: "Dark Mode"),
                        subtitle: followsSystemAppearance
                            ? L10n.text(
                                "appearance.dark_mode_disabled_subtitle",
                                default: "Turn off Follow System Appearance to choose a fixed light or dark mode."
                            )
                            : L10n.text(
                                "appearance.dark_mode_subtitle",
                                default: "Switches the app between light and dark appearance."
                            ),
                        toggleIdentifier: AccessibilityID.darkModeToggle,
                        accessibilityHint: followsSystemAppearance
                            ? L10n.text(
                                "appearance.dark_mode_disabled_hint",
                                default: "Disable Follow System Appearance first to set a fixed theme."
                            )
                            : L10n.text(
                                "appearance.dark_mode_hint",
                                default: "Turns dark appearance on or off for the app."
                            ),
                        isEnabled: !followsSystemAppearance,
                        isOn: darkModeBinding
                    )
                }

                Section(L10n.text("Content Preferences", default: "Content Preferences")) {
                    Toggle(L10n.text("Prefer Images Only", default: "Prefer Images Only"), isOn: $preferImages)
                        .accessibilityLabel(L10n.text("Prefer images only for random selection", default: "Prefer images only for random selection"))
                        .accessibilityHint(L10n.text("Limits random selection to images only", default: "Limits random selection to images only"))
                    Toggle(L10n.text("Allow Video Playback", default: "Allow Video Playback"), isOn: $allowVideoPlayback)
                        .accessibilityLabel(L10n.text("Allow video playback", default: "Allow video playback"))
                        .accessibilityHint(L10n.text("Controls whether APOD videos play inside the app", default: "Controls whether APOD videos play inside the app"))
                }

                Section(L10n.text("API Diagnostics", default: "API Diagnostics")) {
                    LabeledContent(L10n.text("NASA_API_KEY Configured", default: "NASA_API_KEY Configured")) {
                        Text(isAPIKeyConfigured ? L10n.text("Yes", default: "Yes") : L10n.text("No (Using DEMO_KEY)", default: "No (Using DEMO_KEY)"))
                            .foregroundColor(isAPIKeyConfigured ? .green : .orange)
                    }
                    LabeledContent(L10n.text("Last Status Code", default: "Last Status Code")) {
                        Text(lastStatusCode.map(String.init) ?? L10n.notAvailable)
                            .accessibilityIdentifier(AccessibilityID.lastStatusCodeValue)
                    }
                    LabeledContent(L10n.text("Last Request Time", default: "Last Request Time")) {
                        Text(formattedRequestDate(lastRequestDate))
                    }
                    LabeledContent(L10n.text("Using Cached Data", default: "Using Cached Data")) {
                        Text(L10n.yesNo(isUsingCachedData))
                    }
                    if let rateLimitRetryDate {
                        LabeledContent(L10n.text("Rate Limit Retry Time", default: "Rate Limit Retry Time")) {
                            Text(formattedRequestDate(rateLimitRetryDate))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if let lastTransportError {
                        LabeledContent(L10n.text("Last Transport Error", default: "Last Transport Error")) {
                            Text(lastTransportError)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if let apiKeyWarning {
                        LabeledContent(L10n.text("API Key Warning", default: "API Key Warning")) {
                            Text(apiKeyWarning)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if !diagnosticsHistory.isEmpty {
                    Section(L10n.text("Recent Requests", default: "Recent Requests")) {
                        ForEach(diagnosticsHistory.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(localizedDiagnosticResult(item.result)) • \(item.statusCode.map(String.init) ?? L10n.notAvailable)")
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

                Section(L10n.text("Daily Notifications", default: "Daily Notifications")) {
                    Toggle(L10n.text("Enable Daily APOD Alerts", default: "Enable Daily APOD Alerts"), isOn: $dailyNotificationsEnabled)
                    DatePicker(
                        L10n.text("Alert Time", default: "Alert Time"),
                        selection: notificationTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!dailyNotificationsEnabled)
                    LabeledContent(L10n.text("Notification Permission", default: "Notification Permission")) {
                        Text(notificationPermissionLabel)
                    }
                    LabeledContent(L10n.text("Next Scheduled Alert", default: "Next Scheduled Alert")) {
                        Text(formattedRequestDate(nextScheduledNotificationDate))
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(L10n.text("Data Saver", default: "Data Saver")) {
                    SettingsToggleRow(
                        title: L10n.text("Enable Data Saver Mode", default: "Enable Data Saver Mode"),
                        subtitle: L10n.text("Favors lower-bandwidth image URLs and turns off HD image preference.", default: "Favors lower-bandwidth image URLs and turns off HD image preference."),
                        toggleIdentifier: AccessibilityID.dataSaverModeToggle,
                        accessibilityHint: L10n.text("Reduces network usage for APOD media.", default: "Reduces network usage for APOD media."),
                        isEnabled: true,
                        isOn: $dataSaverMode
                    )
                    SettingsToggleRow(
                        title: L10n.text("Prefer HD Images", default: "Prefer HD Images"),
                        subtitle: L10n.text("Uses the highest-resolution image when available.", default: "Uses the highest-resolution image when available."),
                        toggleIdentifier: AccessibilityID.preferHDImagesToggle,
                        accessibilityHint: L10n.text("Downloads higher resolution APOD images when data saver is off.", default: "Downloads higher resolution APOD images when data saver is off."),
                        isEnabled: !dataSaverMode,
                        isOn: $preferHDImages
                    )
                    Toggle(L10n.text("Autoplay Videos on Wi-Fi Only", default: "Autoplay Videos on Wi-Fi Only"), isOn: $wifiOnlyVideoAutoplay)
                        .disabled(!allowVideoPlayback)
                    Stepper(value: $cacheItemLimit, in: 90...1460, step: 30) {
                        LabeledContent(L10n.text("On-Device Archive Limit", default: "On-Device Archive Limit")) {
                            Text(String(cacheItemLimit))
                        }
                    }
                    Text(L10n.text("storage.archive_limit.description", default: "Controls how many APOD records stay on device. Saved images and supported media are downloaded separately for offline use when available."))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(L10n.text("Storage Diagnostics", default: "Storage Diagnostics")) {
                    LabeledContent(L10n.text("Archived APOD Items", default: "Archived APOD Items")) {
                        Text(String(cachedItemCount))
                    }
                    LabeledContent(L10n.text("Applied Cache Limit", default: "Applied Cache Limit")) {
                        Text(String(appliedCacheItemLimit))
                    }
                    LabeledContent(L10n.text("Data Saver Active", default: "Data Saver Active")) {
                        Text(L10n.yesNo(dataSaverMode))
                    }
                    LabeledContent(L10n.text("HD Images Preferred", default: "HD Images Preferred")) {
                        Text(L10n.yesNo(preferHDImages))
                    }
                }

                Section(L10n.text("Network Diagnostics", default: "Network Diagnostics")) {
                    LabeledContent(L10n.text("Connection", default: "Connection")) {
                        Text(networkConnectionLabel)
                            .accessibilityIdentifier(AccessibilityID.networkConnectionValue)
                    }
                    LabeledContent(L10n.text("Network Reachable", default: "Network Reachable")) {
                        Text(L10n.yesNo(networkReachable))
                    }
                    LabeledContent(L10n.text("Metered Network", default: "Metered Network")) {
                        Text(L10n.yesNo(networkIsExpensive))
                            .accessibilityIdentifier(AccessibilityID.meteredNetworkValue)
                    }
                    LabeledContent(L10n.text("Low Data Mode", default: "Low Data Mode")) {
                        Text(L10n.yesNo(networkIsConstrained))
                            .accessibilityIdentifier(AccessibilityID.lowDataModeValue)
                    }
                    LabeledContent(L10n.text("Video Autoplay Eligible", default: "Video Autoplay Eligible")) {
                        Text(L10n.yesNo(videoAutoplayEligible))
                    }
                    LabeledContent(L10n.text("Autoplay Policy", default: "Autoplay Policy")) {
                        Text(videoAutoplayPolicyLabel)
                            .accessibilityIdentifier(AccessibilityID.autoplayPolicyValue)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent(L10n.text("Network Efficiency", default: "Network Efficiency")) {
                        Text(networkEfficiencyLabel)
                            .accessibilityIdentifier(AccessibilityID.networkEfficiencyValue)
                            .multilineTextAlignment(.trailing)
                    }
                    if wifiOnlyVideoAutoplay {
                        Text(L10n.text("Videos will wait for manual playback unless the device is on Wi-Fi.", default: "Videos will wait for manual playback unless the device is on Wi-Fi."))
                            .font(AppTheme.Typography.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section(L10n.text("About & Attribution", default: "About & Attribution")) {
                    Text(
                        L10n.text(
                            "brand.independent_notice",
                            default: "Independent app using NASA's public APOD service. Not affiliated with or endorsed by NASA."
                        )
                    )
                    .font(AppTheme.Typography.footnote)

                    Text(
                        L10n.text(
                            "brand.data_source_notice",
                            default: "APOD imagery, captions, and metadata come from NASA's Astronomy Picture of the Day service. Rights for non-NASA material stay with the credited creator."
                        )
                    )
                    .font(AppTheme.Typography.footnote)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle(L10n.text("Settings", default: "Settings"))
            .overlay(alignment: .topLeading) {
                AccessibilityMarker(identifier: AccessibilityID.settingsSheetRoot)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Done", default: "Done")) { isPresented = false }
                        .accessibilityIdentifier(AccessibilityID.settingsCloseButton)
                        .accessibilityLabel(L10n.text("Close settings", default: "Close settings"))
                }
            }
        }
    }

    private func formattedRequestDate(_ date: Date?) -> String {
        guard let date else { return L10n.notAvailable }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}
