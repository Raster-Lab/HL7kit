/// Test utilities and message generators for HL7 v2.x messages
///
/// Provides utilities for generating test messages, mocking components,
/// and creating test data for unit tests.

import Foundation
import HL7Core

// MARK: - Test Message Generator

/// Generator for creating test HL7 messages
public struct TestMessageGenerator {
    /// Generate a simple ADT^A01 (Admit) message
    /// - Parameters:
    ///   - patientID: Patient ID (default "12345")
    ///   - patientName: Patient name in format "LastName^FirstName" (default "Doe^John")
    ///   - sendingApp: Sending application (default "TestApp")
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Generated ADT^A01 message
    public static func generateADTA01(
        patientID: String = "12345",
        patientName: String = "Doe^John",
        sendingApp: String = "TestApp",
        encodingCharacters: EncodingCharacters = .standard
    ) throws -> HL7v2Message {
        return try HL7v2MessageBuilder(encodingCharacters: encodingCharacters)
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility("TestFacility")
                   .receivingApplication("RecvApp")
                   .receivingFacility("RecvFacility")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID(UUID().uuidString)
                   .version("2.5.1")
            }
            .segment("EVN") { segment in
                segment
                    .field(1, value: "A01")
                    .field(2, value: dateTimeString())
            }
            .segment("PID") { segment in
                segment
                    .field(1, value: "1")
                    .field(2, value: patientID)
                    .field(3, value: patientID)
                    .field(5, value: patientName)
            }
            .segment("PV1") { segment in
                segment
                    .field(1, value: "1")
                    .field(2, value: "I")
                    .field(3, value: "ER^Emergency^1")
            }
            .build()
    }
    
    /// Generate an ORU^R01 (Observation Result) message
    /// - Parameters:
    ///   - patientID: Patient ID (default "12345")
    ///   - observations: Array of (identifier, value) tuples for observations
    ///   - sendingApp: Sending application (default "TestLab")
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Generated ORU^R01 message
    public static func generateORUR01(
        patientID: String = "12345",
        observations: [(identifier: String, value: String)] = [("GLU", "95"), ("NA", "140")],
        sendingApp: String = "TestLab",
        encodingCharacters: EncodingCharacters = .standard
    ) throws -> HL7v2Message {
        let builder = HL7v2MessageBuilder(encodingCharacters: encodingCharacters)
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility("TestLab")
                   .receivingApplication("RecvApp")
                   .receivingFacility("RecvFacility")
                   .messageType("ORU", triggerEvent: "R01")
                   .messageControlID(UUID().uuidString)
                   .version("2.5.1")
            }
            .segment("PID") { segment in
                segment
                    .field(1, value: "1")
                    .field(2, value: patientID)
                    .field(3, value: patientID)
            }
            .segment("OBR") { segment in
                segment
                    .field(1, value: "1")
                    .field(2, value: "ORDER001")
                    .field(3, value: "FILLER001")
                    .field(4, value: "LAB^Laboratory Test")
            }
        
        // Add OBX segments for each observation
        var msgBuilder = builder
        for (index, obs) in observations.enumerated() {
            msgBuilder = msgBuilder.segment("OBX") { segment in
                segment
                    .field(1, value: String(index + 1))
                    .field(2, value: "NM")
                    .field(3, value: obs.identifier)
                    .field(5, value: obs.value)
                    .field(11, value: "F")
            }
        }
        
        return try msgBuilder.build()
    }
    
    /// Generate an ORM^O01 (Order) message
    /// - Parameters:
    ///   - patientID: Patient ID (default "12345")
    ///   - orderID: Order ID (default "ORD123")
    ///   - serviceID: Service identifier (default "LAB^Blood Test")
    ///   - sendingApp: Sending application (default "TestApp")
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Generated ORM^O01 message
    public static func generateORMO01(
        patientID: String = "12345",
        orderID: String = "ORD123",
        serviceID: String = "LAB^Blood Test",
        sendingApp: String = "TestApp",
        encodingCharacters: EncodingCharacters = .standard
    ) throws -> HL7v2Message {
        return try HL7v2MessageBuilder(encodingCharacters: encodingCharacters)
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility("TestFacility")
                   .receivingApplication("RecvApp")
                   .receivingFacility("RecvFacility")
                   .messageType("ORM", triggerEvent: "O01")
                   .messageControlID(UUID().uuidString)
                   .version("2.5.1")
            }
            .segment("PID") { segment in
                segment
                    .field(1, value: "1")
                    .field(2, value: patientID)
                    .field(3, value: patientID)
            }
            .segment("ORC") { segment in
                segment
                    .field(1, value: "NW")
                    .field(2, value: orderID)
                    .field(3, value: orderID + "-F")
            }
            .segment("OBR") { segment in
                segment
                    .field(1, value: "1")
                    .field(2, value: orderID)
                    .field(3, value: orderID + "-F")
                    .field(4, value: serviceID)
                    .field(6, value: dateTimeString())
            }
            .build()
    }
    
    /// Generate an ACK (Acknowledgment) message
    /// - Parameters:
    ///   - originalMessageControlID: Control ID of original message
    ///   - acknowledgmentCode: ACK code (AA=Accept, AE=Error, AR=Reject)
    ///   - textMessage: Optional text message
    ///   - sendingApp: Sending application (default "TestApp")
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Generated ACK message
    public static func generateACK(
        originalMessageControlID: String,
        acknowledgmentCode: String = "AA",
        textMessage: String? = nil,
        sendingApp: String = "TestApp",
        encodingCharacters: EncodingCharacters = .standard
    ) throws -> HL7v2Message {
        let msgBuilder = HL7v2MessageBuilder(encodingCharacters: encodingCharacters)
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility("TestFacility")
                   .receivingApplication("RecvApp")
                   .receivingFacility("RecvFacility")
                   .messageType("ACK", triggerEvent: "A01")
                   .messageControlID(UUID().uuidString)
                   .version("2.5.1")
            }
            .segment("MSA") { segment in
                var seg = segment
                    .field(1, value: acknowledgmentCode)
                    .field(2, value: originalMessageControlID)
                
                if let text = textMessage {
                    seg = seg.field(3, value: text)
                }
                
                return seg
            }
        
        return try msgBuilder.build()
    }
    
    /// Generate a batch of messages
    /// - Parameters:
    ///   - messageCount: Number of messages to generate
    ///   - messageGenerator: Closure that generates a message given an index
    /// - Returns: Array of generated messages
    public static func generateBatch(
        count messageCount: Int,
        using messageGenerator: (Int) throws -> HL7v2Message
    ) rethrows -> [HL7v2Message] {
        try (0..<messageCount).map { try messageGenerator($0) }
    }
    
    /// Generate a message with random data for stress testing
    /// - Parameters:
    ///   - segmentCount: Number of segments (default 10)
    ///   - fieldsPerSegment: Average number of fields per segment (default 5)
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Generated message with random data
    public static func generateRandomMessage(
        segmentCount: Int = 10,
        fieldsPerSegment: Int = 5,
        encodingCharacters: EncodingCharacters = .standard
    ) throws -> HL7v2Message {
        let builder = HL7v2MessageBuilder(encodingCharacters: encodingCharacters)
            .msh { msh in
                msh.sendingApplication("TestApp")
                   .sendingFacility("TestFacility")
                   .receivingApplication("RecvApp")
                   .receivingFacility("RecvFacility")
                   .messageType("XXX", triggerEvent: "X01")
                   .messageControlID(UUID().uuidString)
                   .version("2.5.1")
            }
        
        let segmentIDs = ["ZZ1", "ZZ2", "ZZ3", "ZZ4", "ZZ5"]
        var msgBuilder = builder
        
        for i in 0..<segmentCount {
            let segmentID = segmentIDs[i % segmentIDs.count]
            msgBuilder = msgBuilder.segment(segmentID) { segment in
                var seg = segment
                let fieldCount = fieldsPerSegment + Int.random(in: -2...2)
                for fieldIndex in 0..<fieldCount {
                    seg = seg.field(fieldIndex + 1, value: randomString(length: 10))
                }
                return seg
            }
        }
        
        return try msgBuilder.build()
    }
    
    // MARK: - Helper Methods
    
    /// Get current date/time in HL7 format (YYYYMMDDHHmmss)
    private static func dateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }
    
    /// Generate a random string of specified length
    private static func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}

