/// Subcomponent structure for HL7 v2.x messages
///
/// Represents the smallest unit in the HL7 v2.x message hierarchy.
/// Subcomponents are separated by the subcomponent separator (typically '&').

import Foundation
import HL7Core

/// A subcomponent in an HL7 v2.x message
public struct Subcomponent: Sendable, Equatable {
    
    /// Raw value storage (uses copy-on-write via String's COW)
    private let rawValue: String
    
    /// Encoding characters for processing
    private let encodingCharacters: EncodingCharacters
    
    /// Initialize with raw value
    /// - Parameters:
    ///   - rawValue: The raw subcomponent value
    ///   - encodingCharacters: Encoding characters to use
    public init(rawValue: String, encodingCharacters: EncodingCharacters = .standard) {
        self.rawValue = rawValue
        self.encodingCharacters = encodingCharacters
    }
    
    /// Get the decoded value (with escape sequences processed)
    /// - Returns: Decoded value
    /// - Throws: HL7Error if decoding fails
    public func value() async throws -> String {
        let processor = EscapeSequenceProcessor(encodingCharacters: encodingCharacters)
        return try await processor.decode(rawValue)
    }
    
    /// Get the raw value (without escape sequence processing)
    public var raw: String {
        return rawValue
    }
    
    /// Check if subcomponent is empty
    public var isEmpty: Bool {
        return rawValue.isEmpty
    }
    
    /// Create an encoded subcomponent from a plain string
    /// - Parameters:
    ///   - value: The plain string value
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Encoded subcomponent
    public static func encode(_ value: String, encodingCharacters: EncodingCharacters = .standard) async -> Subcomponent {
        let processor = EscapeSequenceProcessor(encodingCharacters: encodingCharacters)
        let encoded = await processor.encode(value)
        return Subcomponent(rawValue: encoded, encodingCharacters: encodingCharacters)
    }
}

extension Subcomponent: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}
