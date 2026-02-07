/// A type that can be initialised by parsing raw HL7 data.
public protocol HL7Parsable: Sendable {
    /// Initialise from a raw string representation.
    /// - Parameter raw: The raw HL7 string data.
    /// - Throws: `HL7Error` if parsing fails.
    init(parsing raw: String) throws
}
