import XCTest
@testable import HL7Core
@testable import HL7v2Kit
@testable import HL7v3Kit
@testable import FHIRkit

/// Tests for platform-specific example code (iOS and macOS)
final class PlatformExamplesTests: XCTestCase {
    
    // MARK: - iOS Examples Tests
    
    #if canImport(UIKit) && !os(watchOS)
    
    @available(iOS 10.0, *)
    func testNotificationManagerCreation() async throws {
        // Test that NotificationManager can be created
        let manager = NotificationManager.shared
        XCTAssertNotNil(manager)
    }
    
    @available(iOS 13.0, *)
    func testBackgroundMessageProcessorRegistration() {
        // Test that BackgroundMessageProcessor can be created
        let processor = BackgroundMessageProcessor.shared
        XCTAssertNotNil(processor)
        XCTAssertEqual(BackgroundMessageProcessor.taskIdentifier, "com.hl7kit.process-messages")
    }
    
    func testiOSMessageStorageInitialization() async throws {
        // Test that iOSMessageStorage can be initialized
        let storage = try iOSMessageStorage()
        XCTAssertNotNil(storage)
    }
    
    func testiOSMessageStorageSaveAndLoad() async throws {
        let storage = try iOSMessageStorage()
        
        // Create a test message
        let messageString = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||MRN001^^^Hosp^MR||Smith^John
        """
        
        let parser = HL7v2Parser()
        let result = try await parser.parse(messageString)
        let message = result.message
        
        // Save message
        let filename = "test-message-\(UUID().uuidString).hl7"
        try await storage.saveMessage(message, filename: filename)
        
        // Load message back
        let loaded = try await storage.loadMessage(filename: filename)
        XCTAssertEqual(loaded.segmentCount, message.segmentCount)
        XCTAssertEqual(loaded.allSegments.first?.segmentID, "MSH")
        
        // Clean up
        try await storage.deleteMessage(filename: filename)
    }
    
    func testiOSMessageStorageListMessages() async throws {
        let storage = try iOSMessageStorage()
        
        // Save a test message
        let parser = HL7v2Parser()
        let result = try await parser.parse("MSH|^~\\&|App|Fac|App|Fac|20240101||ADT^A01|MSG001|P|2.5.1")
        let message = result.message
        
        let filename = "test-list-\(UUID().uuidString).hl7"
        try await storage.saveMessage(message, filename: filename)
        
        // List messages
        let messages = try await storage.listMessages()
        XCTAssertTrue(messages.contains(filename))
        
        // Clean up
        try await storage.deleteMessage(filename: filename)
    }
    
    @available(iOS 13.0, *)
    func testHL7MessageViewControllerCreation() async throws {
        let parser = HL7v2Parser()
        let result = try await parser.parse("""
        MSH|^~\\&|App|Fac|App|Fac|20240101||ADT^A01|MSG001|P|2.5.1
        PID|1||MRN001^^^Hosp^MR||Smith^John
        """)
        
        let viewController = HL7MessageViewController(message: result.message)
        XCTAssertNotNil(viewController)
        XCTAssertEqual(viewController.title, "HL7 Message")
    }
    
    #endif
    
    // MARK: - macOS Examples Tests
    
    #if os(macOS)
    
    @available(macOS 11.0, *)
    func testAppleScriptSupportGeneration() async throws {
        let appleScript = AppleScriptSupport()
        
        let script = appleScript.generateBatchProcessScript(directory: "/test/path")
        XCTAssertTrue(script.contains("/test/path"))
        XCTAssertTrue(script.contains("hl7"))
        XCTAssertTrue(script.contains("validate"))
    }
    
    @available(macOS 11.0, *)
    func testBatchFileProcessorCreation() {
        let processor = BatchFileProcessor()
        XCTAssertNotNil(processor)
    }
    
    @available(macOS 11.0, *)
    func testSpotlightMetadataExtraction() async throws {
        let parser = HL7v2Parser()
        let result = try await parser.parse("""
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||MRN12345^^^Hosp^MR||Doe^John
        """)
        
        let metadata = SpotlightMetadata(from: result.message)
        XCTAssertEqual(metadata.sendingApplication, "SendApp")
        XCTAssertEqual(metadata.messageType, "ADT^A01")
        XCTAssertEqual(metadata.messageControlID, "MSG001")
        XCTAssertEqual(metadata.patientID, "MRN12345^^^Hosp^MR")
    }
    
    @available(macOS 11.0, *)
    func testSpotlightMetadataWithMissingPID() async throws {
        let parser = HL7v2Parser()
        let result = try await parser.parse("""
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000||ADT^A01|MSG001|P|2.5.1
        """)
        
        let metadata = SpotlightMetadata(from: result.message)
        XCTAssertNil(metadata.patientID)
    }
    
    @available(macOS 11.0, *)
    func testCLIIntegrationCreation() {
        let cli = CLIIntegration()
        XCTAssertNotNil(cli)
    }
    
    @available(macOS 11.0, *)
    func testHL7MenuBarManagerCreation() {
        let manager = HL7MenuBarManager()
        XCTAssertNotNil(manager)
    }
    
    @available(macOS 11.0, *)
    func testHL7ServiceProviderCreation() {
        let provider = HL7ServiceProvider()
        XCTAssertNotNil(provider)
    }
    
    @available(macOS 11.0, *)
    func testHL7MessageWindowControllerCreation() async throws {
        let parser = HL7v2Parser()
        let result = try await parser.parse("""
        MSH|^~\\&|App|Fac|App|Fac|20240101||ADT^A01|MSG001|P|2.5.1
        PID|1||MRN001^^^Hosp^MR||Smith^John
        """)
        
        let windowController = HL7MessageWindowController(message: result.message)
        XCTAssertNotNil(windowController)
        XCTAssertNotNil(windowController.window)
        XCTAssertEqual(windowController.window?.title, "HL7 Message Viewer")
    }
    
    @available(macOS 11.0, *)
    func testHL7DocumentCreation() {
        let document = HL7Document()
        XCTAssertNotNil(document)
        XCTAssertTrue(type(of: document).autosavesInPlace)
    }
    
    @available(macOS 11.0, *)
    func testHL7DocumentReadWrite() async throws {
        let document = HL7Document()
        
        let messageString = """
        MSH|^~\\&|App|Fac|App|Fac|20240101||ADT^A01|MSG001|P|2.5.1
        PID|1||MRN001^^^Hosp^MR||Smith^John
        """
        
        let data = messageString.data(using: .utf8)!
        try document.read(from: data, ofType: "org.hl7.v2x")
        
        let writtenData = try document.data(ofType: "org.hl7.v2x")
        XCTAssertFalse(writtenData.isEmpty)
        
        // Parse the written data to verify it's valid
        let parser = HL7v2Parser()
        let result = try await parser.parse(writtenData)
        XCTAssertEqual(result.message.segmentCount, 2)
    }
    
    @available(macOS 11.0, *)
    func testBatchFileProcessorResultStructure() {
        let result = BatchFileProcessor.ProcessingResult(
            totalFiles: 10,
            successCount: 8,
            errorCount: 2,
            errors: ["file1.hl7": NSError(domain: "test", code: 1)],
            processingTime: 1.5
        )
        
        XCTAssertEqual(result.totalFiles, 10)
        XCTAssertEqual(result.successCount, 8)
        XCTAssertEqual(result.errorCount, 2)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.processingTime, 1.5)
    }
    
    #endif
    
    // MARK: - Cross-Platform Tests
    
    func testMessageParsingForPlatformExamples() async throws {
        let parser = HL7v2Parser()
        let result = try await parser.parse("""
        MSH|^~\\&|SendingApp|SendingFac|ReceivingApp|ReceivingFac|20240101120000||ADT^A01|MSG001|P|2.5.1
        EVN||20240101120000
        PID|1||MRN12345^^^Hospital^MR||Doe^John^A||19800115|M|||123 Main St^^Anytown^CA^12345||555-1234
        PV1|1|I|Ward1^Room101^Bed1
        """)
        
        let message = result.message
        XCTAssertEqual(message.segmentCount, 4)
        XCTAssertEqual(message.allSegments[0].segmentID, "MSH")
        XCTAssertEqual(message.allSegments[1].segmentID, "EVN")
        XCTAssertEqual(message.allSegments[2].segmentID, "PID")
        XCTAssertEqual(message.allSegments[3].segmentID, "PV1")
    }
    
    func testFHIRPatientCreationForPlatformExamples() {
        let patient = Patient(
            id: "patient-123",
            identifier: [
                Identifier(
                    system: "http://hospital.example.org/mrn",
                    value: "MRN12345"
                )
            ],
            name: [
                HumanName(
                    family: "Doe",
                    given: ["John", "A"]
                )
            ],
            gender: "male",
            birthDate: "1980-01-15"
        )
        
        XCTAssertEqual(patient.id, "patient-123")
        XCTAssertEqual(patient.identifier?.first?.value, "MRN12345")
        XCTAssertEqual(patient.name?.first?.family, "Doe")
        XCTAssertEqual(patient.name?.first?.given?.first, "John")
        XCTAssertEqual(patient.gender, "male")
        XCTAssertEqual(patient.birthDate, "1980-01-15")
    }
    
    func testMessageValidationForPlatformExamples() async throws {
        let parser = HL7v2Parser()
        let result = try await parser.parse("""
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||MRN001^^^Hosp^MR||Smith^John
        """)
        
        // Should not throw
        try result.message.validate()
        XCTAssertTrue(true)
    }
    
    func testMessageSerializationForPlatformExamples() async throws {
        let parser = HL7v2Parser()
        let result = try await parser.parse("""
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||MRN001^^^Hosp^MR||Smith^John
        """)
        
        let message = result.message
        let serialized = try message.serialize()
        
        XCTAssertFalse(serialized.isEmpty)
        
        // Parse it back
        let reparsedResult = try await parser.parse(serialized)
        XCTAssertEqual(reparsedResult.message.segmentCount, message.segmentCount)
    }
}
