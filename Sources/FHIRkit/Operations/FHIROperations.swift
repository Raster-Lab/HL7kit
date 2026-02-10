/// FHIROperations.swift
/// FHIR Operations & Extended Operations implementation
///
/// This file provides a comprehensive FHIR operations framework supporting
/// standard operations ($everything, $validate, $convert, $meta, $export)
/// and custom operation definitions with a registry and execution client.
/// See: http://hl7.org/fhir/R4/operations.html

import Foundation
import HL7Core

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Operation Errors

/// Errors that can occur during FHIR operation execution
public enum FHIROperationError: Error, Sendable, CustomStringConvertible {
    /// The parameters provided to the operation are invalid
    case invalidParameters(String)
    /// The requested operation is not supported by the server
    case operationNotSupported(String)
    /// The operation failed during execution
    case operationFailed(String)
    /// The server returned an error response
    case serverError(statusCode: Int, data: Data?)
    /// A network-level error occurred
    case networkError(String)
    /// The server returned an invalid or unparseable response
    case invalidResponse(String)
    /// The operation timed out before completing
    case timeout
    /// The target resource was not found
    case resourceNotFound(resourceType: String, id: String)

    public var description: String {
        switch self {
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .operationNotSupported(let name):
            return "Operation not supported: \(name)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .serverError(let statusCode, _):
            return "Server error: HTTP \(statusCode)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .timeout:
            return "Operation timed out"
        case .resourceNotFound(let resourceType, let id):
            return "Resource not found: \(resourceType)/\(id)"
        }
    }
}

// MARK: - Operation Parameter

/// Defines a parameter for a FHIR operation definition
///
/// Parameters specify inputs and outputs for FHIR operations, including
/// their cardinality, type, and documentation.
/// See: http://hl7.org/fhir/R4/operationdefinition-definitions.html#OperationDefinition.parameter
public struct OperationParameter: Codable, Sendable, Hashable {
    /// Direction of the parameter
    public enum Use: String, Codable, Sendable, Hashable {
        /// Input parameter supplied by the caller
        case `in`
        /// Output parameter returned by the operation
        case out
    }

    /// The name of the parameter
    public let name: String
    /// Whether this is an input or output parameter
    public let use: Use
    /// Minimum cardinality
    public let min: Int
    /// Maximum cardinality (use "*" for unbounded)
    public let max: String
    /// The FHIR data type of the parameter
    public let type: String?
    /// Human-readable documentation for this parameter
    public let documentation: String?

    public init(
        name: String,
        use: Use,
        min: Int = 0,
        max: String = "1",
        type: String? = nil,
        documentation: String? = nil
    ) {
        self.name = name
        self.use = use
        self.min = min
        self.max = max
        self.type = type
        self.documentation = documentation
    }
}

// MARK: - Operation Definition

/// Defines a FHIR operation including its name, scope, and parameters
///
/// An operation definition describes a named operation that can be invoked
/// at the system, type, or instance level.
/// See: http://hl7.org/fhir/R4/operationdefinition.html
public struct FHIROperationDefinition: Codable, Sendable, Hashable {
    /// The human-readable name of the operation
    public let name: String
    /// The operation code (e.g., "everything", "validate")
    public let code: String
    /// Whether the operation can be invoked at the system level
    public let system: Bool
    /// Whether the operation can be invoked at the type level
    public let type: Bool
    /// Whether the operation can be invoked at the instance level
    public let instance: Bool
    /// A human-readable description of the operation
    public let description: String?
    /// Whether the operation modifies server state
    public let affectsState: Bool
    /// Input parameters accepted by the operation
    public let inputParameters: [OperationParameter]
    /// Output parameters returned by the operation
    public let outputParameters: [OperationParameter]

    public init(
        name: String,
        code: String,
        system: Bool = false,
        type: Bool = false,
        instance: Bool = false,
        description: String? = nil,
        affectsState: Bool = false,
        inputParameters: [OperationParameter] = [],
        outputParameters: [OperationParameter] = []
    ) {
        self.name = name
        self.code = code
        self.system = system
        self.type = type
        self.instance = instance
        self.description = description
        self.affectsState = affectsState
        self.inputParameters = inputParameters
        self.outputParameters = outputParameters
    }

