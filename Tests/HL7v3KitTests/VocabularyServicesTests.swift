/// VocabularyServicesTests.swift
/// Tests for vocabulary services framework

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

final class VocabularyServicesTests: XCTestCase {
    
    // MARK: - Concept Tests
    
    func testConceptCreation() {
        let concept = Concept(
            code: "386661006",
            display: "Fever",
            definition: "Elevated body temperature",
            codeSystem: CodeSystem.snomedCT,
            codeSystemVersion: "2023-01",
            properties: ["severity": "moderate"],
            parents: ["271737000"],
            children: ["425151000"]
        )
        
        XCTAssertEqual(concept.code, "386661006")
        XCTAssertEqual(concept.display, "Fever")
        XCTAssertEqual(concept.definition, "Elevated body temperature")
        XCTAssertEqual(concept.codeSystem, CodeSystem.snomedCT)
        XCTAssertEqual(concept.codeSystemVersion, "2023-01")
        XCTAssertEqual(concept.properties?["severity"], "moderate")
        XCTAssertEqual(concept.parents, ["271737000"])
        XCTAssertEqual(concept.children, ["425151000"])
    }
    
    func testConceptEquality() {
        let concept1 = Concept(code: "123", display: "Test", codeSystem: CodeSystem.loinc)
        let concept2 = Concept(code: "123", display: "Test", codeSystem: CodeSystem.loinc)
        let concept3 = Concept(code: "456", display: "Other", codeSystem: CodeSystem.loinc)
        
        XCTAssertEqual(concept1, concept2)
        XCTAssertNotEqual(concept1, concept3)
    }
    
    // MARK: - BasicCodeSystem Tests
    
    func testBasicCodeSystemCreation() {
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender),
            Concept(code: "F", display: "Female", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let codeSystem = BasicCodeSystem(
            identifier: CodeSystem.administrativeGender,
            name: "AdministrativeGender",
            version: "1.0",
            description: "Administrative gender codes",
            publisher: "HL7",
            concepts: concepts
        )
        
        XCTAssertEqual(codeSystem.identifier, CodeSystem.administrativeGender)
        XCTAssertEqual(codeSystem.name, "AdministrativeGender")
        XCTAssertEqual(codeSystem.version, "1.0")
    }
    
    func testCodeSystemLookup() async throws {
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender),
            Concept(code: "F", display: "Female", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let codeSystem = BasicCodeSystem(
            identifier: CodeSystem.administrativeGender,
            name: "AdministrativeGender",
            concepts: concepts
        )
        
        let maleConcept = try await codeSystem.lookupConcept(code: "M")
        XCTAssertNotNil(maleConcept)
        XCTAssertEqual(maleConcept?.code, "M")
        XCTAssertEqual(maleConcept?.display, "Male")
        
        let invalidConcept = try await codeSystem.lookupConcept(code: "X")
        XCTAssertNil(invalidConcept)
    }
    
    func testCodeSystemValidation() async throws {
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender),
            Concept(code: "F", display: "Female", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let codeSystem = BasicCodeSystem(
            identifier: CodeSystem.administrativeGender,
            name: "AdministrativeGender",
            concepts: concepts
        )
        
        let isValidM = try await codeSystem.validateCode("M")
        XCTAssertTrue(isValidM)
        
        let isValidF = try await codeSystem.validateCode("F")
        XCTAssertTrue(isValidF)
        
        let isValidX = try await codeSystem.validateCode("X")
        XCTAssertFalse(isValidX)
    }
    
    // MARK: - BasicValueSet Tests
    
    func testBasicValueSetCreation() {
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender),
            Concept(code: "F", display: "Female", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let valueSet = BasicValueSet(
            identifier: "2.16.840.1.113883.1.11.1",
            name: "AdministrativeGender",
            version: "1.0",
            description: "Administrative gender codes",
            publisher: "HL7",
            concepts: concepts
        )
        
        XCTAssertEqual(valueSet.identifier, "2.16.840.1.113883.1.11.1")
        XCTAssertEqual(valueSet.name, "AdministrativeGender")
        XCTAssertTrue(valueSet.isExpanded)
    }
    
    func testValueSetExpansion() async throws {
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender),
            Concept(code: "F", display: "Female", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let valueSet = BasicValueSet(
            identifier: "2.16.840.1.113883.1.11.1",
            name: "AdministrativeGender",
            concepts: concepts
        )
        
        let expanded = try await valueSet.expand()
        XCTAssertEqual(expanded.count, 2)
        XCTAssertTrue(expanded.contains(where: { $0.code == "M" }))
        XCTAssertTrue(expanded.contains(where: { $0.code == "F" }))
    }
    
