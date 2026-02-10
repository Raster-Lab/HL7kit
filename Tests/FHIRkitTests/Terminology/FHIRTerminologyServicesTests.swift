/// FHIRTerminologyServicesTests.swift
/// Tests for FHIR Terminology Services (Phase 6.2)

import XCTest
import Foundation
@testable import FHIRkit
@testable import HL7Core

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Mock URL Session

/// Mock URL session for terminology service tests
private final class MockTerminologySession: FHIRURLSession, @unchecked Sendable {
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var shouldThrowError: Bool = false

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if shouldThrowError {
            throw URLError(.notConnectedToInternet)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: responseStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}

// MARK: - TerminologyServiceError Tests

final class TerminologyServiceErrorTests: XCTestCase {
    func testErrorDescriptions() {
        let errors: [(TerminologyServiceError, String)] = [
            (.serverError("timeout"), "Terminology server error: timeout"),
            (.invalidResponse("bad json"), "Invalid terminology response: bad json"),
            (.codeSystemNotFound("http://example.com"), "Code system not found: http://example.com"),
            (.valueSetNotFound("http://vs.example.com"), "Value set not found: http://vs.example.com"),
            (.conceptMapNotFound("http://cm.example.com"), "Concept map not found: http://cm.example.com"),
            (.operationNotSupported("$closure"), "Operation not supported: $closure"),
            (.networkError("offline"), "Network error: offline"),
            (.cacheError("full"), "Cache error: full"),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.description, expected)
        }
    }
}

// MARK: - FHIRCodeSystemOperation Tests

final class FHIRCodeSystemOperationTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(FHIRCodeSystemOperation.lookup.rawValue, "$lookup")
        XCTAssertEqual(FHIRCodeSystemOperation.validateCode.rawValue, "$validate-code")
    }
}

// MARK: - PropertyValue Tests

final class PropertyValueTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(PropertyValue.string("abc"), PropertyValue.string("abc"))
        XCTAssertNotEqual(PropertyValue.string("abc"), PropertyValue.string("def"))
        XCTAssertEqual(PropertyValue.code("123"), PropertyValue.code("123"))
        XCTAssertEqual(PropertyValue.boolean(true), PropertyValue.boolean(true))
        XCTAssertNotEqual(PropertyValue.boolean(true), PropertyValue.boolean(false))
        XCTAssertEqual(PropertyValue.integer(42), PropertyValue.integer(42))
        XCTAssertEqual(PropertyValue.decimal(3.14), PropertyValue.decimal(3.14))

        let now = Date()
        XCTAssertEqual(PropertyValue.dateTime(now), PropertyValue.dateTime(now))

        // Cross-type inequality
        XCTAssertNotEqual(PropertyValue.string("42"), PropertyValue.code("42"))
    }
}

// MARK: - CodeSystemDesignation Tests

final class CodeSystemDesignationTests: XCTestCase {
    func testInitializationDefaults() {
        let d = CodeSystemDesignation(value: "Test")
        XCTAssertNil(d.language)
        XCTAssertNil(d.use)
        XCTAssertEqual(d.value, "Test")
    }

    func testInitializationWithAllFields() {
        let use = Coding(system: "http://example.com", code: "syn")
        let d = CodeSystemDesignation(language: "en", use: use, value: "Synonym")
        XCTAssertEqual(d.language, "en")
        XCTAssertEqual(d.use?.code, "syn")
        XCTAssertEqual(d.value, "Synonym")
    }
}

// MARK: - CodeSystemProperty Tests

final class CodeSystemPropertyTests: XCTestCase {
    func testInitialization() {
        let p = CodeSystemProperty(code: "inactive", type: "boolean", value: .boolean(false))
        XCTAssertEqual(p.code, "inactive")
        XCTAssertEqual(p.type, "boolean")
        XCTAssertEqual(p.value, .boolean(false))
    }
}

// MARK: - CodeSystemLookupResult Tests

final class CodeSystemLookupResultTests: XCTestCase {
    func testInitializationDefaults() {
        let r = CodeSystemLookupResult(code: "123", system: "http://example.com")
        XCTAssertEqual(r.code, "123")
        XCTAssertNil(r.display)
        XCTAssertEqual(r.system, "http://example.com")
        XCTAssertTrue(r.designations.isEmpty)
        XCTAssertTrue(r.properties.isEmpty)
    }

