import HL7Core

/// The configurable encoding characters used in an HL7 v2.x message.
///
/// Defined in MSH-1 (field separator) and MSH-2 (encoding characters).
/// Default: `|^~\&`
public struct EncodingCharacters: Sendable, Equatable, Hashable {
    /// Field separator (MSH-1). Default: `|`
    public let fieldSeparator: Character
    /// Component separator. Default: `^`
    public let componentSeparator: Character
    /// Repetition separator. Default: `~`
    public let repetitionSeparator: Character
    /// Escape character. Default: `\`
    public let escapeCharacter: Character
    /// Sub-component separator. Default: `&`
    public let subComponentSeparator: Character

    /// The standard HL7 v2 encoding characters: `|^~\&`
    public static let standard = EncodingCharacters()

    public init(
        fieldSeparator: Character = "|",
        componentSeparator: Character = "^",
        repetitionSeparator: Character = "~",
        escapeCharacter: Character = "\\",
        subComponentSeparator: Character = "&"
    ) {
        self.fieldSeparator = fieldSeparator
        self.componentSeparator = componentSeparator
        self.repetitionSeparator = repetitionSeparator
        self.escapeCharacter = escapeCharacter
        self.subComponentSeparator = subComponentSeparator
    }

    /// Parse encoding characters from the MSH segment header.
    /// - Parameter mshPrefix: The first 8+ characters of the MSH segment (e.g. `MSH|^~\&|`).
    /// - Returns: The parsed encoding characters, or `nil` if the prefix is invalid.
    public static func from(mshPrefix: String) -> EncodingCharacters? {
        guard mshPrefix.count >= 8,
              mshPrefix.hasPrefix("MSH") else {
            return nil
        }
        let chars = Array(mshPrefix)
        return EncodingCharacters(
            fieldSeparator: chars[3],
            componentSeparator: chars[4],
            repetitionSeparator: chars[5],
            escapeCharacter: chars[6],
            subComponentSeparator: chars[7]
        )
    }
}
