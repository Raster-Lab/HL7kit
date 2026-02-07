/// Message builder for HL7 v2.x messages
///
/// Provides a fluent API for constructing HL7 v2.x messages programmatically,
/// with segment builders, field/component convenience methods, template support,
/// and proper encoding and escaping.

import Foundation
import HL7Core

// MARK: - MessageBuilder

/// Fluent builder for constructing HL7 v2.x messages
///
/// ```swift
/// let message = try HL7v2MessageBuilder()
///     .msh { msh in
///         msh.sendingApplication("SendApp")
///            .sendingFacility("SendFac")
///            .receivingApplication("RecApp")
///            .receivingFacility("RecFac")
///            .messageType("ADT", triggerEvent: "A01")
///            .messageControlID("MSG001")
///            .processingID("P")
///            .version("2.5.1")
///     }
///     .segment("PID") { seg in
///         seg.field(1, value: "1")
///            .field(3, value: "12345^^^Hospital^MR")
///            .field(5, value: "Smith^John^A")
///     }
///     .build()
/// ```
public struct HL7v2MessageBuilder: Sendable {

    // MARK: - Properties

    /// Encoding characters to use for the message
    private let encodingCharacters: EncodingCharacters

    /// Accumulated segment data
    private var segmentData: [SegmentData]

    /// Internal representation of a segment being built
    struct SegmentData: Sendable {
        let segmentID: String
        var fields: [Int: FieldData]
    }

    /// Internal representation of a field being built
    struct FieldData: Sendable {
        let rawValue: String
    }

    // MARK: - Initialization

    /// Creates a new message builder
    /// - Parameter encodingCharacters: Encoding characters to use (defaults to standard)
    public init(encodingCharacters: EncodingCharacters = .standard) {
        self.encodingCharacters = encodingCharacters
        self.segmentData = []
    }

    // MARK: - MSH Builder

    /// Add an MSH segment using the MSH-specific builder
    /// - Parameter configure: Closure to configure the MSH segment
    /// - Returns: Updated builder
    public func msh(_ configure: (MSHSegmentBuilder) -> MSHSegmentBuilder) -> HL7v2MessageBuilder {
        let mshBuilder = configure(MSHSegmentBuilder(encodingCharacters: encodingCharacters))
        var copy = self
        copy.segmentData.insert(mshBuilder.toSegmentData(), at: 0)
        return copy
    }

    // MARK: - Generic Segment Builder

    /// Add a segment using the generic segment builder
    /// - Parameters:
    ///   - segmentID: Segment identifier (e.g., "PID", "OBX")
    ///   - configure: Closure to configure the segment
    /// - Returns: Updated builder
    public func segment(_ segmentID: String, _ configure: (SegmentBuilder) -> SegmentBuilder) -> HL7v2MessageBuilder {
        let builder = configure(SegmentBuilder(segmentID: segmentID, encodingCharacters: encodingCharacters))
        var copy = self
        copy.segmentData.append(builder.toSegmentData())
        return copy
    }

    /// Add a raw segment string
    /// - Parameter rawSegment: Raw segment string (e.g., "PID|1||12345")
    /// - Returns: Updated builder
    public func rawSegment(_ rawSegment: String) -> HL7v2MessageBuilder {
        let segmentID = String(rawSegment.prefix(3))
        let fieldSep = String(encodingCharacters.fieldSeparator)
        let rest = String(rawSegment.dropFirst(3))
        let fieldStrings: [String]
        if rest.hasPrefix(fieldSep) {
            fieldStrings = rest.dropFirst().components(separatedBy: fieldSep)
        } else {
            fieldStrings = []
        }

        var fields: [Int: FieldData] = [:]
        for (index, value) in fieldStrings.enumerated() {
            fields[index + 1] = FieldData(rawValue: value)
        }

        var copy = self
        copy.segmentData.append(SegmentData(segmentID: segmentID, fields: fields))
        return copy
    }

    // MARK: - Build

