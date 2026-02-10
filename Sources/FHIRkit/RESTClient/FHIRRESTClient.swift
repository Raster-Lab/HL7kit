/// FHIRRESTClient.swift
/// FHIR RESTful client implementation
///
/// This file provides a production-ready FHIR RESTful client using URLSession with
/// async/await, supporting CRUD operations, search, history, version reads,
/// batch/transaction Bundles, and pagination.
/// See: http://hl7.org/fhir/R4/http.html

import Foundation
import HL7Core

// MARK: - URLSession Protocol (for testability)

/// Protocol abstracting URLSession for dependency injection and testing
public protocol FHIRURLSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLSession: FHIRURLSession {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: FHIRClientError.networkError("No data or response received"))
                }
            }
            task.resume()
        }
    }
}

// MARK: - FHIR Client Configuration

/// Configuration for the FHIR RESTful client
public struct FHIRClientConfiguration: Sendable {
    /// Base URL of the FHIR server (e.g., "https://fhir.example.org/r4")
    public let baseURL: URL

    /// Preferred response format
    public enum ResponseFormat: String, Sendable {
        case json = "application/fhir+json"
        case xml = "application/fhir+xml"
    }

    /// Preferred response format (default: JSON)
    public let preferredFormat: ResponseFormat

    /// Request timeout in seconds
    public let timeout: TimeInterval

    /// Maximum number of retry attempts for transient failures
    public let maxRetryAttempts: Int

    /// Base delay for exponential backoff (in seconds)
    public let retryBaseDelay: TimeInterval

    /// Additional HTTP headers to include in every request
    public let additionalHeaders: [String: String]

    /// Authorization header value (e.g., "Bearer <token>")
    public let authorization: String?

    public init(
        baseURL: URL,
        preferredFormat: ResponseFormat = .json,
        timeout: TimeInterval = 30.0,
        maxRetryAttempts: Int = 3,
        retryBaseDelay: TimeInterval = 1.0,
        additionalHeaders: [String: String] = [:],
        authorization: String? = nil
    ) {
        self.baseURL = baseURL
        self.preferredFormat = preferredFormat
        self.timeout = timeout
        self.maxRetryAttempts = maxRetryAttempts
        self.retryBaseDelay = retryBaseDelay
        self.additionalHeaders = additionalHeaders
        self.authorization = authorization
    }
}

// MARK: - FHIR Client Errors

/// Errors that can occur during FHIR REST operations
public enum FHIRClientError: Error, Sendable, CustomStringConvertible {
    /// Server returned an OperationOutcome with errors
    case operationOutcome(OperationOutcome)
    /// HTTP error with status code
    case httpError(statusCode: Int, data: Data?)
    /// Network connectivity error
    case networkError(String)
    /// Invalid request (e.g., bad URL construction)
    case invalidRequest(String)
    /// Response could not be decoded
    case decodingError(String)
    /// Resource not found (404)
    case notFound(resourceType: String, id: String)
    /// Resource was deleted (410 Gone)
    case gone(resourceType: String, id: String)
    /// Request timed out
    case timeout
    /// Invalid server response
    case invalidResponse(String)

    public var description: String {
        switch self {
        case .operationOutcome(let outcome):
            let issues = outcome.issue.map { "\($0.severity): \($0.code) - \($0.diagnostics ?? "")" }
            return "FHIR OperationOutcome: \(issues.joined(separator: "; "))"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .notFound(let resourceType, let id):
            return "\(resourceType)/\(id) not found"
        case .gone(let resourceType, let id):
            return "\(resourceType)/\(id) has been deleted"
        case .timeout:
            return "Request timed out"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        }
    }
}

// MARK: - FHIR Client Response

/// Response from a FHIR REST operation, including metadata
public struct FHIRResponse<T: Sendable>: Sendable {
    /// The decoded resource
    public let resource: T
    /// HTTP status code
    public let statusCode: Int
    /// ETag header value (for conditional operations)
    public let etag: String?
    /// Last-Modified header value
    public let lastModified: String?
    /// Location header value (for create operations)
    public let location: String?

    public init(
        resource: T,
        statusCode: Int,
        etag: String? = nil,
        lastModified: String? = nil,
        location: String? = nil
    ) {
        self.resource = resource
        self.statusCode = statusCode
        self.etag = etag
        self.lastModified = lastModified
        self.location = location
    }
}

// MARK: - FHIR Client

