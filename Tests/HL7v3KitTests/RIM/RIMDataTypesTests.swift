import XCTest
@testable import HL7v3Kit
@testable import HL7Core

/// Tests for HL7 v3 RIM Data Types
final class RIMDataTypesTests: XCTestCase {
    
    // MARK: - Null Flavor Tests
    
    func testNullFlavorRawValues() {
        XCTAssertEqual(NullFlavor.noInformation.rawValue, "NI")
        XCTAssertEqual(NullFlavor.notApplicable.rawValue, "NA")
        XCTAssertEqual(NullFlavor.unknown.rawValue, "UNK")
        XCTAssertEqual(NullFlavor.askedButUnknown.rawValue, "ASKU")
        XCTAssertEqual(NullFlavor.temporarilyUnavailable.rawValue, "NAV")
        XCTAssertEqual(NullFlavor.notAsked.rawValue, "NASK")
        XCTAssertEqual(NullFlavor.masked.rawValue, "MSK")
        XCTAssertEqual(NullFlavor.other.rawValue, "OTH")
    }
    
    // MARK: - Boolean (BL) Tests
    
    func testBooleanValue() {
        let boolTrue = BL.value(true)
        XCTAssertEqual(boolTrue.boolValue, true)
        
        let boolFalse = BL.value(false)
        XCTAssertEqual(boolFalse.boolValue, false)
    }
    
    func testBooleanNullFlavor() {
        let boolNull = BL.nullFlavor(.unknown)
        XCTAssertNil(boolNull.boolValue)
    }
    
    func testBooleanEquality() {
        XCTAssertEqual(BL.value(true), BL.value(true))
        XCTAssertEqual(BL.value(false), BL.value(false))
        XCTAssertEqual(BL.nullFlavor(.unknown), BL.nullFlavor(.unknown))
        XCTAssertNotEqual(BL.value(true), BL.value(false))
        XCTAssertNotEqual(BL.value(true), BL.nullFlavor(.unknown))
    }
    
    // MARK: - Integer (INT) Tests
    
    func testIntegerValue() {
        let int = INT.value(42)
        XCTAssertEqual(int.intValue, 42)
        
        let negInt = INT.value(-10)
        XCTAssertEqual(negInt.intValue, -10)
    }
    
    func testIntegerNullFlavor() {
        let intNull = INT.nullFlavor(.notAsked)
        XCTAssertNil(intNull.intValue)
    }
    
    // MARK: - Real (REAL) Tests
    
    func testRealValue() {
        let real = REAL.value(3.14159)
        XCTAssertEqual(real.doubleValue, 3.14159)
        
        let negReal = REAL.value(-273.15)
        XCTAssertEqual(negReal.doubleValue, -273.15)
    }
    
    func testRealNullFlavor() {
        let realNull = REAL.nullFlavor(.notApplicable)
        XCTAssertNil(realNull.doubleValue)
    }
    
    // MARK: - String (ST) Tests
    
    func testStringValue() {
        let str = ST.value("Hello, HL7!")
        XCTAssertEqual(str.stringValue, "Hello, HL7!")
    }
    
    func testStringNullFlavor() {
        let strNull = ST.nullFlavor(.masked)
        XCTAssertNil(strNull.stringValue)
    }
    
    // MARK: - Instance Identifier (II) Tests
    
    func testInstanceIdentifierBasic() {
        let ii = II(root: "2.16.840.1.113883.4.1", extension: "123-45-6789")
        XCTAssertEqual(ii.root, "2.16.840.1.113883.4.1")
        XCTAssertEqual(ii.extension, "123-45-6789")
        XCTAssertNil(ii.nullFlavor)
    }
    
    func testInstanceIdentifierWithAuthority() {
        let ii = II(
            root: "2.16.840.1.113883.4.1",
            extension: "123-45-6789",
            assigningAuthorityName: "US SSN"
        )
        XCTAssertEqual(ii.assigningAuthorityName, "US SSN")
    }
    