    /// Build the HL7 v2.x message
    /// - Returns: Constructed message
    /// - Throws: HL7Error if the message is invalid
    public func build() throws -> HL7v2Message {
        guard !segmentData.isEmpty else {
            throw HL7Error.validationError("Message must contain at least one segment")
        }

        guard segmentData[0].segmentID == "MSH" else {
            throw HL7Error.validationError("Message must start with MSH segment")
        }

        var segments: [BaseSegment] = []

        for data in segmentData {
            let segment = try buildSegment(data)
            segments.append(segment)
        }

        return try HL7v2Message(segments: segments, encodingCharacters: encodingCharacters)
    }

    // MARK: - Private Helpers

    /// Build a BaseSegment from internal segment data
    private func buildSegment(_ data: SegmentData) throws -> BaseSegment {
        // Find max field index
        let maxIndex = data.fields.keys.max() ?? 0
        var fields: [Field] = []

        if data.segmentID == "MSH" {
            // MSH-1 is the field separator
            let msh1 = Field.parse(String(encodingCharacters.fieldSeparator), encodingCharacters: encodingCharacters)
            fields.append(msh1)

            // MSH-2 is the encoding characters (special handling)
            let encString = encodingCharacters.toEncodingString()
            let encodingSub = Subcomponent(rawValue: encString, encodingCharacters: encodingCharacters)
            let encodingComp = Component(subcomponents: [encodingSub], encodingCharacters: encodingCharacters)
            let msh2 = Field(repetitions: [[encodingComp]], encodingCharacters: encodingCharacters)
            fields.append(msh2)

            // MSH-3 onward (field index 3 maps to array position 2)
            for i in 3...max(maxIndex, 2) {
                if let fieldData = data.fields[i] {
                    fields.append(Field.parse(fieldData.rawValue, encodingCharacters: encodingCharacters))
                } else {
                    fields.append(Field(repetitions: [], encodingCharacters: encodingCharacters))
                }
            }
        } else {
            for i in 1...max(maxIndex, 0) {
                if let fieldData = data.fields[i] {
                    fields.append(Field.parse(fieldData.rawValue, encodingCharacters: encodingCharacters))
                } else {
                    fields.append(Field(repetitions: [], encodingCharacters: encodingCharacters))
                }
            }
        }

        return BaseSegment(segmentID: data.segmentID, fields: fields, encodingCharacters: encodingCharacters)
    }
}

// MARK: - SegmentBuilder

/// Builder for constructing individual HL7 v2.x segments
///
/// ```swift
/// let builder = SegmentBuilder(segmentID: "PID", encodingCharacters: .standard)
///     .field(1, value: "1")
///     .field(3, value: "12345^^^Hospital^MR")
///     .field(5, value: "Smith^John^A")
/// ```
public struct SegmentBuilder: Sendable {

    // MARK: - Properties

    private let segmentID: String
    private let encodingCharacters: EncodingCharacters
    private var fields: [Int: HL7v2MessageBuilder.FieldData]

    // MARK: - Initialization

    /// Creates a segment builder
    /// - Parameters:
    ///   - segmentID: Segment identifier
    ///   - encodingCharacters: Encoding characters to use
    public init(segmentID: String, encodingCharacters: EncodingCharacters = .standard) {
        self.segmentID = segmentID
        self.encodingCharacters = encodingCharacters
        self.fields = [:]
    }

    // MARK: - Field Methods

    /// Set a field value by index (1-based, matching HL7 field numbering)
    /// - Parameters:
    ///   - index: Field index (1-based)
    ///   - value: Field value as a string
    /// - Returns: Updated builder
    public func field(_ index: Int, value: String) -> SegmentBuilder {
        var copy = self
        copy.fields[index] = HL7v2MessageBuilder.FieldData(rawValue: value)
        return copy
    }

    /// Set a field value with components
    /// - Parameters:
    ///   - index: Field index (1-based)
    ///   - components: Component values
    /// - Returns: Updated builder
    public func field(_ index: Int, components: [String]) -> SegmentBuilder {
        let value = components.joined(separator: String(encodingCharacters.componentSeparator))
        return field(index, value: value)
    }

