/// FHIRValidationTests.swift
/// Comprehensive tests for the FHIR Validation Engine

import XCTest
@testable import FHIRkit
@testable import HL7Core

// MARK: - Core Validation Types Tests

final class FHIRValidationCoreTests: XCTestCase {

    // MARK: - ElementDefinition Tests

    func testElementDefinitionRequired() {
        let element = ElementDefinition(path: "Patient.name", min: 1, max: "*")
        XCTAssertTrue(element.isRequired)
        XCTAssertFalse(element.isProhibited)
        XCTAssertNil(element.maxInt)
    }

    func testElementDefinitionOptional() {
        let element = ElementDefinition(path: "Patient.gender", min: 0, max: "1")
        XCTAssertFalse(element.isRequired)
        XCTAssertFalse(element.isProhibited)
        XCTAssertEqual(element.maxInt, 1)
    }

    func testElementDefinitionProhibited() {
        let element = ElementDefinition(path: "Patient.deceased", min: 0, max: "0")
        XCTAssertFalse(element.isRequired)
        XCTAssertTrue(element.isProhibited)
        XCTAssertEqual(element.maxInt, 0)
    }

    func testElementDefinitionWithBinding() {
        let binding = ElementBinding(
            strength: .required,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender",
            description: "Gender codes"
        )
        let element = ElementDefinition(
            path: "Patient.gender",
            min: 0,
            max: "1",
            binding: binding
        )
        XCTAssertNotNil(element.binding)
        XCTAssertEqual(element.binding?.strength, .required)
    }

    func testElementDefinitionWithConstraints() {
        let constraint = ElementConstraint(
            key: "pat-1",
            severity: .error,
            human: "Contact must have name or telecom",
            expression: "name.exists() or telecom.exists()"
        )
        let element = ElementDefinition(
            path: "Patient.contact",
            constraints: [constraint]
        )
        XCTAssertEqual(element.constraints.count, 1)
        XCTAssertEqual(element.constraints[0].key, "pat-1")
    }

    func testElementDefinitionWithMustSupport() {
        let element = ElementDefinition(path: "Patient.name", mustSupport: true)
        XCTAssertTrue(element.mustSupport)
    }

    func testElementDefinitionWithSliceName() {
        let element = ElementDefinition(
            path: "Patient.identifier",
            sliceName: "MRN"
        )
        XCTAssertEqual(element.sliceName, "MRN")
    }

    // MARK: - StructureDefinition Tests

    func testStructureDefinitionCreation() {
        let profile = StructureDefinition(
            url: "http://example.com/profile",
            name: "TestProfile",
            title: "Test Profile",
            status: .active,
            kind: .resource,
            type: "Patient",
            version: "1.0.0",
            elements: [
                ElementDefinition(path: "Patient.name", min: 1, max: "*")
            ]
        )
        XCTAssertEqual(profile.url, "http://example.com/profile")
        XCTAssertEqual(profile.name, "TestProfile")
        XCTAssertEqual(profile.type, "Patient")
        XCTAssertEqual(profile.status, .active)
        XCTAssertEqual(profile.kind, .resource)
        XCTAssertEqual(profile.elements.count, 1)
    }

    func testStructureDefinitionWithBaseDefinition() {
        let profile = StructureDefinition(
            url: "http://example.com/derived",
            name: "DerivedProfile",
            status: .active,
            baseDefinition: "http://hl7.org/fhir/StructureDefinition/Patient",
            type: "Patient"
        )
        XCTAssertEqual(profile.baseDefinition, "http://hl7.org/fhir/StructureDefinition/Patient")
    }

    // MARK: - Validation Outcome Tests

    func testValidationOutcomeValid() {
        let outcome = FHIRValidationOutcome(issues: [])
        XCTAssertTrue(outcome.isValid)
        XCTAssertTrue(outcome.errors.isEmpty)
        XCTAssertTrue(outcome.warnings.isEmpty)
        XCTAssertTrue(outcome.informational.isEmpty)
    }

    func testValidationOutcomeWithErrors() {
        let outcome = FHIRValidationOutcome(issues: [
            FHIRValidationIssue(severity: .error, code: .required, details: "Missing field"),
            FHIRValidationIssue(severity: .warning, code: .value, details: "Bad value"),
            FHIRValidationIssue(severity: .information, code: .invariant, details: "Info")
        ])
        XCTAssertFalse(outcome.isValid)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertEqual(outcome.warnings.count, 1)
        XCTAssertEqual(outcome.informational.count, 1)
    }

    func testValidationOutcomeWithWarningsOnly() {
        let outcome = FHIRValidationOutcome(issues: [
            FHIRValidationIssue(severity: .warning, code: .value, details: "Not ideal")
        ])
        XCTAssertTrue(outcome.isValid)
        XCTAssertEqual(outcome.warnings.count, 1)
    }

    func testValidationOutcomeToOperationOutcome() {
        let outcome = FHIRValidationOutcome(issues: [
            FHIRValidationIssue(
                severity: .error,
                code: .required,
                details: "Missing name",
                expression: "Patient.name",
                constraintKey: "us-core-1"
            )
        ])
        let opOutcome = outcome.toOperationOutcome()
        XCTAssertEqual(opOutcome.issue.count, 1)
        XCTAssertEqual(opOutcome.issue[0].severity, "error")
        XCTAssertEqual(opOutcome.issue[0].code, "required")
        XCTAssertEqual(opOutcome.issue[0].details?.text, "Missing name")
        XCTAssertEqual(opOutcome.issue[0].expression, ["Patient.name"])
    }

