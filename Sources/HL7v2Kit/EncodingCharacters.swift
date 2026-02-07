/// Encoding characters for HL7 v2.x messages
///
/// This structure represents the delimiter characters used in HL7 v2.x messages
/// to separate fields, components, subcomponents, and repetitions.

import Foundation
import HL7Core

/// Encoding characters used in HL7 v2.x messages
public struct EncodingCharacters: Sendable, Equatable {
    /// Field separator (typically '|')
    public let fieldSeparator: Character
    
    /// Component separator (typically '^')
    public let componentSeparator: Character
    
    /// Repetition separator (typically '~')
    public let repetitionSeparator: Character
    
    /// Escape character (typically '\')
    public let escapeCharacter: Character
    
    /// Subcomponent separator (typically '&')
    public let subcomponentSeparator: Character
    
    /// Default HL7 encoding characters (^~\&)
    public static let standard = EncodingCharacters(
        fieldSeparator: "|",
        componentSeparator: "^",
        repetitionSeparator: "~",
        escapeCharacter: "\\",
        subcomponentSeparator: "&"
    )
    
    /// Initialize with specific encoding characters
    /// - Parameters:
    ///   - fieldSeparator: Field separator character
    ///   - componentSeparator: Component separator character
    ///   - repetitionSeparator: Repetition separator character
    ///   - escapeCharacter: Escape character
    ///   - subcomponentSeparator: Subcomponent separator character
    public init(
        fieldSeparator: Character,
        componentSeparator: Character,
        repetitionSeparator: Character,
        escapeCharacter: Character,
        subcomponentSeparator: Character
    ) {
        self.fieldSeparator = fieldSeparator
        self.componentSeparator = componentSeparator
        self.repetitionSeparator = repetitionSeparator
        self.escapeCharacter = escapeCharacter
        self.subcomponentSeparator = subcomponentSeparator
    }
    
    /// Parse encoding characters from MSH-2 field
    /// - Parameters:
    ///   - encodingString: The encoding characters string (MSH-2)
    ///   - fieldSeparator: The field separator from MSH-1
    /// - Returns: Parsed encoding characters
    /// - Throws: HL7Error if encoding string is invalid
    public static func parse(from encodingString: String, fieldSeparator: Character = "|") throws -> EncodingCharacters {
        // MSH-2 contains 4 characters: ^~\&
        guard encodingString.count == 4 else {
            throw HL7Error.parsingError("Invalid encoding characters: expected 4 characters, got \(encodingString.count)")
        }
        
        let chars = Array(encodingString)
        return EncodingCharacters(
            fieldSeparator: fieldSeparator,
            componentSeparator: chars[0],
            repetitionSeparator: chars[1],
            escapeCharacter: chars[2],
            subcomponentSeparator: chars[3]
        )
    }
    
    /// Convert encoding characters to string format (for MSH-2)
    /// - Returns: Encoding characters as string (e.g., "^~\&")
    public func toEncodingString() -> String {
        return "\(componentSeparator)\(repetitionSeparator)\(escapeCharacter)\(subcomponentSeparator)"
    }
    
    /// Check if a character is a delimiter
    /// - Parameter char: Character to check
    /// - Returns: True if the character is a delimiter
    public func isDelimiter(_ char: Character) -> Bool {
        return char == fieldSeparator ||
               char == componentSeparator ||
               char == repetitionSeparator ||
               char == escapeCharacter ||
               char == subcomponentSeparator
    }
}
