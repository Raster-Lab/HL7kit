/// Tests for compression support
///
/// Tests for message compression and decompression

import XCTest
@testable import HL7v2Kit
@testable import HL7Core

final class CompressionTests: XCTestCase {
    
    let sampleMessage = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000||ADT^A01|MSG001|P|2.5\rPID|1||12345||Doe^John^A||19800101|M|||123 Main St^^Anytown^CA^12345"
    
    // MARK: - Compression Algorithm Tests
    
    func testCompressionAlgorithms() {
        let algorithms: [CompressionAlgorithm] = [.lzfse, .lz4, .zlib, .lzma]
        
        for algorithm in algorithms {
            XCTAssertNotNil(algorithm)
        }
    }
    
    func testCompressionLevels() {
        let levels: [CompressionLevel] = [.fast, .balanced, .best]
        
        for level in levels {
            XCTAssertNotNil(level)
        }
    }
    
    func testDefaultCompressionLevel() {
        XCTAssertEqual(CompressionLevel.default(for: .lz4), .fast)
        XCTAssertEqual(CompressionLevel.default(for: .lzfse), .balanced)
        XCTAssertEqual(CompressionLevel.default(for: .zlib), .balanced)
        XCTAssertEqual(CompressionLevel.default(for: .lzma), .best)
    }
    
    // MARK: - Basic Compression Tests
    
    func testCompressAndDecompress() throws {
        guard let data = sampleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test message")
            return
        }
        
        let compressed = try CompressionUtilities.compress(data, algorithm: .lzfse)
        XCTAssertLessThan(compressed.count, data.count)
        