    func testValidationOutcomeValidToOperationOutcome() {
        let outcome = FHIRValidationOutcome(issues: [])
        let opOutcome = outcome.toOperationOutcome()
        XCTAssertEqual(opOutcome.issue.count, 1)
        XCTAssertEqual(opOutcome.issue[0].severity, "information")
    }

    // MARK: - Issue Collector Tests

    func testIssueCollectorBasic() {
        let collector = ValidationIssueCollector()
        collector.addError("Error 1", path: "Patient.name")
        collector.addWarning("Warning 1", path: "Patient.gender")
        collector.addInfo("Info 1")

        XCTAssertEqual(collector.issues.count, 3)
        XCTAssertTrue(collector.hasErrors)
    }

    func testIssueCollectorMaxIssues() {
        let collector = ValidationIssueCollector(maxIssues: 3)
        for i in 0..<10 {
            collector.addError("Error \(i)")
        }
        XCTAssertEqual(collector.issues.count, 3)
    }

    func testIssueCollectorToOutcome() {
        let collector = ValidationIssueCollector()
        collector.addError("Error")
        let outcome = collector.toOutcome()
        XCTAssertFalse(outcome.isValid)
    }

    func testIssueCollectorNoErrors() {
        let collector = ValidationIssueCollector()
        collector.addWarning("Just a warning")
        XCTAssertFalse(collector.hasErrors)
        let outcome = collector.toOutcome()
        XCTAssertTrue(outcome.isValid)
    }

    // MARK: - Issue Severity Tests

    func testIssueSeverityOrdering() {
        XCTAssertTrue(IssueSeverity.information < IssueSeverity.warning)
        XCTAssertTrue(IssueSeverity.warning < IssueSeverity.error)
        XCTAssertTrue(IssueSeverity.error < IssueSeverity.fatal)
    }

    // MARK: - Binding Strength Tests

    func testBindingStrengthRawValues() {
        XCTAssertEqual(BindingStrength.required.rawValue, "required")
        XCTAssertEqual(BindingStrength.extensible.rawValue, "extensible")
        XCTAssertEqual(BindingStrength.preferred.rawValue, "preferred")
        XCTAssertEqual(BindingStrength.example.rawValue, "example")
    }
}

// MARK: - Cardinality Validator Tests

final class FHIRCardinalityValidatorTests: XCTestCase {
    let validator = FHIRCardinalityValidator()

