import Testing
@testable import HL7Core

@Suite("HL7Version Tests")
struct HL7VersionTests {
    @Test("All v2 versions are identified as v2")
    func v2VersionsAreV2() {
        let v2Versions: [HL7Version] = [.v21, .v22, .v23, .v231, .v24, .v25, .v251, .v26, .v27, .v271, .v28, .v281, .v282]
        for version in v2Versions {
            #expect(version.isV2 == true, "Expected \(version.rawValue) to be v2")
        }
    }

    @Test("v3 is not v2")
    func v3IsNotV2() {
        #expect(HL7Version.v3.isV2 == false)
    }

    @Test("Raw values match expected version strings")
    func rawValues() {
        #expect(HL7Version.v25.rawValue == "2.5")
        #expect(HL7Version.v3.rawValue == "3.0")
    }
}

@Suite("HL7DateFormatter Tests")
struct HL7DateFormatterTests {
    @Test("Parse full HL7 date")
    func parseFullDate() {
        let date = HL7DateFormatter.date(from: "20240101120000")
        #expect(date != nil)
    }

    @Test("Parse date-only HL7 string")
    func parseDateOnly() {
        let date = HL7DateFormatter.date(from: "20240101")
        #expect(date != nil)
    }

    @Test("Empty string returns nil")
    func emptyReturnsNil() {
        let date = HL7DateFormatter.date(from: "")
        #expect(date == nil)
    }

    @Test("Format date to HL7 string")
    func formatDate() {
        let date = HL7DateFormatter.date(from: "20240101120000")!
        let formatted = HL7DateFormatter.string(from: date)
        #expect(formatted.hasPrefix("2024"))
    }
}

@Suite("ValidationResult Tests")
struct ValidationResultTests {
    @Test("Empty issues means valid")
    func emptyIsValid() {
        let result = ValidationResult()
        #expect(result.isValid)
    }

    @Test("Warning does not invalidate")
    func warningIsStillValid() {
        let result = ValidationResult(issues: [
            .init(severity: .warning, message: "minor issue")
        ])
        #expect(result.isValid)
    }

    @Test("Error invalidates")
    func errorInvalidates() {
        let result = ValidationResult(issues: [
            .init(severity: .error, message: "critical issue")
        ])
        #expect(!result.isValid)
    }
}