    /// Set a field value with components and subcomponents
    /// - Parameters:
    ///   - index: Field index (1-based)
    ///   - components: Array of arrays of subcomponent values
    /// - Returns: Updated builder
    public func field(_ index: Int, components: [[String]]) -> SegmentBuilder {
        let value = components.map { subcomponents in
            subcomponents.joined(separator: String(encodingCharacters.subcomponentSeparator))
        }.joined(separator: String(encodingCharacters.componentSeparator))
        return field(index, value: value)
    }

    /// Set a field value with repetitions
    /// - Parameters:
    ///   - index: Field index (1-based)
    ///   - repetitions: Array of repetition values
    /// - Returns: Updated builder
    public func field(_ index: Int, repetitions: [String]) -> SegmentBuilder {
        let value = repetitions.joined(separator: String(encodingCharacters.repetitionSeparator))
        return field(index, value: value)
    }

    // MARK: - Internal

    /// Convert to internal segment data
    func toSegmentData() -> HL7v2MessageBuilder.SegmentData {
        return HL7v2MessageBuilder.SegmentData(segmentID: segmentID, fields: fields)
    }
}

// MARK: - MSHSegmentBuilder

/// Specialized builder for MSH (Message Header) segments
///
/// Provides named methods for common MSH fields:
/// - MSH-3: Sending Application
/// - MSH-4: Sending Facility
/// - MSH-5: Receiving Application
/// - MSH-6: Receiving Facility
/// - MSH-7: Date/Time of Message
/// - MSH-9: Message Type
/// - MSH-10: Message Control ID
/// - MSH-11: Processing ID
/// - MSH-12: Version ID
public struct MSHSegmentBuilder: Sendable {

    // MARK: - Properties

    private let encodingCharacters: EncodingCharacters
    private var fields: [Int: HL7v2MessageBuilder.FieldData]

    // MARK: - Initialization

    /// Creates an MSH segment builder
    /// - Parameter encodingCharacters: Encoding characters to use
    public init(encodingCharacters: EncodingCharacters = .standard) {
        self.encodingCharacters = encodingCharacters
        self.fields = [:]
    }

    // MARK: - Named Field Methods

    /// Set the sending application (MSH-3)
    /// - Parameter value: Sending application name
    /// - Returns: Updated builder
    public func sendingApplication(_ value: String) -> MSHSegmentBuilder {
        return setField(3, value: value)
    }

    /// Set the sending facility (MSH-4)
    /// - Parameter value: Sending facility name
    /// - Returns: Updated builder
    public func sendingFacility(_ value: String) -> MSHSegmentBuilder {
        return setField(4, value: value)
    }

    /// Set the receiving application (MSH-5)
    /// - Parameter value: Receiving application name
    /// - Returns: Updated builder
    public func receivingApplication(_ value: String) -> MSHSegmentBuilder {
        return setField(5, value: value)
    }

    /// Set the receiving facility (MSH-6)
    /// - Parameter value: Receiving facility name
    /// - Returns: Updated builder
    public func receivingFacility(_ value: String) -> MSHSegmentBuilder {
        return setField(6, value: value)
    }

    /// Set the date/time of message (MSH-7)
    /// - Parameter value: Date/time string (HL7 format: YYYYMMDDHHMMSS)
    /// - Returns: Updated builder
    public func dateTime(_ value: String) -> MSHSegmentBuilder {
        return setField(7, value: value)
    }

    /// Set the date/time of message (MSH-7) from a Date object
    /// - Parameter date: Date to use
    /// - Returns: Updated builder
    public func dateTime(_ date: Date) -> MSHSegmentBuilder {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return setField(7, value: formatter.string(from: date))
    }

    /// Set the security field (MSH-8)
    /// - Parameter value: Security value
    /// - Returns: Updated builder
    public func security(_ value: String) -> MSHSegmentBuilder {
        return setField(8, value: value)
    }