    private enum CodingKeys: String, CodingKey {
        case name, code, system, type, instance
        case description, affectsState
        case inputParameters, outputParameters
    }
}

// MARK: - Operation Outcome Result

/// The result of executing a FHIR operation
///
/// Contains the success status, any OperationOutcome issues,
/// raw response data, and the HTTP status code.
public struct FHIROperationOutcome: Sendable {
    /// Whether the operation completed successfully
    public let successful: Bool
    /// The FHIR OperationOutcome resource, if returned
    public let operationOutcome: OperationOutcome?
    /// Raw response data from the server
    public let result: Data?
    /// The HTTP status code of the response
    public let statusCode: Int

    public init(
        successful: Bool,
        operationOutcome: OperationOutcome? = nil,
        result: Data? = nil,
        statusCode: Int
    ) {
        self.successful = successful
        self.operationOutcome = operationOutcome
        self.result = result
        self.statusCode = statusCode
    }
}

// MARK: - $everything Operation

/// Parameters and helpers for the FHIR $everything operation
///
/// The $everything operation returns all resources related to a patient
/// or encounter, enabling comprehensive data retrieval in a single request.
/// See: http://hl7.org/fhir/R4/patient-operation-everything.html
public struct EverythingOperation: Sendable {

    /// Parameters for the $everything operation
    public struct EverythingParameters: Sendable, Hashable {
        /// Only include resources updated after this date
        public let since: Date?
        /// Comma-separated list of resource types to include
        public let type: [String]?
        /// Maximum number of resources to return per page
        public let count: Int?
        /// Start of the clinical date range
        public let start: Date?
        /// End of the clinical date range
        public let end: Date?

        public init(
            since: Date? = nil,
            type: [String]? = nil,
            count: Int? = nil,
            start: Date? = nil,
            end: Date? = nil
        ) {
            self.since = since
            self.type = type
            self.count = count
            self.start = start
            self.end = end
        }

        /// Builds query parameters for the URL request
        internal func queryItems() -> [URLQueryItem] {
            var items: [URLQueryItem] = []
            let formatter = ISO8601DateFormatter()
            if let since = since {
                items.append(URLQueryItem(name: "_since", value: formatter.string(from: since)))
            }
            if let type = type, !type.isEmpty {
                items.append(URLQueryItem(name: "_type", value: type.joined(separator: ",")))
            }
            if let count = count {
                items.append(URLQueryItem(name: "_count", value: String(count)))
            }
            if let start = start {
                items.append(URLQueryItem(name: "start", value: formatter.string(from: start)))
            }
            if let end = end {
                items.append(URLQueryItem(name: "end", value: formatter.string(from: end)))
            }
            return items
        }
    }

    /// Creates parameters for a Patient/$everything operation
    ///
    /// - Parameters:
    ///   - patientId: The ID of the patient
    ///   - start: Start of the clinical date range
    ///   - end: End of the clinical date range
    ///   - type: Resource types to include
    ///   - count: Maximum number of resources per page
    ///   - since: Only include resources updated after this date
    /// - Returns: Configured `EverythingParameters`
    public static func patientEverything(
        patientId: String,
        start: Date? = nil,
        end: Date? = nil,
        type: [String]? = nil,
        count: Int? = nil,
        since: Date? = nil
    ) -> EverythingParameters {
        EverythingParameters(
            since: since,
            type: type,
            count: count,
            start: start,
            end: end
        )
    }

    /// Creates parameters for an Encounter/$everything operation
    ///
    /// - Parameters:
    ///   - encounterId: The ID of the encounter
    ///   - type: Resource types to include
    ///   - count: Maximum number of resources per page
    /// - Returns: Configured `EverythingParameters`
    public static func encounterEverything(
        encounterId: String,
        type: [String]? = nil,
        count: Int? = nil
    ) -> EverythingParameters {
        EverythingParameters(
            type: type,
            count: count
        )
    }
}

// MARK: - $validate Operation

