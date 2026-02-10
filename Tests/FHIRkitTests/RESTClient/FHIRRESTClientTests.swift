import XCTest
@testable import FHIRkit
@testable import HL7Core
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Mock URLSession

/// Mock URL session for testing FHIRClient without network access
final class MockFHIRURLSession: FHIRURLSession, @unchecked Sendable {
    /// Recorded requests
    var requests: [URLRequest] = []
    
    /// Response to return for the next request
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var responseHeaders: [String: String] = [:]
    var responseError: Error?
    
    /// Sequence of responses for multiple calls
    var responseQueue: [(Data, Int, [String: String])] = []
    private var callIndex = 0
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        
        if let error = responseError {
            throw error
        }
        
        let data: Data
        let statusCode: Int
        let headers: [String: String]
        
        if !responseQueue.isEmpty && callIndex < responseQueue.count {
            let response = responseQueue[callIndex]
            data = response.0
            statusCode = response.1
            headers = response.2
            callIndex += 1
        } else {
            data = responseData
            statusCode = responseStatusCode
            headers = responseHeaders
        }
        
        let url = request.url ?? URL(string: "https://example.com")!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        
        return (data, httpResponse)
    }
    
    func reset() {
        requests = []
        responseData = Data()
        responseStatusCode = 200
        responseHeaders = [:]
        responseError = nil
        responseQueue = []
        callIndex = 0
    }
}

// MARK: - Test Helpers

/// Helper to create test JSON data for FHIR resources
enum TestJSONHelper {
    static func patientJSON(id: String = "123", family: String = "Smith", given: String = "John") -> Data {
        let json = """
        {
            "resourceType": "Patient",
            "id": "\(id)",
            "messageID": "test-msg",
            "timestamp": 0,
            "name": [{"family": "\(family)", "given": ["\(given)"]}],
            "active": true
        }
        """
        return json.data(using: .utf8)!
    }
    
    static func bundleJSON(type: String = "searchset", total: Int32 = 1, nextURL: String? = nil, previousURL: String? = nil) -> Data {
        var links: [[String: String]] = []
        links.append(["relation": "self", "url": "https://fhir.example.org/r4/Patient?_count=10"])
        if let nextURL = nextURL {
            links.append(["relation": "next", "url": nextURL])
        }
        if let previousURL = previousURL {
            links.append(["relation": "previous", "url": previousURL])
        }
        
        let linksJSON = links.map { dict in
            "{\"relation\":\"\(dict["relation"]!)\",\"url\":\"\(dict["url"]!)\"}"
        }.joined(separator: ",")
        
        let json = """
        {
            "resourceType": "Bundle",
            "id": "bundle-1",
            "messageID": "test-bundle",
            "timestamp": 0,
            "type": "\(type)",
            "total": \(total),
            "link": [\(linksJSON)],
            "entry": [{
                "fullUrl": "https://fhir.example.org/r4/Patient/123",
                "resource": {
                    "resourceType": "Patient",
                    "id": "123",
                    "messageID": "test-entry",
                    "timestamp": 0,
                    "name": [{"family": "Smith", "given": ["John"]}],
                    "active": true
                }
            }]
        }
        """
        return json.data(using: .utf8)!
    }
    
    static func operationOutcomeJSON(severity: String = "error", code: String = "not-found", diagnostics: String = "Resource not found") -> Data {
        let json = """
        {
            "resourceType": "OperationOutcome",
            "messageID": "test-outcome",
            "timestamp": 0,
            "issue": [{
                "severity": "\(severity)",
                "code": "\(code)",
                "diagnostics": "\(diagnostics)"
            }]
        }
        """
        return json.data(using: .utf8)!
    }
    
    static func transactionBundleJSON() -> Data {
        let json = """
        {
            "resourceType": "Bundle",
            "id": "transaction-response",
            "messageID": "test-txn",
            "timestamp": 0,
            "type": "transaction-response",
            "entry": [{
                "response": {
                    "status": "201 Created",
                    "location": "Patient/456",
                    "etag": "W/\\"1\\""
                }
            }]
        }
        """
        return json.data(using: .utf8)!
    }
}