    func testInstanceIdentifierNullFlavor() {
        let ii = II(nullFlavor: .unknown)
        XCTAssertEqual(ii.nullFlavor, .unknown)
        XCTAssertNil(ii.extension)
    }
    
    // MARK: - Timestamp (TS) Tests
    
    func testTimestampValue() {
        let date = Date()
        let ts = TS(value: date, precision: .second)
        XCTAssertEqual(ts.value, date)
        XCTAssertEqual(ts.precision, .second)
        XCTAssertNil(ts.nullFlavor)
    }
    
    func testTimestampPrecisions() {
        let date = Date()
        let tsYear = TS(value: date, precision: .year)
        let tsMonth = TS(value: date, precision: .month)
        let tsDay = TS(value: date, precision: .day)
        let tsHour = TS(value: date, precision: .hour)
        let tsMinute = TS(value: date, precision: .minute)
        let tsSecond = TS(value: date, precision: .second)
        let tsMillisecond = TS(value: date, precision: .millisecond)
        
        XCTAssertEqual(tsYear.precision, .year)
        XCTAssertEqual(tsMonth.precision, .month)
        XCTAssertEqual(tsDay.precision, .day)
        XCTAssertEqual(tsHour.precision, .hour)
        XCTAssertEqual(tsMinute.precision, .minute)
        XCTAssertEqual(tsSecond.precision, .second)
        XCTAssertEqual(tsMillisecond.precision, .millisecond)
    }
    
    func testTimestampNullFlavor() {
        let ts = TS(nullFlavor: .temporarilyUnavailable)
        XCTAssertNil(ts.value)
        XCTAssertEqual(ts.nullFlavor, .temporarilyUnavailable)
    }
    
    // MARK: - Concept Descriptor (CD) Tests
    
    func testConceptDescriptorBasic() {
        let cd = CD(
            code: "38341003",
            codeSystem: "2.16.840.1.113883.6.96",
            displayName: "Hypertension"
        )
        XCTAssertEqual(cd.code, "38341003")
        XCTAssertEqual(cd.codeSystem, "2.16.840.1.113883.6.96")
        XCTAssertEqual(cd.displayName, "Hypertension")
        XCTAssertNil(cd.nullFlavor)
    }
    
    func testConceptDescriptorWithTranslations() {
        let translation = CD(
            code: "I10",
            codeSystem: "2.16.840.1.113883.6.90",
            displayName: "Essential hypertension"
        )
        
        let cd = CD(
            code: "38341003",
            codeSystem: "2.16.840.1.113883.6.96",
            displayName: "Hypertension",
            translations: [translation]
        )
        
        XCTAssertEqual(cd.translations?.count, 1)
        XCTAssertEqual(cd.translations?.first?.code, "I10")
    }
    
    func testConceptDescriptorNullFlavor() {
        let cd = CD(nullFlavor: .unknown)
        XCTAssertNil(cd.code)
        XCTAssertEqual(cd.nullFlavor, .unknown)
    }
    
    // MARK: - Interval (IVL) Tests
    
    func testIntervalWithLowHigh() {
        let low = TS(value: Date(timeIntervalSince1970: 0))
        let high = TS(value: Date(timeIntervalSince1970: 86400))
        let interval = IVL(low: low, high: high)
        
        XCTAssertNotNil(interval.low)
        XCTAssertNotNil(interval.high)
        XCTAssertNil(interval.width)
        XCTAssertNil(interval.nullFlavor)
    }
    
    func testIntervalWithCenter() {
        let center = TS(value: Date())
        let interval = IVL<TS>(center: center)
        
        XCTAssertNotNil(interval.center)
        XCTAssertNil(interval.low)
        XCTAssertNil(interval.high)
    }
    
    func testIntervalNullFlavor() {
        let interval = IVL<TS>(nullFlavor: .notApplicable)
        XCTAssertEqual(interval.nullFlavor, .notApplicable)
        XCTAssertNil(interval.low)
        XCTAssertNil(interval.high)
    }
    
