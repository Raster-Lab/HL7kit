// =============================================================================
// HL7kit Performance Optimization Examples
// =============================================================================
//
// Techniques for high-throughput HL7 message processing:
//   1. Object pooling for reduced allocations
//   2. String interning for memory savings
//   3. Streaming API for large files
//   4. Batch file processing
//   5. Compression for storage and transport
//   6. Message inspector for diagnostics
//   7. Configurable parser options
//
// =============================================================================

import Foundation
import HL7Core
import HL7v2Kit

// MARK: - 1. Object Pooling

/// Object pools reduce allocation overhead by reusing segment and field objects.
/// HL7kit automatically uses pools for common segment IDs.
///
/// ```swift
/// // Object pools are used automatically during parsing.
/// // You can monitor pool statistics for tuning:
///
/// // Parse many messages — objects are pooled internally
/// for raw in messageStrings {
///     let msg = try HL7v2Message.parse(raw)
///     // Process the message...
/// }
///
/// // The pool reuses segment and field allocations,
/// // reducing memory pressure by 70-80% in high-throughput scenarios.
/// ```

// MARK: - 2. String Interning

/// Common segment IDs (MSH, PID, OBX, etc.) are automatically interned
/// to reduce memory footprint by 15-25%.
///
/// ```swift
/// // String interning is transparent — no API changes needed.
/// // Common segment IDs share a single string allocation:
/// //   MSH, PID, PV1, OBR, OBX, NK1, IN1, GT1, DG1,
/// //   AL1, EVN, ORC, RXA, RXE, RXR, RXO, NTE, etc.
///
/// let msg = try HL7v2Message.parse(raw)
/// // msg.segments(withID: "PID") uses interned lookup
/// ```

// MARK: - 3. Streaming API for Large Files

/// Process large HL7 message files with constant memory usage
/// using the async streaming API.
///
/// ```swift
/// import HL7v2Kit
///
/// // Stream messages from a file without loading everything into memory
/// let fileURL = URL(fileURLWithPath: "/path/to/large-batch.hl7")
///
/// // Create a streaming parser
/// let stream = HL7v2StreamReader(url: fileURL)
///
/// var count = 0
/// for try await message in stream {
///     // Process each message individually
///     count += 1
///     let controlID = message.messageControlID() ?? "?"
///     print("Processing message \(count): \(controlID)")
/// }
/// print("Processed \(count) messages with constant memory")
/// ```

// MARK: - 4. Batch File Processing

/// Process HL7 batch files (FHS/BHS/BTS/FTS wrapped) as structured batches.
///
/// ```swift
/// import HL7v2Kit
///
/// let batchContent = """
/// FHS|^~\\&|SendApp|SendFac|RecApp|RecFac|20240201
/// BHS|^~\\&|SendApp|SendFac|RecApp|RecFac|20240201
/// MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240201||ADT^A01|M001|P|2.5.1
/// PID|1||MRN001||Smith^John
/// MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240201||ADT^A01|M002|P|2.5.1
/// PID|1||MRN002||Doe^Jane
/// BTS|2
/// FTS|1
/// """
///
/// // Parse the batch structure
/// let batch = try HL7v2BatchParser.parse(batchContent)
/// print("Batch contains \(batch.messages.count) messages")
///
/// for message in batch.messages {
///     let id = message.messageControlID() ?? "?"
///     print("  Message: \(id)")
/// }
/// ```

// MARK: - 5. Compression

/// Compress and decompress HL7 messages for storage or transport efficiency.
///
/// ```swift
/// import HL7v2Kit
///
/// let message = try HL7v2Message.parse(rawMessage)
/// let serialized = try message.serialize()
/// let data = Data(serialized.utf8)
///
/// // Compress with ZLIB (best compatibility)
/// let compressed = try HL7v2Compression.compress(data, algorithm: .zlib)
/// let ratio = Double(compressed.count) / Double(data.count) * 100
/// print("Compressed: \(data.count) → \(compressed.count) bytes (\(String(format: "%.1f", ratio))%)")
///
/// // Decompress
/// let decompressed = try HL7v2Compression.decompress(compressed, algorithm: .zlib)
/// let restored = String(data: decompressed, encoding: .utf8)!
/// print("Restored: \(restored.count) characters")
/// ```

// MARK: - 6. Parser Configuration

/// Customize the parser for different scenarios and error handling strategies.
func demonstrateParserConfiguration() throws {
    // Default configuration
    let defaultParser = HL7v2Parser(configuration: ParserConfiguration())

    // Strict parsing — fails on any error
    let strictParser = HL7v2Parser(
        configuration: ParserConfiguration(errorRecovery: .strict)
    )

    // Lenient parsing — skips invalid segments
    let lenientParser = HL7v2Parser(
        configuration: ParserConfiguration(errorRecovery: .skipInvalidSegments)
    )

    // Best-effort parsing — recovers from errors where possible
    let bestEffortParser = HL7v2Parser(
        configuration: ParserConfiguration(errorRecovery: .bestEffort)
    )

    let raw = "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M001|P|2.5.1\rPID|1||MRN001||Smith^John"

    // Parse with diagnostics
    let result = try defaultParser.parse(raw)
    let diag = result.diagnostics

    print("=== Parser Diagnostics ===")
    print("Segments parsed: \(diag.segmentsParsed)")
    if let parseTime = diag.parseTime {
        print("Parse time: \(parseTime)")
    }
    print("Warnings: \(diag.warnings.count)")
    print("Errors: \(diag.errors.count)")

    // Use results
    _ = strictParser
    _ = lenientParser
    _ = bestEffortParser
}

// MARK: - 7. Message Diff and Comparison

/// Compare two HL7 messages to identify differences.
func compareMessages() throws {
    let original = """
    MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M001|P|2.5.1
    PID|1||MRN001^^^Hosp^MR||Smith^John^A|||M|||123 Main St^^Anytown^NY^12345
    PV1|1|I|ICU^101^A
    """

    let updated = """
    MSH|^~\\&|App|Fac|App|Fac|20240202||ADT^A08|M002|P|2.5.1
    PID|1||MRN001^^^Hosp^MR||Smith^John^A|||M|||456 Oak Ave^^Springfield^IL^62704
    PV1|1|I|MED^201^B
    """

    let msg1 = try HL7v2Message.parse(original)
    let msg2 = try HL7v2Message.parse(updated)

    let inspector = MessageInspector(message: msg1)
    let diff = inspector.compare(with: msg2)
    print("=== Message Differences ===")
    print(diff)
}

// MARK: - 8. Benchmarking

/// Measure parsing throughput for performance tuning.
func benchmarkParsing() throws {
    let sampleMessage = """
    MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M001|P|2.5.1
    EVN|A01|20240201
    PID|1||MRN001^^^Hosp^MR||Smith^John^A|||M|||123 Main St^^Anytown^NY^12345
    PV1|1|I|ICU^101^A
    NK1|1|Smith^Mary||555-0101|||||EC
    IN1|1|BCBS001|BC001|Blue Cross
    """

    let iterations = 1000
    let start = Date()

    for _ in 0..<iterations {
        let msg = try HL7v2Message.parse(sampleMessage)
        _ = try msg.serialize()
    }

    let elapsed = Date().timeIntervalSince(start)
    let throughput = Double(iterations) / elapsed

    print("=== Parsing Benchmark ===")
    print("Iterations: \(iterations)")
    print("Total time: \(String(format: "%.3f", elapsed))s")
    print("Throughput: \(String(format: "%.0f", throughput)) messages/second")
    print("Avg latency: \(String(format: "%.3f", elapsed / Double(iterations) * 1000))ms")
}