    func testValueSetContains() async throws {
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender),
            Concept(code: "F", display: "Female", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let valueSet = BasicValueSet(
            identifier: "2.16.840.1.113883.1.11.1",
            name: "AdministrativeGender",
            concepts: concepts
        )
        
        let containsM = try await valueSet.contains(
            code: "M",
            codeSystem: CodeSystem.administrativeGender
        )
        XCTAssertTrue(containsM)
        
        let containsX = try await valueSet.contains(
            code: "X",
            codeSystem: CodeSystem.administrativeGender
        )
        XCTAssertFalse(containsX)
    }
    
    func testValueSetValidation() async throws {
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender),
            Concept(code: "F", display: "Female", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let valueSet = BasicValueSet(
            identifier: "2.16.840.1.113883.1.11.1",
            name: "AdministrativeGender",
            concepts: concepts
        )
        
        let validCode = CD(
            code: "M",
            codeSystem: CodeSystem.administrativeGender,
            displayName: "Male"
        )
        
        let result = try await valueSet.validate(codedValue: validCode)
        XCTAssertTrue(result.isValid)
        XCTAssertNotNil(result.concept)
        XCTAssertEqual(result.concept?.code, "M")
        
        let invalidCode = CD(
            code: "X",
            codeSystem: CodeSystem.administrativeGender,
            displayName: "Invalid"
        )
        
        let invalidResult = try await valueSet.validate(codedValue: invalidCode)
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertNil(invalidResult.concept)
        XCTAssertNotNil(invalidResult.message)
    }
    