// MARK: - Configuration Tests

final class FHIRClientConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let url = URL(string: "https://fhir.example.org/r4")!
        let config = FHIRClientConfiguration(baseURL: url)
        
        XCTAssertEqual(config.baseURL, url)
        XCTAssertEqual(config.preferredFormat, .json)
        XCTAssertEqual(config.timeout, 30.0)
        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertEqual(config.retryBaseDelay, 1.0)
        XCTAssertTrue(config.additionalHeaders.isEmpty)
        XCTAssertNil(config.authorization)
    }
    
    func testCustomConfiguration() {
        let url = URL(string: "https://fhir.example.org/r4")!
        let config = FHIRClientConfiguration(
            baseURL: url,
            preferredFormat: .xml,
            timeout: 60.0,
            maxRetryAttempts: 5,
            retryBaseDelay: 2.0,
            additionalHeaders: ["X-Custom": "value"],
            authorization: "Bearer test-token"
        )
        
        XCTAssertEqual(config.baseURL, url)
        XCTAssertEqual(config.preferredFormat, .xml)
        XCTAssertEqual(config.timeout, 60.0)
        XCTAssertEqual(config.maxRetryAttempts, 5)
        XCTAssertEqual(config.retryBaseDelay, 2.0)
        XCTAssertEqual(config.additionalHeaders["X-Custom"], "value")
        XCTAssertEqual(config.authorization, "Bearer test-token")
    }
    
    func testResponseFormatRawValues() {
        XCTAssertEqual(FHIRClientConfiguration.ResponseFormat.json.rawValue, "application/fhir+json")
        XCTAssertEqual(FHIRClientConfiguration.ResponseFormat.xml.rawValue, "application/fhir+xml")
    }
}

// MARK: - Error Tests

final class FHIRClientErrorTests: XCTestCase {
    
    func testOperationOutcomeErrorDescription() {
        let outcome = OperationOutcome(
            issue: [OperationOutcomeIssue(severity: "error", code: "not-found", diagnostics: "Not found")]
        )
        let error = FHIRClientError.operationOutcome(outcome)
        XCTAssertTrue(error.description.contains("OperationOutcome"))
        XCTAssertTrue(error.description.contains("not-found"))
    }
    
    func testHttpErrorDescription() {
        let error = FHIRClientError.httpError(statusCode: 500, data: nil)
        XCTAssertTrue(error.description.contains("500"))
    }
    
    func testNetworkErrorDescription() {
        let error = FHIRClientError.networkError("Connection refused")
        XCTAssertTrue(error.description.contains("Connection refused"))
    }
    
    func testInvalidRequestDescription() {
        let error = FHIRClientError.invalidRequest("Bad URL")
        XCTAssertTrue(error.description.contains("Bad URL"))
    }
    
    func testDecodingErrorDescription() {
        let error = FHIRClientError.decodingError("Missing field")
        XCTAssertTrue(error.description.contains("Missing field"))
    }
    
    func testNotFoundDescription() {
        let error = FHIRClientError.notFound(resourceType: "Patient", id: "123")
        XCTAssertTrue(error.description.contains("Patient/123"))
    }
    
    func testGoneDescription() {
        let error = FHIRClientError.gone(resourceType: "Patient", id: "123")
        XCTAssertTrue(error.description.contains("deleted"))
    }
    
    func testTimeoutDescription() {
        let error = FHIRClientError.timeout
        XCTAssertTrue(error.description.contains("timed out"))
    }
    
    func testInvalidResponseDescription() {
        let error = FHIRClientError.invalidResponse("Bad response")
        XCTAssertTrue(error.description.contains("Bad response"))
    }
}

// MARK: - FHIRResponse Tests

final class FHIRResponseTests: XCTestCase {
    