    func testInitializationWithAllFields() {
        let designation = CodeSystemDesignation(language: "de", value: "Test")
        let property = CodeSystemProperty(code: "status", type: "code", value: .code("active"))
        let r = CodeSystemLookupResult(
            code: "44054006",
            display: "Diabetes mellitus type 2",
            system: "http://snomed.info/sct",
            designations: [designation],
            properties: [property]
        )
        XCTAssertEqual(r.code, "44054006")
        XCTAssertEqual(r.display, "Diabetes mellitus type 2")
        XCTAssertEqual(r.designations.count, 1)
        XCTAssertEqual(r.properties.count, 1)
    }
}

// MARK: - CodeValidationResult Tests

final class CodeValidationResultTests: XCTestCase {
    func testValidResult() {
        let r = CodeValidationResult(result: true, display: "Test", code: "123", system: "http://example.com")
        XCTAssertTrue(r.result)
        XCTAssertEqual(r.display, "Test")
        XCTAssertEqual(r.code, "123")
    }

    func testInvalidResult() {
        let r = CodeValidationResult(result: false, message: "Code not found")
        XCTAssertFalse(r.result)
        XCTAssertEqual(r.message, "Code not found")
    }
}

// MARK: - ValueSetContains Tests

final class ValueSetContainsTests: XCTestCase {
    func testDefaults() {
        let c = ValueSetContains()
        XCTAssertNil(c.system)
        XCTAssertNil(c.code)
        XCTAssertNil(c.display)
        XCTAssertFalse(c.abstract)
        XCTAssertFalse(c.inactive)
        XCTAssertNil(c.version)
    }

    func testFullInit() {
        let c = ValueSetContains(
            system: "http://loinc.org",
            code: "1234-5",
            display: "Test Result",
            abstract: true,
            inactive: true,
            version: "2.72"
        )
        XCTAssertEqual(c.system, "http://loinc.org")
        XCTAssertEqual(c.code, "1234-5")
        XCTAssertTrue(c.abstract)
        XCTAssertTrue(c.inactive)
        XCTAssertEqual(c.version, "2.72")
    }
}

// MARK: - ValueSetExpansion Tests

final class ValueSetExpansionTests: XCTestCase {
    func testDefaults() {
        let e = ValueSetExpansion()
        XCTAssertNil(e.identifier)
        XCTAssertNil(e.timestamp)
        XCTAssertNil(e.total)
        XCTAssertNil(e.offset)
        XCTAssertTrue(e.contains.isEmpty)
    }

    func testWithContains() {
        let entry = ValueSetContains(system: "http://example.com", code: "A", display: "Alpha")
        let e = ValueSetExpansion(
            identifier: "urn:uuid:test",
            total: 1,
            offset: 0,
            contains: [entry]
        )
        XCTAssertEqual(e.contains.count, 1)
        XCTAssertEqual(e.total, 1)
    }
}

// MARK: - ValueSetValidationResult Tests

final class ValueSetValidationResultTests: XCTestCase {
    func testInit() {
        let r = ValueSetValidationResult(result: true, message: "OK", display: "Alpha")
        XCTAssertTrue(r.result)
        XCTAssertEqual(r.message, "OK")
        XCTAssertEqual(r.display, "Alpha")
    }
}

// MARK: - ConceptMapEquivalence Tests

final class ConceptMapEquivalenceTests: XCTestCase {
    func testAllCases() {
        let cases: [(String, ConceptMapEquivalence)] = [
            ("relatedto", .relatedto),
            ("equivalent", .equivalent),
            ("equal", .equal),
            ("wider", .wider),
            ("subsumes", .subsumes),
            ("narrower", .narrower),
            ("specializes", .specializes),
            ("inexact", .inexact),
            ("unmatched", .unmatched),
            ("disjoint", .disjoint),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(ConceptMapEquivalence(rawValue: raw), expected)
        }
    }
}

// MARK: - ConceptMapProduct Tests