    func testValueSetValidationMissingCode() async throws {
        let valueSet = BasicValueSet(
            identifier: "test",
            name: "Test"
        )
        
        let invalidCode = CD(nullFlavor: .unknown)
        let result = try await valueSet.validate(codedValue: invalidCode)
        
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.message)
    }
    
    // MARK: - VocabularyService Tests
    
    func testVocabularyServiceRegistration() async {
        let service = VocabularyService()
        
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let codeSystem = BasicCodeSystem(
            identifier: CodeSystem.administrativeGender,
            name: "AdministrativeGender",
            concepts: concepts
        )
        
        await service.registerCodeSystem(codeSystem)
        
        let retrieved = await service.getCodeSystem(identifier: CodeSystem.administrativeGender)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.identifier, CodeSystem.administrativeGender)
    }
    
    func testVocabularyServiceLookupWithCaching() async throws {
        let service = VocabularyService()
        
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender),
            Concept(code: "F", display: "Female", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let codeSystem = BasicCodeSystem(
            identifier: CodeSystem.administrativeGender,
            name: "AdministrativeGender",
            concepts: concepts
        )
        
        await service.registerCodeSystem(codeSystem)
        
        // First lookup (cache miss)
        let concept1 = try await service.lookupConcept(
            code: "M",
            codeSystem: CodeSystem.administrativeGender
        )
        XCTAssertNotNil(concept1)
        XCTAssertEqual(concept1?.code, "M")
        
        // Second lookup (cache hit)
        let concept2 = try await service.lookupConcept(
            code: "M",
            codeSystem: CodeSystem.administrativeGender
        )
        XCTAssertNotNil(concept2)
        XCTAssertEqual(concept2?.code, "M")
        
        // Check cache stats
        let stats = await service.getCacheStats()
        XCTAssertEqual(stats.size, 1)
    }
    
    func testVocabularyServiceCodeValidation() async throws {
        let service = VocabularyService()
        
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let codeSystem = BasicCodeSystem(
            identifier: CodeSystem.administrativeGender,
            name: "AdministrativeGender",
            concepts: concepts
        )
        
        await service.registerCodeSystem(codeSystem)
        
        let isValid = try await service.validateCode(
            "M",
            codeSystem: CodeSystem.administrativeGender
        )
        XCTAssertTrue(isValid)
        
        let isInvalid = try await service.validateCode(
            "X",
            codeSystem: CodeSystem.administrativeGender
        )
        XCTAssertFalse(isInvalid)
    }
    
    func testVocabularyServiceCodeSystemNotFound() async {
        let service = VocabularyService()
        
        do {
            _ = try await service.lookupConcept(
                code: "M",
                codeSystem: "invalid.oid"
            )
            XCTFail("Should throw error")
        } catch let error as VocabularyError {
            if case .codeSystemNotFound(let oid) = error {
                XCTAssertEqual(oid, "invalid.oid")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testVocabularyServiceValueSetRegistration() async {
        let service = VocabularyService()
        
        let valueSet = BasicValueSet(
            identifier: "test.valueset",
            name: "Test"
        )
        
        await service.registerValueSet(valueSet)
        
        let retrieved = await service.getValueSet(identifier: "test.valueset")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.identifier, "test.valueset")
    }
    
    func testVocabularyServiceValueSetValidation() async throws {
        let service = VocabularyService()
        
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let valueSet = BasicValueSet(
            identifier: "test.valueset",
            name: "Test",
            concepts: concepts
        )
        
        await service.registerValueSet(valueSet)
        
        let code = CD(
            code: "M",
            codeSystem: CodeSystem.administrativeGender,
            displayName: "Male"
        )
        
        let result = try await service.validateAgainstValueSet(
            codedValue: code,
            valueSet: "test.valueset"
        )
        
        XCTAssertTrue(result.isValid)
    }
    
    func testVocabularyServiceIsInValueSet() async throws {
        let service = VocabularyService()
        
        let concepts = [
            Concept(code: "M", display: "Male", codeSystem: CodeSystem.administrativeGender)
        ]
        
        let valueSet = BasicValueSet(
            identifier: "test.valueset",
            name: "Test",
            concepts: concepts
        )
        
        await service.registerValueSet(valueSet)
        
        let isIn = try await service.isInValueSet(
            code: "M",
            codeSystem: CodeSystem.administrativeGender,
            valueSet: "test.valueset"
        )
        XCTAssertTrue(isIn)
        
        let isNotIn = try await service.isInValueSet(
            code: "X",
            codeSystem: CodeSystem.administrativeGender,
            valueSet: "test.valueset"
        )
        XCTAssertFalse(isNotIn)
    }
    
    func testVocabularyServiceCacheManagement() async throws {
        let service = VocabularyService(maxCacheSize: 2)
        
        let concepts = [
            Concept(code: "1", display: "One", codeSystem: "test"),
            Concept(code: "2", display: "Two", codeSystem: "test"),
            Concept(code: "3", display: "Three", codeSystem: "test")
        ]
        
        let codeSystem = BasicCodeSystem(
            identifier: "test",
            name: "Test",
            concepts: concepts
        )
        
        await service.registerCodeSystem(codeSystem)
        
        // Fill cache
        _ = try await service.lookupConcept(code: "1", codeSystem: "test")
        _ = try await service.lookupConcept(code: "2", codeSystem: "test")
        
        var stats = await service.getCacheStats()
        XCTAssertEqual(stats.size, 2)
        
        // Trigger cache eviction (should evict "1" which was least recently used)
        _ = try await service.lookupConcept(code: "3", codeSystem: "test")
        
        stats = await service.getCacheStats()
        XCTAssertEqual(stats.size, 2) // Cache should be limited to max size of 2
        
        // Clear cache
        await service.clearCache()
        stats = await service.getCacheStats()
        XCTAssertEqual(stats.size, 0)
    }
    
    // MARK: - Standard Value Sets Tests
    
    func testStandardAdministrativeGenderValueSet() async throws {
        let valueSet = StandardValueSets.administrativeGender()
        
        XCTAssertEqual(valueSet.identifier, "2.16.840.1.113883.1.11.1")
        XCTAssertEqual(valueSet.name, "AdministrativeGender")
        XCTAssertTrue(valueSet.isExpanded)
        
        let concepts = try await valueSet.expand()
        XCTAssertEqual(concepts.count, 4)
        
        let containsMale = try await valueSet.contains(
            code: "M",
            codeSystem: CodeSystem.administrativeGender
        )
        XCTAssertTrue(containsMale)
    }
    
    func testStandardConfidentialityCodesValueSet() async throws {
        let valueSet = StandardValueSets.confidentialityCodes()
        
        XCTAssertEqual(valueSet.identifier, "2.16.840.1.113883.1.11.10228")
        XCTAssertEqual(valueSet.name, "ConfidentialityCode")
        
        let concepts = try await valueSet.expand()
        XCTAssertEqual(concepts.count, 3)
        
        let containsNormal = try await valueSet.contains(
            code: "N",
            codeSystem: CodeSystem.confidentiality
        )
        XCTAssertTrue(containsNormal)
    }
    
    // MARK: - External Terminology Service Tests
    
    func testSNOMEDCTServiceStub() async {
        let service = SNOMEDCTService()
        
        XCTAssertEqual(service.serviceName, "SNOMED CT")
        
        // Test that stubs throw appropriate errors
        do {
            _ = try await service.lookupConcept(code: "123", codeSystem: CodeSystem.snomedCT)
            XCTFail("Should throw error")
        } catch let error as VocabularyError {
            if case .expansionFailed(let message) = error {
                XCTAssertTrue(message.contains("not yet implemented"))
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testLOINCServiceStub() async {
        let service = LOINCService()
        
        XCTAssertEqual(service.serviceName, "LOINC")
        
        do {
            _ = try await service.validateCode("123", codeSystem: CodeSystem.loinc)
            XCTFail("Should throw error")
        } catch let error as VocabularyError {
            if case .validationFailed(let message) = error {
                XCTAssertTrue(message.contains("not yet implemented"))
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testICDServiceStub() async {
        let service = ICDService(version: "ICD-10")
        
        XCTAssertEqual(service.serviceName, "ICD")
        
        do {
            _ = try await service.expandValueSet(identifier: "test")
            XCTFail("Should throw error")
        } catch let error as VocabularyError {
            if case .expansionFailed(let message) = error {
                XCTAssertTrue(message.contains("not yet implemented"))
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    // MARK: - Vocabulary Error Tests
    
    func testVocabularyErrorDescriptions() {
        let error1 = VocabularyError.codeSystemNotFound("test.oid")
        XCTAssertTrue(error1.localizedDescription.contains("Code system not found"))
        
        let error2 = VocabularyError.valueSetNotFound("test.vs")
        XCTAssertTrue(error2.localizedDescription.contains("Value set not found"))
        
        let error3 = VocabularyError.conceptNotFound("123", "test")
        XCTAssertTrue(error3.localizedDescription.contains("Concept not found"))
        
        let error4 = VocabularyError.invalidCode("test")
        XCTAssertTrue(error4.localizedDescription.contains("Invalid code"))
        
        let error5 = VocabularyError.expansionFailed("test")
        XCTAssertTrue(error5.localizedDescription.contains("expansion failed"))
        
        let error6 = VocabularyError.validationFailed("test")
        XCTAssertTrue(error6.localizedDescription.contains("Validation failed"))
    }
    
    // MARK: - Integration Tests
    
    func testFullVocabularyWorkflow() async throws {
        // Create a vocabulary service
        let service = VocabularyService()
        
        // Create and register a code system
        let concepts = [
            Concept(
                code: "386661006",
                display: "Fever",
                definition: "Elevated body temperature",
                codeSystem: CodeSystem.snomedCT
            ),
            Concept(
                code: "25064002",
                display: "Headache",
                definition: "Pain in the head",
                codeSystem: CodeSystem.snomedCT
            )
        ]
        
        let codeSystem = BasicCodeSystem(
            identifier: CodeSystem.snomedCT,
            name: "SNOMED CT",
            concepts: concepts
        )
        
        await service.registerCodeSystem(codeSystem)
        
        // Create and register a value set
        let valueSet = BasicValueSet(
            identifier: "symptoms.valueset",
            name: "Common Symptoms",
            concepts: concepts
        )
        
        await service.registerValueSet(valueSet)
        
        // Lookup a concept
        let concept = try await service.lookupConcept(
            code: "386661006",
            codeSystem: CodeSystem.snomedCT
        )
        XCTAssertNotNil(concept)
        XCTAssertEqual(concept?.display, "Fever")
        
        // Validate a code
        let isValid = try await service.validateCode(
            "386661006",
            codeSystem: CodeSystem.snomedCT
        )
        XCTAssertTrue(isValid)
        
        // Check if code is in value set
        let isInValueSet = try await service.isInValueSet(
            code: "386661006",
            codeSystem: CodeSystem.snomedCT,
            valueSet: "symptoms.valueset"
        )
        XCTAssertTrue(isInValueSet)
        
        // Validate against value set
        let code = CD(
            code: "386661006",
            codeSystem: CodeSystem.snomedCT,
            displayName: "Fever"
        )
        
        let result = try await service.validateAgainstValueSet(
            codedValue: code,
            valueSet: "symptoms.valueset"
        )
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.concept?.display, "Fever")
    }
}