/// FHIR RESTful client actor for thread-safe HTTP operations
///
/// Provides async/await CRUD operations, search, history, version reads,
/// batch/transaction support, and pagination for FHIR R4 resources.
///
/// Usage:
/// ```swift
/// let config = FHIRClientConfiguration(baseURL: URL(string: "https://fhir.example.org/r4")!)
/// let client = FHIRClient(configuration: config)
/// let patient = try await client.read(Patient.self, id: "123")
/// ```
public actor FHIRClient {
    /// Client configuration
    public let configuration: FHIRClientConfiguration

    /// URL session used for HTTP requests
    private let session: FHIRURLSession

    /// JSON serializer for encoding/decoding resources
    private let serializer: FHIRJSONSerializer

    public init(
        configuration: FHIRClientConfiguration,
        session: FHIRURLSession? = nil,
        serializer: FHIRJSONSerializer = FHIRJSONSerializer()
    ) {
        self.configuration = configuration
        self.session = session ?? URLSession.shared
        self.serializer = serializer
    }

    /// Convenience initializer with just a base URL
    public init(baseURL: URL, session: FHIRURLSession? = nil) {
        self.init(
            configuration: FHIRClientConfiguration(baseURL: baseURL),
            session: session
        )
    }

    // MARK: - CRUD Operations

    /// Create a new resource on the server (POST [base]/[type])
    ///
    /// - Parameter resource: The resource to create
    /// - Returns: The created resource with server-assigned id
    public func create<T: Resource & Codable & Sendable>(_ resource: T) async throws -> FHIRResponse<T> {
        let url = try buildURL(resourceType: resource.resourceType)
        let body = try await serializer.encode(resource)
        var request = try buildRequest(url: url, method: "POST")
        request.httpBody = body
        request.setValue(configuration.preferredFormat.rawValue, forHTTPHeaderField: "Content-Type")
        return try await execute(request: request)
    }

    /// Read a resource by id (GET [base]/[type]/[id])
    ///
    /// - Parameters:
    ///   - type: The resource type to read
    ///   - id: The resource id
    /// - Returns: The requested resource
    public func read<T: Resource & Codable & Sendable>(_ type: T.Type, id: String) async throws -> FHIRResponse<T> {
        let resourceType = String(describing: type).components(separatedBy: ".").last ?? String(describing: type)
        let url = try buildURL(resourceType: resourceType, id: id)
        let request = try buildRequest(url: url, method: "GET")
        return try await execute(request: request)
    }

    /// Update an existing resource (PUT [base]/[type]/[id])
    ///
    /// - Parameter resource: The resource to update (must have an id)
    /// - Returns: The updated resource
    public func update<T: Resource & Codable & Sendable>(_ resource: T) async throws -> FHIRResponse<T> {
        guard let id = resource.id else {
            throw FHIRClientError.invalidRequest("Resource must have an id for update")
        }
        let url = try buildURL(resourceType: resource.resourceType, id: id)
        let body = try await serializer.encode(resource)
        var request = try buildRequest(url: url, method: "PUT")
        request.httpBody = body
        request.setValue(configuration.preferredFormat.rawValue, forHTTPHeaderField: "Content-Type")
        return try await execute(request: request)
    }

    /// Delete a resource by type and id (DELETE [base]/[type]/[id])
    ///
    /// - Parameters:
    ///   - type: The resource type
    ///   - id: The resource id
    public func delete(resourceType: String, id: String) async throws {
        let url = try buildURL(resourceType: resourceType, id: id)
        let request = try buildRequest(url: url, method: "DELETE")
        let (data, response) = try await performRequest(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FHIRClientError.invalidResponse("Not an HTTP response")
        }
        try handleErrorResponse(statusCode: httpResponse.statusCode, data: data,
                                resourceType: resourceType, id: id)
    }

    // MARK: - Version Operations

    /// Read a specific version of a resource (GET [base]/[type]/[id]/_history/[vid])
    ///
    /// - Parameters:
    ///   - type: The resource type
    ///   - id: The resource id
    ///   - versionId: The version id
    /// - Returns: The specific version of the resource
    public func vread<T: Resource & Codable & Sendable>(
        _ type: T.Type, id: String, versionId: String
    ) async throws -> FHIRResponse<T> {
        let resourceType = String(describing: type).components(separatedBy: ".").last ?? String(describing: type)
        let url = try buildURL(resourceType: resourceType, id: id,
                                additionalPath: "_history/\(versionId)")
        let request = try buildRequest(url: url, method: "GET")
        return try await execute(request: request)
    }

    /// Get the history of a specific resource (GET [base]/[type]/[id]/_history)
    ///
    /// - Parameters:
    ///   - type: The resource type
    ///   - id: The resource id
    ///   - parameters: Optional query parameters (e.g., _count, _since)
    /// - Returns: A Bundle containing the history entries
    public func history<T: Resource & Codable & Sendable>(
        _ type: T.Type, id: String, parameters: [String: String] = [:]
    ) async throws -> FHIRResponse<Bundle> {
        let resourceType = String(describing: type).components(separatedBy: ".").last ?? String(describing: type)
        let url = try buildURL(resourceType: resourceType, id: id,
                                additionalPath: "_history", queryParameters: parameters)
        let request = try buildRequest(url: url, method: "GET")
        return try await execute(request: request)
    }

    /// Get the history of all resources of a type (GET [base]/[type]/_history)
    ///
    /// - Parameters:
    ///   - type: The resource type
    ///   - parameters: Optional query parameters
    /// - Returns: A Bundle containing the history entries
    public func historyOfType<T: Resource & Codable & Sendable>(
        _ type: T.Type, parameters: [String: String] = [:]
    ) async throws -> FHIRResponse<Bundle> {
        let resourceType = String(describing: type).components(separatedBy: ".").last ?? String(describing: type)
        let url = try buildURL(resourceType: resourceType,
                                additionalPath: "_history", queryParameters: parameters)
        let request = try buildRequest(url: url, method: "GET")
        return try await execute(request: request)
    }

    // MARK: - Search

    /// Search for resources (GET [base]/[type]?parameters)
    ///
    /// - Parameters:
    ///   - type: The resource type to search
    ///   - parameters: Search parameters as key-value pairs
    /// - Returns: A Bundle containing search results
    public func search<T: Resource & Codable & Sendable>(
        _ type: T.Type, parameters: [String: String] = [:]
    ) async throws -> FHIRResponse<Bundle> {
        let resourceType = String(describing: type).components(separatedBy: ".").last ?? String(describing: type)
        let url = try buildURL(resourceType: resourceType, queryParameters: parameters)
        let request = try buildRequest(url: url, method: "GET")
        return try await execute(request: request)
    }

    /// Search using POST (POST [base]/[type]/_search)
    ///
    /// Useful when search parameters are too long for URL query strings.
    ///
    /// - Parameters:
    ///   - type: The resource type to search
    ///   - parameters: Search parameters as key-value pairs
    /// - Returns: A Bundle containing search results
    public func searchPost<T: Resource & Codable & Sendable>(
        _ type: T.Type, parameters: [String: String] = [:]
    ) async throws -> FHIRResponse<Bundle> {
        let resourceType = String(describing: type).components(separatedBy: ".").last ?? String(describing: type)
        let url = try buildURL(resourceType: resourceType, additionalPath: "_search")
        var request = try buildRequest(url: url, method: "POST")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let formBody = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = formBody.data(using: .utf8)
        return try await execute(request: request)
    }

    // MARK: - Pagination

    /// Fetch the next page of a search result Bundle
    ///
    /// - Parameter bundle: A search result Bundle with a "next" link
    /// - Returns: The next page Bundle, or nil if no next page
    public func nextPage(from bundle: Bundle) async throws -> FHIRResponse<Bundle>? {
        guard let nextLink = bundle.link?.first(where: { $0.relation == "next" }) else {
            return nil
        }
        guard let url = URL(string: nextLink.url) else {
            throw FHIRClientError.invalidRequest("Invalid next page URL: \(nextLink.url)")
        }
        let request = try buildRequest(url: url, method: "GET")
        return try await execute(request: request)
    }

    /// Fetch the previous page of a search result Bundle
    ///
    /// - Parameter bundle: A search result Bundle with a "previous" link
    /// - Returns: The previous page Bundle, or nil if no previous page
    public func previousPage(from bundle: Bundle) async throws -> FHIRResponse<Bundle>? {
        guard let prevLink = bundle.link?.first(where: { $0.relation == "previous" || $0.relation == "prev" }) else {
            return nil
        }
        guard let url = URL(string: prevLink.url) else {
            throw FHIRClientError.invalidRequest("Invalid previous page URL: \(prevLink.url)")
        }
        let request = try buildRequest(url: url, method: "GET")
        return try await execute(request: request)
    }

    // MARK: - Batch / Transaction

    /// Execute a batch or transaction Bundle
    ///
    /// - Parameter bundle: A Bundle of type "batch" or "transaction"
    /// - Returns: The response Bundle
    public func transaction(_ bundle: Bundle) async throws -> FHIRResponse<Bundle> {
        guard bundle.type == "batch" || bundle.type == "transaction" else {
            throw FHIRClientError.invalidRequest(
                "Bundle must be of type 'batch' or 'transaction', got '\(bundle.type)'"
            )
        }
        let url = configuration.baseURL
        let body = try await serializer.encode(bundle)
        var request = try buildRequest(url: url, method: "POST")
        request.httpBody = body
        request.setValue(configuration.preferredFormat.rawValue, forHTTPHeaderField: "Content-Type")
        return try await execute(request: request)
    }

    // MARK: - URL Building

    /// Build a URL for a FHIR resource operation
    internal func buildURL(
        resourceType: String? = nil,
        id: String? = nil,
        additionalPath: String? = nil,
        queryParameters: [String: String] = [:]
    ) throws -> URL {
        var url = configuration.baseURL
        if let resourceType = resourceType {
            url = url.appendingPathComponent(resourceType)
        }
        if let id = id {
            url = url.appendingPathComponent(id)
        }
        if let additionalPath = additionalPath {
            url = url.appendingPathComponent(additionalPath)
        }
        if !queryParameters.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw FHIRClientError.invalidRequest("Failed to create URL components from \(url)")
            }
            components.queryItems = queryParameters.sorted(by: { $0.key < $1.key }).map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
            guard let finalURL = components.url else {
                throw FHIRClientError.invalidRequest("Failed to create URL from components")
            }
            return finalURL
        }
        return url
    }

    // MARK: - Request Building

    /// Build an HTTP request with standard FHIR headers
    internal func buildRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = configuration.timeout
        request.setValue(configuration.preferredFormat.rawValue, forHTTPHeaderField: "Accept")
        if let authorization = configuration.authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        for (key, value) in configuration.additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    // MARK: - Request Execution

    /// Execute an HTTP request with retry logic
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0..<max(1, configuration.maxRetryAttempts) {
            do {
                let (data, response) = try await session.data(for: request)
                return (data, response)
            } catch {
                lastError = error
                if attempt < configuration.maxRetryAttempts - 1 {
                    let delay = configuration.retryBaseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError ?? FHIRClientError.networkError("Request failed after retries")
    }

    /// Execute a request and decode the response
    private func execute<T: Decodable & Sendable>(request: URLRequest) async throws -> FHIRResponse<T> {
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FHIRClientError.invalidResponse("Not an HTTP response")
        }

        try handleErrorResponse(statusCode: httpResponse.statusCode, data: data,
                                resourceType: nil, id: nil)

        do {
            let resource = try await serializer.decode(T.self, from: data)
            return FHIRResponse(
                resource: resource,
                statusCode: httpResponse.statusCode,
                etag: httpResponse.value(forHTTPHeaderField: "ETag"),
                lastModified: httpResponse.value(forHTTPHeaderField: "Last-Modified"),
                location: httpResponse.value(forHTTPHeaderField: "Location")
            )
        } catch let error as FHIRSerializationError {
            throw FHIRClientError.decodingError(error.description)
        } catch {
            throw FHIRClientError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Error Handling

    /// Handle HTTP error responses, including OperationOutcome parsing
    private func handleErrorResponse(
        statusCode: Int, data: Data,
        resourceType: String?, id: String?
    ) throws {
        switch statusCode {
        case 200...299:
            return // Success
        case 404:
            if let outcome = try? JSONDecoder().decode(OperationOutcome.self, from: data) {
                throw FHIRClientError.operationOutcome(outcome)
            }
            throw FHIRClientError.notFound(
                resourceType: resourceType ?? "Unknown",
                id: id ?? "Unknown"
            )
        case 410:
            throw FHIRClientError.gone(
                resourceType: resourceType ?? "Unknown",
                id: id ?? "Unknown"
            )
        case 400, 401, 403, 409, 422:
            if let outcome = try? JSONDecoder().decode(OperationOutcome.self, from: data) {
                throw FHIRClientError.operationOutcome(outcome)
            }
            throw FHIRClientError.httpError(statusCode: statusCode, data: data)
        default:
            if statusCode >= 400 {
                if let outcome = try? JSONDecoder().decode(OperationOutcome.self, from: data) {
                    throw FHIRClientError.operationOutcome(outcome)
                }
                throw FHIRClientError.httpError(statusCode: statusCode, data: data)
            }
        }
    }
}
