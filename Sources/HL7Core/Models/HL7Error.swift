/// Errors produced by HL7kit operations.
public enum HL7Error: Error, Sendable, Equatable {
    // MARK: - Parsing
    /// The input data is empty or contains no parseable content.
    case emptyMessage
    /// A required segment is missing from the message.
    case missingSegment(String)
    /// A required field at the given index is missing or empty.
    case missingField(segment: String, index: Int)
    /// The message structure is malformed and cannot be parsed.
    case malformedMessage(String)
    /// An encoding character configuration is invalid.
    case invalidEncodingCharacters

    // MARK: - Validation
    /// A validation rule was violated.
    case validationFailed(String)
    /// A field value does not match the expected data type.
    case invalidDataType(field: String, expected: String)

    // MARK: - Transport
    /// A network connection could not be established.
    case connectionFailed(String)
    /// A timeout occurred while waiting for a response.
    case timeout
    /// The MLLP framing is invalid.
    case invalidMLLPFrame

    // MARK: - Encoding
    /// The message could not be encoded to the target format.
    case encodingFailed(String)

    // MARK: - General
    /// An unsupported HL7 version was encountered.
    case unsupportedVersion(String)
}
