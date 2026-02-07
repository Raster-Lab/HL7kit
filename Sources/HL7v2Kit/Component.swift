/// Component structure for HL7 v2.x messages
///
/// Represents a component in an HL7 v2.x message. Components are separated by
/// the component separator (typically '^') and can contain multiple subcomponents.

import Foundation
import HL7Core

/// A component in an HL7 v2.x message
public struct Component: Sendable, Equatable {
    
    /// Collection of subcomponents (copy-on-write via Array's COW)
    private let subcomponents: [Subcomponent]
    
    /// Encoding characters for processing
    private let encodingCharacters: EncodingCharacters
    
    /// Initialize with subcomponents
    /// - Parameters:
    ///   - subcomponents: Array of subcomponents
    ///   - encodingCharacters: Encoding characters to use
    public init(subcomponents: [Subcomponent], encodingCharacters: EncodingCharacters = .standard) {
        self.subcomponents = subcomponents
        self.encodingCharacters = encodingCharacters
    }
    
    /// Parse component from raw string
    /// - Parameters:
    ///   - rawValue: Raw component string
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Parsed component
    public static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters = .standard) -> Component {
        let subcomponentParts = rawValue.split(separator: encodingCharacters.subcomponentSeparator, omittingEmptySubsequences: false)
        let subcomponents = subcomponentParts.map { part in
            Subcomponent(rawValue: String(part), encodingCharacters: encodingCharacters)
        }
        return Component(subcomponents: subcomponents, encodingCharacters: encodingCharacters)
    }
    
    /// Get subcomponent at index
    /// - Parameter index: Subcomponent index (0-based)
    /// - Returns: Subcomponent at index, or empty subcomponent if out of bounds
    public subscript(index: Int) -> Subcomponent {
        guard index >= 0 && index < subcomponents.count else {
            return Subcomponent(rawValue: "", encodingCharacters: encodingCharacters)
        }
        return subcomponents[index]
    }
    
    /// Get the first subcomponent (convenience for simple components)
    public var value: Subcomponent {
        return self[0]
    }
    
    /// Check if component is empty
    public var isEmpty: Bool {
        return subcomponents.isEmpty || subcomponents.allSatisfy { $0.isEmpty }
    }
    
    /// Number of subcomponents
    public var count: Int {
        return subcomponents.count
    }
    
    /// Get all subcomponents
    public var all: [Subcomponent] {
        return subcomponents
    }
    
    /// Serialize component to raw string
    /// - Returns: Serialized component string
    public func serialize() -> String {
        return subcomponents.map { $0.raw }.joined(separator: String(encodingCharacters.subcomponentSeparator))
    }
}

extension Component: CustomStringConvertible {
    public var description: String {
        return serialize()
    }
}
