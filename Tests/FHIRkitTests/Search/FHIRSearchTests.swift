/// FHIRSearchTests.swift
/// Tests for FHIR Search & Query module

import XCTest
@testable import FHIRkit

final class FHIRSearchTests: XCTestCase {

    // MARK: - SearchParamType Tests

    func testSearchParamTypeRawValues() {
        XCTAssertEqual(SearchParamType.string.rawValue, "string")
        XCTAssertEqual(SearchParamType.token.rawValue, "token")
        XCTAssertEqual(SearchParamType.reference.rawValue, "reference")
        XCTAssertEqual(SearchParamType.date.rawValue, "date")
        XCTAssertEqual(SearchParamType.number.rawValue, "number")
        XCTAssertEqual(SearchParamType.quantity.rawValue, "quantity")
        XCTAssertEqual(SearchParamType.composite.rawValue, "composite")
        XCTAssertEqual(SearchParamType.uri.rawValue, "uri")
        XCTAssertEqual(SearchParamType.special.rawValue, "special")
    }

    // MARK: - SearchModifier Tests

    func testSearchModifierRawValues() {
        XCTAssertEqual(SearchModifier.exact.rawValue, "exact")
        XCTAssertEqual(SearchModifier.contains.rawValue, "contains")
        XCTAssertEqual(SearchModifier.text.rawValue, "text")
        XCTAssertEqual(SearchModifier.not.rawValue, "not")
        XCTAssertEqual(SearchModifier.above.rawValue, "above")
        XCTAssertEqual(SearchModifier.below.rawValue, "below")
        XCTAssertEqual(SearchModifier.in.rawValue, "in")
        XCTAssertEqual(SearchModifier.notIn.rawValue, "not-in")
        XCTAssertEqual(SearchModifier.ofType.rawValue, "of-type")
        XCTAssertEqual(SearchModifier.missing.rawValue, "missing")
        XCTAssertEqual(SearchModifier.identifier.rawValue, "identifier")
        XCTAssertEqual(SearchModifier.type.rawValue, "type")
    }

    // MARK: - DatePrefix Tests

    func testDatePrefixRawValues() {
        XCTAssertEqual(DatePrefix.eq.rawValue, "eq")
        XCTAssertEqual(DatePrefix.ne.rawValue, "ne")
        XCTAssertEqual(DatePrefix.gt.rawValue, "gt")
        XCTAssertEqual(DatePrefix.lt.rawValue, "lt")
        XCTAssertEqual(DatePrefix.ge.rawValue, "ge")
        XCTAssertEqual(DatePrefix.le.rawValue, "le")
        XCTAssertEqual(DatePrefix.sa.rawValue, "sa")
        XCTAssertEqual(DatePrefix.eb.rawValue, "eb")
        XCTAssertEqual(DatePrefix.ap.rawValue, "ap")
    }

    // MARK: - SearchParameterValue Tests

    func testStringValueQueryString() {
        let value = SearchParameterValue.string("Smith")
        XCTAssertEqual(value.queryString(), "Smith")
    }

    func testTokenValueWithSystemQueryString() {
        let value = SearchParameterValue.token(system: "http://loinc.org", code: "8867-4")
        XCTAssertEqual(value.queryString(), "http://loinc.org|8867-4")
    }

    func testTokenValueWithoutSystemQueryString() {
        let value = SearchParameterValue.token(system: nil, code: "active")
        XCTAssertEqual(value.queryString(), "active")
    }

    func testReferenceValueQueryString() {
        let value = SearchParameterValue.reference("Patient/123")
        XCTAssertEqual(value.queryString(), "Patient/123")
    }

    func testDateValueWithPrefixQueryString() {
        let value = SearchParameterValue.date(prefix: .ge, value: "2024-01-01")
        XCTAssertEqual(value.queryString(), "ge2024-01-01")
    }

    func testDateValueWithoutPrefixQueryString() {
        let value = SearchParameterValue.date(prefix: nil, value: "2024-01-01")
        XCTAssertEqual(value.queryString(), "2024-01-01")
    }

    func testNumberValueWithPrefixQueryString() {
        let value = SearchParameterValue.number(prefix: .gt, value: "100")
        XCTAssertEqual(value.queryString(), "gt100")
    }

