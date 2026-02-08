/// Tests for HL7 v2.x Composite Data Types

import XCTest
@testable import HL7v2Kit
@testable import HL7Core

final class CompositeDataTypesTests: XCTestCase {
    
    // MARK: - CE (Coded Element) Tests
    
    func testCEBasicCreation() {
        let ce = CE("410623003^Malaria^SNOMED")
        XCTAssertEqual(ce.identifier, "410623003")
        XCTAssertEqual(ce.text, "Malaria")
        XCTAssertEqual(ce.codingSystem, "SNOMED")
        XCTAssertFalse(ce.isEmpty)
    }
    
    func testCEFullCreation() {
        let ce = CE("410623003^Malaria^SNOMED^ALT123^Alternative^LOINC")
        XCTAssertEqual(ce.identifier, "410623003")
        XCTAssertEqual(ce.text, "Malaria")
        XCTAssertEqual(ce.codingSystem, "SNOMED")
        XCTAssertEqual(ce.alternateIdentifier, "ALT123")
        XCTAssertEqual(ce.alternateText, "Alternative")
        XCTAssertEqual(ce.alternateCodingSystem, "LOINC")
    }
    
    func testCEInitializer() {
        let ce = CE(identifier: "410623003", text: "Malaria", codingSystem: "SNOMED")
        XCTAssertEqual(ce.identifier, "410623003")
        XCTAssertEqual(ce.text, "Malaria")
        XCTAssertEqual(ce.codingSystem, "SNOMED")
    }
    
    func testCEEmpty() {
        let ce = CE("")
        XCTAssertTrue(ce.isEmpty)
        XCTAssertNil(ce.identifier)
    }
    
    func testCEValidation() {
        let validCE = CE("410623003^Malaria^SNOMED")
        XCTAssertTrue(validCE.validate().isValid)
        
        let missingIdentifier = CE("^Malaria^SNOMED")
        let result = missingIdentifier.validate()
        XCTAssertFalse(result.isValid)
    }
    
    // MARK: - CX (Extended Composite ID) Tests
    
    func testCXBasicCreation() {
        let cx = CX("123456^^^Hospital^MR")
        XCTAssertEqual(cx.id, "123456")
        XCTAssertEqual(cx.assigningAuthority, "Hospital")
        XCTAssertEqual(cx.identifierTypeCode, "MR")
        XCTAssertFalse(cx.isEmpty)
    }
    
    func testCXFullCreation() {
        let cx = CX("123456^78^M10^Hospital^MR^Facility")
        XCTAssertEqual(cx.id, "123456")
        XCTAssertEqual(cx.checkDigit, "78")
        XCTAssertEqual(cx.checkDigitScheme, "M10")
        XCTAssertEqual(cx.assigningAuthority, "Hospital")
        XCTAssertEqual(cx.identifierTypeCode, "MR")
        XCTAssertEqual(cx.assigningFacility, "Facility")
    }
    
    func testCXInitializer() {
        let cx = CX(id: "123456", assigningAuthority: "Hospital", identifierTypeCode: "MR")
        XCTAssertEqual(cx.id, "123456")
        XCTAssertEqual(cx.assigningAuthority, "Hospital")
        XCTAssertEqual(cx.identifierTypeCode, "MR")
    }
    
    func testCXValidation() {
        let validCX = CX("123456^^^Hospital^MR")
        XCTAssertTrue(validCX.validate().isValid)
        
        let missingID = CX("^^^Hospital^MR")
        XCTAssertFalse(missingID.validate().isValid)
    }
    
    // MARK: - XPN (Extended Person Name) Tests
    
    func testXPNBasicCreation() {
        let xpn = XPN("Smith^John^A^Jr^Dr")
        XCTAssertEqual(xpn.familyName, "Smith")
        XCTAssertEqual(xpn.givenName, "John")
        XCTAssertEqual(xpn.middleName, "A")
        XCTAssertEqual(xpn.suffix, "Jr")
        XCTAssertEqual(xpn.prefix, "Dr")
        XCTAssertFalse(xpn.isEmpty)
    }
    
    func testXPNFullName() {
        let xpn = XPN("Smith^John^A^Jr^Dr^MD")
        let fullName = xpn.fullName
        XCTAssertTrue(fullName.contains("Dr"))
        XCTAssertTrue(fullName.contains("John"))
        XCTAssertTrue(fullName.contains("Smith"))
        XCTAssertTrue(fullName.contains("MD"))
    }
    
    func testXPNInitializer() {
        let xpn = XPN(familyName: "Smith", givenName: "John", prefix: "Dr")
        XCTAssertEqual(xpn.familyName, "Smith")
        XCTAssertEqual(xpn.givenName, "John")
        XCTAssertEqual(xpn.prefix, "Dr")
    }
    