/// Parameters and helpers for the FHIR $validate operation
///
/// The $validate operation checks whether a resource conforms to its
/// profile and base FHIR specification requirements.
/// See: http://hl7.org/fhir/R4/resource-operation-validate.html
public struct ValidateOperation: Sendable {

    /// The validation mode indicating the intended action
    public enum ValidateMode: String, Codable, Sendable, Hashable {
        /// Validate for a create operation
        case create
        /// Validate for an update operation
        case update
        /// Validate for a delete operation
        case delete
    }

    /// Parameters for the $validate operation
    public struct ValidateParameters: Sendable {
        /// The resource to validate, encoded as JSON data
        public let resource: Data?
        /// The validation mode (create, update, or delete)
        public let mode: ValidateMode?
        /// The profile URL to validate against
        public let profile: URL?

        public init(
            resource: Data? = nil,
            mode: ValidateMode? = nil,
            profile: URL? = nil
        ) {
            self.resource = resource
            self.mode = mode
            self.profile = profile
        }
    }
}

// MARK: - $convert Operation

/// Parameters and helpers for the FHIR $convert operation
///
/// The $convert operation transforms a resource between different
/// serialization formats (JSON, XML, Turtle).
/// See: http://hl7.org/fhir/R4/resource-operation-convert.html
public struct ConvertOperation: Sendable {

    /// Supported FHIR serialization formats
    public enum ConvertFormat: String, Codable, Sendable, Hashable {
        /// FHIR JSON format
        case json = "application/fhir+json"
        /// FHIR XML format
        case xml = "application/fhir+xml"
        /// RDF Turtle format
        case turtle = "application/fhir+turtle"
    }

    /// Parameters for the $convert operation
    public struct ConvertParameters: Sendable {
        /// The resource data to convert
        public let input: Data
        /// The format of the input data
        public let inputFormat: ConvertFormat
        /// The desired output format
        public let outputFormat: ConvertFormat

        public init(
            input: Data,
            inputFormat: ConvertFormat,
            outputFormat: ConvertFormat
        ) {
            self.input = input
            self.inputFormat = inputFormat
            self.outputFormat = outputFormat
        }
    }
}

// MARK: - $meta Operations

/// Parameters and helpers for the FHIR $meta, $meta-add, and $meta-delete operations
///
/// The $meta operations allow retrieval and manipulation of resource
/// metadata including profiles, security labels, and tags.
/// See: http://hl7.org/fhir/R4/resource-operation-meta.html
public struct MetaOperation: Sendable {

    /// Metadata associated with a FHIR resource
    public struct MetaData: Codable, Sendable, Hashable {
        /// Profile URLs the resource conforms to
        public let profiles: [String]
        /// Security labels applied to the resource
        public let security: [Coding]
        /// Tags applied to the resource
        public let tags: [Coding]

        public init(
            profiles: [String] = [],
            security: [Coding] = [],
            tags: [Coding] = []
        ) {
            self.profiles = profiles
            self.security = security
            self.tags = tags
        }
    }

    /// Parameters for the $meta-add operation
    public struct MetaOperationAdd: Sendable {
        /// The metadata to add to the resource
        public let meta: MetaData

        public init(meta: MetaData) {
            self.meta = meta
        }
    }

    /// Parameters for the $meta-delete operation
    public struct MetaOperationDelete: Sendable {
        /// The metadata to remove from the resource
        public let meta: MetaData

        public init(meta: MetaData) {
            self.meta = meta
        }
    }
}

// MARK: - Bulk Data Access ($export)

/// Parameters and helpers for the FHIR Bulk Data Access $export operation
///
/// Bulk Data Access enables clients to export large volumes of data from
/// a FHIR server asynchronously, supporting system-level, group, and
/// patient-level exports.
/// See: http://hl7.org/fhir/uv/bulkdata/
public struct BulkExportOperation: Sendable {

    /// The scope of the bulk export
    public enum ExportType: String, Codable, Sendable, Hashable {
        /// Export all data in the system
        case system
        /// Export data for a specific group of patients
        case group
        /// Export data for a specific patient
        case patient
    }

