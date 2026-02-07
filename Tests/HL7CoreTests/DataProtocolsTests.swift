import XCTest
@testable import HL7Core

/// Tests for data handling protocols
final class DataProtocolsTests: XCTestCase {
    
    // MARK: - ParseOptions Tests
    
    func testParseOptionsDefault() {
        let options = ParseOptions.default
        XCTAssertFalse(options.strict)
        XCTAssertTrue(options.validate)
        XCTAssertEqual(options.encoding, .utf8)
        XCTAssertFalse(options.preserveWhitespace)
    }
    
    func testParseOptionsStrict() {
        let options = ParseOptions.strict
        XCTAssertTrue(options.strict)
        XCTAssertTrue(options.validate)
    }
    
    func testParseOptionsCustom() {
        let options = ParseOptions(
            strict: true,
            validate: false,
            encoding: .utf16,
            preserveWhitespace: true
        )
        
        XCTAssertTrue(options.strict)
        XCTAssertFalse(options.validate)
        XCTAssertEqual(options.encoding, .utf16)
        XCTAssertTrue(options.preserveWhitespace)
    }
    
    // MARK: - SerializeOptions Tests
    
    func testSerializeOptionsDefault() {
        let options = SerializeOptions.default
        XCTAssertEqual(options.encoding, .utf8)
        XCTAssertFalse(options.prettyPrint)
        XCTAssertTrue(options.validate)
        XCTAssertEqual(options.lineEnding, .lf)
    }
    
    func testSerializeOptionsPrettyPrint() {
        let options = SerializeOptions.prettyPrint
        XCTAssertTrue(options.prettyPrint)
    }
    
    func testSerializeOptionsCustom() {
        let options = SerializeOptions(
            encoding: .utf16,
            prettyPrint: true,
            validate: false,
            lineEnding: .crlf
        )
        
        XCTAssertEqual(options.encoding, .utf16)
        XCTAssertTrue(options.prettyPrint)
        XCTAssertFalse(options.validate)
        XCTAssertEqual(options.lineEnding, .crlf)
    }
    
    // MARK: - LineEnding Tests
    
    func testLineEndingValues() {
        XCTAssertEqual(LineEnding.lf.rawValue, "\n")
        XCTAssertEqual(LineEnding.crlf.rawValue, "\r\n")
        XCTAssertEqual(LineEnding.cr.rawValue, "\r")
    }
    
    // MARK: - Parseable Protocol Tests
    
    struct TestParseable: Parseable {
        let value: String
        
        static func parse(from data: Data) throws -> TestParseable {
            guard let string = String(data: data, encoding: .utf8) else {
                throw HL7Error.parsingError("Invalid UTF-8 data")
            }
            return TestParseable(value: string)
        }
        
        static func parse(from string: String) throws -> TestParseable {
            return TestParseable(value: string)
        }
    }
    
    func testParseableFromData() throws {
        let data = "test value".data(using: .utf8)!
        let parsed = try TestParseable.parse(from: data)
        XCTAssertEqual(parsed.value, "test value")
    }
    
    func testParseableFromString() throws {
        let parsed = try TestParseable.parse(from: "test value")
        XCTAssertEqual(parsed.value, "test value")
    }
    
    func testParseableInvalidData() {
        let invalidData = Data([0xFF, 0xFE])
        XCTAssertThrowsError(try TestParseable.parse(from: invalidData)) { error in
            guard case HL7Error.parsingError = error else {
                XCTFail("Expected parsing error")
                return
            }
        }
    }
    
    // MARK: - Serializable Protocol Tests
    
    struct TestSerializable: Serializable {
        let value: String
        
        func serialize() throws -> Data {
            guard let data = value.data(using: .utf8) else {
                throw HL7Error.encodingError("Cannot encode to UTF-8")
            }
            return data
        }
        
        func serializeToString() throws -> String {
            return value
        }
    }
    
    func testSerializableToData() throws {
        let serializable = TestSerializable(value: "test value")
        let data = try serializable.serialize()
        let string = String(data: data, encoding: .utf8)
        XCTAssertEqual(string, "test value")
    }
    
    func testSerializableToString() throws {
        let serializable = TestSerializable(value: "test value")
        let string = try serializable.serializeToString()
        XCTAssertEqual(string, "test value")
    }
    
    // MARK: - DataConvertible Protocol Tests
    
    struct TestDataConvertible: DataConvertible {
        let value: String
        
        static func parse(from data: Data) throws -> TestDataConvertible {
            guard let string = String(data: data, encoding: .utf8) else {
                throw HL7Error.parsingError("Invalid UTF-8 data")
            }
            return TestDataConvertible(value: string)
        }
        
        static func parse(from string: String) throws -> TestDataConvertible {
            return TestDataConvertible(value: string)
        }
        
        func serialize() throws -> Data {
            guard let data = value.data(using: .utf8) else {
                throw HL7Error.encodingError("Cannot encode to UTF-8")
            }
            return data
        }
        
        func serializeToString() throws -> String {
            return value
        }
    }
    
    func testDataConvertibleRoundTrip() throws {
        let original = TestDataConvertible(value: "test value")
        let data = try original.serialize()
        let parsed = try TestDataConvertible.parse(from: data)
        XCTAssertEqual(parsed.value, original.value)
    }
    
