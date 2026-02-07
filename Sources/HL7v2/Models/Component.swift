import HL7Core

/// A single component value within an HL7 v2 field, which may contain sub-components.
public struct Component: Sendable, Equatable {
    /// The raw string value of this component.
    public let value: String

    /// Sub-components split by the sub-component separator.
    public let subComponents: [String]

    /// Whether this component is empty.
    public var isEmpty: Bool { value.isEmpty }

    public init(_ value: String, encoding: EncodingCharacters = .standard) {
        self.value = value
        self.subComponents = value.split(
            separator: encoding.subComponentSeparator,
            omittingEmptySubsequences: false
        ).map(String.init)
    }

    /// Access a sub-component by 1-based index.
    public subscript(subComponent index: Int) -> String? {
        guard index >= 1, index <= subComponents.count else { return nil }
        return subComponents[index - 1]
    }
}
