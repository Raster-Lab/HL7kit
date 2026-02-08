/// Character Set support for HL7 v2.x messages
///
/// Provides mapping between HL7 standard character set codes (MSH-18 field)
/// and Swift/Foundation character encodings. Supports HL7-registered character sets
/// from ISO, UNICODE, and other standards.

import Foundation
#if canImport(CoreFoundation)
import CoreFoundation
#endif
import HL7Core

// MARK: - Character Set

/// HL7 v2.x character set identifier
///
/// Represents the standardized character set codes used in MSH-18 field.
/// These codes follow HL7 Table 0211 (Alternate Character Sets).
///
/// Common codes include:
/// - ASCII (7-bit ASCII)
/// - 8859/1 through 8859/9 (ISO Latin series)
/// - ISO IR6 (ASCII)
/// - ISO IR100 (Latin-1)
/// - ISO IR192 (UTF-8)
/// - UNICODE (implies UTF-16)
/// - UNICODE UTF-8 (explicit UTF-8)
/// - UNICODE UTF-16 (explicit UTF-16)
public enum CharacterSet: String, Sendable, Equatable, CaseIterable {
    // MARK: ASCII Variants
    
    /// ASCII (7-bit) - ISO IR6
    case ascii = "ASCII"
    
    /// ISO IR6 (ASCII)
    case isoIR6 = "ISO IR6"
    
    // MARK: ISO 8859 Series (Latin)
    
    /// ISO 8859-1 (Latin-1, Western European)
    case iso88591 = "8859/1"
    
    /// ISO 8859-2 (Latin-2, Central European)
    case iso88592 = "8859/2"
    
    /// ISO 8859-3 (Latin-3, South European)
    case iso88593 = "8859/3"
    
    /// ISO 8859-4 (Latin-4, North European)
    case iso88594 = "8859/4"
    
    /// ISO 8859-5 (Cyrillic)
    case iso88595 = "8859/5"
    
    /// ISO 8859-6 (Arabic)
    case iso88596 = "8859/6"
    
    /// ISO 8859-7 (Greek)
    case iso88597 = "8859/7"
    
    /// ISO 8859-8 (Hebrew)
    case iso88598 = "8859/8"
    
    /// ISO 8859-9 (Latin-5, Turkish)
    case iso88599 = "8859/9"
    
    /// ISO 8859-15 (Latin-9, adds Euro sign)
    case iso885915 = "8859/15"
    
    // MARK: ISO IR Series
    
    /// ISO IR100 (Latin-1)
    case isoIR100 = "ISO IR100"
    
    /// ISO IR101 (Latin-2)
    case isoIR101 = "ISO IR101"
    
    /// ISO IR109 (Latin-3)
    case isoIR109 = "ISO IR109"
    
    /// ISO IR110 (Latin-4)
    case isoIR110 = "ISO IR110"
    
    /// ISO IR144 (Cyrillic)
    case isoIR144 = "ISO IR144"
    
    /// ISO IR127 (Arabic)
    case isoIR127 = "ISO IR127"
    
    /// ISO IR126 (Greek)
    case isoIR126 = "ISO IR126"
    
    /// ISO IR138 (Hebrew)
    case isoIR138 = "ISO IR138"
    
    /// ISO IR148 (Latin-5, Turkish)
    case isoIR148 = "ISO IR148"
    
    /// ISO IR192 (UTF-8)
    case isoIR192 = "ISO IR192"
    
    // MARK: UNICODE
    
    /// UNICODE (typically implies UTF-16)
    case unicode = "UNICODE"
    
    /// UNICODE UTF-8 (explicit UTF-8)
    case unicodeUTF8 = "UNICODE UTF-8"
    
    /// UNICODE UTF-16 (explicit UTF-16)
    case unicodeUTF16 = "UNICODE UTF-16"
    
    // MARK: East Asian Encodings
    
    /// ISO IR87 (Japanese Katakana)
    case isoIR87 = "ISO IR87"
    
    /// ISO IR159 (Japanese JIS X 0212-1990)
    case isoIR159 = "ISO IR159"
    
    /// GB 18030 (Chinese)
    case gb18030 = "GB 18030"
    
    /// KS X 1001 (Korean)
    case ksx1001 = "KS X 1001"
    
    /// CNS 11643 (Taiwanese)
    case cns11643 = "CNS 11643-1992"
    
    /// BIG-5 (Traditional Chinese)
    case big5 = "BIG-5"
    
    // MARK: Map to MessageEncoding
    
