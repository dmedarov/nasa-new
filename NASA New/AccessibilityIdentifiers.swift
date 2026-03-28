import Foundation

enum AccessibilityID {
    static let mainViewRoot = "mainViewRoot"
    static let mainContentScrollView = "mainContentScrollView"
    static let apodMediaSection = "apodMediaSection"
    static let apodDetailsSection = "apodDetailsSection"
    static let shareAPODButton = "shareAPODButton"
    static let refreshAPODButton = "refreshAPODButton"
    static let randomAPODButton = "randomAPODButton"
    static let toggleAppearanceButton = "toggleAppearanceButton"
    static let openSettingsButton = "openSettingsButton"
    static let openFavoritesButton = "openFavoritesButton"
    static let jumpToLatestAPODDateButton = "jumpToLatestAPODDateButton"
    static let previousAPODDateButton = "previousAPODDateButton"
    static let nextAPODDateButton = "nextAPODDateButton"
    static let apodTitleText = "apodTitleText"
    static let apodDateText = "apodDateText"
    static let apodCreditText = "apodCreditText"
    static let apodExplanationText = "apodExplanationText"
    static let apodExplanationToggleButton = "apodExplanationToggleButton"
    static let favoriteAPODButton = "favoriteAPODButton"
    static let openNasaPageButton = "openNasaPageButton"
    static let openPreferredMediaButton = "openPreferredMediaButton"
    static let favoritesSheetRoot = "favoritesSheetRoot"
    static let favoritesEmptyState = "favoritesEmptyState"
    static let favoritesDoneButton = "favoritesDoneButton"
    static let settingsSheetRoot = "settingsSheetRoot"
    static let settingsCloseButton = "settingsCloseButton"
    static let dataSaverModeToggle = "dataSaverModeToggle"
    static let preferHDImagesToggle = "preferHDImagesToggle"
    static let lastStatusCodeValue = "lastStatusCodeValue"
    static let networkConnectionValue = "networkConnectionValue"
    static let meteredNetworkValue = "meteredNetworkValue"
    static let lowDataModeValue = "lowDataModeValue"
    static let autoplayPolicyValue = "autoplayPolicyValue"
    static let networkEfficiencyValue = "networkEfficiencyValue"
    static let apodImageView = "apodImageView"
    static let apodImageUnavailableMessage = "apodImageUnavailableMessage"
    static let videoDisabledMessage = "videoDisabledMessage"
    static let directVideoPlayer = "directVideoPlayer"
    static let playVideoInAppButton = "playVideoInAppButton"
    static let openVideoExternalButton = "openVideoExternalButton"
    static let unsupportedVideoMessage = "unsupportedVideoMessage"
    static let videoAutoplayPausedBadge = "videoAutoplayPausedBadge"

    static func favoriteRowIdentifier(for nasa: NASA) -> String {
        "favoriteAPODRow-\(nasa.date ?? "unknown")"
    }

    static func favoriteDeleteActionIdentifier(for nasa: NASA) -> String {
        "favoriteAPODDelete-\(nasa.date ?? "unknown")"
    }
}