    func testXPNValidation() {
        let validXPN = XPN("Smith^John")
        XCTAssertTrue(validXPN.validate().isValid)
        
        let noName = XPN("^^")
        let result = noName.validate()
        XCTAssertTrue(result.isValid) // Warnings still count as valid
        XCTAssertEqual(result.issues.first?.severity, .warning)
    }
    
    // MARK: - XAD (Extended Address) Tests
    
    func testXADBasicCreation() {
        let xad = XAD("123 Main St^^Boston^MA^02101^USA")
        XCTAssertEqual(xad.street, "123 Main St")
        XCTAssertEqual(xad.city, "Boston")
        XCTAssertEqual(xad.state, "MA")
        XCTAssertEqual(xad.postalCode, "02101")
        XCTAssertEqual(xad.country, "USA")
        XCTAssertFalse(xad.isEmpty)
    }
    
    func testXADFormattedAddress() {
        let xad = XAD("123 Main St^^Boston^MA^02101^USA")
        let formatted = xad.formattedAddress
        XCTAssertTrue(formatted.contains("123 Main St"))
        XCTAssertTrue(formatted.contains("Boston"))
        XCTAssertTrue(formatted.contains("MA"))
        XCTAssertTrue(formatted.contains("02101"))
    }
    
    func testXADInitializer() {
        let xad = XAD(street: "123 Main St", city: "Boston", state: "MA", postalCode: "02101")
        XCTAssertEqual(xad.street, "123 Main St")
        XCTAssertEqual(xad.city, "Boston")
        XCTAssertEqual(xad.state, "MA")
        XCTAssertEqual(xad.postalCode, "02101")
    }
    
    func testXADValidation() {
        let xad = XAD("123 Main St^^Boston^MA^02101")
        XCTAssertTrue(xad.validate().isValid)
        
        let emptyXAD = XAD("")
        XCTAssertTrue(emptyXAD.validate().isValid) // Address fields are flexible
    }
    
    // MARK: - XTN (Extended Telecommunication) Tests
    
    func testXTNBasicCreation() {
        let xtn = XTN("(617)555-1234")
        XCTAssertEqual(xtn.number, "(617)555-1234")
        XCTAssertFalse(xtn.isEmpty)
    }
    
    func testXTNFullCreation() {
        let xtn = XTN("(617)555-1234^WPN^PH^user@example.com")
        XCTAssertEqual(xtn.number, "(617)555-1234")
        XCTAssertEqual(xtn.useCode, "WPN")
        XCTAssertEqual(xtn.equipmentType, "PH")
        XCTAssertEqual(xtn.email, "user@example.com")
    }
    
    func testXTNInitializer() {
        let xtn = XTN(number: "(617)555-1234", useCode: "WPN", equipmentType: "PH")
        XCTAssertEqual(xtn.number, "(617)555-1234")
        XCTAssertEqual(xtn.useCode, "WPN")
        XCTAssertEqual(xtn.equipmentType, "PH")
    }
    
    func testXTNEmailOnly() {
        let xtn = XTN(number: nil, email: "user@example.com")
        XCTAssertNil(xtn.number)
        XCTAssertEqual(xtn.email, "user@example.com")
    }
    
    func testXTNValidation() {
        let validXTN = XTN("(617)555-1234")
        XCTAssertTrue(validXTN.validate().isValid)
        
        let noContact = XTN("^^^")
        let result = noContact.validate()
        XCTAssertTrue(result.isValid) // Warnings still count as valid
        XCTAssertEqual(result.issues.first?.severity, .warning)
    }
    
    // MARK: - EI (Entity Identifier) Tests
    
    func testEIBasicCreation() {
        let ei = EI("MSG00001^SendingSystem")
        XCTAssertEqual(ei.entityIdentifier, "MSG00001")
        XCTAssertEqual(ei.namespaceID, "SendingSystem")
        XCTAssertFalse(ei.isEmpty)
    }
    
    func testEIFullCreation() {
        let ei = EI("MSG00001^SendingSystem^1.2.3.4^ISO")
        XCTAssertEqual(ei.entityIdentifier, "MSG00001")
        XCTAssertEqual(ei.namespaceID, "SendingSystem")
        XCTAssertEqual(ei.universalID, "1.2.3.4")
        XCTAssertEqual(ei.universalIDType, "ISO")
    }
    
    func testEIInitializer() {
        let ei = EI(entityIdentifier: "MSG00001", namespaceID: "SendingSystem")
        XCTAssertEqual(ei.entityIdentifier, "MSG00001")
        XCTAssertEqual(ei.namespaceID, "SendingSystem")
    }
    
    func testEIValidation() {
        let validEI = EI("MSG00001^SendingSystem")
        XCTAssertTrue(validEI.validate().isValid)
        
        let missingIdentifier = EI("^SendingSystem")
        XCTAssertFalse(missingIdentifier.validate().isValid)
    }
    
    // MARK: - HD (Hierarchic Designator) Tests
    
