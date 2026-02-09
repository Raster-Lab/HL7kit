/// FHIRPrimitiveTests.swift
/// Tests for FHIR primitive data types

import XCTest
@testable import FHIRkit

final class FHIRPrimitiveTests: XCTestCase {
    
    // MARK: - FHIRBoolean Tests
    
    func testFHIRBooleanCreation() {
        let trueValue = FHIRBoolean(true)
        XCTAssertTrue(trueValue.value)
        XCTAssertNil(trueValue.id)
        XCTAssertNil(trueValue.extension)
        
        let falseValue = FHIRBoolean(false)
        XCTAssertFalse(falseValue.value)
    }
    
    func testFHIRBooleanValidation() throws {
        let value = FHIRBoolean(true)
        XCTAssertNoThrow(try value.validate())
    }
    
    // MARK: - FHIRInteger Tests
    
    func testFHIRIntegerCreation() {
        let value = FHIRInteger(42)
        XCTAssertEqual(value.value, 42)
        XCTAssertNil(value.id)
        XCTAssertNil(value.extension)
    }
    
    func testFHIRIntegerValidation() throws {
        let value = FHIRInteger(100)
        XCTAssertNoThrow(try value.validate())
    }
    
    // MARK: - FHIRDecimal Tests
    
    func testFHIRDecimalCreation() {
        let value = FHIRDecimal(3.14)
        XCTAssertEqual(value.value, 3.14)
        XCTAssertNil(value.id)
        XCTAssertNil(value.extension)
    }
    
