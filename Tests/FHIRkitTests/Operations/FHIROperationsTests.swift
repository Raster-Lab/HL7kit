import XCTest
@testable import FHIRkit
@testable import HL7Core
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Mock URLSession for Operations Tests

/// Mock URL session for testing FHIROperationsClient without network access
final class MockOperationsURLSession: FHIRURLSession, @unchecked Sendable {
    var requests: [URLRequest] = []
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var responseHeaders: [String: String] = [:]
    var responseError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if let error = responseError {
            throw error
        }
        let url = request.url ?? URL(string: "https://example.com")!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: responseStatusCode,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )!
        return (responseData, httpResponse)
    }

    func reset() {
        requests = []
        responseData = Data()
        responseStatusCode = 200
        responseHeaders = [:]
        responseError = nil
    }
}

// MARK: - FHIROperationError Tests

final class FHIROperationErrorTests: XCTestCase {
    func testErrorDescriptions() {
        let cases: [(FHIROperationError, String)] = [
            (.invalidParameters("bad input"), "Invalid parameters: bad input"),
            (.operationNotSupported("$foo"), "Operation not supported: $foo"),
            (.operationFailed("failed"), "Operation failed: failed"),
            (.serverError(statusCode: 500, data: nil), "Server error: HTTP 500"),
            (.networkError("timeout"), "Network error: timeout"),
            (.invalidResponse("bad json"), "Invalid response: bad json"),
            (.timeout, "Operation timed out"),
            (.resourceNotFound(resourceType: "Patient", id: "1"), "Resource not found: Patient/1"),
        ]
        for (error, expected) in cases {
            XCTAssertEqual(error.description, expected)
        }
    }
}

// MARK: - OperationParameter Tests

final class OperationParameterTests: XCTestCase {
    func testInitDefaults() {
        let param = OperationParameter(name: "resource", use: .in)
        XCTAssertEqual(param.name, "resource")
        XCTAssertEqual(param.use, .in)
        XCTAssertEqual(param.min, 0)
        XCTAssertEqual(param.max, "1")
        XCTAssertNil(param.type)
        XCTAssertNil(param.documentation)
    }

    func testInitCustom() {
        let param = OperationParameter(
            name: "result",
            use: .out,
            min: 1,
            max: "*",
            type: "Bundle",
            documentation: "The result bundle"
        )
        XCTAssertEqual(param.name, "result")
        XCTAssertEqual(param.use, .out)
        XCTAssertEqual(param.min, 1)
        XCTAssertEqual(param.max, "*")
        XCTAssertEqual(param.type, "Bundle")
        XCTAssertEqual(param.documentation, "The result bundle")
    }

    func testCodable() throws {
        let param = OperationParameter(name: "input", use: .in, min: 1, max: "1", type: "Resource")
        let data = try JSONEncoder().encode(param)
        let decoded = try JSONDecoder().decode(OperationParameter.self, from: data)
        XCTAssertEqual(param, decoded)
    }

    func testUseRawValues() {
        XCTAssertEqual(OperationParameter.Use.in.rawValue, "in")
        XCTAssertEqual(OperationParameter.Use.out.rawValue, "out")
    }
}

// MARK: - FHIROperationDefinition Tests

final class FHIROperationDefinitionTests: XCTestCase {
    func testInitDefaults() {
        let def = FHIROperationDefinition(name: "Everything", code: "everything")
        XCTAssertEqual(def.name, "Everything")
        XCTAssertEqual(def.code, "everything")
        XCTAssertFalse(def.system)
        XCTAssertFalse(def.type)
        XCTAssertFalse(def.instance)
        XCTAssertNil(def.description)
        XCTAssertFalse(def.affectsState)
        XCTAssertTrue(def.inputParameters.isEmpty)
        XCTAssertTrue(def.outputParameters.isEmpty)
    }

    func testInitCustom() {
        let inputParam = OperationParameter(name: "start", use: .in, type: "date")
        let outputParam = OperationParameter(name: "return", use: .out, type: "Bundle")
        let def = FHIROperationDefinition(
            name: "Everything",
            code: "everything",
            system: false,
            type: true,
            instance: true,
            description: "Fetch everything",
            affectsState: false,
            inputParameters: [inputParam],
            outputParameters: [outputParam]
        )
        XCTAssertTrue(def.type)
        XCTAssertTrue(def.instance)
        XCTAssertEqual(def.description, "Fetch everything")
        XCTAssertEqual(def.inputParameters.count, 1)
        XCTAssertEqual(def.outputParameters.count, 1)
    }

