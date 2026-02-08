/// Tests for batch and file processing support
///
/// Tests for FHS, BHS, FTS, BTS segments and batch/file message containers

import XCTest
@testable import HL7v2Kit
@testable import HL7Core

final class BatchFileProcessingTests: XCTestCase {
    
    var parser: HL7v2Parser!
    
    override func setUp() async throws {
        parser = HL7v2Parser()
    }
    
    // MARK: - FHS Segment Tests
    
    func testFHSSegmentParsing() throws {
        let fhsString = "FHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000||TestFile|File comment|FC12345|RC12345"
        let fhs = try FHSSegment.parse(fhsString)
        
        XCTAssertEqual(fhs.segmentID, "FHS")
        XCTAssertEqual(fhs.fileFieldSeparator, "|")
        XCTAssertEqual(fhs.fileEncodingCharacters, "^~\\&")
        XCTAssertEqual(fhs.fileSendingApplication, "SendApp")
        XCTAssertEqual(fhs.fileSendingFacility, "SendFac")
        XCTAssertEqual(fhs.fileReceivingApplication, "RecvApp")
        XCTAssertEqual(fhs.fileReceivingFacility, "RecvFac")
        XCTAssertEqual(fhs.fileCreationDateTime, "20240101120000")
        XCTAssertEqual(fhs.fileNameID, "TestFile")
        XCTAssertEqual(fhs.fileHeaderComment, "File comment")
        XCTAssertEqual(fhs.fileControlID, "FC12345")
        XCTAssertEqual(fhs.referenceFileControlID, "RC12345")
    }
    
    func testFHSSegmentSerialization() throws {
        let fhsString = "FHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000"
        let fhs = try FHSSegment.parse(fhsString)
        let serialized = try fhs.serialize()
        
        XCTAssertTrue(serialized.hasPrefix("FHS|^~\\&"))
        XCTAssertTrue(serialized.contains("SendApp"))
    }
    
    // MARK: - FTS Segment Tests
    
    func testFTSSegmentParsing() throws {
        let ftsString = "FTS|3|End of file"
        let fts = try FTSSegment.parse(ftsString)
        
        XCTAssertEqual(fts.segmentID, "FTS")
        XCTAssertEqual(fts.fileBatchCount, 3)
        XCTAssertEqual(fts.fileTrailerComment, "End of file")
    }
    
    func testFTSSegmentSerialization() throws {
        let ftsString = "FTS|5|Complete"
        let fts = try FTSSegment.parse(ftsString)
        let serialized = try fts.serialize()
        
        XCTAssertEqual(serialized, ftsString)
    }
    
    // MARK: - BHS Segment Tests
    
    func testBHSSegmentParsing() throws {
        let bhsString = "BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130000||Batch1|Batch comment|BC12345|RB12345"
        let bhs = try BHSSegment.parse(bhsString)
        
        XCTAssertEqual(bhs.segmentID, "BHS")
        XCTAssertEqual(bhs.batchFieldSeparator, "|")
        XCTAssertEqual(bhs.batchEncodingCharacters, "^~\\&")
        XCTAssertEqual(bhs.batchSendingApplication, "SendApp")
        XCTAssertEqual(bhs.batchSendingFacility, "SendFac")
        XCTAssertEqual(bhs.batchReceivingApplication, "RecvApp")
        XCTAssertEqual(bhs.batchReceivingFacility, "RecvFac")
        XCTAssertEqual(bhs.batchCreationDateTime, "20240101130000")
        XCTAssertEqual(bhs.batchNameIDType, "Batch1")
        XCTAssertEqual(bhs.batchComment, "Batch comment")
        XCTAssertEqual(bhs.batchControlID, "BC12345")
        XCTAssertEqual(bhs.referenceBatchControlID, "RB12345")
    }
    
    func testBHSSegmentSerialization() throws {
        let bhsString = "BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac"
        let bhs = try BHSSegment.parse(bhsString)
        let serialized = try bhs.serialize()
        
        XCTAssertTrue(serialized.hasPrefix("BHS|^~\\&"))
        XCTAssertTrue(serialized.contains("SendApp"))
    }
    
    // MARK: - BTS Segment Tests
    
    func testBTSSegmentParsing() throws {
        let btsString = "BTS|10|Batch complete"
        let bts = try BTSSegment.parse(btsString)
        
        XCTAssertEqual(bts.segmentID, "BTS")
        XCTAssertEqual(bts.batchMessageCount, 10)
        XCTAssertEqual(bts.batchComment, "Batch complete")
    }
    
    func testBTSSegmentSerialization() throws {
        let btsString = "BTS|25|Done"
        let bts = try BTSSegment.parse(btsString)
        let serialized = try bts.serialize()
        
        XCTAssertEqual(serialized, btsString)
    }
    