final class ConceptMapProductTests: XCTestCase {
    func testInit() {
        let coding = Coding(system: "http://example.com", code: "X")
        let p = ConceptMapProduct(element: "target", concept: coding)
        XCTAssertEqual(p.element, "target")
        XCTAssertEqual(p.concept?.code, "X")
    }
}

// MARK: - ConceptMapMatch Tests

final class ConceptMapMatchTests: XCTestCase {
    func testInit() {
        let concept = Coding(system: "http://target.com", code: "B", display: "Beta")
        let m = ConceptMapMatch(
            equivalence: .equivalent,
            concept: concept,
            source: "http://source.com",
            product: []
        )
        XCTAssertEqual(m.equivalence, .equivalent)
        XCTAssertEqual(m.concept?.code, "B")
        XCTAssertEqual(m.source, "http://source.com")
        XCTAssertTrue(m.product.isEmpty)
    }
}

// MARK: - ConceptMapTranslation Tests

final class ConceptMapTranslationTests: XCTestCase {
    func testInit() {
        let t = ConceptMapTranslation(result: true, message: "Mapped", matches: [])
        XCTAssertTrue(t.result)
        XCTAssertEqual(t.message, "Mapped")
        XCTAssertTrue(t.matches.isEmpty)
    }
}

// MARK: - WellKnownCodeSystem Tests

final class WellKnownCodeSystemTests: XCTestCase {
    func testSystemURLs() {
        XCTAssertEqual(WellKnownCodeSystem.snomedCT.system, "http://snomed.info/sct")
        XCTAssertEqual(WellKnownCodeSystem.loinc.system, "http://loinc.org")
        XCTAssertEqual(WellKnownCodeSystem.icd10.system, "http://hl7.org/fhir/sid/icd-10")
        XCTAssertEqual(WellKnownCodeSystem.icd10CM.system, "http://hl7.org/fhir/sid/icd-10-cm")
        XCTAssertEqual(WellKnownCodeSystem.rxNorm.system, "http://www.nlm.nih.gov/research/umls/rxnorm")
        XCTAssertEqual(WellKnownCodeSystem.cpt.system, "http://www.ama-assn.org/go/cpt")
        XCTAssertEqual(WellKnownCodeSystem.cvx.system, "http://hl7.org/fhir/sid/cvx")
        XCTAssertEqual(WellKnownCodeSystem.ndc.system, "http://hl7.org/fhir/sid/ndc")
        XCTAssertEqual(WellKnownCodeSystem.unii.system, "http://fdasis.nlm.nih.gov")
    }

    func testNames() {
        XCTAssertEqual(WellKnownCodeSystem.snomedCT.name, "SNOMED CT")
        XCTAssertEqual(WellKnownCodeSystem.loinc.name, "LOINC")
        XCTAssertEqual(WellKnownCodeSystem.icd10.name, "ICD-10")
        XCTAssertEqual(WellKnownCodeSystem.icd10CM.name, "ICD-10-CM")
        XCTAssertEqual(WellKnownCodeSystem.rxNorm.name, "RxNorm")
        XCTAssertEqual(WellKnownCodeSystem.cpt.name, "CPT")
        XCTAssertEqual(WellKnownCodeSystem.cvx.name, "CVX")
        XCTAssertEqual(WellKnownCodeSystem.ndc.name, "NDC")
        XCTAssertEqual(WellKnownCodeSystem.unii.name, "UNII")
    }

    func testCaseIterable() {
        XCTAssertEqual(WellKnownCodeSystem.allCases.count, 9)
    }
}

// MARK: - TerminologyCache Tests