    func testRequiredElementPresent() {
        let def = ElementDefinition(path: "Patient.name", min: 1, max: "*")
        let collector = ValidationIssueCollector()
        validator.validate(definition: def, count: 1, collector: collector)
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testRequiredElementMissing() {
        let def = ElementDefinition(path: "Patient.name", min: 1, max: "*")
        let collector = ValidationIssueCollector()
        validator.validate(definition: def, count: 0, collector: collector)
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].severity, .error)
        XCTAssertEqual(collector.issues[0].code, .required)
    }

    func testMaxCardinalityExceeded() {
        let def = ElementDefinition(path: "Patient.gender", min: 0, max: "1")
        let collector = ValidationIssueCollector()
        validator.validate(definition: def, count: 2, collector: collector)
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].code, .structure)
    }

    func testProhibitedElementPresent() {
        let def = ElementDefinition(path: "Patient.extension", min: 0, max: "0")
        let collector = ValidationIssueCollector()
        validator.validate(definition: def, count: 1, collector: collector)
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].code, .structure)
    }

    func testProhibitedElementAbsent() {
        let def = ElementDefinition(path: "Patient.extension", min: 0, max: "0")
        let collector = ValidationIssueCollector()
        validator.validate(definition: def, count: 0, collector: collector)
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testUnboundedMaxCardinality() {
        let def = ElementDefinition(path: "Patient.name", min: 0, max: "*")
        let collector = ValidationIssueCollector()
        validator.validate(definition: def, count: 100, collector: collector)
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testRequiredFieldsValidation() {
        let elements = [
            ElementDefinition(path: "Patient.name", min: 1, max: "*"),
            ElementDefinition(path: "Patient.gender", min: 1, max: "1")
        ]
        let data: [String: Any] = [
            "resourceType": "Patient",
            "name": [["family": "Smith"]]
            // Missing gender
        ]
        let collector = ValidationIssueCollector()
        validator.validateRequiredFields(
            elements: elements,
            resourceData: data,
            resourceType: "Patient",
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1) // Missing gender
    }

    func testExtractFieldName() {
        XCTAssertEqual(
            validator.extractFieldName(from: "Patient.name", resourceType: "Patient"),
            "name"
        )
        XCTAssertNil(
            validator.extractFieldName(from: "Patient.name.family", resourceType: "Patient")
        )
        XCTAssertNil(
            validator.extractFieldName(from: "Observation.status", resourceType: "Patient")
        )
    }

    func testElementCountArray() {
        XCTAssertEqual(validator.elementCount(["a", "b", "c"] as [Any]), 3)
        XCTAssertEqual(validator.elementCount([] as [Any]), 0)
    }

    func testElementCountSingle() {
        XCTAssertEqual(validator.elementCount("value" as Any), 1)
        XCTAssertEqual(validator.elementCount(nil), 0)
    }
}

// MARK: - Terminology Validator Tests

final class FHIRTerminologyValidatorTests: XCTestCase {

    // MARK: - Code System Tests

    func testCodeSystemContains() {
        let cs = FHIRCodeSystemDefinition(
            url: "http://example.com/cs",
            name: "Test",
            codes: ["A", "B", "C"],
            caseSensitive: true
        )
        XCTAssertTrue(cs.contains("A"))
        XCTAssertFalse(cs.contains("a")) // case sensitive
        XCTAssertFalse(cs.contains("D"))
    }

    func testCodeSystemCaseInsensitive() {
        let cs = FHIRCodeSystemDefinition(
            url: "http://example.com/cs",
            name: "Test",
            codes: ["Active", "Inactive"],
            caseSensitive: false
        )
        XCTAssertTrue(cs.contains("active"))
        XCTAssertTrue(cs.contains("ACTIVE"))
    }

    // MARK: - Value Set Tests

    func testValueSetContains() {
        let vs = FHIRValueSetDefinition(
            url: "http://example.com/vs",
            name: "Test",
            includes: ["http://example.com/cs": ["A", "B"]]
        )
        XCTAssertTrue(vs.contains(system: "http://example.com/cs", code: "A"))
        XCTAssertFalse(vs.contains(system: "http://example.com/cs", code: "C"))
        XCTAssertFalse(vs.contains(system: "http://other.com/cs", code: "A"))
    }

    func testValueSetContainsCode() {
        let vs = FHIRValueSetDefinition(
            url: "http://example.com/vs",
            name: "Test",
            includes: [
                "http://sys1.com": ["A", "B"],
                "http://sys2.com": ["C", "D"]
            ]
        )
        XCTAssertTrue(vs.containsCode("A"))
        XCTAssertTrue(vs.containsCode("C"))
        XCTAssertFalse(vs.containsCode("E"))
    }

    // MARK: - Local Terminology Service Tests

    func testLocalTerminologyServiceStandardValueSets() {
        let service = LocalTerminologyService()

        // Administrative gender
        let genderVS = service.valueSet(for: "http://hl7.org/fhir/ValueSet/administrative-gender")
        XCTAssertNotNil(genderVS)

        XCTAssertTrue(service.validateCode(
            system: "http://hl7.org/fhir/administrative-gender",
            code: "male",
            valueSetUrl: "http://hl7.org/fhir/ValueSet/administrative-gender"
        ))

        XCTAssertFalse(service.validateCode(
            system: "http://hl7.org/fhir/administrative-gender",
            code: "invalid",
            valueSetUrl: "http://hl7.org/fhir/ValueSet/administrative-gender"
        ))
    }

    func testLocalTerminologyServiceCustomRegistration() {
        let service = LocalTerminologyService()
        let cs = FHIRCodeSystemDefinition(
            url: "http://example.com/custom-cs",
            name: "Custom",
            codes: ["X", "Y", "Z"]
        )
        service.register(cs)
        XCTAssertNotNil(service.codeSystem(for: "http://example.com/custom-cs"))
    }

    func testLocalTerminologyServiceUnknownValueSet() {
        let service = LocalTerminologyService()
        // Unknown value set returns true (cannot validate)
        XCTAssertTrue(service.validateCode(
            system: nil,
            code: "anything",
            valueSetUrl: "http://unknown.com/vs"
        ))
    }

    // MARK: - Terminology Validator Tests

    func testTerminologyValidatorRequiredBinding() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .required,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        // Valid code
        validator.validate(
            system: "http://hl7.org/fhir/administrative-gender",
            code: "male",
            binding: binding,
            path: "Patient.gender",
            collector: collector
        )
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testTerminologyValidatorInvalidRequiredBinding() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .required,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        validator.validate(
            system: "http://hl7.org/fhir/administrative-gender",
            code: "invalid-code",
            binding: binding,
            path: "Patient.gender",
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].severity, .error)
        XCTAssertEqual(collector.issues[0].code, .codeInvalid)
    }

    func testTerminologyValidatorExtensibleBinding() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .extensible,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        validator.validate(
            system: "http://hl7.org/fhir/administrative-gender",
            code: "invalid-code",
            binding: binding,
            path: "Patient.gender",
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].severity, .warning)
    }

    func testTerminologyValidatorPreferredBinding() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .preferred,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        validator.validate(
            system: "http://hl7.org/fhir/administrative-gender",
            code: "invalid-code",
            binding: binding,
            path: "Patient.gender",
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].severity, .information)
    }

    func testTerminologyValidatorExampleBinding() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .example,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        validator.validate(
            system: "http://hl7.org/fhir/administrative-gender",
            code: "invalid-code",
            binding: binding,
            path: "Patient.gender",
            collector: collector
        )
        XCTAssertTrue(collector.issues.isEmpty) // Example binding produces no issues
    }

    func testValidateCoding() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .required,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        let coding = Coding(
            system: "http://hl7.org/fhir/administrative-gender",
            code: "female"
        )
        validator.validateCoding(coding, binding: binding, path: "Patient.gender", collector: collector)
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testValidateCodeableConceptValid() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .required,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        let concept = CodeableConcept(coding: [
            Coding(system: "http://hl7.org/fhir/administrative-gender", code: "male")
        ])
        validator.validateCodeableConcept(concept, binding: binding, path: "Patient.gender", collector: collector)
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testValidateCodeableConceptInvalid() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .required,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        let concept = CodeableConcept(coding: [
            Coding(system: "http://hl7.org/fhir/administrative-gender", code: "invalid")
        ])
        validator.validateCodeableConcept(concept, binding: binding, path: "Patient.gender", collector: collector)
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].severity, .error)
    }

    func testValidateCodeableConceptNoCoding() {
        let service = LocalTerminologyService()
        let validator = FHIRTerminologyValidator(service: service)
        let binding = ElementBinding(
            strength: .required,
            valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
        )
        let collector = ValidationIssueCollector()

        let concept = CodeableConcept(text: "Male")
        validator.validateCodeableConcept(concept, binding: binding, path: "Patient.gender", collector: collector)
        XCTAssertEqual(collector.issues.count, 1)
    }
}

