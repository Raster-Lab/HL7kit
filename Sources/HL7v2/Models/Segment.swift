import HL7Core

/// A segment within an HL7 v2 message (e.g. MSH, PID, OBX).
public struct Segment: Sendable, Equatable {
    /// The 3-character segment identifier (e.g. "MSH", "PID").
    public let id: String

    /// The fields in this segment (0-based internal storage, 1-based public access).
    public let fields: [Field]

    /// The raw string representation of this segment.
    public let rawValue: String

    public init(_ raw: String, encoding: EncodingCharacters = .standard) {
        self.rawValue = raw
        let sep = encoding.fieldSeparator

        let parts = raw.split(separator: sep, omittingEmptySubsequences: false).map(String.init)
        self.id = parts.first ?? ""

        // For MSH, field 1 is the field separator itself, and field 2 is the encoding characters.
        // Other segments: fields start after the segment ID.
        if self.id == "MSH" {
            // MSH-1 = field separator, MSH-2 = encoding characters (next 4 chars)
            var mshFields = [Field(String(sep), encoding: encoding)]
            if parts.count > 1 {
                mshFields += parts.dropFirst().map { Field($0, encoding: encoding) }
            }
            self.fields = mshFields
        } else {
            self.fields = parts.dropFirst().map { Field($0, encoding: encoding) }
        }
    }

    /// Access a field by 1-based index (HL7 convention).
    public subscript(field index: Int) -> Field? {
        guard index >= 1, index <= fields.count else { return nil }
        return fields[index - 1]
    }
}
