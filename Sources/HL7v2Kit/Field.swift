/// Field structure for HL7 v2.x messages
///
/// Represents a field in an HL7 v2.x message. Fields are separated by the field
/// separator (typically '|') and can contain multiple repetitions and components.

import Foundation
import HL7Core

/// A field in an HL7 v2.x message
public struct Field: Sendable, Equatable {
    
    /// Collection of field repetitions (copy-on-write via Array's COW)
    private let repetitions: [[Component]]
    
    /// Encoding characters for processing
    private let encodingCharacters: EncodingCharacters
    
    /// Initialize with repetitions
    /// - Parameters:
    ///   - repetitions: Array of component arrays (each array is one repetition)
    ///   - encodingCharacters: Encoding characters to use
    public init(repetitions: [[Component]], encodingCharacters: EncodingCharacters = .standard) {
        self.repetitions = repetitions
        self.encodingCharacters = encodingCharacters
    }
    
    /// Parse field from raw string
    /// - Parameters:
    ///   - rawValue: Raw field string
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Parsed field
    public static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters = .standard) -> Field {
        // Split by repetition separator
        let repetitionParts = rawValue.split(separator: encodingCharacters.repetitionSeparator, omittingEmptySubsequences: false)
        
        let repetitions = repetitionParts.map { repetitionPart -> [Component] in
            // Split by component separator
            let componentParts = repetitionPart.split(separator: encodingCharacters.componentSeparator, omittingEmptySubsequences: false)
            return componentParts.map { componentPart in
                Component.parse(String(componentPart), encodingCharacters: encodingCharacters)
            }
        }
        
        return Field(repetitions: repetitions, encodingCharacters: encodingCharacters)
    }
    
    /// Get first repetition (most common case)
    public var firstRepetition: [Component] {
        return repetitions.first ?? []
    }
    
    /// Get repetition at index
    /// - Parameter index: Repetition index (0-based)
    /// - Returns: Array of components for that repetition, or empty array if out of bounds
    public func repetition(at index: Int) -> [Component] {
        guard index >= 0 && index < repetitions.count else {
            return []
        }
        return repetitions[index]
    }
    
    /// Get component from first repetition (convenience)
    /// - Parameter index: Component index (0-based)
    /// - Returns: Component at index, or empty component if out of bounds
    public subscript(index: Int) -> Component {
        let components = firstRepetition
        guard index >= 0 && index < components.count else {
            return Component(subcomponents: [], encodingCharacters: encodingCharacters)
        }
        return components[index]
    }
    
    /// Get the first component of the first repetition (most common case)
    public var value: Component {
        return self[0]
    }
    
    /// Check if field is empty
    public var isEmpty: Bool {
        return repetitions.isEmpty || repetitions.allSatisfy { components in
            components.isEmpty || components.allSatisfy { $0.isEmpty }
        }
    }
    
    /// Number of repetitions
    public var repetitionCount: Int {
        return repetitions.count
    }
    
    /// Get all repetitions
    public var allRepetitions: [[Component]] {
        return repetitions
    }
    
    /// Serialize field to raw string
    /// - Returns: Serialized field string
    public func serialize() -> String {
        return repetitions.map { components in
            components.map { $0.serialize() }.joined(separator: String(encodingCharacters.componentSeparator))
        }.joined(separator: String(encodingCharacters.repetitionSeparator))
    }
}

extension Field: CustomStringConvertible {
    public var description: String {
        return serialize()
    }
}