    func testCodable() throws {
        let def = FHIROperationDefinition(
            name: "Validate",
            code: "validate",
            type: true,
            instance: true,
            description: "Validate a resource",
            inputParameters: [OperationParameter(name: "resource", use: .in, type: "Resource")]
        )
        let data = try JSONEncoder().encode(def)
        let decoded = try JSONDecoder().decode(FHIROperationDefinition.self, from: data)
        XCTAssertEqual(def, decoded)
    }
}

// MARK: - FHIROperationOutcome Tests

final class FHIROperationOutcomeTests: XCTestCase {
    func testInitSuccess() {
        let outcome = FHIROperationOutcome(successful: true, statusCode: 200)
        XCTAssertTrue(outcome.successful)
        XCTAssertNil(outcome.operationOutcome)
        XCTAssertNil(outcome.result)
        XCTAssertEqual(outcome.statusCode, 200)
    }

    func testInitWithData() {
        let data = Data("test".utf8)
        let outcome = FHIROperationOutcome(
            successful: false,
            result: data,
            statusCode: 422
        )
        XCTAssertFalse(outcome.successful)
        XCTAssertEqual(outcome.statusCode, 422)
        XCTAssertEqual(outcome.result, data)
    }
}

// MARK: - EverythingOperation Tests

final class EverythingOperationTests: XCTestCase {
    func testPatientEverythingDefaults() {
        let params = EverythingOperation.patientEverything(patientId: "123")
        XCTAssertNil(params.since)
        XCTAssertNil(params.type)
        XCTAssertNil(params.count)
        XCTAssertNil(params.start)
        XCTAssertNil(params.end)
    }

    func testPatientEverythingCustom() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 86400)
        let params = EverythingOperation.patientEverything(
            patientId: "456",
            start: start,
            end: end,
            type: ["Condition", "Observation"],
            count: 50,
            since: start
        )
        XCTAssertEqual(params.start, start)
        XCTAssertEqual(params.end, end)
        XCTAssertEqual(params.type, ["Condition", "Observation"])
        XCTAssertEqual(params.count, 50)
        XCTAssertEqual(params.since, start)
    }

    func testEncounterEverythingDefaults() {
        let params = EverythingOperation.encounterEverything(encounterId: "enc-1")
        XCTAssertNil(params.type)
        XCTAssertNil(params.count)
        XCTAssertNil(params.start)
        XCTAssertNil(params.end)
    }

    func testQueryItemsEmpty() {
        let params = EverythingOperation.EverythingParameters()
        let items = params.queryItems()
        XCTAssertTrue(items.isEmpty)
    }

    func testQueryItemsFull() {
        let since = Date(timeIntervalSince1970: 1000)
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 86400)
        let params = EverythingOperation.EverythingParameters(
            since: since,
            type: ["Patient", "Observation"],
            count: 10,
            start: start,
            end: end
        )
        let items = params.queryItems()
        XCTAssertEqual(items.count, 5)
        XCTAssertTrue(items.contains(where: { $0.name == "_since" }))
        XCTAssertTrue(items.contains(where: { $0.name == "_type" && $0.value == "Patient,Observation" }))
        XCTAssertTrue(items.contains(where: { $0.name == "_count" && $0.value == "10" }))
        XCTAssertTrue(items.contains(where: { $0.name == "start" }))
        XCTAssertTrue(items.contains(where: { $0.name == "end" }))
    }

    func testHashable() {
        let a = EverythingOperation.EverythingParameters(count: 10)
        let b = EverythingOperation.EverythingParameters(count: 10)
        XCTAssertEqual(a, b)
    }
}

// MARK: - ValidateOperation Tests

final class ValidateOperationTests: XCTestCase {
    func testValidateModeRawValues() {
        XCTAssertEqual(ValidateOperation.ValidateMode.create.rawValue, "create")
        XCTAssertEqual(ValidateOperation.ValidateMode.update.rawValue, "update")
        XCTAssertEqual(ValidateOperation.ValidateMode.delete.rawValue, "delete")
    }

    func testValidateParametersDefaults() {
        let params = ValidateOperation.ValidateParameters()
        XCTAssertNil(params.resource)
        XCTAssertNil(params.mode)
        XCTAssertNil(params.profile)
    }

