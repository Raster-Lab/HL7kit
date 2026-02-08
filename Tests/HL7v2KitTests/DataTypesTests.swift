/// Tests for HL7 v2.x Data Types
///
/// Comprehensive test suite for primitive and composite data types

import XCTest
@testable import HL7v2Kit
@testable import HL7Core

final class DataTypesTests: XCTestCase {
    
    // MARK: - ST (String) Tests
    
    func testSTBasicCreation() {
        let st = ST("Patient Name")
        XCTAssertEqual(st.rawValue, "Patient Name")
        XCTAssertFalse(st.isEmpty)
    }
    
    func testSTEmpty() {
        let st = ST("")
        XCTAssertTrue(st.isEmpty)
    }
    
    func testSTValidation() {
        let validST = ST("Normal string")
        XCTAssertTrue(validST.validate().isValid)
        
        // Test max length warning
        let longString = String(repeating: "a", count: 200)
        let longST = ST(longString)
        let result = longST.validate()
        XCTAssertTrue(result.isValid) // Warnings still count as valid
        XCTAssertEqual(result.issues.first?.severity, .warning)
        XCTAssertEqual(result.issues.count, 1)
    }
    
    // MARK: - TX (Text) Tests
    
    func testTXBasicCreation() {
        let tx = TX("This is a long clinical note with multiple sentences.")
        XCTAssertEqual(tx.rawValue, "This is a long clinical note with multiple sentences.")
        XCTAssertFalse(tx.isEmpty)
    }
    
    func testTXValidation() {
        let validTX = TX("Normal text field")
        XCTAssertTrue(validTX.validate().isValid)
        
        // Test max length warning
        let veryLongString = String(repeating: "a", count: 65537)
        let longTX = TX(veryLongString)
        let result = longTX.validate()
        XCTAssertTrue(result.isValid) // Warnings still count as valid
        XCTAssertEqual(result.issues.first?.severity, .warning)
    }
    
    // MARK: - FT (Formatted Text) Tests
    
    func testFTBasicCreation() {
        let ft = FT("Formatted\\.br\\text with line break")
        XCTAssertEqual(ft.rawValue, "Formatted\\.br\\text with line break")
        XCTAssertFalse(ft.isEmpty)
    }
    
    func testFTPlainText() {
        let ft = FT("Line 1\\.br\\Line 2\\.sp\\Line 3")
        let plainText = ft.plainText
        XCTAssertTrue(plainText.contains("\n"))
        XCTAssertTrue(plainText.contains("Line 1"))
        XCTAssertTrue(plainText.contains("Line 2"))
    }
    
    // MARK: - NM (Numeric) Tests
    
    func testNMIntegerCreation() {
        let nm = NM("123")
        XCTAssertEqual(nm.rawValue, "123")
        XCTAssertEqual(nm.doubleValue, 123.0)
        XCTAssertEqual(nm.numericValue, 123)
    }
    
    func testNMDecimalCreation() {
        let nm = NM("123.45")
        XCTAssertEqual(nm.rawValue, "123.45")
        XCTAssertEqual(nm.doubleValue, 123.45)
    }
    
    func testNMFromDecimal() {
        let nm = NM(Decimal(99.99))
        XCTAssertEqual(nm.numericValue, Decimal(99.99))
    }
    
    func testNMFromDouble() {
        let nm = NM(42.5)
        XCTAssertEqual(nm.doubleValue, 42.5)
    }
    
    func testNMValidation() {
        let validNM = NM("123.45")
        XCTAssertTrue(validNM.validate().isValid)
        
        let invalidNM = NM("not a number")
        XCTAssertFalse(invalidNM.validate().isValid)
    }
    
    // MARK: - SI (Sequence ID) Tests
    
    func testSIBasicCreation() {
        let si = SI("1")
        XCTAssertEqual(si.rawValue, "1")
        XCTAssertEqual(si.intValue, 1)
    }
    
    func testSIFromInt() {
        let si = SI(42)
        XCTAssertEqual(si.intValue, 42)
        XCTAssertEqual(si.rawValue, "42")
    }
    
    func testSIValidation() {
        let validSI = SI("5")
        XCTAssertTrue(validSI.validate().isValid)
        
        let invalidSI = SI("not a number")
        XCTAssertFalse(invalidSI.validate().isValid)
        
        // Zero or negative should give warning
        let zeroSI = SI("0")
        let result = zeroSI.validate()
        XCTAssertTrue(result.isValid) // Warnings still count as valid
        XCTAssertEqual(result.issues.first?.severity, .warning)
    }
    
    // MARK: - DT (Date) Tests
    
    func testDTFullDate() {
        let dt = DT("20240207")
        XCTAssertEqual(dt.rawValue, "20240207")
        XCTAssertFalse(dt.isEmpty)
        
        let components = dt.dateComponents
        XCTAssertEqual(components?.year, 2024)
        XCTAssertEqual(components?.month, 2)
        XCTAssertEqual(components?.day, 7)
    }
    
    func testDTYearMonthOnly() {
        let dt = DT("202402")
        XCTAssertEqual(dt.rawValue, "202402")
        
        let components = dt.dateComponents
        XCTAssertEqual(components?.year, 2024)
        XCTAssertEqual(components?.month, 2)
        XCTAssertNil(components?.day)
    }
    
    func testDTYearOnly() {
        let dt = DT("2024")
        XCTAssertEqual(dt.rawValue, "2024")
        
        let components = dt.dateComponents
        XCTAssertEqual(components?.year, 2024)
        XCTAssertNil(components?.month)
        XCTAssertNil(components?.day)
    }
    