    func testNumberValueWithoutPrefixQueryString() {
        let value = SearchParameterValue.number(prefix: nil, value: "42")
        XCTAssertEqual(value.queryString(), "42")
    }

    func testQuantityValueFullQueryString() {
        let value = SearchParameterValue.quantity(
            prefix: .lt, value: "5.4",
            system: "http://unitsofmeasure.org", code: "mg"
        )
        XCTAssertEqual(value.queryString(), "lt5.4|http://unitsofmeasure.org|mg")
    }

    func testQuantityValuePartialQueryString() {
        let value = SearchParameterValue.quantity(
            prefix: nil, value: "5.4", system: nil, code: nil
        )
        XCTAssertEqual(value.queryString(), "5.4||")
    }

    func testCompositeValueQueryString() {
        let value = SearchParameterValue.composite([
            ("code", "8867-4"), ("value", "60")
        ])
        XCTAssertEqual(value.queryString(), "code$8867-4,value$60")
    }

    func testMissingValueQueryString() {
        XCTAssertEqual(SearchParameterValue.missing(true).queryString(), "true")
        XCTAssertEqual(SearchParameterValue.missing(false).queryString(), "false")
    }

    // MARK: - SearchParameterValue Equatable Tests

    func testSearchParameterValueEquality() {
        XCTAssertEqual(
            SearchParameterValue.string("test"),
            SearchParameterValue.string("test")
        )
        XCTAssertNotEqual(
            SearchParameterValue.string("a"),
            SearchParameterValue.string("b")
        )
        XCTAssertNotEqual(
            SearchParameterValue.string("test"),
            SearchParameterValue.token(system: nil, code: "test")
        )
        XCTAssertEqual(
            SearchParameterValue.token(system: "sys", code: "code"),
            SearchParameterValue.token(system: "sys", code: "code")
        )
        XCTAssertEqual(
            SearchParameterValue.composite([("a", "b")]),
            SearchParameterValue.composite([("a", "b")])
        )
        XCTAssertNotEqual(
            SearchParameterValue.composite([("a", "b")]),
            SearchParameterValue.composite([("a", "c")])
        )
        XCTAssertNotEqual(
            SearchParameterValue.composite([("a", "b")]),
            SearchParameterValue.composite([("a", "b"), ("c", "d")])
        )
        XCTAssertEqual(
            SearchParameterValue.missing(true),
            SearchParameterValue.missing(true)
        )
        XCTAssertNotEqual(
            SearchParameterValue.missing(true),
            SearchParameterValue.missing(false)
        )
    }

    // MARK: - SearchParameter Tests

    func testSearchParameterToQueryItemWithoutModifier() {
        let param = SearchParameter(name: "name", value: .string("Smith"))
        let item = param.toQueryItem()
        XCTAssertEqual(item.name, "name")
        XCTAssertEqual(item.value, "Smith")
    }

    func testSearchParameterToQueryItemWithModifier() {
        let param = SearchParameter(
            name: "name", modifier: .exact, value: .string("Smith")
        )
        let item = param.toQueryItem()
        XCTAssertEqual(item.name, "name:exact")
        XCTAssertEqual(item.value, "Smith")
    }