    func testValidateParametersCustom() {
        let data = Data("{\"resourceType\":\"Patient\"}".utf8)
        let profile = URL(string: "http://hl7.org/fhir/StructureDefinition/Patient")!
        let params = ValidateOperation.ValidateParameters(
            resource: data,
            mode: .create,
            profile: profile
        )
        XCTAssertNotNil(params.resource)
        XCTAssertEqual(params.mode, .create)
        XCTAssertEqual(params.profile, profile)
    }
}

// MARK: - ConvertOperation Tests

final class ConvertOperationTests: XCTestCase {
    func testConvertFormatRawValues() {
        XCTAssertEqual(ConvertOperation.ConvertFormat.json.rawValue, "application/fhir+json")
        XCTAssertEqual(ConvertOperation.ConvertFormat.xml.rawValue, "application/fhir+xml")
        XCTAssertEqual(ConvertOperation.ConvertFormat.turtle.rawValue, "application/fhir+turtle")
    }

    func testConvertParameters() {
        let input = Data("<Patient/>".utf8)
        let params = ConvertOperation.ConvertParameters(
            input: input,
            inputFormat: .xml,
            outputFormat: .json
        )
        XCTAssertEqual(params.input, input)
        XCTAssertEqual(params.inputFormat, .xml)
        XCTAssertEqual(params.outputFormat, .json)
    }
}

// MARK: - MetaOperation Tests

final class MetaOperationTests: XCTestCase {
    func testMetaDataDefaults() {
        let meta = MetaOperation.MetaData()
        XCTAssertTrue(meta.profiles.isEmpty)
        XCTAssertTrue(meta.security.isEmpty)
        XCTAssertTrue(meta.tags.isEmpty)
    }

    func testMetaDataCustom() {
        let coding = Coding(system: "http://example.com", code: "test", display: "Test")
        let meta = MetaOperation.MetaData(
            profiles: ["http://hl7.org/fhir/StructureDefinition/Patient"],
            security: [coding],
            tags: [coding]
        )
        XCTAssertEqual(meta.profiles.count, 1)
        XCTAssertEqual(meta.security.count, 1)
        XCTAssertEqual(meta.tags.count, 1)
    }

    func testMetaDataCodable() throws {
        let coding = Coding(system: "http://example.com", code: "tag1")
        let meta = MetaOperation.MetaData(profiles: ["prof1"], tags: [coding])
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(MetaOperation.MetaData.self, from: data)
        XCTAssertEqual(meta, decoded)
    }

    func testMetaOperationAdd() {
        let meta = MetaOperation.MetaData(profiles: ["http://example.com/profile"])
        let add = MetaOperation.MetaOperationAdd(meta: meta)
        XCTAssertEqual(add.meta.profiles.count, 1)
    }

    func testMetaOperationDelete() {
        let coding = Coding(code: "remove-me")
        let meta = MetaOperation.MetaData(tags: [coding])
        let del = MetaOperation.MetaOperationDelete(meta: meta)
        XCTAssertEqual(del.meta.tags.count, 1)
    }
}

// MARK: - BulkExportOperation Tests

final class BulkExportOperationTests: XCTestCase {
    func testExportTypeRawValues() {
        XCTAssertEqual(BulkExportOperation.ExportType.system.rawValue, "system")
        XCTAssertEqual(BulkExportOperation.ExportType.group.rawValue, "group")
        XCTAssertEqual(BulkExportOperation.ExportType.patient.rawValue, "patient")
    }

    func testExportStatusRawValues() {
        XCTAssertEqual(BulkExportOperation.ExportStatus.pending.rawValue, "pending")
        XCTAssertEqual(BulkExportOperation.ExportStatus.inProgress.rawValue, "inProgress")
        XCTAssertEqual(BulkExportOperation.ExportStatus.complete.rawValue, "complete")
        XCTAssertEqual(BulkExportOperation.ExportStatus.error.rawValue, "error")
    }

    func testExportParametersDefaults() {
        let params = BulkExportOperation.ExportParameters()
        XCTAssertNil(params.outputFormat)
        XCTAssertNil(params.since)
        XCTAssertNil(params.types)
    }