    /// Set the message type (MSH-9)
    /// - Parameters:
    ///   - type: Message type (e.g., "ADT")
    ///   - triggerEvent: Trigger event (e.g., "A01")
    /// - Returns: Updated builder
    public func messageType(_ type: String, triggerEvent: String) -> MSHSegmentBuilder {
        let value = "\(type)\(encodingCharacters.componentSeparator)\(triggerEvent)"
        return setField(9, value: value)
    }

    /// Set the message type (MSH-9) with message structure
    /// - Parameters:
    ///   - type: Message type (e.g., "ADT")
    ///   - triggerEvent: Trigger event (e.g., "A01")
    ///   - messageStructure: Message structure (e.g., "ADT_A01")
    /// - Returns: Updated builder
    public func messageType(_ type: String, triggerEvent: String, messageStructure: String) -> MSHSegmentBuilder {
        let sep = String(encodingCharacters.componentSeparator)
        let value = "\(type)\(sep)\(triggerEvent)\(sep)\(messageStructure)"
        return setField(9, value: value)
    }

    /// Set the message control ID (MSH-10)
    /// - Parameter value: Message control ID
    /// - Returns: Updated builder
    public func messageControlID(_ value: String) -> MSHSegmentBuilder {
        return setField(10, value: value)
    }

    /// Set the processing ID (MSH-11)
    /// - Parameter value: Processing ID (e.g., "P" for production, "T" for test)
    /// - Returns: Updated builder
    public func processingID(_ value: String) -> MSHSegmentBuilder {
        return setField(11, value: value)
    }

    /// Set the version ID (MSH-12)
    /// - Parameter value: HL7 version (e.g., "2.5.1")
    /// - Returns: Updated builder
    public func version(_ value: String) -> MSHSegmentBuilder {
        return setField(12, value: value)
    }

    /// Set a field by index (1-based, but note MSH-1 and MSH-2 are auto-generated)
    /// - Parameters:
    ///   - index: Field index (3-based for user fields; 1 and 2 are auto-generated)
    ///   - value: Field value
    /// - Returns: Updated builder
    public func field(_ index: Int, value: String) -> MSHSegmentBuilder {
        return setField(index, value: value)
    }

    // MARK: - Private Helpers

    private func setField(_ index: Int, value: String) -> MSHSegmentBuilder {
        var copy = self
        copy.fields[index] = HL7v2MessageBuilder.FieldData(rawValue: value)
        return copy
    }

    // MARK: - Internal

    /// Convert to internal segment data
    func toSegmentData() -> HL7v2MessageBuilder.SegmentData {
        return HL7v2MessageBuilder.SegmentData(segmentID: "MSH", fields: fields)
    }
}

// MARK: - Message Templates

/// Predefined message templates for common HL7 v2.x message types
public enum MessageTemplate: Sendable {