    func testDTFromDate() {
        let date = Date()
        let dt = DT(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        XCTAssertTrue(dt.rawValue.count == 8)
        XCTAssertEqual(dt.dateComponents?.year, components.year)
        XCTAssertEqual(dt.dateComponents?.month, components.month)
        XCTAssertEqual(dt.dateComponents?.day, components.day)
    }
    
    func testDTValidation() {
        let validDT = DT("20240207")
        XCTAssertTrue(validDT.validate().isValid)
        
        let invalidDT = DT("2024020")
        XCTAssertFalse(invalidDT.validate().isValid)
        
        let invalidMonth = DT("20241307")
        XCTAssertFalse(invalidMonth.validate().isValid)
    }
    
    // MARK: - TM (Time) Tests
    
    func testTMHourMinute() {
        let tm = TM("1230")
        XCTAssertEqual(tm.rawValue, "1230")
        
        let components = tm.timeComponents
        XCTAssertEqual(components?.hour, 12)
        XCTAssertEqual(components?.minute, 30)
        XCTAssertNil(components?.second)
    }
    
    func testTMWithSeconds() {
        let tm = TM("123045")
        XCTAssertEqual(tm.rawValue, "123045")
        
        let components = tm.timeComponents
        XCTAssertEqual(components?.hour, 12)
        XCTAssertEqual(components?.minute, 30)
        XCTAssertEqual(components?.second, 45)
    }
    
    func testTMWithFractionalSeconds() {
        let tm = TM("123045.123")
        XCTAssertEqual(tm.rawValue, "123045.123")
        
        let components = tm.timeComponents
        XCTAssertEqual(components?.hour, 12)
        XCTAssertEqual(components?.minute, 30)
        XCTAssertEqual(components?.second, 45)
        XCTAssertNotNil(components?.nanosecond)
    }
    
    func testTMValidation() {
        let validTM = TM("1230")
        XCTAssertTrue(validTM.validate().isValid)
        
        let invalidTM = TM("123")
        XCTAssertFalse(invalidTM.validate().isValid)
        
        let invalidHour = TM("2530")
        XCTAssertFalse(invalidHour.validate().isValid)
    }
    
    // MARK: - DTM/TS (DateTime) Tests
    
    func testDTMFullDateTime() {
        let dtm = DTM("20240207123045")
        XCTAssertEqual(dtm.rawValue, "20240207123045")
        
        let result = dtm.dateTimeComponents
        XCTAssertNotNil(result)
        
        let components = result?.components
        XCTAssertEqual(components?.year, 2024)
        XCTAssertEqual(components?.month, 2)
        XCTAssertEqual(components?.day, 7)
        XCTAssertEqual(components?.hour, 12)
        XCTAssertEqual(components?.minute, 30)
        XCTAssertEqual(components?.second, 45)
    }
    
    func testDTMWithTimezone() {
        let dtm = DTM("20240207123045+0500")
        XCTAssertEqual(dtm.rawValue, "20240207123045+0500")
        
        let result = dtm.dateTimeComponents
        XCTAssertNotNil(result)
        
        let timezone = result?.timezone
        XCTAssertNotNil(timezone)
        XCTAssertEqual(timezone?.secondsFromGMT(), 5 * 3600)
    }
    
    func testDTMFromDate() {
        let date = Date()
        let dtm = DTM(date)
        
        XCTAssertTrue(dtm.rawValue.count >= 14)
        XCTAssertNotNil(dtm.date)
    }
    
    func testDTMValidation() {
        let validDTM = DTM("20240207123045")
        XCTAssertTrue(validDTM.validate().isValid)
        
        let invalidDTM = DTM("2024")
        XCTAssertTrue(invalidDTM.validate().isValid) // Minimum format is YYYY
        
        let invalidMonth = DTM("20241307120000")
        XCTAssertFalse(invalidMonth.validate().isValid)
    }
    
    func testTSAlias() {
        let ts: TS = TS("20240207123045")
        XCTAssertEqual(ts.rawValue, "20240207123045")
    }
    
    // MARK: - ID (Coded Value) Tests
    
    func testIDBasicCreation() {
        let id = ID("M")
        XCTAssertEqual(id.rawValue, "M")
        XCTAssertNil(id.tableId)
    }
    
    func testIDWithTable() {
        let id = ID("M", table: "0001")
        XCTAssertEqual(id.rawValue, "M")
        XCTAssertEqual(id.tableId, "0001")
    }
    
    func testIDValidation() {
        let validID = ID("M")
        XCTAssertTrue(validID.validate().isValid)
        
        // Very long ID should give warning
        let longID = ID(String(repeating: "A", count: 25))
        let result = longID.validate()
        XCTAssertTrue(result.isValid) // Warnings still count as valid
        XCTAssertEqual(result.issues.first?.severity, .warning)
    }
    
    // MARK: - IS (User-Defined) Tests
    
    func testISBasicCreation() {
        let is_ = IS("CustomValue")
        XCTAssertEqual(is_.rawValue, "CustomValue")
        XCTAssertNil(is_.tableId)
    }
    
    func testISWithTable() {
        let is_ = IS("CustomValue", table: "9999")
        XCTAssertEqual(is_.rawValue, "CustomValue")
        XCTAssertEqual(is_.tableId, "9999")
    }
    
    func testISValidation() {
        let validIS = IS("CustomValue")
        XCTAssertTrue(validIS.validate().isValid)
    }
}