    func testHDBasicCreation() {
        let hd = HD("Hospital^1.2.3.4^ISO")
        XCTAssertEqual(hd.namespaceID, "Hospital")
        XCTAssertEqual(hd.universalID, "1.2.3.4")
        XCTAssertEqual(hd.universalIDType, "ISO")
        XCTAssertFalse(hd.isEmpty)
    }
    
    func testHDInitializer() {
        let hd = HD(namespaceID: "Hospital", universalID: "1.2.3.4", universalIDType: "ISO")
        XCTAssertEqual(hd.namespaceID, "Hospital")
        XCTAssertEqual(hd.universalID, "1.2.3.4")
        XCTAssertEqual(hd.universalIDType, "ISO")
    }
    
    func testHDValidation() {
        let validHD = HD("Hospital^1.2.3.4^ISO")
        XCTAssertTrue(validHD.validate().isValid)
        
        let missingNamespace = HD("^1.2.3.4^ISO")
        XCTAssertFalse(missingNamespace.validate().isValid)
    }
    
    // MARK: - PL (Person Location) Tests
    
    func testPLBasicCreation() {
        let pl = PL("4E^401^B^Hospital^^N")
        XCTAssertEqual(pl.pointOfCare, "4E")
        XCTAssertEqual(pl.room, "401")
        XCTAssertEqual(pl.bed, "B")
        XCTAssertEqual(pl.facility, "Hospital")
        XCTAssertEqual(pl.personLocationType, "N")
        XCTAssertFalse(pl.isEmpty)
    }
    
    func testPLFullCreation() {
        let pl = PL("4E^401^B^Hospital^Active^N^MainBuilding^4")
        XCTAssertEqual(pl.pointOfCare, "4E")
        XCTAssertEqual(pl.room, "401")
        XCTAssertEqual(pl.bed, "B")
        XCTAssertEqual(pl.facility, "Hospital")
        XCTAssertEqual(pl.locationStatus, "Active")
        XCTAssertEqual(pl.personLocationType, "N")
        XCTAssertEqual(pl.building, "MainBuilding")
        XCTAssertEqual(pl.floor, "4")
    }
    
    func testPLFormattedLocation() {
        let pl = PL("4E^401^B^Hospital^^N")
        let formatted = pl.formattedLocation
        XCTAssertTrue(formatted.contains("Hospital"))
        XCTAssertTrue(formatted.contains("4E"))
        XCTAssertTrue(formatted.contains("Room 401"))
        XCTAssertTrue(formatted.contains("Bed B"))
    }
    
    func testPLInitializer() {
        let pl = PL(pointOfCare: "4E", room: "401", bed: "B", facility: "Hospital")
        XCTAssertEqual(pl.pointOfCare, "4E")
        XCTAssertEqual(pl.room, "401")
        XCTAssertEqual(pl.bed, "B")
        XCTAssertEqual(pl.facility, "Hospital")
    }
    
    func testPLValidation() {
        let pl = PL("4E^401^B^Hospital")
        XCTAssertTrue(pl.validate().isValid)
        
        let emptyPL = PL("")
        XCTAssertTrue(emptyPL.validate().isValid) // Location fields are flexible
    }
    
    // MARK: - Integration Tests
    
    func testMultipleDataTypesInMessage() {
        // Simulate parsing a patient segment with multiple data types
        let patientID = CX("12345^^^Hospital^MR")
        let patientName = XPN("Doe^John^M^^Dr")
        let dateOfBirth = DT("19800115")
        let address = XAD("456 Oak St^^Cambridge^MA^02139^USA")
        let phone = XTN("(617)555-9876^WPN^PH")
        
        XCTAssertEqual(patientID.id, "12345")
        XCTAssertEqual(patientName.familyName, "Doe")
        XCTAssertEqual(patientName.givenName, "John")
        XCTAssertEqual(dateOfBirth.dateComponents?.year, 1980)
        XCTAssertEqual(address.city, "Cambridge")
        XCTAssertEqual(phone.number, "(617)555-9876")
    }
    
    func testDataTypeConversions() {
        // Test numeric conversions
        let nm = NM("123.45")
        XCTAssertNotNil(nm.doubleValue)
        XCTAssertNotNil(nm.numericValue)
        
        // Test date conversions
        let dt = DT(Date())
        XCTAssertNotNil(dt.date)
        
        // Test datetime conversions
        let dtm = DTM(Date())
        XCTAssertNotNil(dtm.date)
    }
    
    func testEmptyFieldHandling() {
        // Test that empty components are handled correctly
        let ce = CE("123^^SNOMED")
        XCTAssertEqual(ce.identifier, "123")
        XCTAssertNil(ce.text)
        XCTAssertEqual(ce.codingSystem, "SNOMED")
        
        let xpn = XPN("Smith^^^^Dr")
        XCTAssertEqual(xpn.familyName, "Smith")
        XCTAssertNil(xpn.givenName)
        XCTAssertEqual(xpn.prefix, "Dr")
    }
}
