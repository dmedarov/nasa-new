import Foundation

struct APODDateRestoration {
    static func restoredDate(
        storedValue: String?,
        parseDate: (String?) -> Date?,
        minimumDate: Date,
        maximumDate: Date
    ) -> Date? {
        guard let restoredDate = parseDate(storedValue) else { return nil }
        return min(max(restoredDate, minimumDate), maximumDate)
    }
}