// MARK: - FHIRPath Evaluator Tests

final class FHIRPathEvaluatorTests: XCTestCase {

    let evaluator = FHIRPathEvaluator()

    // MARK: - Tokenizer Tests

    func testTokenizerSimplePath() {
        let tokenizer = FHIRPathTokenizer()
        let tokens = tokenizer.tokenize("name.exists()")
        XCTAssertTrue(tokens.count >= 4) // name, dot, exists, (, ), eof
    }

    func testTokenizerStringLiteral() {
        let tokenizer = FHIRPathTokenizer()
        let tokens = tokenizer.tokenize("'hello'")
        if case .stringLiteral(let val) = tokens[0].type {
            XCTAssertEqual(val, "hello")
        } else {
            XCTFail("Expected string literal")
        }
    }

    func testTokenizerNumberLiteral() {
        let tokenizer = FHIRPathTokenizer()
        let tokens = tokenizer.tokenize("42")
        if case .numberLiteral(let val) = tokens[0].type {
            XCTAssertEqual(val, "42")
        } else {
            XCTFail("Expected number literal")
        }
    }

    func testTokenizerBooleanLiteral() {
        let tokenizer = FHIRPathTokenizer()
        let tokens = tokenizer.tokenize("true")
        XCTAssertEqual(tokens[0].type, .booleanLiteral(true))
    }

    func testTokenizerComparison() {
        let tokenizer = FHIRPathTokenizer()
        let tokens = tokenizer.tokenize("a = b")
        XCTAssertEqual(tokens[0].type, .identifier("a"))
        XCTAssertEqual(tokens[1].type, .equals)
        XCTAssertEqual(tokens[2].type, .identifier("b"))
    }

    func testTokenizerNotEquals() {
        let tokenizer = FHIRPathTokenizer()
        let tokens = tokenizer.tokenize("a != b")
        XCTAssertEqual(tokens[1].type, .notEquals)
    }

    func testTokenizerGreaterThanOrEqual() {
        let tokenizer = FHIRPathTokenizer()
        let tokens = tokenizer.tokenize("a >= b")
        XCTAssertEqual(tokens[1].type, .greaterThanOrEqual)
    }

    func testTokenizerLessThanOrEqual() {
        let tokenizer = FHIRPathTokenizer()
        let tokens = tokenizer.tokenize("a <= b")
        XCTAssertEqual(tokens[1].type, .lessThanOrEqual)
    }

    // MARK: - Evaluator Tests

    func testEvaluateSimpleField() {
        let result = evaluator.evaluate("name", resource: ["name": "John"])
        XCTAssertEqual(result, .string("John"))
    }

    func testEvaluateExistsFunctionTrue() {
        let result = evaluator.evaluateBoolean("name.exists()", resource: ["name": "John"])
        XCTAssertTrue(result)
    }

    func testEvaluateExistsFunctionFalse() {
        let result = evaluator.evaluateBoolean("name.exists()", resource: [:])
        XCTAssertFalse(result)
    }

    func testEvaluateEmptyFunctionTrue() {
        let result = evaluator.evaluateBoolean("name.empty()", resource: [:])
        XCTAssertTrue(result)
    }

    func testEvaluateEmptyFunctionFalse() {
        let result = evaluator.evaluateBoolean("name.empty()", resource: ["name": "John"])
        XCTAssertFalse(result)
    }

    func testEvaluateCountFunction() {
        let result = evaluator.evaluate("name.count()", resource: ["name": "John"])
        XCTAssertEqual(result, .integer(1))
    }

    func testEvaluateHasValueFunction() {
        let result = evaluator.evaluateBoolean("name.hasValue()", resource: ["name": "John"])
        XCTAssertTrue(result)
    }

    func testEvaluateNotFunction() {
        let result = evaluator.evaluateBoolean("name.not()", resource: ["name": "John"])
        XCTAssertFalse(result)
    }

    func testEvaluateBooleanLiteral() {
        XCTAssertTrue(evaluator.evaluateBoolean("true", resource: [:]))
        XCTAssertFalse(evaluator.evaluateBoolean("false", resource: [:]))
    }

    func testEvaluateAndOperator() {
        let result = evaluator.evaluateBoolean("true and true", resource: [:])
        XCTAssertTrue(result)

        let result2 = evaluator.evaluateBoolean("true and false", resource: [:])
        XCTAssertFalse(result2)
    }

    func testEvaluateOrOperator() {
        let result = evaluator.evaluateBoolean("false or true", resource: [:])
        XCTAssertTrue(result)

        let result2 = evaluator.evaluateBoolean("false or false", resource: [:])
        XCTAssertFalse(result2)
    }

