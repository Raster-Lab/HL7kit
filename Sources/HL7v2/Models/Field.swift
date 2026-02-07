import HL7Core

/// A field within an HL7 v2 segment, which may contain components and repetitions.
public struct Field: Sendable, Equatable {
    /// The raw string value of this field (including any repetitions).
    public let rawValue: String

    /// Individual repetitions of this field (split by `~`).
    public let repetitions: [String]

    /// Components of the first (or only) repetition.
    public let components: [Component]

    /// Whether this field is empty.
    public var isEmpty: Bool { rawValue.isEmpty }

    /// The value of the first component (convenience accessor).
    public var value: String { components.first?.value ?? "" }

    public init(_ rawValue: String, encoding: EncodingCharacters = .standard) {
        self.rawValue = rawValue
        self.repetitions = rawValue.split(
            separator: encoding.repetitionSeparator,
            omittingEmptySubsequences: false
        ).map(String.init)

        let firstRepetition = self.repetitions.first ?? ""
        self.components = firstRepetition.split(
            separator: encoding.componentSeparator,
            omittingEmptySubsequences: false
        ).map { Component(String($0), encoding: encoding) }
    }

    /// Access a component by 1-based index.
    public subscript(component index: Int) -> Component? {
        guard index >= 1, index <= components.count else { return nil }
        return components[index - 1]
    }

    /// Get components of a specific repetition (0-based repetition index).
    public func components(ofRepetition index: Int, encoding: EncodingCharacters = .standard) -> [Component] {
        guard index >= 0, index < repetitions.count else { return [] }
        return repetitions[index].split(
            separator: encoding.componentSeparator,
            omittingEmptySubsequences: false
        ).map { Component(String($0), encoding: encoding) }
    }
}
