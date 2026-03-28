import Foundation

enum L10n {
    static func text(_ key: String, default defaultValue: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: defaultValue, comment: "")
    }

    static func format(_ key: String, default defaultValue: String, _ arguments: CVarArg...) -> String {
        String(format: text(key, default: defaultValue), locale: Locale.current, arguments: arguments)
    }
}