    func testEvaluateXorOperator() {
        let result = evaluator.evaluateBoolean("true xor false", resource: [:])
        XCTAssertTrue(result)

        let result2 = evaluator.evaluateBoolean("true xor true", resource: [:])
        XCTAssertFalse(result2)
    }

    func testEvaluateImpliesOperator() {
        // true implies true = true
        XCTAssertTrue(evaluator.evaluateBoolean("true implies true", resource: [:]))
        // true implies false = false
        XCTAssertFalse(evaluator.evaluateBoolean("true implies false", resource: [:]))
        // false implies anything = true
        XCTAssertTrue(evaluator.evaluateBoolean("false implies false", resource: [:]))
        XCTAssertTrue(evaluator.evaluateBoolean("false implies true", resource: [:]))
    }

    func testEvaluateEquality() {
        let result = evaluator.evaluateBoolean("name = 'John'", resource: ["name": "John"])
        XCTAssertTrue(result)

        let result2 = evaluator.evaluateBoolean("name = 'Jane'", resource: ["name": "John"])
        XCTAssertFalse(result2)
    }

    func testEvaluateInequality() {
        let result = evaluator.evaluateBoolean("name != 'Jane'", resource: ["name": "John"])
        XCTAssertTrue(result)
    }

    func testEvaluateNumericComparison() {
        let result = evaluator.evaluateBoolean("age > 18", resource: ["age": 25])
        XCTAssertTrue(result)

        let result2 = evaluator.evaluateBoolean("age < 18", resource: ["age": 25])
        XCTAssertFalse(result2)
    }

    func testEvaluateAddition() {
        let result = evaluator.evaluate("1 + 2", resource: [:])
        XCTAssertEqual(result, .integer(3))
    }

    func testEvaluateStringConcatenation() {
        let result = evaluator.evaluate("'hello' + ' world'", resource: [:])
        XCTAssertEqual(result, .string("hello world"))
    }

    func testEvaluateStartsWith() {
        let result = evaluator.evaluateBoolean("name.startsWith('Jo')", resource: ["name": "John"])
        XCTAssertTrue(result)
    }

    func testEvaluateEndsWith() {
        let result = evaluator.evaluateBoolean("name.endsWith('hn')", resource: ["name": "John"])
        XCTAssertTrue(result)
    }

    func testEvaluateContains() {
        let result = evaluator.evaluateBoolean("name.contains('oh')", resource: ["name": "John"])
        XCTAssertTrue(result)
    }

    func testEvaluateLength() {
        let result = evaluator.evaluate("name.length()", resource: ["name": "John"])
        XCTAssertEqual(result, .integer(4))
    }

    func testFHIRPathValueStringValue() {
        XCTAssertEqual(FHIRPathValue.string("test").stringValue, "test")
        XCTAssertEqual(FHIRPathValue.integer(42).stringValue, "42")
        XCTAssertEqual(FHIRPathValue.boolean(true).stringValue, "true")
        XCTAssertNil(FHIRPathValue.empty.stringValue)
    }

    func testFHIRPathValueIntValue() {
        XCTAssertEqual(FHIRPathValue.integer(42).intValue, 42)
        XCTAssertEqual(FHIRPathValue.string("10").intValue, 10)
        XCTAssertNil(FHIRPathValue.empty.intValue)
    }

    func testFHIRPathValueIsTruthy() {
        XCTAssertTrue(FHIRPathValue.boolean(true).isTruthy)
        XCTAssertFalse(FHIRPathValue.boolean(false).isTruthy)
        XCTAssertTrue(FHIRPathValue.string("test").isTruthy)
        XCTAssertFalse(FHIRPathValue.string("").isTruthy)
        XCTAssertTrue(FHIRPathValue.integer(1).isTruthy)
        XCTAssertFalse(FHIRPathValue.integer(0).isTruthy)
        XCTAssertFalse(FHIRPathValue.empty.isTruthy)
    }
}

// MARK: - Profile Validator Tests

final class FHIRProfileValidatorTests: XCTestCase {