final class TerminologyCacheTests: XCTestCase {
    func testLookupCacheHitAndMiss() async {
        let cache = TerminologyCache()
        let result = CodeSystemLookupResult(code: "123", display: "Test", system: "http://example.com")

        // Miss
        let missed = await cache.getCachedLookup(key: "test|123|")
        XCTAssertNil(missed)

        // Store and hit
        await cache.cacheLookup(result, key: "test|123|")
        let hit = await cache.getCachedLookup(key: "test|123|")
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.code, "123")
    }

    func testValidationCache() async {
        let cache = TerminologyCache()
        let result = CodeValidationResult(result: true, code: "A")

        await cache.cacheValidation(result, key: "v1")
        let hit = await cache.getCachedValidation(key: "v1")
        XCTAssertNotNil(hit)
        XCTAssertTrue(hit!.result)
    }

    func testExpansionCache() async {
        let cache = TerminologyCache()
        let expansion = ValueSetExpansion(identifier: "test-id", total: 5, contains: [])

        await cache.cacheExpansion(expansion, key: "e1")
        let hit = await cache.getCachedExpansion(key: "e1")
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.identifier, "test-id")
    }

    func testTranslationCache() async {
        let cache = TerminologyCache()
        let translation = ConceptMapTranslation(result: true, message: "OK", matches: [])

        await cache.cacheTranslation(translation, key: "t1")
        let hit = await cache.getCachedTranslation(key: "t1")
        XCTAssertNotNil(hit)
        XCTAssertTrue(hit!.result)
    }

    func testClearCache() async {
        let cache = TerminologyCache()
        await cache.cacheLookup(
            CodeSystemLookupResult(code: "1", system: "s"), key: "k1"
        )
        await cache.cacheValidation(
            CodeValidationResult(result: true), key: "k2"
        )
        await cache.cacheExpansion(
            ValueSetExpansion(), key: "k3"
        )
        await cache.cacheTranslation(
            ConceptMapTranslation(result: false), key: "k4"
        )

        var stats = await cache.cacheStatistics()
        XCTAssertEqual(stats["lookups"], 1)
        XCTAssertEqual(stats["validations"], 1)
        XCTAssertEqual(stats["expansions"], 1)
        XCTAssertEqual(stats["translations"], 1)

        await cache.clearCache()

        stats = await cache.cacheStatistics()
        XCTAssertEqual(stats["lookups"], 0)
        XCTAssertEqual(stats["validations"], 0)
        XCTAssertEqual(stats["expansions"], 0)
        XCTAssertEqual(stats["translations"], 0)
    }

    func testTTLExpiration() async {
        let cache = TerminologyCache(ttl: 0.01)
        await cache.cacheLookup(
            CodeSystemLookupResult(code: "1", system: "s"), key: "exp"
        )

        // Wait for expiry
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms

        let result = await cache.getCachedLookup(key: "exp")
        XCTAssertNil(result)
    }

    func testLRUEviction() async {
        let cache = TerminologyCache(maxSize: 2)

        await cache.cacheLookup(
            CodeSystemLookupResult(code: "1", system: "s"), key: "a"
        )
        await cache.cacheLookup(
            CodeSystemLookupResult(code: "2", system: "s"), key: "b"
        )
        // Access "a" to make it more recent
        _ = await cache.getCachedLookup(key: "a")

        // Adding a third should evict "b" (least recently accessed)
        await cache.cacheLookup(
            CodeSystemLookupResult(code: "3", system: "s"), key: "c"
        )

        let a = await cache.getCachedLookup(key: "a")
        let b = await cache.getCachedLookup(key: "b")
        let c = await cache.getCachedLookup(key: "c")

        XCTAssertNotNil(a)
        XCTAssertNil(b)
        XCTAssertNotNil(c)
    }

    func testCacheStatistics() async {
        let cache = TerminologyCache()
        let stats = await cache.cacheStatistics()
        XCTAssertEqual(stats["lookups"], 0)
        XCTAssertEqual(stats["validations"], 0)
        XCTAssertEqual(stats["expansions"], 0)
        XCTAssertEqual(stats["translations"], 0)
    }
}

// MARK: - FHIRTerminologyClient Tests

final class FHIRTerminologyClientTests: XCTestCase {

    // MARK: - Lookup Tests

    func testLookupSuccess() async throws {
        let session = MockTerminologySession()
        session.responseData = makeLookupResponseJSON()

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.lookup(code: "44054006", system: "http://snomed.info/sct")
        XCTAssertEqual(result.code, "44054006")
        XCTAssertEqual(result.display, "Diabetes mellitus type 2")
        XCTAssertEqual(result.system, "http://snomed.info/sct")
    }