    func testResponseCreation() {
        let response = FHIRResponse(
            resource: "test",
            statusCode: 200,
            etag: "W/\"1\"",
            lastModified: "2024-01-01T00:00:00Z",
            location: "Patient/123"
        )
        
        XCTAssertEqual(response.resource, "test")
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.etag, "W/\"1\"")
        XCTAssertEqual(response.lastModified, "2024-01-01T00:00:00Z")
        XCTAssertEqual(response.location, "Patient/123")
    }
    
    func testResponseDefaultOptionals() {
        let response = FHIRResponse(resource: 42, statusCode: 201)
        
        XCTAssertEqual(response.resource, 42)
        XCTAssertEqual(response.statusCode, 201)
        XCTAssertNil(response.etag)
        XCTAssertNil(response.lastModified)
        XCTAssertNil(response.location)
    }
}

// MARK: - URL Building Tests

final class FHIRClientURLBuildingTests: XCTestCase {
    
    var client: FHIRClient!
    var mockSession: MockFHIRURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!
        )
        client = FHIRClient(configuration: config, session: mockSession)
    }
    
    func testBuildBaseURL() async throws {
        let url = try await client.buildURL()
        XCTAssertEqual(url.absoluteString, "https://fhir.example.org/r4")
    }
    
    func testBuildResourceTypeURL() async throws {
        let url = try await client.buildURL(resourceType: "Patient")
        XCTAssertEqual(url.absoluteString, "https://fhir.example.org/r4/Patient")
    }
    
    func testBuildResourceIdURL() async throws {
        let url = try await client.buildURL(resourceType: "Patient", id: "123")
        XCTAssertEqual(url.absoluteString, "https://fhir.example.org/r4/Patient/123")
    }
    
    func testBuildHistoryURL() async throws {
        let url = try await client.buildURL(
            resourceType: "Patient", id: "123", additionalPath: "_history"
        )
        XCTAssertEqual(url.absoluteString, "https://fhir.example.org/r4/Patient/123/_history")
    }
    
    func testBuildVersionReadURL() async throws {
        let url = try await client.buildURL(
            resourceType: "Patient", id: "123", additionalPath: "_history/2"
        )
        XCTAssertEqual(url.absoluteString, "https://fhir.example.org/r4/Patient/123/_history/2")
    }
    
    func testBuildSearchURL() async throws {
        let url = try await client.buildURL(
            resourceType: "Patient",
            queryParameters: ["name": "Smith", "active": "true"]
        )
        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains("Patient?"))
        XCTAssertTrue(urlString.contains("active=true"))
        XCTAssertTrue(urlString.contains("name=Smith"))
    }
    
    func testBuildSearchPostURL() async throws {
        let url = try await client.buildURL(
            resourceType: "Patient", additionalPath: "_search"
        )
        XCTAssertEqual(url.absoluteString, "https://fhir.example.org/r4/Patient/_search")
    }
}

// MARK: - Request Building Tests

final class FHIRClientRequestBuildingTests: XCTestCase {
    
    var mockSession: MockFHIRURLSession!
    
    func testRequestHasAcceptHeader() async throws {
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            preferredFormat: .json
        )
        let client = FHIRClient(configuration: config, session: mockSession)
        
        let request = try await client.buildRequest(
            url: URL(string: "https://fhir.example.org/r4/Patient")!,
            method: "GET"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/fhir+json")
    }
    
    func testRequestHasAuthorizationHeader() async throws {
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            authorization: "Bearer my-token"
        )
        let client = FHIRClient(configuration: config, session: mockSession)
        
        let request = try await client.buildRequest(
            url: URL(string: "https://fhir.example.org/r4/Patient")!,
            method: "GET"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer my-token")
    }
    
    func testRequestHasCustomHeaders() async throws {
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            additionalHeaders: ["X-Request-Id": "abc-123"]
        )
        let client = FHIRClient(configuration: config, session: mockSession)
        
        let request = try await client.buildRequest(
            url: URL(string: "https://fhir.example.org/r4/Patient")!,
            method: "GET"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Request-Id"), "abc-123")
    }
    