    func testValidatePatientAgainstProfile() {
        let profile = StructureDefinition(
            url: "http://example.com/patient-profile",
            name: "TestPatientProfile",
            status: .active,
            type: "Patient",
            elements: [
                ElementDefinition(path: "Patient.name", min: 1, max: "*"),
                ElementDefinition(path: "Patient.gender", min: 1, max: "1")
            ]
        )

        let validator = FHIRProfileValidator()
        let collector = ValidationIssueCollector()

        let resourceData: [String: Any] = [
            "resourceType": "Patient",
            "name": [["family": "Smith"]],
            "gender": "male"
        ]

        validator.validate(resourceData: resourceData, profile: profile, collector: collector)
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testValidatePatientMissingRequired() {
        let profile = StructureDefinition(
            url: "http://example.com/patient-profile",
            name: "TestPatientProfile",
            status: .active,
            type: "Patient",
            elements: [
                ElementDefinition(path: "Patient.name", min: 1, max: "*"),
                ElementDefinition(path: "Patient.gender", min: 1, max: "1")
            ]
        )

        let validator = FHIRProfileValidator()
        let collector = ValidationIssueCollector()

        let resourceData: [String: Any] = [
            "resourceType": "Patient"
            // Missing name and gender
        ]

        validator.validate(resourceData: resourceData, profile: profile, collector: collector)
        XCTAssertEqual(collector.issues.count, 2) // Missing name and gender
    }

    func testValidateWrongResourceType() {
        let profile = StructureDefinition(
            url: "http://example.com/patient-profile",
            name: "TestPatientProfile",
            status: .active,
            type: "Patient",
            elements: []
        )

        let validator = FHIRProfileValidator()
        let collector = ValidationIssueCollector()

        let resourceData: [String: Any] = [
            "resourceType": "Observation"
        ]

        validator.validate(resourceData: resourceData, profile: profile, collector: collector)
        XCTAssertTrue(collector.hasErrors)
    }

    func testValidateFixedValue() {
        let profile = StructureDefinition(
            url: "http://example.com/profile",
            name: "TestProfile",
            status: .active,
            type: "Patient",
            elements: [
                ElementDefinition(
                    path: "Patient.active",
                    min: 1,
                    max: "1",
                    fixedValue: "true"
                )
            ]
        )

        let validator = FHIRProfileValidator()

        // Correct fixed value
        let collector1 = ValidationIssueCollector()
        validator.validate(
            resourceData: ["resourceType": "Patient", "active": "true"],
            profile: profile,
            collector: collector1
        )
        XCTAssertFalse(collector1.hasErrors)

        // Wrong fixed value
        let collector2 = ValidationIssueCollector()
        validator.validate(
            resourceData: ["resourceType": "Patient", "active": "false"],
            profile: profile,
            collector: collector2
        )
        XCTAssertTrue(collector2.hasErrors)
    }

    func testValidatePatternValue() {
        let profile = StructureDefinition(
            url: "http://example.com/profile",
            name: "TestProfile",
            status: .active,
            type: "Patient",
            elements: [
                ElementDefinition(
                    path: "Patient.name",
                    min: 1,
                    max: "1",
                    patternValue: "Smith"
                )
            ]
        )

        let validator = FHIRProfileValidator()
        let collector = ValidationIssueCollector()
        validator.validate(
            resourceData: ["resourceType": "Patient", "name": "John Smith"],
            profile: profile,
            collector: collector
        )
        XCTAssertFalse(collector.hasErrors)
    }

    func testValidateWithConstraint() {
        let profile = StructureDefinition(
            url: "http://example.com/profile",
            name: "TestProfile",
            status: .active,
            type: "Patient",
            elements: [
                ElementDefinition(
                    path: "Patient.name",
                    constraints: [
                        ElementConstraint(
                            key: "test-1",
                            severity: .error,
                            human: "Name must exist",
                            expression: "name.exists()"
                        )
                    ]
                )
            ]
        )

        let validator = FHIRProfileValidator()

        // With name present
        let collector1 = ValidationIssueCollector()
        validator.validate(
            resourceData: ["resourceType": "Patient", "name": "John"],
            profile: profile,
            collector: collector1
        )
        let constraintIssues1 = collector1.issues.filter { $0.code == .invariant }
        XCTAssertTrue(constraintIssues1.isEmpty)

        // Without name
        let collector2 = ValidationIssueCollector()
        validator.validate(
            resourceData: ["resourceType": "Patient"],
            profile: profile,
            collector: collector2
        )
        let constraintIssues2 = collector2.issues.filter { $0.code == .invariant }
        XCTAssertEqual(constraintIssues2.count, 1)
    }

    func testValidateWithTerminology() {
        let service = LocalTerminologyService()
        let validator = FHIRProfileValidator(terminologyService: service)

        let profile = StructureDefinition(
            url: "http://example.com/profile",
            name: "TestProfile",
            status: .active,
            type: "Patient",
            elements: [
                ElementDefinition(
                    path: "Patient.gender",
                    min: 1,
                    max: "1",
                    binding: ElementBinding(
                        strength: .required,
                        valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
                    )
                )
            ]
        )

        // Valid gender
        let collector1 = ValidationIssueCollector()
        validator.validate(
            resourceData: ["resourceType": "Patient", "gender": "male"],
            profile: profile,
            collector: collector1
        )
        let codeIssues1 = collector1.issues.filter { $0.code == .codeInvalid }
        XCTAssertTrue(codeIssues1.isEmpty)
    }

    func testValidateUSCorePatientProfile() {
        let validator = FHIRProfileValidator()
        let collector = ValidationIssueCollector()

        // Missing required US Core fields
        validator.validate(
            resourceData: ["resourceType": "Patient"],
            profile: StandardProfiles.usCorePatient,
            collector: collector
        )

        // Should have errors for missing identifier, name, gender
        let requiredIssues = collector.issues.filter { $0.code == .required }
        XCTAssertEqual(requiredIssues.count, 3)
    }
}

// MARK: - Custom Validation Rules Tests

final class FHIRCustomValidationRulesTests: XCTestCase {

