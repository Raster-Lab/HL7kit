import Foundation

/// Utilities for parsing and formatting HL7 date/time values.
///
/// HL7 uses the format `YYYYMMDDHHMMSS.SSS±ZZZZ` with varying precision.
public enum HL7DateFormatter: Sendable {

    /// Parse an HL7 date/time string to a `Date`.
    /// Supports formats from `YYYY` through `YYYYMMDDHHMMSS.SSS±ZZZZ`.
    /// - Parameter hl7String: The HL7 date/time string.
    /// - Returns: A `Date` if parsing succeeds, `nil` otherwise.
    public static func date(from hl7String: String) -> Date? {
        let trimmed = hl7String.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Determine the format based on string length (before timezone)
        let baseLength = min(trimmed.count, 14)
        switch baseLength {
        case 4:
            formatter.dateFormat = "yyyy"
        case 6:
            formatter.dateFormat = "yyyyMM"
        case 8:
            formatter.dateFormat = "yyyyMMdd"
        case 10:
            formatter.dateFormat = "yyyyMMddHH"
        case 12:
            formatter.dateFormat = "yyyyMMddHHmm"
        case 14...:
            if trimmed.contains(".") {
                formatter.dateFormat = "yyyyMMddHHmmss.SSS"
            } else {
                formatter.dateFormat = "yyyyMMddHHmmss"
            }
        default:
            return nil
        }

        return formatter.date(from: trimmed)
    }

    /// Format a `Date` to an HL7 date/time string with full precision.
    /// - Parameter date: The date to format.
    /// - Returns: HL7-formatted date/time string (`YYYYMMDDHHMMSS`).
    public static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: date)
    }
}