// MARK: - Mock Objects

/// Mock segment for testing
public struct MockSegment: HL7v2Segment, Equatable {
    public let segmentID: String
    public let fields: [Field]
    public let encodingCharacters: EncodingCharacters
    
    public init(
        segmentID: String = "TST",
        fields: [String] = [],
        encodingCharacters: EncodingCharacters = .standard
    ) {
        self.segmentID = segmentID
        self.encodingCharacters = encodingCharacters
        self.fields = fields.map { value in
            Field.parse(value, encodingCharacters: encodingCharacters)
        }
    }
    
    public subscript(index: Int) -> Field {
        guard index >= 0 && index < fields.count else {
            return Field(repetitions: [], encodingCharacters: encodingCharacters)
        }
        return fields[index]
    }
    
    public func serialize() throws -> String {
        var result = segmentID
        for field in fields {
            result += String(encodingCharacters.fieldSeparator)
            result += field.serialize()
        }
        return result
    }
    
    public static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters) throws -> MockSegment {
        let baseSegment = try BaseSegment.parse(rawValue, encodingCharacters: encodingCharacters)
        let fieldStrings = baseSegment.fields.map { $0.serialize() }
        return MockSegment(segmentID: baseSegment.segmentID, fields: fieldStrings, encodingCharacters: encodingCharacters)
    }
}