    func testSearchParameterEquality() {
        let a = SearchParameter(name: "name", value: .string("Smith"))
        let b = SearchParameter(name: "name", value: .string("Smith"))
        let c = SearchParameter(name: "name", modifier: .exact, value: .string("Smith"))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - IncludeParameter Tests

    func testIncludeParameterQueryValue() {
        let inc = IncludeParameter(
            sourceType: "MedicationRequest",
            searchParameter: "patient"
        )
        XCTAssertEqual(inc.queryValue(), "MedicationRequest:patient")
    }

    func testIncludeParameterQueryValueWithTarget() {
        let inc = IncludeParameter(
            sourceType: "MedicationRequest",
            searchParameter: "subject",
            targetType: "Patient"
        )
        XCTAssertEqual(inc.queryValue(), "MedicationRequest:subject:Patient")
    }

    func testIncludeParameterQueryName() {
        let inc = IncludeParameter(sourceType: "X", searchParameter: "y")
        XCTAssertEqual(inc.queryName(isRevInclude: false), "_include")
        XCTAssertEqual(inc.queryName(isRevInclude: true), "_revinclude")
    }

    func testIncludeParameterIterateQueryName() {
        let inc = IncludeParameter(sourceType: "X", searchParameter: "y", iterate: true)
        XCTAssertEqual(inc.queryName(isRevInclude: false), "_include:iterate")
        XCTAssertEqual(inc.queryName(isRevInclude: true), "_revinclude:iterate")
    }

    // MARK: - SortParameter Tests

    func testSortParameterAscending() {
        let sort = SortParameter(field: "birthdate", ascending: true)
        XCTAssertEqual(sort.queryValue(), "birthdate")
    }

    func testSortParameterDescending() {
        let sort = SortParameter(field: "birthdate", ascending: false)
        XCTAssertEqual(sort.queryValue(), "-birthdate")
    }

    // MARK: - SummaryMode Tests

    func testSummaryModeRawValues() {
        XCTAssertEqual(SummaryMode.true.rawValue, "true")
        XCTAssertEqual(SummaryMode.text.rawValue, "text")
        XCTAssertEqual(SummaryMode.data.rawValue, "data")
        XCTAssertEqual(SummaryMode.count.rawValue, "count")
        XCTAssertEqual(SummaryMode.false.rawValue, "false")
    }

    // MARK: - TotalMode Tests

    func testTotalModeRawValues() {
        XCTAssertEqual(TotalMode.none.rawValue, "none")
        XCTAssertEqual(TotalMode.estimate.rawValue, "estimate")
        XCTAssertEqual(TotalMode.accurate.rawValue, "accurate")
    }

    // MARK: - FHIRSearchQuery Builder Tests

    func testEmptyQuery() {
        let query = FHIRSearchQuery(resourceType: "Patient")
        XCTAssertEqual(query.resourceType, "Patient")
        XCTAssertTrue(query.parameters.isEmpty)
        XCTAssertTrue(query.includes.isEmpty)
        XCTAssertTrue(query.revIncludes.isEmpty)
        XCTAssertNil(query.sort)
        XCTAssertNil(query.count)
        XCTAssertNil(query.offset)
        XCTAssertNil(query.summary)
        XCTAssertNil(query.elements)
        XCTAssertNil(query.total)
    }

    func testQueryWhereString() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", .string("Smith"))
        XCTAssertEqual(query.parameters.count, 1)
        XCTAssertEqual(query.parameters[0].name, "name")
        XCTAssertEqual(query.parameters[0].value, .string("Smith"))
        XCTAssertNil(query.parameters[0].modifier)
    }