    func testDataConvertibleStringRoundTrip() throws {
        let original = TestDataConvertible(value: "test value")
        let string = try original.serializeToString()
        let parsed = try TestDataConvertible.parse(from: string)
        XCTAssertEqual(parsed.value, original.value)
    }
    
    // MARK: - DataTransformer Protocol Tests
    
    struct UppercaseTransformer: DataTransformer {
        func transform(_ input: String) throws -> String {
            return input.uppercased()
        }
    }
    
    func testDataTransformer() throws {
        let transformer = UppercaseTransformer()
        let result = try transformer.transform("hello world")
        XCTAssertEqual(result, "HELLO WORLD")
    }
    
    struct StringToIntTransformer: DataTransformer {
        func transform(_ input: String) throws -> Int {
            guard let value = Int(input) else {
                throw HL7Error.invalidDataType("Not a valid integer")
            }
            return value
        }
    }
    
    func testDataTransformerTypeConversion() throws {
        let transformer = StringToIntTransformer()
        let result = try transformer.transform("42")
        XCTAssertEqual(result, 42)
    }
    
    func testDataTransformerError() {
        let transformer = StringToIntTransformer()
        XCTAssertThrowsError(try transformer.transform("not a number")) { error in
            guard case HL7Error.invalidDataType = error else {
                XCTFail("Expected invalid data type error")
                return
            }
        }
    }
    
    // MARK: - LazyParseable Protocol Tests
    
    // Note: Using @unchecked Sendable for test purposes only
    final class TestLazyParseable: LazyParseable, @unchecked Sendable {
        typealias RawData = String
        typealias Parsed = String
        
        let rawData: String
        private var cachedParsed: String?
        
        init(rawData: String) {
            self.rawData = rawData
            self.cachedParsed = nil
        }
        
        var isParsed: Bool {
            cachedParsed != nil
        }
        
        func parsed() throws -> String {
            if let cached = cachedParsed {
                return cached
            }
            let parsed = rawData.uppercased()
            cachedParsed = parsed
            return parsed
        }
    }
    
    func testLazyParseableInitialState() {
        let lazy = TestLazyParseable(rawData: "test")
        XCTAssertFalse(lazy.isParsed)
        XCTAssertEqual(lazy.rawData, "test")
    }
    
    func testLazyParseableParsing() throws {
        let lazy = TestLazyParseable(rawData: "test")
        XCTAssertFalse(lazy.isParsed)
        
        let parsed = try lazy.parsed()
        XCTAssertEqual(parsed, "TEST")
        XCTAssertTrue(lazy.isParsed)
    }
    
    func testLazyParseableCaching() throws {
        let lazy = TestLazyParseable(rawData: "test")
        
        let first = try lazy.parsed()
        let second = try lazy.parsed()
        
        XCTAssertEqual(first, second)
        XCTAssertTrue(lazy.isParsed)
    }
    
    // MARK: - StreamingParser Protocol Tests
    
    struct TestStreamingParser: StreamingParser {
        private var elements: [String]
        private var index = 0
        
        init(elements: [String]) {
            self.elements = elements
        }
        
        var hasMore: Bool {
            index < elements.count
        }
        
        mutating func next() throws -> String? {
            guard hasMore else { return nil }
            let element = elements[index]
            index += 1
            return element
        }
    }
    
    func testStreamingParserIteration() throws {
        var parser = TestStreamingParser(elements: ["a", "b", "c"])
        
        XCTAssertTrue(parser.hasMore)
        XCTAssertEqual(try parser.next(), "a")
        XCTAssertEqual(try parser.next(), "b")
        XCTAssertEqual(try parser.next(), "c")
        XCTAssertNil(try parser.next())
        XCTAssertFalse(parser.hasMore)
    }
    
    func testStreamingParserEmpty() throws {
        var parser = TestStreamingParser(elements: [])
        XCTAssertFalse(parser.hasMore)
        XCTAssertNil(try parser.next())
    }
    
    // MARK: - BatchProcessor Protocol Tests
    
    struct TestBatchProcessor: BatchProcessor {
        func processBatch(_ items: [String]) throws -> [String] {
            return items.map { $0.uppercased() }
        }
    }
    
    func testBatchProcessor() throws {
        let processor = TestBatchProcessor()
        let input = ["hello", "world"]
        let results = try processor.processBatch(input)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], "HELLO")
        XCTAssertEqual(results[1], "WORLD")
    }
    
    func testBatchProcessorEmpty() throws {
        let processor = TestBatchProcessor()
        let results = try processor.processBatch([])
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testParsePerformance() {
        let data = "test value".data(using: .utf8)!
        
        measure {
            for _ in 0..<1000 {
                _ = try? TestParseable.parse(from: data)
            }
        }
    }
    
    func testSerializePerformance() {
        let serializable = TestSerializable(value: "test value")
        
        measure {
            for _ in 0..<1000 {
                _ = try? serializable.serialize()
            }
        }
    }
    
    func testTransformPerformance() {
        let transformer = UppercaseTransformer()
        
        measure {
            for _ in 0..<1000 {
                _ = try? transformer.transform("test value")
            }
        }
    }
}
