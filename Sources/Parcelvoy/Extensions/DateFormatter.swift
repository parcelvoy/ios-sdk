import Foundation

extension DateFormatter {
    static let jsonDateFormat: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        return dateFormatter
    }()
}