    func testExportParametersQueryItems() {
        let params = BulkExportOperation.ExportParameters(
            outputFormat: "application/fhir+ndjson",
            since: Date(timeIntervalSince1970: 0),
            types: ["Patient", "Observation"]
        )
        let items = params.queryItems()
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains(where: { $0.name == "_outputFormat" }))
        XCTAssertTrue(items.contains(where: { $0.name == "_since" }))
        XCTAssertTrue(items.contains(where: { $0.name == "_type" && $0.value == "Patient,Observation" }))
    }

    func testExportParametersEmptyQueryItems() {
        let params = BulkExportOperation.ExportParameters()
        XCTAssertTrue(params.queryItems().isEmpty)
    }

    func testExportFile() {
        let file = BulkExportOperation.ExportFile(
            type: "Patient",
            url: "https://example.com/export/patient.ndjson",
            count: 100
        )
        XCTAssertEqual(file.type, "Patient")
        XCTAssertEqual(file.url, "https://example.com/export/patient.ndjson")
        XCTAssertEqual(file.count, 100)
    }

    func testExportFileCodable() throws {
        let file = BulkExportOperation.ExportFile(type: "Observation", url: "https://example.com/obs.ndjson", count: 50)
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(BulkExportOperation.ExportFile.self, from: data)
        XCTAssertEqual(file, decoded)
    }

    func testExportStatusResponse() {
        let file = BulkExportOperation.ExportFile(type: "Patient", url: "https://example.com/p.ndjson")
        let response = BulkExportOperation.ExportStatusResponse(
            transactionTime: "2024-01-01T00:00:00Z",
            request: "https://example.com/$export",
            requiresAccessToken: true,
            output: [file],
            error: []
        )
        XCTAssertEqual(response.transactionTime, "2024-01-01T00:00:00Z")
        XCTAssertTrue(response.requiresAccessToken)
        XCTAssertEqual(response.output.count, 1)
        XCTAssertTrue(response.error.isEmpty)
    }

    func testExportStatusResponseCodable() throws {
        let response = BulkExportOperation.ExportStatusResponse(
            transactionTime: "2024-01-01T00:00:00Z",
            request: "https://example.com/$export",
            output: [BulkExportOperation.ExportFile(type: "Patient", url: "https://example.com/p.ndjson", count: 10)]
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(BulkExportOperation.ExportStatusResponse.self, from: data)
        XCTAssertEqual(response, decoded)
    }
}

// MARK: - CustomOperation Tests

final class CustomOperationTests: XCTestCase {
    func testOperationLevelRawValues() {
        XCTAssertEqual(CustomOperation.OperationLevel.system.rawValue, "system")
        XCTAssertEqual(CustomOperation.OperationLevel.type.rawValue, "type")
        XCTAssertEqual(CustomOperation.OperationLevel.instance.rawValue, "instance")
    }

    func testHTTPMethodRawValues() {
        XCTAssertEqual(CustomOperation.HTTPMethod.GET.rawValue, "GET")
        XCTAssertEqual(CustomOperation.HTTPMethod.POST.rawValue, "POST")
    }

    func testParameterValueString() {
        let val = CustomOperation.ParameterValue.string("hello")
        let param = CustomOperation.CustomOperationParameter(name: "greeting", value: val)
        XCTAssertEqual(param.name, "greeting")
        if case .string(let s) = param.value {
            XCTAssertEqual(s, "hello")
        } else {
            XCTFail("Expected string value")
        }
    }

    func testParameterValueInteger() {
        let val = CustomOperation.ParameterValue.integer(42)
        if case .integer(let i) = val {
            XCTAssertEqual(i, 42)
        } else {
            XCTFail("Expected integer value")
        }
    }

    func testParameterValueBoolean() {
        let val = CustomOperation.ParameterValue.boolean(true)
        if case .boolean(let b) = val {
            XCTAssertTrue(b)
        } else {
            XCTFail("Expected boolean value")
        }
    }

    func testParameterValueDecimal() {
        let val = CustomOperation.ParameterValue.decimal(3.14)
        if case .decimal(let d) = val {
            XCTAssertEqual(d, 3.14, accuracy: 0.001)
        } else {
            XCTFail("Expected decimal value")
        }
    }

    func testParameterValueDate() {
        let date = Date(timeIntervalSince1970: 0)
        let val = CustomOperation.ParameterValue.date(date)
        if case .date(let d) = val {
            XCTAssertEqual(d, date)
        } else {
            XCTFail("Expected date value")
        }
    }

    func testParameterValueResource() {
        let data = Data("{\"resourceType\":\"Patient\"}".utf8)
        let val = CustomOperation.ParameterValue.resource(data)
        if case .resource(let d) = val {
            XCTAssertEqual(d, data)
        } else {
            XCTFail("Expected resource value")
        }
    }

    func testCustomOperationDefinitionDefaults() {
        let def = CustomOperation.CustomOperationDefinition(name: "$my-op")
        XCTAssertEqual(def.name, "$my-op")
        XCTAssertEqual(def.httpMethod, .POST)
        XCTAssertEqual(def.level, .system)
        XCTAssertTrue(def.parameters.isEmpty)
    }