    func testFHIRDecimalValidation() throws {
        let value = FHIRDecimal(2.71828)
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRDecimalInvalidNaN() {
        let value = FHIRDecimal(Decimal.nan)
        XCTAssertThrowsError(try value.validate()) { error in
            guard case FHIRValidationError.invalidValue = error else {
                XCTFail("Expected invalidValue error")
                return
            }
        }
    }
    
    // MARK: - FHIRString Tests
    
    func testFHIRStringCreation() {
        let value = FHIRString("Hello, FHIR!")
        XCTAssertEqual(value.value, "Hello, FHIR!")
        XCTAssertNil(value.id)
        XCTAssertNil(value.extension)
    }
    
    func testFHIRStringValidation() throws {
        let value = FHIRString("Valid string")
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRStringTooLarge() {
        let largeString = String(repeating: "A", count: 1_048_577) // Just over 1MB
        let value = FHIRString(largeString)
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRUri Tests
    
    func testFHIRUriCreation() {
        let value = FHIRUri("http://example.com")
        XCTAssertEqual(value.value, "http://example.com")
    }
    
    func testFHIRUriValidation() throws {
        let value = FHIRUri("http://hl7.org/fhir")
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRUriEmpty() {
        let value = FHIRUri("")
        XCTAssertThrowsError(try value.validate())
    }
    
    func testFHIRUriWithWhitespace() {
        let value = FHIRUri("http://example.com/with space")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRUrl Tests
    
    func testFHIRUrlCreation() {
        let value = FHIRUrl("https://example.com")
        XCTAssertEqual(value.value, "https://example.com")
    }
    
    func testFHIRUrlValidation() throws {
        let value = FHIRUrl("https://hl7.org/fhir/r4")
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRUrlInvalid() {
        let value = FHIRUrl("not a url")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRCode Tests
    
    func testFHIRCodeCreation() {
        let value = FHIRCode("active")
        XCTAssertEqual(value.value, "active")
    }
    
    func testFHIRCodeValidation() throws {
        let value = FHIRCode("completed")
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRCodeEmpty() {
        let value = FHIRCode("")
        XCTAssertThrowsError(try value.validate())
    }
    
    func testFHIRCodeLeadingSpace() {
        let value = FHIRCode(" active")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRId Tests
    
    func testFHIRIdCreation() {
        let value = FHIRId("patient-123")
        XCTAssertEqual(value.value, "patient-123")
    }
    
    func testFHIRIdValidation() throws {
        let value = FHIRId("abc-123.def")
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRIdTooLong() {
        let longId = String(repeating: "a", count: 65)
        let value = FHIRId(longId)
        XCTAssertThrowsError(try value.validate())
    }
    
    func testFHIRIdInvalidCharacters() {
        let value = FHIRId("patient#123")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRDate Tests
    
    func testFHIRDateCreation() {
        let value = FHIRDate("2024-01-15")
        XCTAssertEqual(value.value, "2024-01-15")
    }
    
    func testFHIRDateValidation() throws {
        let yearOnly = FHIRDate("2024")
        XCTAssertNoThrow(try yearOnly.validate())
        
        let yearMonth = FHIRDate("2024-01")
        XCTAssertNoThrow(try yearMonth.validate())
        
        let fullDate = FHIRDate("2024-01-15")
        XCTAssertNoThrow(try fullDate.validate())
    }
    
    func testFHIRDateInvalid() {
        let invalidMonth = FHIRDate("2024-13-01")
        XCTAssertThrowsError(try invalidMonth.validate())
        
        let invalidDay = FHIRDate("2024-01-32")
        XCTAssertThrowsError(try invalidDay.validate())
    }
    
    func testFHIRDateComponents() {
        let fullDate = FHIRDate("2024-01-15")
        let components = fullDate.dateComponents
        XCTAssertEqual(components?.year, 2024)
        XCTAssertEqual(components?.month, 1)
        XCTAssertEqual(components?.day, 15)
    }
    
    // MARK: - FHIRDateTime Tests
    
    func testFHIRDateTimeCreation() {
        let value = FHIRDateTime("2024-01-15T14:30:00Z")
        XCTAssertEqual(value.value, "2024-01-15T14:30:00Z")
    }
    
    func testFHIRDateTimeValidation() throws {
        let value = FHIRDateTime("2024-01-15T14:30:00+00:00")
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRDateTimeEmpty() {
        let value = FHIRDateTime("")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRTime Tests
    
    func testFHIRTimeCreation() {
        let value = FHIRTime("14:30:00")
        XCTAssertEqual(value.value, "14:30:00")
    }
    
    func testFHIRTimeValidation() throws {
        let value = FHIRTime("09:15:30")
        XCTAssertNoThrow(try value.validate())
        
        let withMillis = FHIRTime("09:15:30.123")
        XCTAssertNoThrow(try withMillis.validate())
    }
    
    func testFHIRTimeInvalidFormat() {
        let value = FHIRTime("25:00:00")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRInstant Tests
    
    func testFHIRInstantCreation() {
        let value = FHIRInstant("2024-01-15T14:30:00.000Z")
        XCTAssertEqual(value.value, "2024-01-15T14:30:00.000Z")
    }
    
    func testFHIRInstantValidation() throws {
        let value = FHIRInstant("2024-01-15T14:30:00+05:00")
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRInstantMissingTimezone() {
        let value = FHIRInstant("2024-01-15T14:30:00")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRBase64Binary Tests
    
    func testFHIRBase64BinaryCreation() {
        let value = FHIRBase64Binary("SGVsbG8gV29ybGQ=")
        XCTAssertEqual(value.value, "SGVsbG8gV29ybGQ=")
    }
    
    func testFHIRBase64BinaryValidation() throws {
        let value = FHIRBase64Binary("SGVsbG8gV29ybGQ=")
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRBase64BinaryData() {
        let value = FHIRBase64Binary("SGVsbG8gV29ybGQ=")
        let data = value.data
        XCTAssertNotNil(data)
        let string = String(data: data!, encoding: .utf8)
        XCTAssertEqual(string, "Hello World")
    }
    
    func testFHIRBase64BinaryInvalid() {
        let value = FHIRBase64Binary("Not valid base64!")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - FHIRUuid Tests
    
    func testFHIRUuidCreation() {
        let uuid = UUID()
        let value = FHIRUuid(uuid)
        XCTAssertTrue(value.value.starts(with: "urn:uuid:"))
    }
    
    func testFHIRUuidValidation() throws {
        let uuid = UUID()
        let value = FHIRUuid(uuid)
        XCTAssertNoThrow(try value.validate())
    }
    
    func testFHIRUuidInvalidFormat() {
        let value = FHIRUuid("not-a-uuid")
        XCTAssertThrowsError(try value.validate())
    }
    
    // MARK: - Codable Tests
    
    func testFHIRStringCodable() throws {
        let original = FHIRString("Test string")
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FHIRString.self, from: data)
        
        XCTAssertEqual(original.value, decoded.value)
    }
    
    func testFHIRIntegerCodable() throws {
        let original = FHIRInteger(42)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FHIRInteger.self, from: data)
        
        XCTAssertEqual(original.value, decoded.value)
    }
    
    func testFHIRDateCodable() throws {
        let original = FHIRDate("2024-01-15")
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FHIRDate.self, from: data)
        
        XCTAssertEqual(original.value, decoded.value)
    }
    
    // MARK: - Hashable Tests
    
    func testFHIRStringHashable() {
        let value1 = FHIRString("test")
        let value2 = FHIRString("test")
        let value3 = FHIRString("different")
        
        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
        
        let set: Set = [value1, value2, value3]
        XCTAssertEqual(set.count, 2) // value1 and value2 are equal
    }
    
    // MARK: - Performance Tests
    
    func testFHIRPrimitiveCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = FHIRString("test")
                _ = FHIRInteger(42)
                _ = FHIRBoolean(true)
            }
        }
    }
    
    func testFHIRPrimitiveValidationPerformance() {
        let string = FHIRString("test")
        let integer = FHIRInteger(42)
        let date = FHIRDate("2024-01-15")
        
        measure {
            for _ in 0..<1000 {
                try? string.validate()
                try? integer.validate()
                try? date.validate()
            }
        }
    }
}
