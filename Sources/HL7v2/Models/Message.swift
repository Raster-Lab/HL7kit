import HL7Core

/// An HL7 v2.x message composed of segments.
public struct Message: Sendable, Equatable {
    /// The encoding characters used in this message.
    public let encoding: EncodingCharacters

    /// All segments in the message, in order.
    public let segments: [Segment]

    /// A terser for path-based field access.
    public var terser: Terser { Terser(message: self) }

    /// The HL7 version from MSH-12, if present.
    public var version: HL7Version? {
        guard let msh = segment("MSH"),
              let versionField = msh[field: 12] else { return nil }
        return HL7Version(rawValue: versionField.value)
    }

    /// The message type from MSH-9 (e.g. "ADT^A04").
    public var messageType: String? {
        segment("MSH")?[field: 9]?.rawValue
    }

    /// The message control ID from MSH-10.
    public var controlID: String? {
        segment("MSH")?[field: 10]?.value
    }

    // MARK: - Initialisation

    /// Parse a message from a raw HL7 v2 string.
    /// - Parameter raw: The raw HL7 message string. Segments may be separated by `\r`, `\n`, or `\r\n`.
    /// - Throws: `HL7Error` if the message cannot be parsed.
    public init(parsing raw: String) throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HL7Error.emptyMessage
        }

        guard trimmed.hasPrefix("MSH") else {
            throw HL7Error.malformedMessage("Message must begin with MSH segment")
        }

        // Parse encoding characters from MSH header
        guard let enc = EncodingCharacters.from(mshPrefix: trimmed) else {
            throw HL7Error.invalidEncodingCharacters
        }
        self.encoding = enc

        // Split into segment lines — HL7 uses \r, but we also accept \n and \r\n
        let lines = trimmed
            .replacingOccurrences(of: "\r\n", with: "\r")
            .replacingOccurrences(of: "\n", with: "\r")
            .split(separator: "\r", omittingEmptySubsequences: true)
            .map(String.init)

        guard !lines.isEmpty else {
            throw HL7Error.emptyMessage
        }

        self.segments = lines.map { Segment($0, encoding: enc) }
    }

    /// Create a message from pre-built segments.
    public init(segments: [Segment], encoding: EncodingCharacters = .standard) {
        self.segments = segments
        self.encoding = encoding
    }

    // MARK: - Segment Access

    /// Get the first segment with the given ID.
    public func segment(_ id: String) -> Segment? {
        segments.first { $0.id == id }
    }

    /// Get all segments with the given ID.
    public func segments(_ id: String) -> [Segment] {
        segments.filter { $0.id == id }
    }

    // MARK: - Encoding

    /// Encode to ER7 (pipe-delimited) format.
    public func encodeER7() -> String {
        segments.map(\.rawValue).joined(separator: "\r")
    }
}

// MARK: - HL7Parsable conformance

extension Message: HL7Parsable {}