    /// Convert CharacterSet to MessageEncoding
    /// - Returns: Corresponding MessageEncoding, or nil if no direct mapping exists
    public func toMessageEncoding() -> MessageEncoding? {
        switch self {
        case .ascii, .isoIR6:
            return .ascii
            
        case .iso88591, .isoIR100:
            return .latin1
            
        case .isoIR192, .unicodeUTF8:
            return .utf8
            
        case .unicode, .unicodeUTF16:
            return .utf16
            
        // Note: For other encodings not directly supported by MessageEncoding,
        // we return nil. Applications can handle these specially if needed.
        default:
            return nil
        }
    }
    
    /// Convert to Swift String.Encoding
    /// - Returns: Corresponding String.Encoding, or nil if no direct mapping exists
    public func toStringEncoding() -> String.Encoding? {
        switch self {
        case .ascii, .isoIR6:
            return .ascii
            
        case .iso88591, .isoIR100:
            return .isoLatin1
            
        case .iso88592, .isoIR101:
            return .isoLatin2
            
        case .isoIR192, .unicodeUTF8:
            return .utf8
            
        case .unicode, .unicodeUTF16:
            return .utf16
            
        #if canImport(CoreFoundation)
        case .iso88595, .isoIR144:
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin5.rawValue)))
            
        case .iso88596, .isoIR127:
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatinArabic.rawValue)))
            
        case .iso88597, .isoIR126:
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatinGreek.rawValue)))
            
        case .iso88598, .isoIR138:
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatinHebrew.rawValue)))
            
        case .iso88599, .isoIR148:
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin9.rawValue)))
        #endif
            
        default:
            return nil
        }
    }
    
    /// Parse character set from MSH-18 field value
    /// - Parameter value: Raw field value (e.g., "ISO IR192", "UNICODE UTF-8")
    /// - Returns: Parsed CharacterSet, or nil if not recognized
    public static func parse(_ value: String) -> CharacterSet? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Try exact match first
        if let charset = CharacterSet(rawValue: trimmed) {
            return charset
        }
        
        // Try case-insensitive match
        for charset in CharacterSet.allCases {
            if charset.rawValue.uppercased() == trimmed {
                return charset
            }
        }
        
        // Handle common variations
        switch trimmed {
        case "UTF-8", "UTF8":
            return .unicodeUTF8
        case "UTF-16", "UTF16":
            return .unicodeUTF16
        case "ISO-8859-1", "ISO_8859-1", "LATIN1", "LATIN-1":
            return .iso88591
        case "ISO-8859-2", "ISO_8859-2", "LATIN2", "LATIN-2":
            return .iso88592
        case "ISO-8859-5", "ISO_8859-5":
            return .iso88595
        default:
            return nil
        }
    }
}

// MARK: - HL7v2Message Extension

extension HL7v2Message {
    
    /// Get the character set from MSH-18 field
    ///
    /// MSH-18 specifies the character set(s) used in the message.
    /// This field can contain multiple values (repetitions) when the message
    /// contains text in multiple character sets.
    ///
    /// - Returns: Array of CharacterSet values, empty if MSH-18 is not present or empty
    public func characterSets() -> [CharacterSet] {
        let msh = messageHeader
        
        // MSH-18 is at field index 18 (MSH-1 is at index 0, MSH-2 at index 1, etc.)
        let field = msh[18]
        
        guard !field.isEmpty else {
            return []
        }
        
        // Parse each repetition
        var charsets: [CharacterSet] = []
        for i in 0..<field.repetitionCount {
            let repetition = field.repetition(at: i)
            guard let firstComponent = repetition.first else {
                continue
            }
            
            let value = firstComponent.value.raw
            if let charset = CharacterSet.parse(value) {
                charsets.append(charset)
            }
        }
        
        return charsets
    }
    
    /// Get the primary character set from MSH-18 field
    ///
    /// Returns the first character set in MSH-18, or nil if the field is empty.
    /// This is the most common usage pattern.
    ///
    /// - Returns: Primary CharacterSet, or nil if not specified
    public func primaryCharacterSet() -> CharacterSet? {
        return characterSets().first
    }
    
    /// Get the primary encoding based on MSH-18 field
    ///
    /// Converts the primary character set to a MessageEncoding.
    /// Returns nil if MSH-18 is empty or the character set is not supported.
    ///
    /// - Returns: MessageEncoding for the primary character set, or nil
    public func primaryEncoding() -> MessageEncoding? {
        return primaryCharacterSet()?.toMessageEncoding()
    }
}