    // MARK: - Batch Message Tests
    
    func testBatchMessageParsing() throws {
        let batchString = """
        BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130000
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130001||ADT^A01|MSG001|P|2.5
        PID|1||12345||Doe^John
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130002||ADT^A01|MSG002|P|2.5
        PID|1||67890||Smith^Jane
        BTS|2|Batch complete
        """
        
        let batch = try parser.parseBatch(batchString)
        
        XCTAssertEqual(batch.header.segmentID, "BHS")
        XCTAssertEqual(batch.messages.count, 2)
        XCTAssertEqual(batch.trailer.batchMessageCount, 2)
        XCTAssertTrue(batch.validate())
    }
    
    func testBatchMessageValidation() throws {
        let bhsString = "BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac"
        let bhs = try BHSSegment.parse(bhsString)
        
        let mshString = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5"
        let parseResult = try parser.parse(mshString)
        let messages = [parseResult.message]
        
        let btsString = "BTS|1"
        let bts = try BTSSegment.parse(btsString)
        
        let batch = BatchMessage(header: bhs, messages: messages, trailer: bts)
        
        XCTAssertTrue(batch.validate())
    }
    
    func testBatchMessageSerializeAndParse() throws {
        let bhsString = "BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac"
        let bhs = try BHSSegment.parse(bhsString)
        
        let mshString = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5"
        let parseResult = try parser.parse(mshString)
        let messages = [parseResult.message]
        
        let btsString = "BTS|1"
        let bts = try BTSSegment.parse(btsString)
        
        let batch = BatchMessage(header: bhs, messages: messages, trailer: bts)
        let serialized = try batch.serialize()
        
        // Parse it back
        let parsedBatch = try parser.parseBatch(serialized)
        XCTAssertEqual(parsedBatch.messages.count, 1)
    }
    
    // MARK: - File Message Tests
    
    func testFileMessageParsing() throws {
        let fileString = """
        FHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000
        BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130000
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130001||ADT^A01|MSG001|P|2.5
        PID|1||12345||Doe^John
        BTS|1|Batch complete
        FTS|1|File complete
        """
        
        let file = try parser.parseFile(fileString)
        
        XCTAssertEqual(file.header.segmentID, "FHS")
        XCTAssertEqual(file.batches.count, 1)
        XCTAssertEqual(file.batches[0].messages.count, 1)
        XCTAssertEqual(file.trailer.fileBatchCount, 1)
        XCTAssertTrue(file.validate())
    }
    
    func testFileMessageWithIndividualMessages() throws {
        let fileString = """
        FHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130001||ADT^A01|MSG001|P|2.5
        PID|1||12345||Doe^John
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130002||ADT^A01|MSG002|P|2.5
        PID|1||67890||Smith^Jane
        FTS|2|File complete
        """
        
        let file = try parser.parseFile(fileString)
        
        XCTAssertEqual(file.header.segmentID, "FHS")
        XCTAssertEqual(file.batches.count, 0)
        XCTAssertEqual(file.messages.count, 2)
        XCTAssertEqual(file.trailer.fileBatchCount, 2)
        XCTAssertTrue(file.validate())
    }
    
    func testFileMessageSerialization() throws {
        let fhsString = "FHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac"
        let fhs = try FHSSegment.parse(fhsString)
        
        let ftsString = "FTS|0"
        let fts = try FTSSegment.parse(ftsString)
        
        let file = FileMessage(header: fhs, batches: [], messages: [], trailer: fts)
        let serialized = try file.serialize()
        
        XCTAssertTrue(serialized.contains("FHS|^~\\&"))
        XCTAssertTrue(serialized.contains("FTS|0"))
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidBatchMissingBHS() throws {
        let invalidBatch = """
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5
        BTS|1
        """
        
        XCTAssertThrowsError(try parser.parseBatch(invalidBatch)) { error in
            XCTAssertTrue(error is HL7Error)
        }
    }
    
    func testInvalidBatchMissingBTS() throws {
        let invalidBatch = """
        BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5
        """
        
        XCTAssertThrowsError(try parser.parseBatch(invalidBatch)) { error in
            XCTAssertTrue(error is HL7Error)
        }
    }
    
    func testInvalidFileMissingFHS() throws {
        let invalidFile = """
        BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac
        BTS|0
        FTS|1
        """
        
        XCTAssertThrowsError(try parser.parseFile(invalidFile)) { error in
            XCTAssertTrue(error is HL7Error)
        }
    }
    
    func testInvalidFileMissingFTS() throws {
        let invalidFile = """
        FHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac
        BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac
        BTS|0
        """
        
        XCTAssertThrowsError(try parser.parseFile(invalidFile)) { error in
            XCTAssertTrue(error is HL7Error)
        }
    }
}