    // MARK: - Physical Quantity (PQ) Tests
    
    func testPhysicalQuantity() {
        let pq = PQ(value: 70.5, unit: "kg")
        XCTAssertEqual(pq.value, 70.5)
        XCTAssertEqual(pq.unit, "kg")
        XCTAssertNil(pq.nullFlavor)
    }
    
    func testPhysicalQuantityUnits() {
        let weight = PQ(value: 150, unit: "lb")
        let height = PQ(value: 180, unit: "cm")
        let temp = PQ(value: 37.0, unit: "Cel")
        
        XCTAssertEqual(weight.unit, "lb")
        XCTAssertEqual(height.unit, "cm")
        XCTAssertEqual(temp.unit, "Cel")
    }
    
    func testPhysicalQuantityNullFlavor() {
        let pq = PQ(nullFlavor: .notAsked)
        XCTAssertNil(pq.value)
        XCTAssertNil(pq.unit)
        XCTAssertEqual(pq.nullFlavor, .notAsked)
    }
    
    // MARK: - Entity Name (EN) Tests
    
    func testEntityNameBasic() {
        let familyName = EN.NamePart(value: "Smith", type: .family)
        let givenName = EN.NamePart(value: "John", type: .given)
        
        let name = EN(parts: [familyName, givenName])
        
        XCTAssertEqual(name.parts.count, 2)
        XCTAssertEqual(name.parts[0].value, "Smith")
        XCTAssertEqual(name.parts[0].type, .family)
        XCTAssertEqual(name.parts[1].value, "John")
        XCTAssertEqual(name.parts[1].type, .given)
    }
    
    func testEntityNameWithPrefix() {
        let prefix = EN.NamePart(value: "Dr.", type: .prefix)
        let family = EN.NamePart(value: "Smith", type: .family)
        let given = EN.NamePart(value: "Jane", type: .given)
        let suffix = EN.NamePart(value: "M.D.", type: .suffix)
        
        let name = EN(parts: [prefix, given, family, suffix], use: .official)
        
        XCTAssertEqual(name.parts.count, 4)
        XCTAssertEqual(name.use, .official)
    }
    
    func testEntityNameUse() {
        let parts = [EN.NamePart(value: "Doe", type: .family)]
        
        let legalName = EN(parts: parts, use: .legal)
        let maidenName = EN(parts: parts, use: .maiden)
        let nickname = EN(parts: parts, use: .nickname)
        
        XCTAssertEqual(legalName.use, .legal)
        XCTAssertEqual(maidenName.use, .maiden)
        XCTAssertEqual(nickname.use, .nickname)
    }
    
    func testEntityNameNullFlavor() {
        let name = EN(nullFlavor: .masked)
        XCTAssertTrue(name.parts.isEmpty)
        XCTAssertEqual(name.nullFlavor, .masked)
    }
    
    // MARK: - Address (AD) Tests
    
    func testAddressBasic() {
        let street = AD.AddressPart(value: "123 Main St", type: .streetAddressLine)
        let city = AD.AddressPart(value: "Springfield", type: .city)
        let state = AD.AddressPart(value: "IL", type: .state)
        let zip = AD.AddressPart(value: "62701", type: .postalCode)
        let country = AD.AddressPart(value: "USA", type: .country)
        
        let address = AD(parts: [street, city, state, zip, country])
        
        XCTAssertEqual(address.parts.count, 5)
        XCTAssertEqual(address.parts[0].value, "123 Main St")
        XCTAssertEqual(address.parts[1].value, "Springfield")
    }
    
    func testAddressUse() {
        let parts = [AD.AddressPart(value: "123 Main St", type: .streetAddressLine)]
        
        let homeAddr = AD(parts: parts, use: .home)
        let workAddr = AD(parts: parts, use: .work)
        let physicalAddr = AD(parts: parts, use: .physical)
        
        XCTAssertEqual(homeAddr.use, .home)
        XCTAssertEqual(workAddr.use, .work)
        XCTAssertEqual(physicalAddr.use, .physical)
    }
    