    func testCustomOperationDefinitionCustom() {
        let param = CustomOperation.CustomOperationParameter(
            name: "input",
            value: .string("test")
        )
        let def = CustomOperation.CustomOperationDefinition(
            name: "$custom",
            httpMethod: .GET,
            level: .type,
            parameters: [param]
        )
        XCTAssertEqual(def.httpMethod, .GET)
        XCTAssertEqual(def.level, .type)
        XCTAssertEqual(def.parameters.count, 1)
    }

    func testParameterValueHashable() {
        let a = CustomOperation.ParameterValue.string("test")
        let b = CustomOperation.ParameterValue.string("test")
        XCTAssertEqual(a, b)

        let c = CustomOperation.ParameterValue.integer(1)
        let d = CustomOperation.ParameterValue.integer(2)
        XCTAssertNotEqual(c, d)
    }
}

// MARK: - FHIROperationRegistry Tests

final class FHIROperationRegistryTests: XCTestCase {
    func testRegisterAndRetrieve() async {
        let registry = FHIROperationRegistry()
        let def = CustomOperation.CustomOperationDefinition(name: "$test-op")
        await registry.register(def)
        let retrieved = await registry.operation(named: "$test-op")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "$test-op")
    }

    func testUnregister() async {
        let registry = FHIROperationRegistry()
        let def = CustomOperation.CustomOperationDefinition(name: "$remove-me")
        await registry.register(def)
        await registry.unregister(name: "$remove-me")
        let retrieved = await registry.operation(named: "$remove-me")
        XCTAssertNil(retrieved)
    }

    func testOperationNotFound() async {
        let registry = FHIROperationRegistry()
        let retrieved = await registry.operation(named: "$nonexistent")
        XCTAssertNil(retrieved)
    }

    func testAllOperations() async {
        let registry = FHIROperationRegistry()
        await registry.register(CustomOperation.CustomOperationDefinition(name: "$op1"))
        await registry.register(CustomOperation.CustomOperationDefinition(name: "$op2"))
        let all = await registry.allOperations()
        XCTAssertEqual(all.count, 2)
    }

    func testRegisterOverwrites() async {
        let registry = FHIROperationRegistry()
        await registry.register(CustomOperation.CustomOperationDefinition(name: "$op", httpMethod: .GET))
        await registry.register(CustomOperation.CustomOperationDefinition(name: "$op", httpMethod: .POST))
        let retrieved = await registry.operation(named: "$op")
        XCTAssertEqual(retrieved?.httpMethod, .POST)
    }
}

// MARK: - FHIROperationsClient Tests

final class FHIROperationsClientTests: XCTestCase {
    var mockSession: MockOperationsURLSession!
    var client: FHIROperationsClient!
    let baseURL = URL(string: "https://fhir.example.com/r4")!

    override func setUp() {
        super.setUp()
        mockSession = MockOperationsURLSession()
        client = FHIROperationsClient(session: mockSession, baseURL: baseURL)
    }

    // MARK: - $everything Tests