    /// Parameters for initiating a bulk export
    public struct ExportParameters: Sendable, Hashable {
        /// The desired output format (defaults to FHIR NDJSON)
        public let outputFormat: String?
        /// Only include resources updated after this date
        public let since: Date?
        /// Resource types to include in the export
        public let types: [String]?

        public init(
            outputFormat: String? = nil,
            since: Date? = nil,
            types: [String]? = nil
        ) {
            self.outputFormat = outputFormat
            self.since = since
            self.types = types
        }

        /// Builds query parameters for the export request URL
        internal func queryItems() -> [URLQueryItem] {
            var items: [URLQueryItem] = []
            if let outputFormat = outputFormat {
                items.append(URLQueryItem(name: "_outputFormat", value: outputFormat))
            }
            if let since = since {
                let formatter = ISO8601DateFormatter()
                items.append(URLQueryItem(name: "_since", value: formatter.string(from: since)))
            }
            if let types = types, !types.isEmpty {
                items.append(URLQueryItem(name: "_type", value: types.joined(separator: ",")))
            }
            return items
        }
    }

    /// A single file in a bulk export response
    public struct ExportFile: Codable, Sendable, Hashable {
        /// The FHIR resource type contained in this file
        public let type: String
        /// The URL where the exported file can be downloaded
        public let url: String
        /// The number of resources in this file
        public let count: Int?

        public init(type: String, url: String, count: Int? = nil) {
            self.type = type
            self.url = url
            self.count = count
        }
    }

    /// The response from a completed bulk export status check
    public struct ExportStatusResponse: Codable, Sendable, Hashable {
        /// The time the export was completed
        public let transactionTime: String
        /// The original export request URL
        public let request: String
        /// Whether an access token is required to download the files
        public let requiresAccessToken: Bool
        /// Successfully exported files
        public let output: [ExportFile]
        /// Files containing error information
        public let error: [ExportFile]

        public init(
            transactionTime: String,
            request: String,
            requiresAccessToken: Bool = false,
            output: [ExportFile] = [],
            error: [ExportFile] = []
        ) {
            self.transactionTime = transactionTime
            self.request = request
            self.requiresAccessToken = requiresAccessToken
            self.output = output
            self.error = error
        }
    }

    /// The current status of a bulk export job
    public enum ExportStatus: String, Sendable, Hashable {
        /// The export request has been accepted but not started
        case pending
        /// The export is currently in progress
        case inProgress
        /// The export has completed successfully
        case complete
        /// The export encountered an error
        case error
    }
}

// MARK: - Custom Operation Framework

/// Defines a custom FHIR operation that can be registered and executed
///
/// Custom operations extend the standard FHIR operations with server-specific
/// or implementation-specific functionality.
public struct CustomOperation: Sendable {

    /// The level at which an operation can be invoked
    public enum OperationLevel: String, Codable, Sendable, Hashable {
        /// Operation applies to the entire system
        case system
        /// Operation applies to a resource type
        case type
        /// Operation applies to a specific resource instance
        case instance
    }

    /// The HTTP method used to invoke the operation
    public enum HTTPMethod: String, Codable, Sendable, Hashable {
        case GET
        case POST
    }

    /// The value of a custom operation parameter
    public enum ParameterValue: Sendable, Hashable {
        /// A string value
        case string(String)
        /// An integer value
        case integer(Int)
        /// A boolean value
        case boolean(Bool)
        /// A decimal value
        case decimal(Double)
        /// A date value
        case date(Date)
        /// A FHIR resource encoded as JSON data
        case resource(Data)
    }

    /// A parameter for a custom operation
    public struct CustomOperationParameter: Sendable, Hashable {
        /// The parameter name
        public let name: String
        /// The parameter value
        public let value: ParameterValue

        public init(name: String, value: ParameterValue) {
            self.name = name
            self.value = value
        }
    }

    /// The definition of a custom FHIR operation
    public struct CustomOperationDefinition: Sendable, Hashable {
        /// The operation name (e.g., "$my-operation")
        public let name: String
        /// The HTTP method for invoking the operation
        public let httpMethod: HTTPMethod
        /// The level at which the operation can be invoked
        public let level: OperationLevel
        /// The parameters accepted by the operation
        public let parameters: [CustomOperationParameter]