    func testQueryWhereWithModifier() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", modifier: .exact, .string("Smith"))
        XCTAssertEqual(query.parameters.count, 1)
        XCTAssertEqual(query.parameters[0].modifier, .exact)
    }

    func testQueryMultipleWhere() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", .string("Smith"))
            .where("gender", .token(system: nil, code: "male"))
            .where("birthdate", .date(prefix: .ge, value: "1990-01-01"))
        XCTAssertEqual(query.parameters.count, 3)
    }

    func testQueryInclude() {
        let query = FHIRSearchQuery(resourceType: "MedicationRequest")
            .include("MedicationRequest", parameter: "patient")
        XCTAssertEqual(query.includes.count, 1)
        XCTAssertEqual(query.includes[0].sourceType, "MedicationRequest")
        XCTAssertEqual(query.includes[0].searchParameter, "patient")
    }

    func testQueryRevInclude() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .revInclude("Observation", parameter: "subject")
        XCTAssertEqual(query.revIncludes.count, 1)
        XCTAssertEqual(query.revIncludes[0].sourceType, "Observation")
    }

    func testQueryChained() {
        let query = FHIRSearchQuery(resourceType: "Observation")
            .chained("subject:Patient.name", .string("Smith"))
        XCTAssertEqual(query.parameters.count, 1)
        XCTAssertEqual(query.parameters[0].name, "subject:Patient.name")
    }

    func testQueryReverseChained() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .reverseChained(
                targetType: "Observation",
                parameter: "patient",
                searchParam: "code",
                value: .token(system: "http://loinc.org", code: "8867-4")
            )
        XCTAssertEqual(query.parameters.count, 1)
        XCTAssertEqual(query.parameters[0].name, "_has:Observation:patient:code")
    }

    func testQuerySorted() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .sorted(by: "birthdate", ascending: false)
        XCTAssertEqual(query.sort?.count, 1)
        XCTAssertEqual(query.sort?[0].field, "birthdate")
        XCTAssertEqual(query.sort?[0].ascending, false)
    }

    func testQueryMultipleSorts() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .sorted(by: "family", ascending: true)
            .sorted(by: "birthdate", ascending: false)
        XCTAssertEqual(query.sort?.count, 2)
    }

    func testQueryLimited() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .limited(to: 10)
        XCTAssertEqual(query.count, 10)
    }

    func testQueryOffset() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .offset(20)
        XCTAssertEqual(query.offset, 20)
    }

    func testQuerySummary() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .withSummary(.count)
        XCTAssertEqual(query.summary, .count)
    }

    func testQueryElements() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .withElements(["id", "name", "birthDate"])
        XCTAssertEqual(query.elements, ["id", "name", "birthDate"])
    }

    func testQueryTotal() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .withTotal(.accurate)
        XCTAssertEqual(query.total, .accurate)
    }

    // MARK: - Query Conversion Tests

    func testToQueryItems() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", .string("Smith"))
            .where("gender", .token(system: nil, code: "male"))
            .include("Patient", parameter: "general-practitioner")
            .sorted(by: "birthdate", ascending: false)
            .limited(to: 10)
            .offset(20)
            .withSummary(.data)
            .withTotal(.accurate)

        let items = query.toQueryItems()

        XCTAssertTrue(items.contains(where: { $0.name == "name" && $0.value == "Smith" }))
        XCTAssertTrue(items.contains(where: { $0.name == "gender" && $0.value == "male" }))
        XCTAssertTrue(items.contains(where: {
            $0.name == "_include" && $0.value == "Patient:general-practitioner"
        }))
        XCTAssertTrue(items.contains(where: { $0.name == "_sort" && $0.value == "-birthdate" }))
        XCTAssertTrue(items.contains(where: { $0.name == "_count" && $0.value == "10" }))
        XCTAssertTrue(items.contains(where: { $0.name == "_offset" && $0.value == "20" }))
        XCTAssertTrue(items.contains(where: { $0.name == "_summary" && $0.value == "data" }))
        XCTAssertTrue(items.contains(where: { $0.name == "_total" && $0.value == "accurate" }))
    }

    func testToQueryItemsElements() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .withElements(["id", "name"])
        let items = query.toQueryItems()
        XCTAssertTrue(items.contains(where: { $0.name == "_elements" && $0.value == "id,name" }))
    }

    func testToQueryItemsRevInclude() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .revInclude("Observation", parameter: "subject", targetType: "Patient")
        let items = query.toQueryItems()
        XCTAssertTrue(items.contains(where: {
            $0.name == "_revinclude" && $0.value == "Observation:subject:Patient"
        }))
    }

    func testToQueryItemsIterateInclude() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .include("Patient", parameter: "link", iterate: true)
        let items = query.toQueryItems()
        XCTAssertTrue(items.contains(where: {
            $0.name == "_include:iterate" && $0.value == "Patient:link"
        }))
    }

    func testToQueryParameters() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", .string("Smith"))
            .limited(to: 10)
        let params = query.toQueryParameters()
        XCTAssertEqual(params["name"], "Smith")
        XCTAssertEqual(params["_count"], "10")
    }

    func testToQueryParametersMultipleSorts() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .sorted(by: "family", ascending: true)
            .sorted(by: "birthdate", ascending: false)
        let params = query.toQueryParameters()
        XCTAssertEqual(params["_sort"], "family,-birthdate")
    }

    // MARK: - Complex Query Tests

    func testComplexPatientQuery() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", modifier: .exact, .string("Smith"))
            .where("birthdate", .date(prefix: .ge, value: "1990-01-01"))
            .where("birthdate", .date(prefix: .le, value: "2000-12-31"))
            .where("active", .token(system: nil, code: "true"))
            .include("Patient", parameter: "general-practitioner", targetType: "Practitioner")
            .revInclude("Observation", parameter: "subject")
            .sorted(by: "birthdate", ascending: false)
            .limited(to: 50)
            .withTotal(.accurate)

        let items = query.toQueryItems()
        XCTAssertTrue(items.count >= 9)
        XCTAssertTrue(items.contains(where: { $0.name == "name:exact" && $0.value == "Smith" }))
    }

    func testComplexObservationQuery() {
        let query = FHIRSearchQuery(resourceType: "Observation")
            .where("code", .token(system: "http://loinc.org", code: "8867-4"))
            .where("value-quantity", .quantity(
                prefix: .gt, value: "60",
                system: "http://unitsofmeasure.org", code: "/min"
            ))
            .where("date", .date(prefix: .ge, value: "2024-01-01"))
            .chained("subject:Patient.name", .string("Smith"))
            .include("Observation", parameter: "subject")
            .sorted(by: "date", ascending: false)
            .limited(to: 20)

        let items = query.toQueryItems()
        XCTAssertTrue(items.contains(where: {
            $0.name == "code" && $0.value == "http://loinc.org|8867-4"
        }))
        XCTAssertTrue(items.contains(where: {
            $0.name == "value-quantity" && $0.value == "gt60|http://unitsofmeasure.org|/min"
        }))
        XCTAssertTrue(items.contains(where: {
            $0.name == "subject:Patient.name" && $0.value == "Smith"
        }))
    }

    // MARK: - Immutability Tests

    func testQueryBuilderImmutability() {
        let base = FHIRSearchQuery(resourceType: "Patient")
        let withName = base.where("name", .string("Smith"))
        let withGender = base.where("gender", .token(system: nil, code: "male"))

        XCTAssertTrue(base.parameters.isEmpty)
        XCTAssertEqual(withName.parameters.count, 1)
        XCTAssertEqual(withName.parameters[0].name, "name")
        XCTAssertEqual(withGender.parameters.count, 1)
        XCTAssertEqual(withGender.parameters[0].name, "gender")
    }

    // MARK: - CompartmentSearch Tests

    func testCompartmentSearchPath() {
        let search = CompartmentSearch(
            compartmentType: "Patient",
            compartmentId: "123",
            resourceType: "Observation"
        )
        XCTAssertEqual(search.path(), "Patient/123/Observation")
    }

    func testCompartmentSearchPathWithoutResourceType() {
        let search = CompartmentSearch(
            compartmentType: "Patient",
            compartmentId: "123"
        )
        XCTAssertEqual(search.path(), "Patient/123")
    }

    func testCompartmentSearchEquality() {
        let a = CompartmentSearch(compartmentType: "Patient", compartmentId: "123", resourceType: "Observation")
        let b = CompartmentSearch(compartmentType: "Patient", compartmentId: "123", resourceType: "Observation")
        let c = CompartmentSearch(compartmentType: "Patient", compartmentId: "456", resourceType: "Observation")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - SearchResult Tests

    func testSearchResultFromBundle() {
        let entry1 = BundleEntry(
            fullUrl: "http://example.com/Patient/1",
            resource: .patient(Patient(
                id: "1",
                name: [HumanName(family: "Smith", given: ["John"])]
            )),
            search: BundleEntrySearch(mode: "match", score: 1.0),
            request: nil,
            response: nil
        )
        let entry2 = BundleEntry(
            fullUrl: "http://example.com/Patient/2",
            resource: .patient(Patient(
                id: "2",
                name: [HumanName(family: "Doe", given: ["Jane"])]
            )),
            search: BundleEntrySearch(mode: "match", score: 0.9),
            request: nil,
            response: nil
        )
        let bundle = Bundle(
            type: "searchset",
            total: 2,
            link: [
                BundleLink(relation: "self", url: "http://example.com/Patient"),
                BundleLink(relation: "next", url: "http://example.com/Patient?_offset=10")
            ],
            entry: [entry1, entry2]
        )

        let result = SearchResult(bundle: bundle, type: Patient.self)
        XCTAssertEqual(result.total, 2)
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertTrue(result.hasNextPage)
        XCTAssertFalse(result.hasPreviousPage)
        XCTAssertEqual(result.entries[0].resource.id, "1")
        XCTAssertEqual(result.entries[0].fullUrl, "http://example.com/Patient/1")
        XCTAssertEqual(result.entries[0].searchMode, "match")
        XCTAssertEqual(result.entries[0].searchScore, 1.0)
        XCTAssertEqual(result.entries[1].resource.id, "2")
    }

    func testSearchResultPreviousPage() {
        let bundle = Bundle(
            type: "searchset",
            total: 20,
            link: [
                BundleLink(relation: "previous", url: "http://example.com/Patient?_offset=0"),
                BundleLink(relation: "next", url: "http://example.com/Patient?_offset=20")
            ],
            entry: []
        )
        let result = SearchResult(bundle: bundle, type: Patient.self)
        XCTAssertTrue(result.hasNextPage)
        XCTAssertTrue(result.hasPreviousPage)
    }

    func testSearchResultPrevLink() {
        let bundle = Bundle(
            type: "searchset",
            total: 20,
            link: [
                BundleLink(relation: "prev", url: "http://example.com/Patient?_offset=0")
            ],
            entry: []
        )
        let result = SearchResult(bundle: bundle, type: Patient.self)
        XCTAssertTrue(result.hasPreviousPage)
    }

    func testSearchResultEmptyBundle() {
        let bundle = Bundle(
            type: "searchset",
            total: 0,
            link: nil,
            entry: nil
        )
        let result = SearchResult(bundle: bundle, type: Patient.self)
        XCTAssertEqual(result.total, 0)
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertFalse(result.hasNextPage)
        XCTAssertFalse(result.hasPreviousPage)
    }

    func testSearchResultTypeMismatch() {
        let entry = BundleEntry(
            fullUrl: "http://example.com/Observation/1",
            resource: .observation(Observation(
                status: "final",
                code: CodeableConcept(coding: [Coding(system: "http://loinc.org", code: "8867-4")])
            )),
            search: nil,
            request: nil,
            response: nil
        )
        let bundle = Bundle(type: "searchset", total: 1, link: nil, entry: [entry])

        // Requesting Patient from an Observation bundle should return 0 entries
        let result = SearchResult(bundle: bundle, type: Patient.self)
        XCTAssertTrue(result.entries.isEmpty)
    }

    func testSearchResultCorrectTypeExtraction() {
        let entry = BundleEntry(
            fullUrl: "http://example.com/Observation/1",
            resource: .observation(Observation(
                id: "obs-1",
                status: "final",
                code: CodeableConcept(coding: [Coding(system: "http://loinc.org", code: "8867-4")])
            )),
            search: BundleEntrySearch(mode: "match", score: nil),
            request: nil,
            response: nil
        )
        let bundle = Bundle(type: "searchset", total: 1, link: nil, entry: [entry])

        let result = SearchResult(bundle: bundle, type: Observation.self)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].resource.id, "obs-1")
    }

    // MARK: - SearchValidationIssue Tests

    func testValidationIssueSeverity() {
        let error = SearchValidationIssue(severity: .error, message: "test error")
        let warning = SearchValidationIssue(severity: .warning, message: "test warning", parameter: "name")
        XCTAssertEqual(error.severity, .error)
        XCTAssertEqual(warning.severity, .warning)
        XCTAssertNil(error.parameter)
        XCTAssertEqual(warning.parameter, "name")
    }

    func testValidationIssueEquality() {
        let a = SearchValidationIssue(severity: .error, message: "msg", parameter: "p")
        let b = SearchValidationIssue(severity: .error, message: "msg", parameter: "p")
        let c = SearchValidationIssue(severity: .warning, message: "msg", parameter: "p")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - SearchParameterValidator Tests

    func testValidateValidQuery() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", .string("Smith"))
            .where("birthdate", .date(prefix: .ge, value: "1990-01-01"))
            .limited(to: 10)
        let issues = SearchParameterValidator.validate(query)
        XCTAssertTrue(issues.filter { $0.severity == .error }.isEmpty)
    }

    func testValidateUnknownParameter() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("nonexistent-param", .string("value"))
        let issues = SearchParameterValidator.validate(query)
        XCTAssertTrue(issues.contains(where: {
            $0.severity == .warning && $0.parameter == "nonexistent-param"
        }))
    }

    func testValidateEmptyResourceType() {
        let query = FHIRSearchQuery(resourceType: "")
        let issues = SearchParameterValidator.validate(query)
        XCTAssertTrue(issues.contains(where: {
            $0.severity == .error && $0.message.contains("empty")
        }))
    }

    func testValidateNegativeCount() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .limited(to: -1)
        let issues = SearchParameterValidator.validate(query)
        XCTAssertTrue(issues.contains(where: {
            $0.severity == .error && $0.parameter == "_count"
        }))
    }

    func testValidateNegativeOffset() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .offset(-5)
        let issues = SearchParameterValidator.validate(query)
        XCTAssertTrue(issues.contains(where: {
            $0.severity == .error && $0.parameter == "_offset"
        }))
    }

    func testValidateGlobalParameters() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("_id", .string("123"))
            .where("_lastUpdated", .date(prefix: .gt, value: "2024-01-01"))
        let issues = SearchParameterValidator.validate(query)
        XCTAssertTrue(issues.filter { $0.severity == .error }.isEmpty)
        XCTAssertTrue(issues.filter { $0.severity == .warning }.isEmpty)
    }

    func testValidateReverseChainedSkipped() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .reverseChained(
                targetType: "Observation",
                parameter: "patient",
                searchParam: "code",
                value: .token(system: nil, code: "8867-4")
            )
        let issues = SearchParameterValidator.validate(query)
        // _has parameters should not produce warnings
        XCTAssertTrue(issues.isEmpty)
    }

    func testValidateUnknownResourceType() {
        let query = FHIRSearchQuery(resourceType: "CustomResource")
            .where("custom-field", .string("value"))
        let issues = SearchParameterValidator.validate(query)
        // Unknown resource types should allow all parameters
        XCTAssertTrue(issues.filter { $0.severity == .warning }.isEmpty)
    }

    func testValidateModifierCompatibility() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("birthdate", modifier: .exact, .date(prefix: nil, value: "2000-01-01"))
        let issues = SearchParameterValidator.validate(query)
        XCTAssertTrue(issues.contains(where: {
            $0.severity == .warning && $0.message.contains("string parameters")
        }))
    }

    func testValidateMissingModifierWithWrongValue() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", modifier: .missing, .string("true"))
        let issues = SearchParameterValidator.validate(query)
        XCTAssertTrue(issues.contains(where: {
            $0.severity == .warning && $0.message.contains("missing")
        }))
    }

    // MARK: - isValidParameter Tests

    func testIsValidParameterKnownType() {
        XCTAssertTrue(SearchParameterValidator.isValidParameter("name", for: "Patient"))
        XCTAssertTrue(SearchParameterValidator.isValidParameter("birthdate", for: "Patient"))
        XCTAssertTrue(SearchParameterValidator.isValidParameter("code", for: "Observation"))
        XCTAssertFalse(SearchParameterValidator.isValidParameter("nonexistent", for: "Patient"))
    }

    func testIsValidParameterGlobal() {
        XCTAssertTrue(SearchParameterValidator.isValidParameter("_id", for: "Patient"))
        XCTAssertTrue(SearchParameterValidator.isValidParameter("_lastUpdated", for: "Patient"))
        XCTAssertTrue(SearchParameterValidator.isValidParameter("_tag", for: "Observation"))
    }

    func testIsValidParameterUnknownResourceType() {
        XCTAssertTrue(SearchParameterValidator.isValidParameter("anything", for: "UnknownResource"))
    }

    // MARK: - commonParameters Coverage

    func testCommonParametersForAllRegisteredTypes() {
        let types = ["Patient", "Observation", "Condition", "Encounter",
                     "Practitioner", "Organization", "MedicationRequest",
                     "DiagnosticReport", "AllergyIntolerance", "Bundle"]
        for type in types {
            XCTAssertNotNil(
                SearchParameterValidator.commonParameters[type],
                "Missing common parameters for \(type)"
            )
            XCTAssertFalse(
                SearchParameterValidator.commonParameters[type]!.isEmpty,
                "Common parameters for \(type) should not be empty"
            )
        }
    }

    // MARK: - Edge Cases

    func testQuantityValueNoSystemNoCode() {
        let value = SearchParameterValue.quantity(
            prefix: .ge, value: "100", system: nil, code: nil
        )
        XCTAssertEqual(value.queryString(), "ge100||")
    }

    func testQuantityValueWithSystemNoCode() {
        let value = SearchParameterValue.quantity(
            prefix: nil, value: "100", system: "http://example.com", code: nil
        )
        XCTAssertEqual(value.queryString(), "100|http://example.com|")
    }

    func testCompositeEmptyPairs() {
        let value = SearchParameterValue.composite([])
        XCTAssertEqual(value.queryString(), "")
    }

    func testSortMultipleValues() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .sorted(by: "family", ascending: true)
            .sorted(by: "given", ascending: true)
            .sorted(by: "birthdate", ascending: false)
        let items = query.toQueryItems()
        let sortItem = items.first(where: { $0.name == "_sort" })
        XCTAssertEqual(sortItem?.value, "family,given,-birthdate")
    }

    func testEmptyQueryProducesNoItems() {
        let query = FHIRSearchQuery(resourceType: "Patient")
        let items = query.toQueryItems()
        XCTAssertTrue(items.isEmpty)
    }

    func testTokenMissingModifier() {
        let param = SearchParameter(
            name: "code", modifier: .missing, value: .missing(true)
        )
        let item = param.toQueryItem()
        XCTAssertEqual(item.name, "code:missing")
        XCTAssertEqual(item.value, "true")
    }

    // MARK: - SearchResultEntry Tests

    func testSearchResultEntryInit() {
        let patient = Patient(id: "test-id", name: [HumanName(family: "Test")])
        let entry = SearchResultEntry(
            resource: patient,
            fullUrl: "http://example.com/Patient/test-id",
            searchMode: "match",
            searchScore: 0.95
        )
        XCTAssertEqual(entry.resource.id, "test-id")
        XCTAssertEqual(entry.fullUrl, "http://example.com/Patient/test-id")
        XCTAssertEqual(entry.searchMode, "match")
        XCTAssertEqual(entry.searchScore, 0.95)
    }

    func testSearchResultEntryDefaultValues() {
        let patient = Patient(id: "test-id")
        let entry = SearchResultEntry(resource: patient)
        XCTAssertNil(entry.fullUrl)
        XCTAssertNil(entry.searchMode)
        XCTAssertNil(entry.searchScore)
    }

    // MARK: - Performance Tests

    func testSearchQueryBuilderPerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = FHIRSearchQuery(resourceType: "Patient")
                    .where("name", .string("Smith"))
                    .where("gender", .token(system: nil, code: "male"))
                    .where("birthdate", .date(prefix: .ge, value: "1990-01-01"))
                    .include("Patient", parameter: "general-practitioner")
                    .revInclude("Observation", parameter: "subject")
                    .sorted(by: "birthdate", ascending: false)
                    .limited(to: 50)
                    .withTotal(.accurate)
                    .toQueryItems()
            }
        }
    }

    func testValidationPerformance() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", .string("Smith"))
            .where("gender", .token(system: nil, code: "male"))
            .where("birthdate", .date(prefix: .ge, value: "1990-01-01"))
            .where("address-city", .string("Boston"))
            .where("active", .token(system: nil, code: "true"))

        measure {
            for _ in 0..<1000 {
                let _ = SearchParameterValidator.validate(query)
            }
        }
    }

    // MARK: - Sendable Conformance Tests

    func testSendableTypes() async {
        // Verify types can be passed across concurrency boundaries
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("name", .string("Smith"))

        let task = Task { @Sendable in
            return query.toQueryItems()
        }
        let items = await task.value
        XCTAssertFalse(items.isEmpty)
    }

    func testSendableCompartmentSearch() async {
        let search = CompartmentSearch(
            compartmentType: "Patient",
            compartmentId: "123",
            resourceType: "Observation"
        )
        let task = Task { @Sendable in
            return search.path()
        }
        let path = await task.value
        XCTAssertEqual(path, "Patient/123/Observation")
    }
}