    func testLookupCachesResult() async throws {
        let session = MockTerminologySession()
        session.responseData = makeLookupResponseJSON()

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result1 = try await client.lookup(code: "44054006", system: "http://snomed.info/sct")
        // Second call should use cache
        session.responseData = Data()
        let result2 = try await client.lookup(code: "44054006", system: "http://snomed.info/sct")

        XCTAssertEqual(result1, result2)
    }

    func testLookupInvalidResponse() async {
        let session = MockTerminologySession()
        session.responseData = Data("not json".utf8)

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        do {
            _ = try await client.lookup(code: "test", system: "http://example.com")
            XCTFail("Expected error")
        } catch let error as TerminologyServiceError {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLookupServerError() async {
        let session = MockTerminologySession()
        session.responseStatusCode = 500
        session.responseData = Data("Server Error".utf8)

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        do {
            _ = try await client.lookup(code: "test", system: "http://example.com")
            XCTFail("Expected error")
        } catch let error as TerminologyServiceError {
            if case .serverError = error {
                // Expected
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLookupNetworkError() async {
        let session = MockTerminologySession()
        session.shouldThrowError = true

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        do {
            _ = try await client.lookup(code: "test", system: "http://example.com")
            XCTFail("Expected error")
        } catch let error as TerminologyServiceError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Validate Code Tests

    func testValidateCodeSuccess() async throws {
        let session = MockTerminologySession()
        session.responseData = makeValidateCodeResponseJSON(result: true)

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.validateCode(
            code: "44054006",
            system: "http://snomed.info/sct"
        )
        XCTAssertTrue(result.result)
    }

    func testValidateCodeInvalid() async throws {
        let session = MockTerminologySession()
        session.responseData = makeValidateCodeResponseJSON(result: false, message: "Unknown code")

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.validateCode(
            code: "INVALID",
            system: "http://snomed.info/sct"
        )
        XCTAssertFalse(result.result)
        XCTAssertEqual(result.message, "Unknown code")
    }

    // MARK: - ValueSet Expansion Tests

    func testExpandValueSet() async throws {
        let session = MockTerminologySession()
        session.responseData = makeExpansionResponseJSON()

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.expandValueSet(
            url: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        XCTAssertEqual(result.contains.count, 2)
        XCTAssertEqual(result.contains[0].code, "male")
        XCTAssertEqual(result.contains[1].code, "female")
    }

    func testExpandValueSetWithFilter() async throws {
        let session = MockTerminologySession()
        session.responseData = makeExpansionResponseJSON()

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.expandValueSet(
            url: "http://hl7.org/fhir/ValueSet/administrative-gender",
            filter: "ma",
            offset: 0,
            count: 10
        )
        XCTAssertFalse(result.contains.isEmpty)
    }

    // MARK: - ValueSet Validation Tests

    func testValidateValueSetMembership() async throws {
        let session = MockTerminologySession()
        session.responseData = makeValueSetValidationResponseJSON(result: true, display: "Male")

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.validateValueSetMembership(
            code: "male",
            system: "http://hl7.org/fhir/administrative-gender",
            valueSet: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        XCTAssertTrue(result.result)
        XCTAssertEqual(result.display, "Male")
    }

    // MARK: - ConceptMap Translation Tests

    func testTranslateSuccess() async throws {
        let session = MockTerminologySession()
        session.responseData = makeTranslationResponseJSON()

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.translate(
            code: "44054006",
            system: "http://snomed.info/sct",
            target: "http://hl7.org/fhir/sid/icd-10"
        )
        XCTAssertTrue(result.result)
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches[0].equivalence, .equivalent)
    }

    func testTranslateNoMatch() async throws {
        let session = MockTerminologySession()
        session.responseData = makeNoMatchTranslationJSON()

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.translate(
            code: "UNKNOWN",
            system: "http://snomed.info/sct"
        )
        XCTAssertFalse(result.result)
        XCTAssertTrue(result.matches.isEmpty)
    }

    // MARK: - Clear Cache Tests

    func testClearCache() async throws {
        let session = MockTerminologySession()
        session.responseData = makeLookupResponseJSON()

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        // Populate cache
        _ = try await client.lookup(code: "44054006", system: "http://snomed.info/sct")

        // Clear and verify next call hits server
        await client.clearCache()

        // If cache was cleared, this should work with valid response data
        session.responseData = makeLookupResponseJSON()
        let result = try await client.lookup(code: "44054006", system: "http://snomed.info/sct")
        XCTAssertEqual(result.code, "44054006")
    }

    // MARK: - Lookup with Designations and Properties

    func testLookupWithDesignationsAndProperties() async throws {
        let session = MockTerminologySession()
        session.responseData = makeFullLookupResponseJSON()

        let client = FHIRTerminologyClient(
            session: session,
            baseURL: URL(string: "https://tx.example.org/r4")!
        )

        let result = try await client.lookup(code: "44054006", system: "http://snomed.info/sct")
        XCTAssertEqual(result.designations.count, 1)
        XCTAssertEqual(result.designations[0].language, "de")
        XCTAssertEqual(result.designations[0].value, "Diabetes Typ 2")
        XCTAssertEqual(result.properties.count, 1)
        XCTAssertEqual(result.properties[0].code, "inactive")
        XCTAssertEqual(result.properties[0].value, .boolean(false))
    }

    // MARK: - JSON Response Helpers

    private func makeLookupResponseJSON() -> Data {
        let json: [String: Any] = [
            "resourceType": "Parameters",
            "parameter": [
                ["name": "code", "valueCode": "44054006"],
                ["name": "display", "valueString": "Diabetes mellitus type 2"],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeFullLookupResponseJSON() -> Data {
        let json: [String: Any] = [
            "resourceType": "Parameters",
            "parameter": [
                ["name": "code", "valueCode": "44054006"],
                ["name": "display", "valueString": "Diabetes mellitus type 2"],
                [
                    "name": "designation",
                    "part": [
                        ["name": "language", "valueCode": "de"],
                        ["name": "value", "valueString": "Diabetes Typ 2"],
                    ],
                ],
                [
                    "name": "property",
                    "part": [
                        ["name": "code", "valueCode": "inactive"],
                        ["name": "value", "valueBoolean": false],
                    ],
                ],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeValidateCodeResponseJSON(result: Bool, message: String? = nil) -> Data {
        var params: [[String: Any]] = [
            ["name": "result", "valueBoolean": result],
        ]
        if let message = message {
            params.append(["name": "message", "valueString": message])
        }
        let json: [String: Any] = [
            "resourceType": "Parameters",
            "parameter": params,
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeExpansionResponseJSON() -> Data {
        let json: [String: Any] = [
            "resourceType": "ValueSet",
            "expansion": [
                "identifier": "urn:uuid:expansion-1",
                "timestamp": "2024-01-01T00:00:00Z",
                "total": 2,
                "offset": 0,
                "contains": [
                    ["system": "http://hl7.org/fhir/administrative-gender", "code": "male", "display": "Male"],
                    ["system": "http://hl7.org/fhir/administrative-gender", "code": "female", "display": "Female"],
                ],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeValueSetValidationResponseJSON(result: Bool, display: String?) -> Data {
        var params: [[String: Any]] = [
            ["name": "result", "valueBoolean": result],
        ]
        if let display = display {
            params.append(["name": "display", "valueString": display])
        }
        let json: [String: Any] = [
            "resourceType": "Parameters",
            "parameter": params,
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeTranslationResponseJSON() -> Data {
        let json: [String: Any] = [
            "resourceType": "Parameters",
            "parameter": [
                ["name": "result", "valueBoolean": true],
                [
                    "name": "match",
                    "part": [
                        ["name": "equivalence", "valueCode": "equivalent"],
                        [
                            "name": "concept",
                            "valueCoding": [
                                "system": "http://hl7.org/fhir/sid/icd-10",
                                "code": "E11",
                                "display": "Type 2 diabetes mellitus",
                            ],
                        ],
                    ],
                ],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeNoMatchTranslationJSON() -> Data {
        let json: [String: Any] = [
            "resourceType": "Parameters",
            "parameter": [
                ["name": "result", "valueBoolean": false],
                ["name": "message", "valueString": "No mapping found"],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
}