        public init(
            name: String,
            httpMethod: HTTPMethod = .POST,
            level: OperationLevel = .system,
            parameters: [CustomOperationParameter] = []
        ) {
            self.name = name
            self.httpMethod = httpMethod
            self.level = level
            self.parameters = parameters
        }
    }
}

// MARK: - Operation Registry

/// Thread-safe registry for custom FHIR operation definitions
///
/// Allows registration and lookup of custom operations by name,
/// ensuring safe concurrent access through Swift's actor model.
///
/// Usage:
/// ```swift
/// let registry = FHIROperationRegistry()
/// await registry.register(myOperationDefinition)
/// let op = await registry.operation(named: "$my-operation")
/// ```
public actor FHIROperationRegistry {
    /// Stored operation definitions keyed by operation name
    private var operations: [String: CustomOperation.CustomOperationDefinition] = [:]

    public init() {}

    /// Registers a custom operation definition
    ///
    /// - Parameter definition: The operation definition to register
    public func register(_ definition: CustomOperation.CustomOperationDefinition) {
        operations[definition.name] = definition
    }

    /// Removes a registered operation by name
    ///
    /// - Parameter name: The name of the operation to unregister
    public func unregister(name: String) {
        operations.removeValue(forKey: name)
    }

    /// Retrieves a registered operation definition by name
    ///
    /// - Parameter name: The name of the operation
    /// - Returns: The operation definition, or `nil` if not registered
    public func operation(named name: String) -> CustomOperation.CustomOperationDefinition? {
        operations[name]
    }

    /// Returns all registered operation definitions
    public func allOperations() -> [CustomOperation.CustomOperationDefinition] {
        Array(operations.values)
    }
}

// MARK: - FHIR Operations Client

