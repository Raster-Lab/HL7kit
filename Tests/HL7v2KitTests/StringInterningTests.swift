/// Unit tests for string interning functionality
///
/// Tests for StringInterner, InternedSegmentID, and string interning optimization

import XCTest
@testable import HL7v2Kit

final class StringInterningTests: XCTestCase {
    
    // MARK: - StringInterner Tests
    
    func testStringInternerBasicInterning() async throws {
        let interner = StringInterner()
        
        let str1 = await interner.intern("MSH")
        let str2 = await interner.intern("MSH")
        
        XCTAssertEqual(str1, str2)
        
        let stats = await interner.statistics()
        XCTAssertEqual(stats.internedCount, 1)
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
    }
    
    func testStringInternerMultipleStrings() async throws {
        let interner = StringInterner()
        
        _ = await interner.intern("MSH")
        _ = await interner.intern("PID")
        _ = await interner.intern("OBX")
        _ = await interner.intern("MSH")  // hit
        _ = await interner.intern("PID")  // hit
        
        let stats = await interner.statistics()
        XCTAssertEqual(stats.internedCount, 3)
        XCTAssertEqual(stats.hitCount, 2)
        XCTAssertEqual(stats.missCount, 3)
        XCTAssertEqual(stats.hitRate, 2.0 / 5.0, accuracy: 0.001)
    }
    
    func testStringInternerClear() async throws {
        let interner = StringInterner()
        
        _ = await interner.intern("MSH")
        _ = await interner.intern("PID")
        
        await interner.clear()
        
        let stats = await interner.statistics()
        XCTAssertEqual(stats.internedCount, 0)
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
    }
    