    /// ADT (Admit/Discharge/Transfer) message template
    /// - Parameters:
    ///   - triggerEvent: Trigger event (e.g., "A01" for admit, "A02" for transfer, "A03" for discharge)
    ///   - sendingApp: Sending application name
    ///   - sendingFacility: Sending facility name
    ///   - receivingApp: Receiving application name
    ///   - receivingFacility: Receiving facility name
    ///   - controlID: Message control ID
    ///   - version: HL7 version (default "2.5.1")
    /// - Returns: Preconfigured message builder
    public static func adt(
        triggerEvent: String,
        sendingApp: String = "",
        sendingFacility: String = "",
        receivingApp: String = "",
        receivingFacility: String = "",
        controlID: String = "",
        version: String = "2.5.1"
    ) -> HL7v2MessageBuilder {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateTime = dateFormatter.string(from: Date())

        return HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility(sendingFacility)
                   .receivingApplication(receivingApp)
                   .receivingFacility(receivingFacility)
                   .dateTime(dateTime)
                   .messageType("ADT", triggerEvent: triggerEvent)
                   .messageControlID(controlID)
                   .processingID("P")
                   .version(version)
            }
    }

    /// ORU (Observation Result) message template
    /// - Parameters:
    ///   - sendingApp: Sending application name
    ///   - sendingFacility: Sending facility name
    ///   - receivingApp: Receiving application name
    ///   - receivingFacility: Receiving facility name
    ///   - controlID: Message control ID
    ///   - version: HL7 version (default "2.5.1")
    /// - Returns: Preconfigured message builder
    public static func oru(
        sendingApp: String = "",
        sendingFacility: String = "",
        receivingApp: String = "",
        receivingFacility: String = "",
        controlID: String = "",
        version: String = "2.5.1"
    ) -> HL7v2MessageBuilder {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateTime = dateFormatter.string(from: Date())

        return HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility(sendingFacility)
                   .receivingApplication(receivingApp)
                   .receivingFacility(receivingFacility)
                   .dateTime(dateTime)
                   .messageType("ORU", triggerEvent: "R01")
                   .messageControlID(controlID)
                   .processingID("P")
                   .version(version)
            }
    }

    /// ORM (Order) message template
    /// - Parameters:
    ///   - sendingApp: Sending application name
    ///   - sendingFacility: Sending facility name
    ///   - receivingApp: Receiving application name
    ///   - receivingFacility: Receiving facility name
    ///   - controlID: Message control ID
    ///   - version: HL7 version (default "2.5.1")
    /// - Returns: Preconfigured message builder
    public static func orm(
        sendingApp: String = "",
        sendingFacility: String = "",
        receivingApp: String = "",
        receivingFacility: String = "",
        controlID: String = "",
        version: String = "2.5.1"
    ) -> HL7v2MessageBuilder {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateTime = dateFormatter.string(from: Date())

        return HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility(sendingFacility)
                   .receivingApplication(receivingApp)
                   .receivingFacility(receivingFacility)
                   .dateTime(dateTime)
                   .messageType("ORM", triggerEvent: "O01")
                   .messageControlID(controlID)
                   .processingID("P")
                   .version(version)
            }
    }

    /// ACK (Acknowledgment) message template
    /// - Parameters:
    ///   - originalMessage: The original message being acknowledged
    ///   - ackCode: Acknowledgment code ("AA" = accept, "AE" = error, "AR" = reject)
    ///   - sendingApp: Sending application name
    ///   - sendingFacility: Sending facility name
    ///   - controlID: Message control ID for the ACK
    ///   - textMessage: Optional text message
    ///   - version: HL7 version (default "2.5.1")
    /// - Returns: Preconfigured message builder
    public static func ack(
        originalMessage: HL7v2Message,
        ackCode: String = "AA",
        sendingApp: String = "",
        sendingFacility: String = "",
        controlID: String = "",
        textMessage: String? = nil,
        version: String = "2.5.1"
    ) -> HL7v2MessageBuilder {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateTime = dateFormatter.string(from: Date())

        let originalControlID = originalMessage.messageControlID()

        // Swap sending/receiving from original message
        let origMSH = originalMessage.messageHeader
        let recvApp = origMSH[2].value.value.raw
        let recvFac = origMSH[3].value.value.raw

        return HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility(sendingFacility)
                   .receivingApplication(recvApp)
                   .receivingFacility(recvFac)
                   .dateTime(dateTime)
                   .messageType("ACK", triggerEvent: "")
                   .messageControlID(controlID)
                   .processingID("P")
                   .version(version)
            }
            .segment("MSA") { seg in
                var msaBuilder = seg.field(1, value: ackCode)
                                    .field(2, value: originalControlID)
                if let text = textMessage {
                    msaBuilder = msaBuilder.field(3, value: text)
                }
                return msaBuilder
            }
    }
}

// MARK: - Convenience Extensions on HL7v2Message

extension HL7v2Message {

    /// Create a new message builder
    /// - Parameter encodingCharacters: Encoding characters to use
    /// - Returns: New message builder
    public static func builder(encodingCharacters: EncodingCharacters = .standard) -> HL7v2MessageBuilder {
        return HL7v2MessageBuilder(encodingCharacters: encodingCharacters)
    }
}
