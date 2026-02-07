/// A type that can encode itself to an HL7 wire format string.
public protocol HL7Encodable: Sendable {
    /// Encode to the default wire format.
    /// - Returns: The encoded string representation.
    func encode() -> String
}
