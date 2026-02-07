/// Escape sequence processor for HL7 v2.x messages
///
/// This actor handles encoding and decoding of escape sequences in HL7 v2.x messages,
/// allowing special characters to be represented within field values.

import Foundation
import HL7Core

/// Actor for processing escape sequences in HL7 v2.x messages
public actor EscapeSequenceProcessor {
    
    private let encodingCharacters: EncodingCharacters
    
    /// Initialize with encoding characters
    /// - Parameter encodingCharacters: The encoding characters to use
    public init(encodingCharacters: EncodingCharacters = .standard) {
        self.encodingCharacters = encodingCharacters
    }
    
    /// Decode escape sequences in a string
    /// - Parameter input: String with escape sequences
    /// - Returns: Decoded string with actual characters
    /// - Throws: HL7Error if escape sequence is invalid
    public func decode(_ input: String) throws -> String {
        var result = ""
        var index = input.startIndex
        
        while index < input.endIndex {
            if input[index] == encodingCharacters.escapeCharacter {
                // Found escape character, process escape sequence
                let remaining = String(input[index...])
                
                // Find closing escape character
                if let endIndex = remaining.dropFirst().firstIndex(of: encodingCharacters.escapeCharacter) {
                    let escapeSequence = String(remaining[remaining.index(after: remaining.startIndex)..<endIndex])
                    
                    // Decode the escape sequence
                    result += try decodeSequence(escapeSequence)
                    
                    // Move index past the closing escape character
                    index = input.index(index, offsetBy: escapeSequence.count + 2)
                } else {
                    throw HL7Error.parsingError("Unclosed escape sequence at position \(input.distance(from: input.startIndex, to: index))")
                }
            } else {
                result.append(input[index])
                index = input.index(after: index)
            }
        }
        
        return result
    }
    
    /// Encode special characters as escape sequences
    /// - Parameter input: String with special characters
    /// - Returns: Encoded string with escape sequences
    public func encode(_ input: String) -> String {
        var result = ""
        
        for char in input {
            if char == encodingCharacters.fieldSeparator {
                result += "\(encodingCharacters.escapeCharacter)F\(encodingCharacters.escapeCharacter)"
            } else if char == encodingCharacters.componentSeparator {
                result += "\(encodingCharacters.escapeCharacter)S\(encodingCharacters.escapeCharacter)"
            } else if char == encodingCharacters.subcomponentSeparator {
                result += "\(encodingCharacters.escapeCharacter)T\(encodingCharacters.escapeCharacter)"
            } else if char == encodingCharacters.repetitionSeparator {
                result += "\(encodingCharacters.escapeCharacter)R\(encodingCharacters.escapeCharacter)"
            } else if char == encodingCharacters.escapeCharacter {
                result += "\(encodingCharacters.escapeCharacter)E\(encodingCharacters.escapeCharacter)"
            } else if char == "\n" {
                result += "\(encodingCharacters.escapeCharacter).br\(encodingCharacters.escapeCharacter)"
            } else {
                result.append(char)
            }
        }
        
        return result
    }
    
    /// Decode a single escape sequence
    /// - Parameter sequence: The escape sequence content (without escape characters)
    /// - Returns: Decoded character or string
    /// - Throws: HL7Error if sequence is invalid
    private func decodeSequence(_ sequence: String) throws -> String {
        switch sequence {
        case ".br":
            return "\n"
        case "F":
            return String(encodingCharacters.fieldSeparator)
        case "S":
            return String(encodingCharacters.componentSeparator)
        case "T":
            return String(encodingCharacters.subcomponentSeparator)
        case "R":
            return String(encodingCharacters.repetitionSeparator)
        case "E":
            return String(encodingCharacters.escapeCharacter)
        default:
            // Handle hexadecimal sequences (Xnn)
            if sequence.hasPrefix("X") && sequence.count == 3 {
                let hexString = String(sequence.dropFirst())
                if let value = UInt8(hexString, radix: 16) {
                    return String(UnicodeScalar(value))
                }
            }
            throw HL7Error.parsingError("Unknown escape sequence: \(sequence)")
        }
    }
}