    func testPatientEverythingSuccess() async throws {
        let bundleJSON = Data("{\"resourceType\":\"Bundle\",\"type\":\"searchset\"}".utf8)
        mockSession.responseData = bundleJSON
        mockSession.responseStatusCode = 200

        let data = try await client.executePatientEverything(patientId: "123")
        XCTAssertEqual(data, bundleJSON)
        XCTAssertEqual(mockSession.requests.count, 1)
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.absoluteString.contains("Patient/123/$everything") ?? false)
    }

    func testPatientEverythingWithParameters() async throws {
        mockSession.responseData = Data("{}".utf8)
        mockSession.responseStatusCode = 200

        let params = EverythingOperation.EverythingParameters(
            type: ["Condition"],
            count: 20
        )
        _ = try await client.executePatientEverything(patientId: "456", parameters: params)
        let url = mockSession.requests[0].url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("_type=Condition"))
        XCTAssertTrue(url.contains("_count=20"))
    }

    func testPatientEverythingEmptyIdThrows() async {
        do {
            _ = try await client.executePatientEverything(patientId: "")
            XCTFail("Expected error for empty patientId")
        } catch let error as FHIROperationError {
            if case .invalidParameters = error {
                // Expected
            } else {
                XCTFail("Expected invalidParameters, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testEncounterEverythingSuccess() async throws {
        mockSession.responseData = Data("{\"resourceType\":\"Bundle\"}".utf8)
        mockSession.responseStatusCode = 200

        let data = try await client.executeEncounterEverything(encounterId: "enc-1")
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(mockSession.requests[0].url?.absoluteString.contains("Encounter/enc-1/$everything") ?? false)
    }

    func testEncounterEverythingEmptyIdThrows() async {
        do {
            _ = try await client.executeEncounterEverything(encounterId: "")
            XCTFail("Expected error for empty encounterId")
        } catch let error as FHIROperationError {
            if case .invalidParameters = error {
                // Expected
            } else {
                XCTFail("Expected invalidParameters error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testEverythingServerError() async {
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 500

        do {
            _ = try await client.executePatientEverything(patientId: "123")
            XCTFail("Expected server error")
        } catch let error as FHIROperationError {
            if case .serverError(let code, _) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected serverError")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - $validate Tests

    func testValidateSuccess() async throws {
        let outcomeJSON = """
        {
            "resourceType": "OperationOutcome",
            "messageID": "test",
            "timestamp": 0,
            "issue": [{"severity": "information", "code": "informational"}]
        }
        """.data(using: .utf8)!
        mockSession.responseData = outcomeJSON
        mockSession.responseStatusCode = 200

        let resourceData = Data("{\"resourceType\":\"Patient\"}".utf8)
        let params = ValidateOperation.ValidateParameters(resource: resourceData, mode: .create)
        let result = try await client.executeValidate(resourceType: "Patient", parameters: params)
        XCTAssertTrue(result.successful)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(mockSession.requests[0].httpMethod, "POST")
        let url = mockSession.requests[0].url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("Patient/$validate"))
        XCTAssertTrue(url.contains("mode=create"))
    }

    func testValidateWithProfile() async throws {
        mockSession.responseData = Data("{}".utf8)
        mockSession.responseStatusCode = 200

        let profile = URL(string: "http://hl7.org/fhir/StructureDefinition/Patient")!
        let params = ValidateOperation.ValidateParameters(mode: .update, profile: profile)
        _ = try await client.executeValidate(resourceType: "Patient", parameters: params)
        let url = mockSession.requests[0].url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("profile="))
    }

    func testValidateFailure() async throws {
        mockSession.responseData = Data("{}".utf8)
        mockSession.responseStatusCode = 422

        let params = ValidateOperation.ValidateParameters()
        let result = try await client.executeValidate(resourceType: "Patient", parameters: params)
        XCTAssertFalse(result.successful)
        XCTAssertEqual(result.statusCode, 422)
    }

    func testValidateEmptyResourceTypeThrows() async {
        do {
            let params = ValidateOperation.ValidateParameters()
            _ = try await client.executeValidate(resourceType: "", parameters: params)
            XCTFail("Expected error")
        } catch let error as FHIROperationError {
            if case .invalidParameters = error {} else { XCTFail("Wrong error type") }
        } catch {
            XCTFail("Unexpected error")
        }
    }

    // MARK: - $convert Tests

    func testConvertSuccess() async throws {
        let outputData = Data("{\"resourceType\":\"Patient\"}".utf8)
        mockSession.responseData = outputData
        mockSession.responseStatusCode = 200

        let params = ConvertOperation.ConvertParameters(
            input: Data("<Patient/>".utf8),
            inputFormat: .xml,
            outputFormat: .json
        )
        let result = try await client.executeConvert(parameters: params)
        XCTAssertEqual(result, outputData)
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/fhir+xml")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/fhir+json")
    }

    func testConvertServerError() async {
        mockSession.responseStatusCode = 500
        mockSession.responseData = Data()

        let params = ConvertOperation.ConvertParameters(
            input: Data("invalid".utf8),
            inputFormat: .json,
            outputFormat: .xml
        )
        do {
            _ = try await client.executeConvert(parameters: params)
            XCTFail("Expected server error")
        } catch let error as FHIROperationError {
            if case .serverError(let code, _) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected serverError")
            }
        } catch {
            XCTFail("Unexpected error")
        }
    }

    // MARK: - $meta Tests

    func testMetaSuccess() async throws {
        let metaJSON = Data("{\"profiles\":[],\"security\":[],\"tags\":[]}".utf8)
        mockSession.responseData = metaJSON
        mockSession.responseStatusCode = 200

        let meta = try await client.executeMeta(resourceType: "Patient", resourceId: "123")
        XCTAssertTrue(meta.profiles.isEmpty)
        XCTAssertTrue(mockSession.requests[0].url?.absoluteString.contains("Patient/123/$meta") ?? false)
    }

    func testMetaAddSuccess() async throws {
        let responseJSON = Data("{\"profiles\":[\"http://example.com/prof\"],\"security\":[],\"tags\":[]}".utf8)
        mockSession.responseData = responseJSON
        mockSession.responseStatusCode = 200

        let addMeta = MetaOperation.MetaData(profiles: ["http://example.com/prof"])
        let result = try await client.executeMetaAdd(
            resourceType: "Patient",
            resourceId: "123",
            meta: addMeta
        )
        XCTAssertEqual(result.profiles.count, 1)
        XCTAssertTrue(mockSession.requests[0].url?.absoluteString.contains("$meta-add") ?? false)
        XCTAssertEqual(mockSession.requests[0].httpMethod, "POST")
    }

    func testMetaDeleteSuccess() async throws {
        let responseJSON = Data("{\"profiles\":[],\"security\":[],\"tags\":[]}".utf8)
        mockSession.responseData = responseJSON
        mockSession.responseStatusCode = 200

        let delMeta = MetaOperation.MetaData(tags: [Coding(code: "remove")])
        let result = try await client.executeMetaDelete(
            resourceType: "Patient",
            resourceId: "123",
            meta: delMeta
        )
        XCTAssertTrue(result.tags.isEmpty)
        XCTAssertTrue(mockSession.requests[0].url?.absoluteString.contains("$meta-delete") ?? false)
    }

    func testMetaEmptyParamsThrows() async {
        do {
            _ = try await client.executeMeta(resourceType: "", resourceId: "123")
            XCTFail("Expected error")
        } catch let error as FHIROperationError {
            if case .invalidParameters = error {} else { XCTFail("Wrong error") }
        } catch {
            XCTFail("Unexpected error")
        }
    }

    // MARK: - Bulk Export Tests

    func testStartBulkExportSuccess() async throws {
        mockSession.responseStatusCode = 202
        mockSession.responseHeaders = [
            "Content-Location": "https://fhir.example.com/r4/$export-status/123"
        ]
        mockSession.responseData = Data()

        let params = BulkExportOperation.ExportParameters(types: ["Patient"])
        let statusURL = try await client.startBulkExport(parameters: params)
        XCTAssertEqual(statusURL.absoluteString, "https://fhir.example.com/r4/$export-status/123")
        let request = mockSession.requests[0]
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "respond-async")
    }

    func testStartBulkExportNon202Throws() async {
        mockSession.responseStatusCode = 200
        mockSession.responseData = Data()

        do {
            _ = try await client.startBulkExport(parameters: BulkExportOperation.ExportParameters())
            XCTFail("Expected error")
        } catch let error as FHIROperationError {
            if case .operationFailed = error {} else { XCTFail("Wrong error: \(error)") }
        } catch {
            XCTFail("Unexpected error")
        }
    }

    func testCheckBulkExportStatusComplete() async throws {
        let responseJSON = """
        {
            "transactionTime": "2024-01-01T00:00:00Z",
            "request": "https://example.com/$export",
            "requiresAccessToken": false,
            "output": [{"type": "Patient", "url": "https://example.com/p.ndjson", "count": 100}],
            "error": []
        }
        """.data(using: .utf8)!
        mockSession.responseData = responseJSON
        mockSession.responseStatusCode = 200

        let statusURL = URL(string: "https://fhir.example.com/r4/$export-status/123")!
        let response = try await client.checkBulkExportStatus(statusURL: statusURL)
        XCTAssertEqual(response.transactionTime, "2024-01-01T00:00:00Z")
        XCTAssertEqual(response.output.count, 1)
        XCTAssertEqual(response.output[0].count, 100)
    }

    func testCheckBulkExportStatusInProgress() async {
        mockSession.responseStatusCode = 202
        mockSession.responseData = Data()

        let statusURL = URL(string: "https://fhir.example.com/r4/$export-status/123")!
        do {
            _ = try await client.checkBulkExportStatus(statusURL: statusURL)
            XCTFail("Expected error for in-progress export")
        } catch let error as FHIROperationError {
            if case .operationFailed = error {} else { XCTFail("Wrong error") }
        } catch {
            XCTFail("Unexpected error")
        }
    }

    // MARK: - Custom Operation Tests

    func testExecuteCustomGETOperation() async throws {
        mockSession.responseData = Data("{\"result\":\"ok\"}".utf8)
        mockSession.responseStatusCode = 200

        let def = CustomOperation.CustomOperationDefinition(
            name: "$my-op",
            httpMethod: .GET,
            level: .system
        )
        let params = [CustomOperation.CustomOperationParameter(name: "input", value: .string("test"))]
        let data = try await client.executeCustomOperation(definition: def, parameters: params)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(mockSession.requests[0].httpMethod, "GET")
        let url = mockSession.requests[0].url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("$my-op"))
        XCTAssertTrue(url.contains("input=test"))
    }

    func testExecuteCustomPOSTOperation() async throws {
        mockSession.responseData = Data("{}".utf8)
        mockSession.responseStatusCode = 200

        let def = CustomOperation.CustomOperationDefinition(
            name: "$process",
            httpMethod: .POST,
            level: .type
        )
        let params = [
            CustomOperation.CustomOperationParameter(name: "count", value: .integer(5)),
            CustomOperation.CustomOperationParameter(name: "active", value: .boolean(true)),
        ]
        let data = try await client.executeCustomOperation(
            definition: def,
            resourceType: "Patient",
            parameters: params
        )
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(mockSession.requests[0].httpMethod, "POST")
        let url = mockSession.requests[0].url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("Patient/$process"))
    }

    func testExecuteCustomInstanceOperation() async throws {
        mockSession.responseData = Data("{}".utf8)
        mockSession.responseStatusCode = 200

        let def = CustomOperation.CustomOperationDefinition(
            name: "$summary",
            httpMethod: .GET,
            level: .instance
        )
        _ = try await client.executeCustomOperation(
            definition: def,
            resourceType: "Patient",
            resourceId: "123"
        )
        let url = mockSession.requests[0].url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("Patient/123/$summary"))
    }

    func testRegisterCustomOperation() async {
        let def = CustomOperation.CustomOperationDefinition(name: "$registered")
        await client.registerCustomOperation(def)
        // Registration should not throw
    }

    // MARK: - Network Error Tests

    func testNetworkErrorWrapped() async {
        mockSession.responseError = URLError(.notConnectedToInternet)

        do {
            _ = try await client.executePatientEverything(patientId: "123")
            XCTFail("Expected network error")
        } catch let error as FHIROperationError {
            if case .networkError = error {} else { XCTFail("Expected networkError, got \(error)") }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Custom Operation with Resource Parameter

    func testCustomOperationWithResourceParam() async throws {
        mockSession.responseData = Data("{}".utf8)
        mockSession.responseStatusCode = 200

        let resourceData = Data("{\"resourceType\":\"Patient\"}".utf8)
        let def = CustomOperation.CustomOperationDefinition(
            name: "$process",
            httpMethod: .POST,
            level: .system
        )
        let params = [
            CustomOperation.CustomOperationParameter(name: "resource", value: .resource(resourceData))
        ]
        _ = try await client.executeCustomOperation(definition: def, parameters: params)
        let request = mockSession.requests[0]
        XCTAssertNotNil(request.httpBody)
    }

    func testCustomOperationGETSkipsResourceParam() async throws {
        mockSession.responseData = Data("{}".utf8)
        mockSession.responseStatusCode = 200

        let resourceData = Data("{\"resourceType\":\"Patient\"}".utf8)
        let def = CustomOperation.CustomOperationDefinition(
            name: "$check",
            httpMethod: .GET,
            level: .system
        )
        let params = [
            CustomOperation.CustomOperationParameter(name: "resource", value: .resource(resourceData)),
            CustomOperation.CustomOperationParameter(name: "name", value: .string("test")),
        ]
        _ = try await client.executeCustomOperation(definition: def, parameters: params)
        let url = mockSession.requests[0].url?.absoluteString ?? ""
        // Resource params should be skipped in GET queries
        XCTAssertTrue(url.contains("name=test"))
    }

    // MARK: - Custom Operation with Decimal and Date Parameters

    func testCustomOperationDecimalAndDateParams() async throws {
        mockSession.responseData = Data("{}".utf8)
        mockSession.responseStatusCode = 200

        let def = CustomOperation.CustomOperationDefinition(
            name: "$calc",
            httpMethod: .GET,
            level: .system
        )
        let date = Date(timeIntervalSince1970: 0)
        let params = [
            CustomOperation.CustomOperationParameter(name: "amount", value: .decimal(99.99)),
            CustomOperation.CustomOperationParameter(name: "date", value: .date(date)),
        ]
        _ = try await client.executeCustomOperation(definition: def, parameters: params)
        let url = mockSession.requests[0].url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("amount=99.99"))
        XCTAssertTrue(url.contains("date="))
    }
}