        let decompressed = try CompressionUtilities.decompress(compressed, algorithm: .lzfse)
        XCTAssertEqual(decompressed, data)
    }
    
    func testCompressString() throws {
        let compressed = try CompressionUtilities.compress(sampleMessage, algorithm: .lzfse)
        XCTAssertGreaterThan(compressed.count, 0)
    }
    
    func testDecompressToString() throws {
        let compressed = try CompressionUtilities.compress(sampleMessage, algorithm: .lzfse)
        let decompressed = try CompressionUtilities.decompressToString(compressed, algorithm: .lzfse)
        
        XCTAssertEqual(decompressed, sampleMessage)
    }
    
    // MARK: - Compression Ratio Tests
    
    func testCompressionRatio() {
        let ratio = CompressionUtilities.compressionRatio(original: 1000, compressed: 500)
        XCTAssertEqual(ratio, 0.5)
    }
    
    func testCompressionRatioWithZeroOriginal() {
        let ratio = CompressionUtilities.compressionRatio(original: 0, compressed: 100)
        XCTAssertEqual(ratio, 0.0)
    }
    
    // MARK: - Algorithm-Specific Tests
    
    func testLZFSECompression() throws {
        guard let data = sampleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test message")
            return
        }
        
        let compressed = try CompressionUtilities.compress(data, algorithm: .lzfse)
        let decompressed = try CompressionUtilities.decompress(compressed, algorithm: .lzfse)
        
        XCTAssertEqual(decompressed, data)
    }
    
    func testLZ4Compression() throws {
        guard let data = sampleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test message")
            return
        }
        
        let compressed = try CompressionUtilities.compress(data, algorithm: .lz4)
        let decompressed = try CompressionUtilities.decompress(compressed, algorithm: .lz4)
        
        XCTAssertEqual(decompressed, data)
    }
    
    func testZLIBCompression() throws {
        guard let data = sampleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test message")
            return
        }
        
        let compressed = try CompressionUtilities.compress(data, algorithm: .zlib)
        let decompressed = try CompressionUtilities.decompress(compressed, algorithm: .zlib)
        
        XCTAssertEqual(decompressed, data)
    }
    
    func testLZMACompression() throws {
        guard let data = sampleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test message")
            return
        }
        
        let compressed = try CompressionUtilities.compress(data, algorithm: .lzma)
        let decompressed = try CompressionUtilities.decompress(compressed, algorithm: .lzma)
        
        XCTAssertEqual(decompressed, data)
    }
    
    // MARK: - Compressed Message Tests
    
    func testCompressedMessageCreation() throws {
        let data = Data([1, 2, 3, 4, 5])
        let compressedMsg = CompressedMessage(data: data, algorithm: .lzfse, originalSize: 100)
        
        XCTAssertEqual(compressedMsg.data, data)
        XCTAssertEqual(compressedMsg.algorithm, .lzfse)
        XCTAssertEqual(compressedMsg.originalSize, 100)
        XCTAssertEqual(compressedMsg.compressedSize, 5)
        XCTAssertEqual(compressedMsg.compressionRatio, 0.05)
    }
    
    // MARK: - HL7v2Message Compression Tests
    
    func testMessageCompress() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(sampleMessage)
        
        let compressedMessage = try result.message.compress(algorithm: .lzfse)
        
        XCTAssertGreaterThan(compressedMessage.compressedSize, 0)
        XCTAssertLessThan(compressedMessage.compressedSize, compressedMessage.originalSize)
        XCTAssertEqual(compressedMessage.algorithm, .lzfse)
    }
    
    func testMessageCompressAndParse() throws {
        let parser = HL7v2Parser()
        let parseResult = try parser.parse(sampleMessage)
        
        let compressedMessage = try parseResult.message.compress(algorithm: .lzfse)
        
        let decompressedMessage = try parser.parseCompressed(compressedMessage)
        
        XCTAssertEqual(decompressedMessage.segments.count, parseResult.message.segments.count)
    }
    
    func testMessageCompressWithDifferentLevels() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(sampleMessage)
        
        let fastCompressed = try result.message.compress(algorithm: .lz4, level: .fast)
        let balancedCompressed = try result.message.compress(algorithm: .lzfse, level: .balanced)
        let bestCompressed = try result.message.compress(algorithm: .lzma, level: .best)
        
        XCTAssertGreaterThan(fastCompressed.compressedSize, 0)
        XCTAssertGreaterThan(balancedCompressed.compressedSize, 0)
        XCTAssertGreaterThan(bestCompressed.compressedSize, 0)
    }
    
    // MARK: - Batch Compression Tests
    
    func testBatchMessageCompress() throws {
        let bhsString = "BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac"
        let bhs = try BHSSegment.parse(bhsString)
        
        let parser = HL7v2Parser()
        let mshString = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5"
        let parseResult = try parser.parse(mshString)
        let messages = [parseResult.message]
        
        let btsString = "BTS|1"
        let bts = try BTSSegment.parse(btsString)
        
        let batch = BatchMessage(header: bhs, messages: messages, trailer: bts)
        let compressed = try batch.compress(algorithm: .lzfse)
        
        XCTAssertGreaterThan(compressed.compressedSize, 0)
        XCTAssertLessThan(compressed.compressedSize, compressed.originalSize)
    }
    
    // MARK: - File Compression Tests
    
    func testFileMessageCompress() throws {
        let fhsString = "FHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac"
        let fhs = try FHSSegment.parse(fhsString)
        
        let ftsString = "FTS|0"
        let fts = try FTSSegment.parse(ftsString)
        
        let file = FileMessage(header: fhs, batches: [], messages: [], trailer: fts)
        let compressed = try file.compress(algorithm: .lzfse)
        
        XCTAssertGreaterThan(compressed.compressedSize, 0)
    }
    
    // MARK: - Parser Integration Tests
    
    func testParserParseCompressedData() throws {
        guard let data = sampleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test message")
            return
        }
        
        let compressed = try CompressionUtilities.compress(data, algorithm: .lzfse)
        
        let parser = HL7v2Parser()
        let parsedMessage = try parser.parseCompressed(compressed, algorithm: .lzfse)
        
        XCTAssertEqual(parsedMessage.segments.count, 2) // MSH and PID
    }
    
    func testParserParseCompressedMessage() throws {
        let parser = HL7v2Parser()
        let parseResult = try parser.parse(sampleMessage)
        
        let compressedMessage = try parseResult.message.compress(algorithm: .zlib)
        let decompressedMessage = try parser.parseCompressed(compressedMessage)
        
        let originalMSH = parseResult.message.msh()
        let decompressedMSH = decompressedMessage.msh()
        
        XCTAssertEqual(originalMSH?.sendingApplication, decompressedMSH?.sendingApplication)
        XCTAssertEqual(originalMSH?.messageType, decompressedMSH?.messageType)
    }
    
    // MARK: - Large Message Tests
    
    func testCompressLargeMessage() throws {
        // Create a large message with many segments
        var largeMessage = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ORU^R01|MSG001|P|2.5\r"
        largeMessage += "PID|1||12345||Doe^John^A||19800101|M\r"
        
        for i in 1...100 {
            largeMessage += "OBX|\(i)|ST|TEST\(i)||Result\(i)||||||F\r"
        }
        
        let parser = HL7v2Parser()
        let result = try parser.parse(largeMessage)
        
        let compressed = try result.message.compress(algorithm: .lzfse)
        
        // Should achieve decent compression on repetitive data
        XCTAssertLessThan(Double(compressed.compressedSize) / Double(compressed.originalSize), 0.8)
        
        // Verify round-trip
        let decompressed = try parser.parseCompressed(compressed)
        XCTAssertEqual(decompressed.segments.count, result.message.segments.count)
    }
    
    // MARK: - Error Handling Tests
    
    func testDecompressInvalidData() throws {
        let invalidData = Data([1, 2, 3, 4, 5])
        
        XCTAssertThrowsError(try CompressionUtilities.decompress(invalidData, algorithm: .lzfse))
    }
    
    func testCompressEmptyData() throws {
        let emptyData = Data()
        
        // Empty data should still compress/decompress without error
        let compressed = try CompressionUtilities.compress(emptyData, algorithm: .lzfse)
        let decompressed = try CompressionUtilities.decompress(compressed, algorithm: .lzfse)
        
        XCTAssertEqual(decompressed, emptyData)
    }
    
    // MARK: - Performance Tests
    
    func testCompressionPerformance() throws {
        guard let data = sampleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test message")
            return
        }
        
        measure {
            _ = try? CompressionUtilities.compress(data, algorithm: .lzfse)
        }
    }
    
    func testDecompressionPerformance() throws {
        guard let data = sampleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test message")
            return
        }
        
        let compressed = try CompressionUtilities.compress(data, algorithm: .lzfse)
        
        measure {
            _ = try? CompressionUtilities.decompress(compressed, algorithm: .lzfse)
        }
    }
}