    func testStringInternerStatistics() async throws {
        let interner = StringInterner()
        
        for _ in 0..<100 {
            _ = await interner.intern("COMMON")
        }
        
        let stats = await interner.statistics()
        XCTAssertEqual(stats.internedCount, 1)
        XCTAssertEqual(stats.hitCount, 99)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.hitRate, 0.99, accuracy: 0.001)
    }
    
    // MARK: - InternStatistics Tests
    
    func testInternStatisticsHitRate() {
        let stats1 = InternStatistics(internedCount: 10, hitCount: 80, missCount: 20)
        XCTAssertEqual(stats1.hitRate, 0.8, accuracy: 0.001)
        
        let stats2 = InternStatistics(internedCount: 0, hitCount: 0, missCount: 0)
        XCTAssertEqual(stats2.hitRate, 0.0)
        
        let stats3 = InternStatistics(internedCount: 5, hitCount: 100, missCount: 0)
        XCTAssertEqual(stats3.hitRate, 1.0)
    }
    
    // MARK: - InternedSegmentID Tests
    
    func testInternedSegmentIDCommonSegments() {
        XCTAssertTrue(InternedSegmentID.isCommon("MSH"))
        XCTAssertTrue(InternedSegmentID.isCommon("PID"))
        XCTAssertTrue(InternedSegmentID.isCommon("PV1"))
        XCTAssertTrue(InternedSegmentID.isCommon("OBX"))
        XCTAssertTrue(InternedSegmentID.isCommon("OBR"))
        XCTAssertTrue(InternedSegmentID.isCommon("EVN"))
        XCTAssertTrue(InternedSegmentID.isCommon("ORC"))
        XCTAssertTrue(InternedSegmentID.isCommon("NK1"))
        XCTAssertTrue(InternedSegmentID.isCommon("AL1"))
        XCTAssertTrue(InternedSegmentID.isCommon("DG1"))
    }
    
    func testInternedSegmentIDUncommonSegments() {
        XCTAssertFalse(InternedSegmentID.isCommon("ZZZ"))
        XCTAssertFalse(InternedSegmentID.isCommon("ZAB"))
        XCTAssertFalse(InternedSegmentID.isCommon("XYZ"))
        XCTAssertFalse(InternedSegmentID.isCommon("ABC"))
    }
    
    func testInternedSegmentIDInternCommon() {
        let msh1 = InternedSegmentID.intern("MSH")
        let msh2 = InternedSegmentID.intern("MSH")
        
        // Should return the same constant
        XCTAssertEqual(msh1, msh2)
        XCTAssertEqual(msh1, InternedSegmentID.MSH)
    }
    
    func testInternedSegmentIDInternUncommon() {
        let zzz1 = InternedSegmentID.intern("ZZZ")
        let zzz2 = InternedSegmentID.intern("ZZZ")
        
        // Should return the same string (though not from constant pool)
        XCTAssertEqual(zzz1, zzz2)
    }
    
    func testInternedSegmentIDAllCommonSegments() {
        let commonSegments = [
            "MSH", "EVN", "PID", "PD1", "NK1", "PV1", "PV2",
            "OBR", "OBX", "ORC", "RXA", "RXE", "RXO", "RXR",
            "DG1", "PR1", "GT1", "IN1", "IN2", "IN3",
            "AL1", "ACC", "AIG", "AIL", "AIP", "AIS",
            "BHS", "BTS", "FHS", "FTS",
            "DSC", "DSP", "ERR", "ERQ",
            "MFI", "MFE", "MSA", "QAK", "QPD", "QRD", "QRF",
            "RGS", "SCH", "TXA", "NTE", "ROL",
            "SPM", "SAC", "TQ1", "TQ2",
            "SFT", "UAC", "STF", "ARQ", "APR"
        ]
        
        for segment in commonSegments {
            XCTAssertTrue(InternedSegmentID.isCommon(segment), "\(segment) should be common")
            let interned = InternedSegmentID.intern(segment)
            XCTAssertEqual(interned, segment)
        }
    }
    
    // MARK: - Shared Interner Tests
    
    func testSharedInterner() async throws {
        // Clear shared interner
        await sharedInterner.clear()
        
        let str1 = await sharedInterner.intern("TEST")
        let str2 = await sharedInterner.intern("TEST")
        
        XCTAssertEqual(str1, str2)
        
        let stats = await sharedInterner.statistics()
        XCTAssertEqual(stats.internedCount, 1)
        XCTAssertEqual(stats.hitCount, 1)
    }
    
    // MARK: - Integration Tests
    
    func testSegmentParsingUsesInterning() throws {
        let segment1 = try BaseSegment.parse("MSH|^~\\&|TEST", encodingCharacters: .standard)
        let segment2 = try BaseSegment.parse("MSH|^~\\&|TEST2", encodingCharacters: .standard)
        
        // Segment IDs should be interned (same memory location for common segments)
        XCTAssertEqual(segment1.segmentID, segment2.segmentID)
        XCTAssertEqual(segment1.segmentID, "MSH")
    }
    
    func testMultipleSegmentParsingInterning() throws {
        let segments = [
            "MSH|^~\\&|TEST",
            "PID|1||12345",
            "PV1|1|I|WARD",
            "OBX|1|ST|CODE",
            "MSH|^~\\&|TEST2",  // Another MSH
            "PID|2||67890"     // Another PID
        ]
        
        var parsedSegments: [BaseSegment] = []
        for segStr in segments {
            let segment = try BaseSegment.parse(segStr, encodingCharacters: .standard)
            parsedSegments.append(segment)
        }
        
        // Check that common segments are interned
        XCTAssertEqual(parsedSegments[0].segmentID, parsedSegments[4].segmentID)  // Both MSH
        XCTAssertEqual(parsedSegments[1].segmentID, parsedSegments[5].segmentID)  // Both PID
    }
    
    // MARK: - Performance Tests
    
    func testInterningPerformance() async throws {
        let interner = StringInterner()
        let iterations = 10000
        
        measure {
            Task {
                for _ in 0..<iterations {
                    _ = await interner.intern("MSH")
                    _ = await interner.intern("PID")
                    _ = await interner.intern("OBX")
                }
            }
        }
    }
    
    func testInternedLookupPerformance() {
        measure {
            for _ in 0..<100000 {
                _ = InternedSegmentID.intern("MSH")
                _ = InternedSegmentID.intern("PID")
                _ = InternedSegmentID.intern("OBX")
                _ = InternedSegmentID.intern("OBR")
            }
        }
    }
    
    func testInterningVsRegularStrings() async throws {
        let iterations = 1000
        
        // Without interning - just string creation
        let regularStart = Date()
        var regularStrings: [String] = []
        for i in 0..<iterations {
            regularStrings.append("MSH\(i % 10)")
        }
        let regularDuration = Date().timeIntervalSince(regularStart)
        
        // With interning
        let interner = StringInterner()
        let internStart = Date()
        var internedStrings: [String] = []
        for i in 0..<iterations {
            let str = await interner.intern("MSH\(i % 10)")
            internedStrings.append(str)
        }
        let internDuration = Date().timeIntervalSince(internStart)
        
        print("📊 String Creation Performance:")
        print("   - Regular: \(String(format: "%.6f", regularDuration))s")
        print("   - Interned: \(String(format: "%.6f", internDuration))s")
        
        let stats = await interner.statistics()
        print("   - Unique Strings: \(stats.internedCount)")
        print("   - Hit Rate: \(String(format: "%.1f%%", stats.hitRate * 100))")
    }
    
    // MARK: - Thread Safety Tests
    
    func testInternerThreadSafety() async throws {
        let interner = StringInterner()
        let segmentIDs = ["MSH", "PID", "PV1", "OBX", "OBR", "EVN", "ORC", "NK1"]
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    for _ in 0..<100 {
                        for id in segmentIDs {
                            _ = await interner.intern(id)
                        }
                    }
                }
            }
        }
        
        let stats = await interner.statistics()
        XCTAssertEqual(stats.internedCount, segmentIDs.count)
        XCTAssertGreaterThan(stats.hitRate, 0.9, "Should have high hit rate with concurrent access")
    }
}