    func testRequiredFieldsRule() {
        let rule = RequiredFieldsRule(
            ruleId: "test-required",
            resourceTypes: ["Patient"],
            requiredFields: ["name", "birthDate"]
        )

        let collector = ValidationIssueCollector()
        rule.validate(
            resourceData: [
                "resourceType": "Patient",
                "name": "John"
                // Missing birthDate
            ],
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertTrue(collector.issues[0].details.contains("birthDate"))
    }

    func testRequiredFieldsRuleWrongResourceType() {
        let rule = RequiredFieldsRule(
            ruleId: "test-required",
            resourceTypes: ["Patient"],
            requiredFields: ["name"]
        )

        let collector = ValidationIssueCollector()
        rule.validate(
            resourceData: ["resourceType": "Observation"],
            collector: collector
        )
        XCTAssertTrue(collector.issues.isEmpty) // Rule doesn't apply
    }

    func testCoOccurrenceRule() {
        let rule = CoOccurrenceRule(
            ruleId: "test-co-occur",
            ifField: "deceased",
            thenField: "deceasedDateTime"
        )

        // Trigger: deceased present but no deceasedDateTime
        let collector = ValidationIssueCollector()
        rule.validate(
            resourceData: [
                "resourceType": "Patient",
                "deceased": true
            ],
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].code, .businessRule)
    }

    func testCoOccurrenceRuleSatisfied() {
        let rule = CoOccurrenceRule(
            ruleId: "test-co-occur",
            ifField: "deceased",
            thenField: "deceasedDateTime"
        )

        let collector = ValidationIssueCollector()
        rule.validate(
            resourceData: [
                "resourceType": "Patient",
                "deceased": true,
                "deceasedDateTime": "2024-01-01"
            ],
            collector: collector
        )
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testValueConstraintRule() {
        let rule = ValueConstraintRule(
            ruleId: "test-value",
            field: "status",
            allowedValues: ["active", "inactive", "resolved"]
        )

        // Invalid value
        let collector = ValidationIssueCollector()
        rule.validate(
            resourceData: [
                "resourceType": "Condition",
                "status": "pending"
            ],
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1)
        XCTAssertEqual(collector.issues[0].code, .codeInvalid)
    }

    func testValueConstraintRuleValid() {
        let rule = ValueConstraintRule(
            ruleId: "test-value",
            field: "status",
            allowedValues: ["active", "inactive", "resolved"]
        )

        let collector = ValidationIssueCollector()
        rule.validate(
            resourceData: [
                "resourceType": "Condition",
                "status": "active"
            ],
            collector: collector
        )
        XCTAssertTrue(collector.issues.isEmpty)
    }

    func testClosureValidationRule() {
        let rule = ClosureValidationRule(
            ruleId: "test-closure",
            description: "Custom closure rule",
            resourceTypes: ["Patient"]
        ) { resourceData, collector in
            if let name = resourceData["name"] as? String, name.isEmpty {
                collector.addError("Name cannot be empty", path: "Patient.name")
            }
        }

        let collector = ValidationIssueCollector()
        rule.validate(
            resourceData: ["resourceType": "Patient", "name": ""],
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1)
    }

    func testValidationRuleRegistry() {
        let registry = FHIRValidationRuleRegistry()

        let rule1 = RequiredFieldsRule(
            ruleId: "rule1",
            resourceTypes: ["Patient"],
            requiredFields: ["name"]
        )
        let rule2 = RequiredFieldsRule(
            ruleId: "rule2",
            resourceTypes: ["Observation"],
            requiredFields: ["status"]
        )

        registry.register(rule1)
        registry.register(rule2)

        XCTAssertEqual(registry.allRules.count, 2)
        XCTAssertEqual(registry.rules(for: "Patient").count, 1)
        XCTAssertEqual(registry.rules(for: "Observation").count, 1)

        registry.remove(ruleId: "rule1")
        XCTAssertEqual(registry.allRules.count, 1)
    }

    func testValidationRuleRegistryValidate() {
        let registry = FHIRValidationRuleRegistry()
        registry.register(RequiredFieldsRule(
            ruleId: "req-status",
            resourceTypes: ["Observation"],
            requiredFields: ["status"]
        ))

        let collector = ValidationIssueCollector()
        registry.validate(
            resourceData: ["resourceType": "Observation"],
            collector: collector
        )
        XCTAssertEqual(collector.issues.count, 1)
    }
}

// MARK: - FHIRValidator Integration Tests

final class FHIRValidatorTests: XCTestCase {