    func testRequestHasTimeout() async throws {
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            timeout: 45.0
        )
        let client = FHIRClient(configuration: config, session: mockSession)
        
        let request = try await client.buildRequest(
            url: URL(string: "https://fhir.example.org/r4/Patient")!,
            method: "GET"
        )
        XCTAssertEqual(request.timeoutInterval, 45.0)
    }
    
    func testRequestHTTPMethod() async throws {
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!
        )
        let client = FHIRClient(configuration: config, session: mockSession)
        
        for method in ["GET", "POST", "PUT", "DELETE"] {
            let request = try await client.buildRequest(
                url: URL(string: "https://fhir.example.org/r4/Patient")!,
                method: method
            )
            XCTAssertEqual(request.httpMethod, method)
        }
    }
}

// MARK: - CRUD Operation Tests

final class FHIRClientCRUDTests: XCTestCase {
    
    var client: FHIRClient!
    var mockSession: MockFHIRURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            maxRetryAttempts: 1
        )
        client = FHIRClient(configuration: config, session: mockSession)
    }
    
    func testReadPatient() async throws {
        mockSession.responseData = TestJSONHelper.patientJSON()
        mockSession.responseStatusCode = 200
        mockSession.responseHeaders = ["ETag": "W/\"1\""]
        
        let response: FHIRResponse<Patient> = try await client.read(Patient.self, id: "123")
        
        XCTAssertEqual(response.resource.id, "123")
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.etag, "W/\"1\"")
        
        // Verify request
        XCTAssertEqual(mockSession.requests.count, 1)
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.absoluteString.contains("Patient/123") ?? false)
    }
    
    func testCreatePatient() async throws {
        mockSession.responseData = TestJSONHelper.patientJSON(id: "456")
        mockSession.responseStatusCode = 201
        mockSession.responseHeaders = [
            "Location": "https://fhir.example.org/r4/Patient/456",
            "ETag": "W/\"1\""
        ]
        
        let patient = Patient(
            id: nil,
            name: [HumanName(family: "Doe", given: ["Jane"])]
        )
        let response = try await client.create(patient)
        
        XCTAssertEqual(response.statusCode, 201)
        XCTAssertEqual(response.location, "https://fhir.example.org/r4/Patient/456")
        
        // Verify request
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.absoluteString.contains("Patient") ?? false)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/fhir+json")
        XCTAssertNotNil(request.httpBody)
    }
    
    func testUpdatePatient() async throws {
        mockSession.responseData = TestJSONHelper.patientJSON(id: "123", family: "Updated")
        mockSession.responseStatusCode = 200
        
        let patient = Patient(
            id: "123",
            name: [HumanName(family: "Updated", given: ["John"])]
        )
        let response = try await client.update(patient)
        
        XCTAssertEqual(response.statusCode, 200)
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertTrue(request.url?.absoluteString.contains("Patient/123") ?? false)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/fhir+json")
    }
    
    func testUpdateWithoutIdThrows() async {
        let patient = Patient(
            id: nil,
            name: [HumanName(family: "Smith")]
        )
        
        do {
            _ = try await client.update(patient)
            XCTFail("Should have thrown")
        } catch let error as FHIRClientError {
            if case .invalidRequest(let msg) = error {
                XCTAssertTrue(msg.contains("id"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDeleteResource() async throws {
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 204
        
        try await client.delete(resourceType: "Patient", id: "123")
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertTrue(request.url?.absoluteString.contains("Patient/123") ?? false)
    }
}

// MARK: - Error Handling Tests

final class FHIRClientErrorHandlingTests: XCTestCase {
    
    var client: FHIRClient!
    var mockSession: MockFHIRURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            maxRetryAttempts: 1
        )
        client = FHIRClient(configuration: config, session: mockSession)
    }
    
    func testNotFoundError() async {
        mockSession.responseData = TestJSONHelper.operationOutcomeJSON()
        mockSession.responseStatusCode = 404
        
        do {
            let _: FHIRResponse<Patient> = try await client.read(Patient.self, id: "nonexistent")
            XCTFail("Should have thrown")
        } catch let error as FHIRClientError {
            if case .operationOutcome(let outcome) = error {
                XCTAssertEqual(outcome.issue.first?.severity, "error")
                XCTAssertEqual(outcome.issue.first?.code, "not-found")
            } else {
                XCTFail("Expected operationOutcome error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testNotFoundWithoutOperationOutcome() async {
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 404
        
        do {
            let _: FHIRResponse<Patient> = try await client.read(Patient.self, id: "123")
            XCTFail("Should have thrown")
        } catch let error as FHIRClientError {
            if case .notFound = error {
                // Expected
            } else {
                XCTFail("Expected notFound error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testGoneError() async {
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 410
        
        do {
            let _: FHIRResponse<Patient> = try await client.read(Patient.self, id: "deleted")
            XCTFail("Should have thrown")
        } catch let error as FHIRClientError {
            if case .gone = error {
                // Expected
            } else {
                XCTFail("Expected gone error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testServerError() async {
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 500
        
        do {
            let _: FHIRResponse<Patient> = try await client.read(Patient.self, id: "123")
            XCTFail("Should have thrown")
        } catch let error as FHIRClientError {
            if case .httpError(let code, _) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testValidationError422() async {
        mockSession.responseData = TestJSONHelper.operationOutcomeJSON(
            severity: "error", code: "invalid", diagnostics: "Validation failed"
        )
        mockSession.responseStatusCode = 422
        
        do {
            let patient = Patient(id: "123", name: [HumanName(family: "Test")])
            _ = try await client.update(patient)
            XCTFail("Should have thrown")
        } catch let error as FHIRClientError {
            if case .operationOutcome(let outcome) = error {
                XCTAssertEqual(outcome.issue.first?.code, "invalid")
            } else {
                XCTFail("Expected operationOutcome error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDeleteNotFoundError() async {
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 404
        
        do {
            try await client.delete(resourceType: "Patient", id: "nonexistent")
            XCTFail("Should have thrown")
        } catch let error as FHIRClientError {
            if case .notFound(let type, let id) = error {
                XCTAssertEqual(type, "Patient")
                XCTAssertEqual(id, "nonexistent")
            } else {
                XCTFail("Expected notFound error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Search Tests

final class FHIRClientSearchTests: XCTestCase {
    
    var client: FHIRClient!
    var mockSession: MockFHIRURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            maxRetryAttempts: 1
        )
        client = FHIRClient(configuration: config, session: mockSession)
    }
    
    func testSearchWithParameters() async throws {
        mockSession.responseData = TestJSONHelper.bundleJSON()
        mockSession.responseStatusCode = 200
        
        let response = try await client.search(
            Patient.self,
            parameters: ["name": "Smith", "active": "true"]
        )
        
        XCTAssertEqual(response.resource.type, "searchset")
        XCTAssertEqual(response.resource.total, 1)
        XCTAssertEqual(response.resource.entry?.count, 1)
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "GET")
        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("Patient?"))
        XCTAssertTrue(urlString.contains("name=Smith"))
        XCTAssertTrue(urlString.contains("active=true"))
    }
    
    func testSearchNoParameters() async throws {
        mockSession.responseData = TestJSONHelper.bundleJSON()
        mockSession.responseStatusCode = 200
        
        let response = try await client.search(Patient.self)
        
        XCTAssertEqual(response.resource.type, "searchset")
        
        let request = mockSession.requests[0]
        XCTAssertTrue(request.url?.absoluteString.hasSuffix("Patient") ?? false)
    }
    
    func testSearchPost() async throws {
        mockSession.responseData = TestJSONHelper.bundleJSON()
        mockSession.responseStatusCode = 200
        
        let response = try await client.searchPost(
            Patient.self,
            parameters: ["name": "Smith"]
        )
        
        XCTAssertEqual(response.resource.type, "searchset")
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.absoluteString.contains("_search") ?? false)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            XCTAssertTrue(bodyString.contains("name=Smith"))
        } else {
            XCTFail("Expected form body")
        }
    }
}

// MARK: - Pagination Tests

final class FHIRClientPaginationTests: XCTestCase {
    
    var client: FHIRClient!
    var mockSession: MockFHIRURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            maxRetryAttempts: 1
        )
        client = FHIRClient(configuration: config, session: mockSession)
    }
    
    func testNextPage() async throws {
        mockSession.responseData = TestJSONHelper.bundleJSON()
        mockSession.responseStatusCode = 200
        
        let bundle = Bundle(
            type: "searchset",
            link: [
                BundleLink(relation: "next", url: "https://fhir.example.org/r4/Patient?_page=2")
            ]
        )
        
        let response = try await client.nextPage(from: bundle)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.resource.type, "searchset")
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.url?.absoluteString, "https://fhir.example.org/r4/Patient?_page=2")
    }
    
    func testNextPageWhenNoMorePages() async throws {
        let bundle = Bundle(
            type: "searchset",
            link: [
                BundleLink(relation: "self", url: "https://fhir.example.org/r4/Patient")
            ]
        )
        
        let response = try await client.nextPage(from: bundle)
        XCTAssertNil(response)
    }
    
    func testPreviousPage() async throws {
        mockSession.responseData = TestJSONHelper.bundleJSON()
        mockSession.responseStatusCode = 200
        
        let bundle = Bundle(
            type: "searchset",
            link: [
                BundleLink(relation: "previous", url: "https://fhir.example.org/r4/Patient?_page=1")
            ]
        )
        
        let response = try await client.previousPage(from: bundle)
        XCTAssertNotNil(response)
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.url?.absoluteString, "https://fhir.example.org/r4/Patient?_page=1")
    }
    
    func testPreviousPageWithPrevRelation() async throws {
        mockSession.responseData = TestJSONHelper.bundleJSON()
        mockSession.responseStatusCode = 200
        
        let bundle = Bundle(
            type: "searchset",
            link: [
                BundleLink(relation: "prev", url: "https://fhir.example.org/r4/Patient?_page=1")
            ]
        )
        
        let response = try await client.previousPage(from: bundle)
        XCTAssertNotNil(response)
    }
    
    func testPreviousPageWhenNoPreviousPage() async throws {
        let bundle = Bundle(
            type: "searchset",
            link: [
                BundleLink(relation: "self", url: "https://fhir.example.org/r4/Patient")
            ]
        )
        
        let response = try await client.previousPage(from: bundle)
        XCTAssertNil(response)
    }
}

// MARK: - Version / History Tests

final class FHIRClientHistoryTests: XCTestCase {
    
    var client: FHIRClient!
    var mockSession: MockFHIRURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            maxRetryAttempts: 1
        )
        client = FHIRClient(configuration: config, session: mockSession)
    }
    
    func testVersionRead() async throws {
        mockSession.responseData = TestJSONHelper.patientJSON()
        mockSession.responseStatusCode = 200
        
        let response: FHIRResponse<Patient> = try await client.vread(Patient.self, id: "123", versionId: "2")
        
        XCTAssertEqual(response.resource.id, "123")
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.absoluteString.contains("Patient/123/_history/2") ?? false)
    }
    
    func testHistory() async throws {
        let historyBundle = TestJSONHelper.bundleJSON(type: "history")
        mockSession.responseData = historyBundle
        mockSession.responseStatusCode = 200
        
        let response = try await client.history(Patient.self, id: "123")
        
        XCTAssertEqual(response.statusCode, 200)
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.absoluteString.contains("Patient/123/_history") ?? false)
    }
    
    func testHistoryWithParameters() async throws {
        let historyBundle = TestJSONHelper.bundleJSON(type: "history")
        mockSession.responseData = historyBundle
        mockSession.responseStatusCode = 200
        
        let response = try await client.history(
            Patient.self, id: "123",
            parameters: ["_count": "10", "_since": "2024-01-01"]
        )
        
        XCTAssertEqual(response.statusCode, 200)
        
        let request = mockSession.requests[0]
        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("_count=10"))
        XCTAssertTrue(urlString.contains("_since=2024-01-01"))
    }
    
    func testHistoryOfType() async throws {
        let historyBundle = TestJSONHelper.bundleJSON(type: "history")
        mockSession.responseData = historyBundle
        mockSession.responseStatusCode = 200
        
        let response = try await client.historyOfType(Patient.self)
        
        XCTAssertEqual(response.statusCode, 200)
        
        let request = mockSession.requests[0]
        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("Patient/_history"))
        XCTAssertFalse(urlString.contains("Patient/"))
        // The URL should be Patient/_history, not Patient/<id>/_history
    }
}

// MARK: - Batch/Transaction Tests

final class FHIRClientTransactionTests: XCTestCase {
    
    var client: FHIRClient!
    var mockSession: MockFHIRURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockFHIRURLSession()
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            maxRetryAttempts: 1
        )
        client = FHIRClient(configuration: config, session: mockSession)
    }
    
    func testTransactionBundle() async throws {
        mockSession.responseData = TestJSONHelper.transactionBundleJSON()
        mockSession.responseStatusCode = 200
        
        let txBundle = Bundle(
            type: "transaction",
            entry: [
                BundleEntry(
                    fullUrl: "urn:uuid:abc",
                    resource: .patient(Patient(id: nil, name: [HumanName(family: "New")])),
                    request: BundleEntryRequest(method: "POST", url: "Patient")
                )
            ]
        )
        
        let response = try await client.transaction(txBundle)
        
        XCTAssertEqual(response.resource.type, "transaction-response")
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "POST")
        // Transaction posts to the base URL
        XCTAssertEqual(request.url?.absoluteString, "https://fhir.example.org/r4")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/fhir+json")
    }
    
    func testBatchBundle() async throws {
        mockSession.responseData = TestJSONHelper.bundleJSON(type: "batch-response")
        mockSession.responseStatusCode = 200
        
        let batchBundle = Bundle(
            type: "batch",
            entry: [
                BundleEntry(
                    request: BundleEntryRequest(method: "GET", url: "Patient/123")
                )
            ]
        )
        
        let response = try await client.transaction(batchBundle)
        XCTAssertNotNil(response)
        
        let request = mockSession.requests[0]
        XCTAssertEqual(request.httpMethod, "POST")
    }
    
    func testInvalidBundleTypeThrows() async {
        let invalidBundle = Bundle(type: "searchset")
        
        do {
            _ = try await client.transaction(invalidBundle)
            XCTFail("Should have thrown")
        } catch let error as FHIRClientError {
            if case .invalidRequest(let msg) = error {
                XCTAssertTrue(msg.contains("batch"))
                XCTAssertTrue(msg.contains("transaction"))
            } else {
                XCTFail("Expected invalidRequest error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Convenience Initializer Tests

final class FHIRClientInitTests: XCTestCase {
    
    func testConvenienceInit() async throws {
        let url = URL(string: "https://fhir.example.org/r4")!
        let client = FHIRClient(baseURL: url)
        
        let config = await client.configuration
        XCTAssertEqual(config.baseURL, url)
        XCTAssertEqual(config.preferredFormat, .json)
    }
    
    func testConvenienceInitWithMockSession() async throws {
        let url = URL(string: "https://fhir.example.org/r4")!
        let mockSession = MockFHIRURLSession()
        mockSession.responseData = TestJSONHelper.patientJSON()
        mockSession.responseStatusCode = 200
        
        let client = FHIRClient(baseURL: url, session: mockSession)
        let response: FHIRResponse<Patient> = try await client.read(Patient.self, id: "123")
        XCTAssertEqual(response.resource.id, "123")
    }
}