    func testAddressNullFlavor() {
        let address = AD(nullFlavor: .unknown)
        XCTAssertTrue(address.parts.isEmpty)
        XCTAssertEqual(address.nullFlavor, .unknown)
    }
    
    // MARK: - Telecommunication Address (TEL) Tests
    
    func testTelecommunicationPhone() {
        let tel = TEL(value: "tel:+1-217-555-1234", use: .home)
        XCTAssertEqual(tel.value, "tel:+1-217-555-1234")
        XCTAssertEqual(tel.use, .home)
        XCTAssertNil(tel.nullFlavor)
    }
    
    func testTelecommunicationEmail() {
        let tel = TEL(value: "mailto:patient@example.com", use: .work)
        XCTAssertEqual(tel.value, "mailto:patient@example.com")
        XCTAssertEqual(tel.use, .work)
    }
    
    func testTelecommunicationUseTypes() {
        let home = TEL(value: "tel:555-1234", use: .home)
        let work = TEL(value: "tel:555-5678", use: .work)
        let mobile = TEL(value: "tel:555-9012", use: .mobile)
        let fax = TEL(value: "tel:555-3456", use: .fax)
        
        XCTAssertEqual(home.use, .home)
        XCTAssertEqual(work.use, .work)
        XCTAssertEqual(mobile.use, .mobile)
        XCTAssertEqual(fax.use, .fax)
    }
    
    func testTelecommunicationNullFlavor() {
        let tel = TEL(nullFlavor: .notAsked)
        XCTAssertNil(tel.value)
        XCTAssertEqual(tel.nullFlavor, .notAsked)
    }
    
    // MARK: - Codable Tests
    
    func testInstanceIdentifierCodable() throws {
        let original = II(root: "2.16.840.1.113883.4.1", extension: "123-45-6789")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(II.self, from: encoded)
        
        XCTAssertEqual(decoded.root, original.root)
        XCTAssertEqual(decoded.extension, original.extension)
    }
    
    func testConceptDescriptorCodable() throws {
        let original = CD(
            code: "38341003",
            codeSystem: "2.16.840.1.113883.6.96",
            displayName: "Hypertension"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CD.self, from: encoded)
        
        XCTAssertEqual(decoded.code, original.code)
        XCTAssertEqual(decoded.codeSystem, original.codeSystem)
        XCTAssertEqual(decoded.displayName, original.displayName)
    }
    
    func testEntityNameCodable() throws {
        let original = EN(parts: [
            EN.NamePart(value: "Smith", type: .family),
            EN.NamePart(value: "John", type: .given)
        ])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EN.self, from: encoded)
        
        XCTAssertEqual(decoded.parts.count, original.parts.count)
        XCTAssertEqual(decoded.parts[0].value, original.parts[0].value)
    }
    
    // MARK: - Sendable Tests
    
    func testSendableConformance() async {
        let ii = II(root: "test", extension: "123")
        let cd = CD(code: "test")
        let pq = PQ(value: 10.0, unit: "kg")
        
        await Task {
            XCTAssertEqual(ii.root, "test")
            XCTAssertEqual(cd.code, "test")
            XCTAssertEqual(pq.value, 10.0)
        }.value
    }
    
    // MARK: - Performance Tests
    
    func testDataTypeCreationPerformance() {
        measure {
            for i in 0..<1000 {
                _ = II(root: "2.16.840.1.113883.4.1", extension: "\(i)")
                _ = CD(code: "code\(i)", codeSystem: "system", displayName: "Name \(i)")
                _ = PQ(value: Double(i), unit: "kg")
            }
        }
    }
    
    func testIntervalCreationPerformance() {
        measure {
            for i in 0..<1000 {
                let low = TS(value: Date(timeIntervalSince1970: Double(i)))
                let high = TS(value: Date(timeIntervalSince1970: Double(i + 3600)))
                _ = IVL(low: low, high: high)
            }
        }
    }
}