    func testValidateValidPatient() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Patient",
            "id": "123",
            "name": [["family": "Smith", "given": ["John"]]],
            "gender": "male"
        ])
        XCTAssertTrue(outcome.isValid)
    }

    func testValidateMissingResourceType() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([:])
        XCTAssertFalse(outcome.isValid)
        XCTAssertTrue(outcome.errors.first?.details.contains("resourceType") ?? false)
    }

    func testValidateEmptyResourceType() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary(["resourceType": ""])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateUnknownResourceTypeStrict() {
        let validator = FHIRValidator(configuration: .strict)
        let outcome = validator.validateDictionary(["resourceType": "CustomResource"])
        XCTAssertTrue(outcome.warnings.count > 0)
    }

    func testValidateObservationMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Observation"
            // Missing status and code
        ])
        XCTAssertFalse(outcome.isValid)
        let requiredErrors = outcome.errors.filter { $0.code == .required }
        XCTAssertGreaterThanOrEqual(requiredErrors.count, 2) // status and code
    }

    func testValidateObservationValid() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Observation",
            "status": "final",
            "code": ["text": "Blood Pressure"]
        ])
        XCTAssertTrue(outcome.isValid)
    }

    func testValidateWithProfile() {
        let validator = FHIRValidator()
        validator.addProfile(StandardProfiles.usCorePatient)

        let outcome = validator.validateDictionary([
            "resourceType": "Patient"
            // Missing required US Core fields
        ])
        XCTAssertFalse(outcome.isValid)
        XCTAssertTrue(outcome.errors.count >= 3) // identifier, name, gender
    }

    func testValidateWithCustomRule() {
        let validator = FHIRValidator()
        validator.addRule(RequiredFieldsRule(
            ruleId: "custom-1",
            resourceTypes: ["Patient"],
            requiredFields: ["birthDate"]
        ))

        let outcome = validator.validateDictionary([
            "resourceType": "Patient",
            "name": [["family": "Smith"]]
            // Missing birthDate
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateCodableResource() {
        let validator = FHIRValidator()
        let patient = Patient(
            messageID: "msg-1",
            id: "pat-1",
            meta: nil,
            text: nil,
            identifier: [Identifier(system: "http://example.com", value: "12345")],
            active: true,
            name: [HumanName(family: "Smith", given: ["John"])],
            gender: "male",
            birthDate: "1990-01-01"
        )

        let outcome = validator.validate(patient)
        XCTAssertTrue(outcome.isValid)
    }

    func testProfileManagement() {
        let validator = FHIRValidator()
        XCTAssertTrue(validator.registeredProfiles.isEmpty)

        validator.addProfile(StandardProfiles.patient)
        XCTAssertEqual(validator.registeredProfiles.count, 1)

        validator.addProfile(StandardProfiles.observation)
        XCTAssertEqual(validator.registeredProfiles.count, 2)

        validator.clearProfiles()
        XCTAssertTrue(validator.registeredProfiles.isEmpty)
    }

    func testCustomRuleManagement() {
        let validator = FHIRValidator()
        validator.addRule(RequiredFieldsRule(
            ruleId: "rule-1",
            requiredFields: ["name"]
        ))
        validator.addRule(RequiredFieldsRule(
            ruleId: "rule-2",
            requiredFields: ["status"]
        ))

        // Validate with both rules
        let outcome = validator.validateDictionary([
            "resourceType": "Patient"
        ])
        // rule-1 should fire for missing name
        let nameErrors = outcome.issues.filter { $0.details.contains("name") && $0.code == .required }
        XCTAssertGreaterThanOrEqual(nameErrors.count, 1)

        validator.removeRule(ruleId: "rule-1")
        let outcome2 = validator.validateDictionary([
            "resourceType": "Patient"
        ])
        // rule-1 should no longer fire
        let nameErrors2 = outcome2.issues.filter { $0.details.contains("'name'") && $0.details.contains("missing") }
        XCTAssertEqual(nameErrors2.count, 0)
    }

    func testValidateEncounterMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Encounter"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateBundleMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Bundle"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateOperationOutcomeMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "OperationOutcome"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateConditionMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Condition"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateAllergyIntoleranceMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "AllergyIntolerance"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateMedicationRequestMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "MedicationRequest"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateDiagnosticReportMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "DiagnosticReport"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateAppointmentMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Appointment"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateScheduleMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Schedule"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateMedicationStatementMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "MedicationStatement"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidateDocumentReferenceMissingRequired() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "DocumentReference"
        ])
        XCTAssertFalse(outcome.isValid)
    }

    func testValidatorConfiguration() {
        let config = FHIRValidatorConfiguration(
            validateStructure: false,
            validateProfiles: false,
            validateCustomRules: false,
            maxIssues: 50
        )
        let validator = FHIRValidator(configuration: config)

        // With structure validation disabled, missing resourceType should pass
        let outcome = validator.validateDictionary([:])
        XCTAssertTrue(outcome.isValid)
    }

    func testValidateEmptyArrayField() {
        let validator = FHIRValidator()
        let outcome = validator.validateDictionary([
            "resourceType": "Appointment",
            "status": "booked",
            "participant": [] as [Any]  // Empty array should fail required
        ])
        XCTAssertFalse(outcome.isValid)
    }

    // MARK: - Standard Profiles Tests

    func testStandardPatientProfile() {
        let profile = StandardProfiles.patient
        XCTAssertEqual(profile.type, "Patient")
        XCTAssertEqual(profile.elements.count, 5)
    }

    func testStandardObservationProfile() {
        let profile = StandardProfiles.observation
        XCTAssertEqual(profile.type, "Observation")
        XCTAssertEqual(profile.elements.count, 4)
        XCTAssertTrue(profile.elements[0].isRequired) // status
        XCTAssertTrue(profile.elements[1].isRequired) // code
    }

    func testStandardUSCorePatientProfile() {
        let profile = StandardProfiles.usCorePatient
        XCTAssertEqual(profile.type, "Patient")
        XCTAssertNotNil(profile.baseDefinition)
        XCTAssertEqual(profile.elements.count, 3)
        XCTAssertTrue(profile.elements[0].mustSupport)
        XCTAssertTrue(profile.elements[1].mustSupport)
        XCTAssertTrue(profile.elements[2].mustSupport)
    }

    // MARK: - Performance Tests

    func testValidationPerformance() {
        let validator = FHIRValidator()
        validator.addProfile(StandardProfiles.patient)

        let resourceData: [String: Any] = [
            "resourceType": "Patient",
            "id": "test-patient",
            "name": [["family": "Smith", "given": ["John"]]],
            "gender": "male",
            "birthDate": "1990-01-01"
        ]

        measure {
            for _ in 0..<1000 {
                _ = validator.validateDictionary(resourceData)
            }
        }
    }
}
