import HL7Core

/// Path-based field accessor for HL7 v2 messages, inspired by HAPI's Terser.
///
/// Supports paths like:
/// - `PID-5` — field 5 of the first PID segment
/// - `PID-5-1` — component 1 of field 5
/// - `PID-5-1-2` — sub-component 2 of component 1 of field 5
/// - `OBX(1)-5` — field 5 of the second OBX segment (0-based repetition index)
public struct Terser: Sendable {
    private let message: Message

    public init(message: Message) {
        self.message = message
    }

    /// Access a value by terser path.
    ///
    /// - Parameter path: A terser path string (e.g. `"PID-5-1"`).
    /// - Returns: The string value at that path, or `nil` if not found.
    public subscript(path: String) -> String? {
        get {
            guard let parsed = TerserPath.parse(path) else { return nil }
            return resolve(parsed)
        }
    }

    private func resolve(_ path: TerserPath) -> String? {
        let matchingSegments = message.segments(path.segmentID)
        guard path.segmentRepetition < matchingSegments.count else { return nil }
        let segment = matchingSegments[path.segmentRepetition]

        guard let field = segment[field: path.fieldIndex] else { return nil }

        if let componentIndex = path.componentIndex {
            guard let component = field[component: componentIndex] else { return nil }
            if let subComponentIndex = path.subComponentIndex {
                return component[subComponent: subComponentIndex]
            }
            return component.value
        }

        return field.value
    }
}

// MARK: - Path Parsing

/// A parsed terser path.
struct TerserPath: Sendable {
    let segmentID: String
    let segmentRepetition: Int
    let fieldIndex: Int
    let componentIndex: Int?
    let subComponentIndex: Int?

    /// Parse a terser path string.
    ///
    /// Format: `SEG(rep)-field-component-subcomponent`
    /// Examples: `PID-5`, `PID-5-1`, `OBX(1)-5-1-2`
    static func parse(_ path: String) -> TerserPath? {
        var remaining = path

        // Extract segment ID and optional repetition
        var segmentID: String
        var segmentRep = 0

        if let parenStart = remaining.firstIndex(of: "("),
           let parenEnd = remaining.firstIndex(of: ")") {
            segmentID = String(remaining[remaining.startIndex..<parenStart])
            let repStr = String(remaining[remaining.index(after: parenStart)..<parenEnd])
            guard let rep = Int(repStr) else { return nil }
            segmentRep = rep
            remaining = String(remaining[remaining.index(after: parenEnd)...])
        } else {
            // Find first dash
            guard let dashIndex = remaining.firstIndex(of: "-") else { return nil }
            segmentID = String(remaining[remaining.startIndex..<dashIndex])
            remaining = String(remaining[dashIndex...])
        }

        guard !segmentID.isEmpty else { return nil }

        // Split remaining by dashes
        let parts = remaining.split(separator: "-", omittingEmptySubsequences: false).dropFirst()
        let indices = parts.compactMap { Int($0) }

        guard !indices.isEmpty else { return nil }

        return TerserPath(
            segmentID: segmentID,
            segmentRepetition: segmentRep,
            fieldIndex: indices[0],
            componentIndex: indices.count > 1 ? indices[1] : nil,
            subComponentIndex: indices.count > 2 ? indices[2] : nil
        )
    }
}