/// Thread-safe client for executing FHIR operations against a server
///
/// Provides async/await methods for standard FHIR operations ($everything,
/// $validate, $convert, $meta, $export) and custom operations. Uses an
/// actor model for thread-safe mutable state.
///
/// Usage:
/// ```swift
/// let client = FHIROperationsClient(
///     session: URLSession.shared,
///     baseURL: URL(string: "https://fhir.example.com/r4")!
/// )
/// let data = try await client.executePatientEverything(
///     patientId: "123",
///     parameters: EverythingOperation.patientEverything(patientId: "123")
/// )
/// ```
public actor FHIROperationsClient {
    /// The URL session used for HTTP requests
    private let session: FHIRURLSession
    /// The base URL of the FHIR server
    private let baseURL: URL
    /// Registry for custom operations
    private let registry: FHIROperationRegistry

    /// Creates a new FHIR operations client
    ///
    /// - Parameters:
    ///   - session: The URL session to use for requests
    ///   - baseURL: The base URL of the FHIR server
    ///   - registry: An optional custom operation registry
    public init(
        session: FHIRURLSession,
        baseURL: URL,
        registry: FHIROperationRegistry = FHIROperationRegistry()
    ) {
        self.session = session
        self.baseURL = baseURL
        self.registry = registry
    }

    // MARK: - $everything Operations

    /// Executes the Patient/$everything operation
    ///
    /// - Parameters:
    ///   - patientId: The ID of the patient
    ///   - parameters: The everything operation parameters
    /// - Returns: The raw response data (typically a Bundle)
    /// - Throws: `FHIROperationError` if the operation fails
    public func executePatientEverything(
        patientId: String,
        parameters: EverythingOperation.EverythingParameters = .init()
    ) async throws -> Data {
        guard !patientId.isEmpty else {
            throw FHIROperationError.invalidParameters("patientId must not be empty")
        }
        let path = "Patient/\(patientId)/$everything"
        return try await executeGetOperation(path: path, queryItems: parameters.queryItems())
    }

    /// Executes the Encounter/$everything operation
    ///
    /// - Parameters:
    ///   - encounterId: The ID of the encounter
    ///   - parameters: The everything operation parameters
    /// - Returns: The raw response data (typically a Bundle)
    /// - Throws: `FHIROperationError` if the operation fails
    public func executeEncounterEverything(
        encounterId: String,
        parameters: EverythingOperation.EverythingParameters = .init()
    ) async throws -> Data {
        guard !encounterId.isEmpty else {
            throw FHIROperationError.invalidParameters("encounterId must not be empty")
        }
        let path = "Encounter/\(encounterId)/$everything"
        return try await executeGetOperation(path: path, queryItems: parameters.queryItems())
    }

    // MARK: - $validate Operation

    /// Executes the $validate operation on a resource type
    ///
    /// - Parameters:
    ///   - resourceType: The FHIR resource type to validate against
    ///   - parameters: The validate operation parameters
    /// - Returns: A `FHIROperationOutcome` with the validation result
    /// - Throws: `FHIROperationError` if the request fails
    public func executeValidate(
        resourceType: String,
        parameters: ValidateOperation.ValidateParameters
    ) async throws -> FHIROperationOutcome {
        guard !resourceType.isEmpty else {
            throw FHIROperationError.invalidParameters("resourceType must not be empty")
        }
        let path = "\(resourceType)/$validate"
        var queryItems: [URLQueryItem] = []
        if let mode = parameters.mode {
            queryItems.append(URLQueryItem(name: "mode", value: mode.rawValue))
        }
        if let profile = parameters.profile {
            queryItems.append(URLQueryItem(name: "profile", value: profile.absoluteString))
        }

        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        request.httpBody = parameters.resource

        let (data, response) = try await performRequest(request)
        let statusCode = httpStatusCode(from: response)

        let outcome = try? JSONDecoder().decode(OperationOutcome.self, from: data)
        return FHIROperationOutcome(
            successful: (200..<300).contains(statusCode),
            operationOutcome: outcome,
            result: data,
            statusCode: statusCode
        )
    }

    // MARK: - $convert Operation

    /// Executes the $convert operation to transform a resource between formats
    ///
    /// - Parameter parameters: The convert operation parameters
    /// - Returns: The converted resource data in the requested format
    /// - Throws: `FHIROperationError` if the conversion fails
    public func executeConvert(
        parameters: ConvertOperation.ConvertParameters
    ) async throws -> Data {
        let url = try buildURL(path: "$convert")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(parameters.inputFormat.rawValue, forHTTPHeaderField: "Content-Type")
        request.setValue(parameters.outputFormat.rawValue, forHTTPHeaderField: "Accept")
        request.httpBody = parameters.input

        let (data, response) = try await performRequest(request)
        let statusCode = httpStatusCode(from: response)
        guard (200..<300).contains(statusCode) else {
            throw FHIROperationError.serverError(statusCode: statusCode, data: data)
        }
        return data
    }

    // MARK: - $meta Operations

    /// Retrieves metadata for a specific resource
    ///
    /// - Parameters:
    ///   - resourceType: The FHIR resource type
    ///   - resourceId: The resource ID
    /// - Returns: The resource's `MetaData`
    /// - Throws: `FHIROperationError` if the operation fails
    public func executeMeta(
        resourceType: String,
        resourceId: String
    ) async throws -> MetaOperation.MetaData {
        guard !resourceType.isEmpty, !resourceId.isEmpty else {
            throw FHIROperationError.invalidParameters("resourceType and resourceId must not be empty")
        }
        let path = "\(resourceType)/\(resourceId)/$meta"
        let data = try await executeGetOperation(path: path)
        return try decodeMetaData(from: data)
    }

    /// Adds metadata to a specific resource using $meta-add
    ///
    /// - Parameters:
    ///   - resourceType: The FHIR resource type
    ///   - resourceId: The resource ID
    ///   - meta: The metadata to add
    /// - Returns: The updated `MetaData`
    /// - Throws: `FHIROperationError` if the operation fails
    public func executeMetaAdd(
        resourceType: String,
        resourceId: String,
        meta: MetaOperation.MetaData
    ) async throws -> MetaOperation.MetaData {
        guard !resourceType.isEmpty, !resourceId.isEmpty else {
            throw FHIROperationError.invalidParameters("resourceType and resourceId must not be empty")
        }
        let path = "\(resourceType)/\(resourceId)/$meta-add"
        let body = try JSONEncoder().encode(meta)
        let data = try await executePostOperation(path: path, body: body)
        return try decodeMetaData(from: data)
    }

    /// Removes metadata from a specific resource using $meta-delete
    ///
    /// - Parameters:
    ///   - resourceType: The FHIR resource type
    ///   - resourceId: The resource ID
    ///   - meta: The metadata to remove
    /// - Returns: The updated `MetaData`
    /// - Throws: `FHIROperationError` if the operation fails
    public func executeMetaDelete(
        resourceType: String,
        resourceId: String,
        meta: MetaOperation.MetaData
    ) async throws -> MetaOperation.MetaData {
        guard !resourceType.isEmpty, !resourceId.isEmpty else {
            throw FHIROperationError.invalidParameters("resourceType and resourceId must not be empty")
        }
        let path = "\(resourceType)/\(resourceId)/$meta-delete"
        let body = try JSONEncoder().encode(meta)
        let data = try await executePostOperation(path: path, body: body)
        return try decodeMetaData(from: data)
    }

    // MARK: - Bulk Data Access ($export)

    /// Initiates a bulk data export and returns the status polling URL
    ///
    /// - Parameter parameters: The export parameters
    /// - Returns: The URL to poll for export status
    /// - Throws: `FHIROperationError` if the export request fails
    public func startBulkExport(
        parameters: BulkExportOperation.ExportParameters
    ) async throws -> URL {
        let url = try buildURL(path: "$export", queryItems: parameters.queryItems())
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("respond-async", forHTTPHeaderField: "Prefer")
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")

        let (_, response) = try await performRequest(request)
        let statusCode = httpStatusCode(from: response)

        guard statusCode == 202 else {
            throw FHIROperationError.operationFailed(
                "Expected 202 Accepted for bulk export, got \(statusCode)"
            )
        }

        guard let httpResponse = response as? HTTPURLResponse,
              let contentLocation = httpResponse.value(forHTTPHeaderField: "Content-Location"),
              let statusURL = URL(string: contentLocation) else {
            throw FHIROperationError.invalidResponse(
                "Missing Content-Location header in bulk export response"
            )
        }
        return statusURL
    }

    /// Checks the status of a bulk data export
    ///
    /// - Parameter statusURL: The status polling URL returned by `startBulkExport`
    /// - Returns: The export status response with file locations
    /// - Throws: `FHIROperationError` if the status check fails
    public func checkBulkExportStatus(
        statusURL: URL
    ) async throws -> BulkExportOperation.ExportStatusResponse {
        var request = URLRequest(url: statusURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)
        let statusCode = httpStatusCode(from: response)

        switch statusCode {
        case 200:
            return try JSONDecoder().decode(
                BulkExportOperation.ExportStatusResponse.self,
                from: data
            )
        case 202:
            throw FHIROperationError.operationFailed("Export still in progress")
        default:
            throw FHIROperationError.serverError(statusCode: statusCode, data: data)
        }
    }

    // MARK: - Custom Operations

    /// Executes a custom FHIR operation
    ///
    /// - Parameters:
    ///   - definition: The custom operation definition
    ///   - resourceType: The target resource type (for type/instance level operations)
    ///   - resourceId: The target resource ID (for instance level operations)
    ///   - parameters: Additional parameters for the operation
    /// - Returns: The raw response data
    /// - Throws: `FHIROperationError` if the operation fails
    public func executeCustomOperation(
        definition: CustomOperation.CustomOperationDefinition,
        resourceType: String? = nil,
        resourceId: String? = nil,
        parameters: [CustomOperation.CustomOperationParameter] = []
    ) async throws -> Data {
        let path = buildCustomOperationPath(
            definition: definition,
            resourceType: resourceType,
            resourceId: resourceId
        )

        switch definition.httpMethod {
        case .GET:
            let queryItems = parameters.compactMap { param -> URLQueryItem? in
                switch param.value {
                case .string(let v): return URLQueryItem(name: param.name, value: v)
                case .integer(let v): return URLQueryItem(name: param.name, value: String(v))
                case .boolean(let v): return URLQueryItem(name: param.name, value: String(v))
                case .decimal(let v): return URLQueryItem(name: param.name, value: String(v))
                case .date(let v):
                    let formatter = ISO8601DateFormatter()
                    return URLQueryItem(name: param.name, value: formatter.string(from: v))
                case .resource:
                    return nil
                }
            }
            return try await executeGetOperation(path: path, queryItems: queryItems)

        case .POST:
            let body = try buildParametersBody(parameters)
            return try await executePostOperation(path: path, body: body)
        }
    }

    /// Registers a custom operation definition in the registry
    ///
    /// - Parameter definition: The custom operation definition to register
    public func registerCustomOperation(
        _ definition: CustomOperation.CustomOperationDefinition
    ) async {
        await registry.register(definition)
    }

    // MARK: - Request Helpers

    /// Builds a URL from the base URL, path, and optional query items
    private func buildURL(
        path: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        let basePath = baseURL.path.hasSuffix("/") ? baseURL.path : baseURL.path + "/"
        components.path = basePath + path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw FHIROperationError.invalidParameters("Could not construct URL for path: \(path)")
        }
        return url
    }

    /// Executes a GET operation and returns the response data
    private func executeGetOperation(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)
        let statusCode = httpStatusCode(from: response)
        guard (200..<300).contains(statusCode) else {
            throw FHIROperationError.serverError(statusCode: statusCode, data: data)
        }
        return data
    }

    /// Executes a POST operation with a JSON body and returns the response data
    private func executePostOperation(
        path: String,
        body: Data,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let (data, response) = try await performRequest(request)
        let statusCode = httpStatusCode(from: response)
        guard (200..<300).contains(statusCode) else {
            throw FHIROperationError.serverError(statusCode: statusCode, data: data)
        }
        return data
    }

    /// Performs the HTTP request using the configured session
    private func performRequest(
        _ request: URLRequest
    ) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw FHIROperationError.networkError(error.localizedDescription)
        }
    }

    /// Extracts the HTTP status code from a URLResponse
    private func httpStatusCode(from response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    /// Decodes MetaData from raw response data
    private func decodeMetaData(from data: Data) throws -> MetaOperation.MetaData {
        do {
            return try JSONDecoder().decode(MetaOperation.MetaData.self, from: data)
        } catch {
            throw FHIROperationError.invalidResponse(
                "Could not decode MetaData: \(error.localizedDescription)"
            )
        }
    }

    /// Builds the URL path for a custom operation
    private func buildCustomOperationPath(
        definition: CustomOperation.CustomOperationDefinition,
        resourceType: String?,
        resourceId: String?
    ) -> String {
        let operationName = definition.name.hasPrefix("$")
            ? definition.name
            : "$\(definition.name)"

        switch definition.level {
        case .system:
            return operationName
        case .type:
            guard let resourceType = resourceType else {
                return operationName
            }
            return "\(resourceType)/\(operationName)"
        case .instance:
            guard let resourceType = resourceType, let resourceId = resourceId else {
                if let resourceType = resourceType {
                    return "\(resourceType)/\(operationName)"
                }
                return operationName
            }
            return "\(resourceType)/\(resourceId)/\(operationName)"
        }
    }

    /// Builds a FHIR Parameters resource body from custom operation parameters
    private func buildParametersBody(
        _ parameters: [CustomOperation.CustomOperationParameter]
    ) throws -> Data {
        var parameterArray: [[String: Any]] = []
        for param in parameters {
            var entry: [String: Any] = ["name": param.name]
            switch param.value {
            case .string(let v):
                entry["valueString"] = v
            case .integer(let v):
                entry["valueInteger"] = v
            case .boolean(let v):
                entry["valueBoolean"] = v
            case .decimal(let v):
                entry["valueDecimal"] = v
            case .date(let v):
                let formatter = ISO8601DateFormatter()
                entry["valueDateTime"] = formatter.string(from: v)
            case .resource(let v):
                if let json = try? JSONSerialization.jsonObject(with: v) {
                    entry["resource"] = json
                }
            }
            parameterArray.append(entry)
        }

        let body: [String: Any] = [
            "resourceType": "Parameters",
            "parameter": parameterArray
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }
}