/// Mock message parser for testing
public class MockParser {
    public var shouldSucceed: Bool = true
    public var parseCount: Int = 0
    public var lastParsedData: String?
    
    public init() {}
    
    public func parse(_ data: String) throws -> HL7v2Message {
        parseCount += 1
        lastParsedData = data
        
        guard shouldSucceed else {
            throw HL7Error.parsingError("Mock parse failure")
        }
        
        // Return a simple test message
        return try TestMessageGenerator.generateADTA01()
    }
    
    public func reset() {
        parseCount = 0
        lastParsedData = nil
        shouldSucceed = true
    }
}

/// Mock validator for testing
public struct MockValidator {
    public var validationResult: ValidationResult
    
    public init(result: ValidationResult = .valid) {
        self.validationResult = result
    }
    
    public func validate(_ message: HL7v2Message) -> ValidationResult {
        return validationResult
    }
}

// MARK: - Test Data Builder

/// Builder for creating test data
public struct TestDataBuilder {
    /// Create a test patient ID
    /// - Parameter prefix: Prefix for ID (default "TEST")
    /// - Returns: Generated patient ID
    public static func patientID(prefix: String = "TEST") -> String {
        "\(prefix)\(Int.random(in: 10000...99999))"
    }
    
    /// Create a test patient name
    /// - Parameters:
    ///   - lastName: Last name (default random)
    ///   - firstName: First name (default random)
    /// - Returns: Patient name in HL7 format
    public static func patientName(lastName: String? = nil, firstName: String? = nil) -> String {
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
        let firstNames = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda"]
        
        let last = lastName ?? lastNames.randomElement()!
        let first = firstName ?? firstNames.randomElement()!
        
        return "\(last)^\(first)"
    }
    
    /// Create a test date in HL7 format
    /// - Parameter daysAgo: Number of days in the past (default 0 for today)
    /// - Returns: Date string in HL7 format (YYYYMMDD)
    public static func date(daysAgo: Int = 0) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
    
    /// Create a test timestamp in HL7 format
    /// - Parameter minutesAgo: Number of minutes in the past (default 0 for now)
    /// - Returns: Timestamp string in HL7 format (YYYYMMDDHHmmss)
    public static func timestamp(minutesAgo: Int = 0) -> String {
        let date = Calendar.current.date(byAdding: .minute, value: -minutesAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: date)
    }
    
    /// Create a test observation value
    /// - Parameters:
    ///   - identifier: Observation identifier (e.g., "GLU", "NA")
    ///   - value: Observation value
    ///   - unit: Unit of measurement (optional)
    /// - Returns: Formatted observation identifier string
    public static func observation(identifier: String, value: String, unit: String? = nil) -> String {
        if let unit = unit {
            return "\(identifier)^^\(value)^\(unit)"
        } else {
            return "\(identifier)^^\(value)"
        }
    }
}

// MARK: - Performance Test Helpers

/// Utilities for performance testing
public struct PerformanceTestHelpers {
    /// Measure execution time of a block
    /// - Parameter block: Block to measure
    /// - Returns: Execution time in seconds
    public static func measureTime(_ block: () throws -> Void) rethrows -> TimeInterval {
        let start = Date()
        try block()
        return Date().timeIntervalSince(start)
    }
    
    /// Measure average execution time over multiple iterations
    /// - Parameters:
    ///   - iterations: Number of iterations (default 100)
    ///   - block: Block to measure
    /// - Returns: Average execution time in seconds
    public static func measureAverage(iterations: Int = 100, _ block: () throws -> Void) rethrows -> TimeInterval {
        var totalTime: TimeInterval = 0
        for _ in 0..<iterations {
            totalTime += try measureTime(block)
        }
        return totalTime / Double(iterations)
    }
    
    /// Measure throughput (operations per second)
    /// - Parameters:
    ///   - duration: Test duration in seconds (default 5)
    ///   - block: Block to measure
    /// - Returns: Operations per second
    public static func measureThroughput(duration: TimeInterval = 5.0, _ block: () throws -> Void) rethrows -> Double {
        let startTime = Date()
        var iterations = 0
        
        while Date().timeIntervalSince(startTime) < duration {
            try block()
            iterations += 1
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return Double(iterations) / elapsed
    }
}
