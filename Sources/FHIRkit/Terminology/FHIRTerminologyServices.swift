/// FHIRTerminologyServices.swift
/// FHIR Terminology Services implementation (Phase 6.2)
///
/// Provides terminology operations including CodeSystem lookup, ValueSet expansion
/// and validation, ConceptMap translation, and a local terminology cache with
/// TTL-based expiration and LRU eviction.
///
/// See: http://hl7.org/fhir/R4/terminology-service.html

import Foundation
import HL7Core

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Terminology Service Error

/// Errors that can occur during terminology service operations
public enum TerminologyServiceError: Error, Sendable, CustomStringConvertible {
    /// Server returned an error
    case serverError(String)
    /// Response could not be parsed
    case invalidResponse(String)
    /// Code system not found
    case codeSystemNotFound(String)
    /// Value set not found
    case valueSetNotFound(String)
    /// Concept map not found
    case conceptMapNotFound(String)
    /// Operation is not supported by the server
    case operationNotSupported(String)
    /// Network communication error
    case networkError(String)
    /// Cache operation error
    case cacheError(String)

    public var description: String {
        switch self {
        case .serverError(let message):
            return "Terminology server error: \(message)"
        case .invalidResponse(let message):
            return "Invalid terminology response: \(message)"
        case .codeSystemNotFound(let system):
            return "Code system not found: \(system)"
        case .valueSetNotFound(let url):
            return "Value set not found: \(url)"
        case .conceptMapNotFound(let url):
            return "Concept map not found: \(url)"
        case .operationNotSupported(let operation):
            return "Operation not supported: \(operation)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        }
    }
}

// MARK: - CodeSystem Operations

/// Operations available on a FHIR CodeSystem
public enum FHIRCodeSystemOperation: String, Sendable {
    /// Look up a code in a code system
    case lookup = "$lookup"
    /// Validate that a code is in a code system
    case validateCode = "$validate-code"
}

// MARK: - Property Value

/// Represents the polymorphic value of a code system property
public enum PropertyValue: Sendable, Equatable {
    /// String value
    case string(String)
    /// Code value
    case code(String)
    /// Boolean value
    case boolean(Bool)
    /// Integer value
    case integer(Int)
    /// Decimal value
    case decimal(Double)
    /// DateTime value
    case dateTime(Date)
}

// MARK: - CodeSystem Designation

/// A designation for a code in a code system
public struct CodeSystemDesignation: Sendable, Equatable {
    /// The language of the designation
    public let language: String?
    /// A code that represents the type of designation
    public let use: Coding?
    /// The text value of the designation
    public let value: String

    public init(
        language: String? = nil,
        use: Coding? = nil,
        value: String
    ) {
        self.language = language
        self.use = use
        self.value = value
    }
}

// MARK: - CodeSystem Property

/// A property of a code in a code system
public struct CodeSystemProperty: Sendable, Equatable {
    /// The code identifying the property
    public let code: String
    /// The type of the property value
    public let type: String
    /// The value of the property
    public let value: PropertyValue

    public init(
        code: String,
        type: String,
        value: PropertyValue
    ) {
        self.code = code
        self.type = type
        self.value = value
    }
}

// MARK: - CodeSystem Lookup Result

/// Result of a CodeSystem $lookup operation
public struct CodeSystemLookupResult: Sendable, Equatable {
    /// The code that was looked up
    public let code: String
    /// The display text for the code
    public let display: String?
    /// The code system URL
    public let system: String
    /// Designations for the code (e.g., translations)
    public let designations: [CodeSystemDesignation]
    /// Properties of the code
    public let properties: [CodeSystemProperty]

    public init(
        code: String,
        display: String? = nil,
        system: String,
        designations: [CodeSystemDesignation] = [],
        properties: [CodeSystemProperty] = []
    ) {
        self.code = code
        self.display = display
        self.system = system
        self.designations = designations
        self.properties = properties
    }
}

// MARK: - Code Validation Result

/// Result of a CodeSystem $validate-code operation
public struct CodeValidationResult: Sendable, Equatable {
    /// Whether the code is valid
    public let result: Bool
    /// Human-readable message about the validation
    public let message: String?
    /// The display text for the code
    public let display: String?
    /// The code that was validated
    public let code: String?
    /// The code system URL
    public let system: String?

    public init(
        result: Bool,
        message: String? = nil,
        display: String? = nil,
        code: String? = nil,
        system: String? = nil
    ) {
        self.result = result
        self.message = message
        self.display = display
        self.code = code
        self.system = system
    }
}

// MARK: - ValueSet Expansion

/// Contains in a ValueSet expansion
public struct ValueSetContains: Sendable, Equatable {
    /// The code system URL
    public let system: String?
    /// The code value
    public let code: String?
    /// The display text
    public let display: String?
    /// Whether this is an abstract concept (not selectable)
    public let abstract: Bool
    /// Whether this concept is inactive
    public let inactive: Bool
    /// The version of the code system
    public let version: String?

    public init(
        system: String? = nil,
        code: String? = nil,
        display: String? = nil,
        abstract: Bool = false,
        inactive: Bool = false,
        version: String? = nil
    ) {
        self.system = system
        self.code = code
        self.display = display
        self.abstract = abstract
        self.inactive = inactive
        self.version = version
    }
}

/// Result of a ValueSet $expand operation
public struct ValueSetExpansion: Sendable, Equatable {
    /// Unique identifier for this expansion
    public let identifier: String?
    /// When the expansion was generated
    public let timestamp: Date?
    /// Total number of concepts in the expansion
    public let total: Int?
    /// Offset at which this page starts
    public let offset: Int?
    /// Codes in the expansion
    public let contains: [ValueSetContains]

    public init(
        identifier: String? = nil,
        timestamp: Date? = nil,
        total: Int? = nil,
        offset: Int? = nil,
        contains: [ValueSetContains] = []
    ) {
        self.identifier = identifier
        self.timestamp = timestamp
        self.total = total
        self.offset = offset
        self.contains = contains
    }
}

// MARK: - ValueSet Validation Result

/// Result of a ValueSet $validate-code operation
public struct ValueSetValidationResult: Sendable, Equatable {
    /// Whether the code is a member of the value set
    public let result: Bool
    /// Human-readable message about the validation
    public let message: String?
    /// The display text for the code
    public let display: String?

    public init(
        result: Bool,
        message: String? = nil,
        display: String? = nil
    ) {
        self.result = result
        self.message = message
        self.display = display
    }
}

// MARK: - ConceptMap Equivalence

/// The degree of equivalence between concepts in a ConceptMap
public enum ConceptMapEquivalence: String, Sendable, Equatable {
    /// The concepts are related but the exact relationship is not specified
    case relatedto = "relatedto"
    /// The concepts are semantically equivalent
    case equivalent = "equivalent"
    /// The concepts are exactly equal
    case equal = "equal"
    /// The target concept is wider in meaning than the source
    case wider = "wider"
    /// The target concept subsumes the source
    case subsumes = "subsumes"
    /// The target concept is narrower in meaning than the source
    case narrower = "narrower"
    /// The target concept specializes the source
    case specializes = "specializes"
    /// The concepts have an inexact mapping
    case inexact = "inexact"
    /// There is no match for the source concept
    case unmatched = "unmatched"
    /// The concepts are completely unrelated
    case disjoint = "disjoint"
}

// MARK: - ConceptMap Product

/// A product element in a ConceptMap match (additional context for the mapping)
public struct ConceptMapProduct: Sendable, Equatable {
    /// A reference to a specific element in the target
    public let element: String?
    /// The concept in the target code system
    public let concept: Coding?

    public init(
        element: String? = nil,
        concept: Coding? = nil
    ) {
        self.element = element
        self.concept = concept
    }
}

// MARK: - ConceptMap Match

/// A match in a ConceptMap translation result
public struct ConceptMapMatch: Sendable, Equatable {
    /// The degree of equivalence between source and target
    public let equivalence: ConceptMapEquivalence
    /// The target concept
    public let concept: Coding?
    /// The canonical URL of the source value set or concept map
    public let source: String?
    /// Product elements providing additional mapping context
    public let product: [ConceptMapProduct]

    public init(
        equivalence: ConceptMapEquivalence,
        concept: Coding? = nil,
        source: String? = nil,
        product: [ConceptMapProduct] = []
    ) {
        self.equivalence = equivalence
        self.concept = concept
        self.source = source
        self.product = product
    }
}

// MARK: - ConceptMap Translation

/// Result of a ConceptMap $translate operation
public struct ConceptMapTranslation: Sendable, Equatable {
    /// Whether a mapping was found
    public let result: Bool
    /// Human-readable message about the translation
    public let message: String?
    /// The matches found
    public let matches: [ConceptMapMatch]

    public init(
        result: Bool,
        message: String? = nil,
        matches: [ConceptMapMatch] = []
    ) {
        self.result = result
        self.message = message
        self.matches = matches
    }
}

// MARK: - Well-Known Code Systems

/// Well-known FHIR terminology code systems
public enum WellKnownCodeSystem: String, Sendable, CaseIterable {
    /// SNOMED Clinical Terms
    case snomedCT = "snomed-ct"
    /// Logical Observation Identifiers Names and Codes
    case loinc = "loinc"
    /// International Classification of Diseases, 10th Revision
    case icd10 = "icd-10"
    /// ICD-10 Clinical Modification (US)
    case icd10CM = "icd-10-cm"
    /// RxNorm drug terminology
    case rxNorm = "rxnorm"
    /// Current Procedural Terminology
    case cpt = "cpt"
    /// Vaccines Administered (CDC)
    case cvx = "cvx"
    /// National Drug Code
    case ndc = "ndc"
    /// Unique Ingredient Identifier
    case unii = "unii"

    /// The canonical URL for this code system
    public var system: String {
        switch self {
        case .snomedCT:
            return "http://snomed.info/sct"
        case .loinc:
            return "http://loinc.org"
        case .icd10:
            return "http://hl7.org/fhir/sid/icd-10"
        case .icd10CM:
            return "http://hl7.org/fhir/sid/icd-10-cm"
        case .rxNorm:
            return "http://www.nlm.nih.gov/research/umls/rxnorm"
        case .cpt:
            return "http://www.ama-assn.org/go/cpt"
        case .cvx:
            return "http://hl7.org/fhir/sid/cvx"
        case .ndc:
            return "http://hl7.org/fhir/sid/ndc"
        case .unii:
            return "http://fdasis.nlm.nih.gov"
        }
    }

    /// Human-readable name for this code system
    public var name: String {
        switch self {
        case .snomedCT:
            return "SNOMED CT"
        case .loinc:
            return "LOINC"
        case .icd10:
            return "ICD-10"
        case .icd10CM:
            return "ICD-10-CM"
        case .rxNorm:
            return "RxNorm"
        case .cpt:
            return "CPT"
        case .cvx:
            return "CVX"
        case .ndc:
            return "NDC"
        case .unii:
            return "UNII"
        }
    }
}

// MARK: - Terminology Cache

/// Thread-safe cache for terminology operation results with TTL-based expiration and LRU eviction
public actor TerminologyCache {
    /// A cached entry with timestamp for TTL and access tracking for LRU
    private struct CacheEntry<T: Sendable>: Sendable {
        let value: T
        let cachedAt: Date
        var lastAccessed: Date
    }

    /// Time-to-live for cache entries in seconds
    private let ttl: TimeInterval

    /// Maximum number of entries per cache category
    private let maxSize: Int

    // Cache storage keyed by composite string keys
    private var lookupCache: [String: CacheEntry<CodeSystemLookupResult>] = [:]
    private var validationCache: [String: CacheEntry<CodeValidationResult>] = [:]
    private var expansionCache: [String: CacheEntry<ValueSetExpansion>] = [:]
    private var translationCache: [String: CacheEntry<ConceptMapTranslation>] = [:]

    /// Creates a new terminology cache
    ///
    /// - Parameters:
    ///   - ttl: Time-to-live for entries in seconds (default: 3600 = 1 hour)
    ///   - maxSize: Maximum entries per cache category (default: 1000)
    public init(ttl: TimeInterval = 3600, maxSize: Int = 1000) {
        self.ttl = ttl
        self.maxSize = maxSize
    }

    // MARK: - Lookup Cache

    /// Retrieve a cached code system lookup result
    ///
    /// - Parameter key: Cache key (typically system + "|" + code)
    /// - Returns: The cached result, or nil if not found or expired
    public func getCachedLookup(key: String) -> CodeSystemLookupResult? {
        guard var entry = lookupCache[key] else { return nil }
        guard !isExpired(entry) else {
            lookupCache.removeValue(forKey: key)
            return nil
        }
        entry.lastAccessed = Date()
        lookupCache[key] = entry
        return entry.value
    }

    /// Cache a code system lookup result
    ///
    /// - Parameters:
    ///   - result: The lookup result to cache
    ///   - key: Cache key
    public func cacheLookup(_ result: CodeSystemLookupResult, key: String) {
        evictIfNeeded(from: &lookupCache)
        let now = Date()
        lookupCache[key] = CacheEntry(value: result, cachedAt: now, lastAccessed: now)
    }

    // MARK: - Validation Cache

    /// Retrieve a cached code validation result
    ///
    /// - Parameter key: Cache key
    /// - Returns: The cached result, or nil if not found or expired
    public func getCachedValidation(key: String) -> CodeValidationResult? {
        guard var entry = validationCache[key] else { return nil }
        guard !isExpired(entry) else {
            validationCache.removeValue(forKey: key)
            return nil
        }
        entry.lastAccessed = Date()
        validationCache[key] = entry
        return entry.value
    }

    /// Cache a code validation result
    ///
    /// - Parameters:
    ///   - result: The validation result to cache
    ///   - key: Cache key
    public func cacheValidation(_ result: CodeValidationResult, key: String) {
        evictIfNeeded(from: &validationCache)
        let now = Date()
        validationCache[key] = CacheEntry(value: result, cachedAt: now, lastAccessed: now)
    }

    // MARK: - Expansion Cache

    /// Retrieve a cached value set expansion
    ///
    /// - Parameter key: Cache key (typically value set URL + filter parameters)
    /// - Returns: The cached expansion, or nil if not found or expired
    public func getCachedExpansion(key: String) -> ValueSetExpansion? {
        guard var entry = expansionCache[key] else { return nil }
        guard !isExpired(entry) else {
            expansionCache.removeValue(forKey: key)
            return nil
        }
        entry.lastAccessed = Date()
        expansionCache[key] = entry
        return entry.value
    }

    /// Cache a value set expansion
    ///
    /// - Parameters:
    ///   - result: The expansion to cache
    ///   - key: Cache key
    public func cacheExpansion(_ result: ValueSetExpansion, key: String) {
        evictIfNeeded(from: &expansionCache)
        let now = Date()
        expansionCache[key] = CacheEntry(value: result, cachedAt: now, lastAccessed: now)
    }

    // MARK: - Translation Cache

    /// Retrieve a cached concept map translation
    ///
    /// - Parameter key: Cache key
    /// - Returns: The cached translation, or nil if not found or expired
    public func getCachedTranslation(key: String) -> ConceptMapTranslation? {
        guard var entry = translationCache[key] else { return nil }
        guard !isExpired(entry) else {
            translationCache.removeValue(forKey: key)
            return nil
        }
        entry.lastAccessed = Date()
        translationCache[key] = entry
        return entry.value
    }

    /// Cache a concept map translation
    ///
    /// - Parameters:
    ///   - result: The translation to cache
    ///   - key: Cache key
    public func cacheTranslation(_ result: ConceptMapTranslation, key: String) {
        evictIfNeeded(from: &translationCache)
        let now = Date()
        translationCache[key] = CacheEntry(value: result, cachedAt: now, lastAccessed: now)
    }

    // MARK: - Cache Management

    /// Clear all cached entries
    public func clearCache() {
        lookupCache.removeAll()
        validationCache.removeAll()
        expansionCache.removeAll()
        translationCache.removeAll()
    }

    /// Returns statistics about the current cache state
    ///
    /// - Returns: A dictionary with cache category names and their entry counts
    public func cacheStatistics() -> [String: Int] {
        return [
            "lookups": lookupCache.count,
            "validations": validationCache.count,
            "expansions": expansionCache.count,
            "translations": translationCache.count,
        ]
    }

    // MARK: - Private Helpers

    /// Check if a cache entry has expired based on TTL
    private func isExpired<T: Sendable>(_ entry: CacheEntry<T>) -> Bool {
        return Date().timeIntervalSince(entry.cachedAt) > ttl
    }

    /// Evict the least recently used entry if the cache is at capacity
    private func evictIfNeeded<T: Sendable>(from cache: inout [String: CacheEntry<T>]) {
        guard cache.count >= maxSize else { return }
        // Find the least recently accessed entry
        if let lruKey = cache.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key {
            cache.removeValue(forKey: lruKey)
        }
    }
}

// MARK: - FHIR Terminology Client

/// Actor-based FHIR terminology service client
///
/// Provides async/await operations for CodeSystem lookup, ValueSet expansion,
/// code validation, and ConceptMap translation against a FHIR terminology server.
///
/// Usage:
/// ```swift
/// let client = FHIRTerminologyClient(
///     session: URLSession.shared,
///     baseURL: URL(string: "https://tx.fhir.org/r4")!
/// )
/// let result = try await client.lookup(code: "44054006", system: WellKnownCodeSystem.snomedCT.system)
/// ```
public actor FHIRTerminologyClient {
    /// URL session for HTTP requests
    private let session: FHIRURLSession

    /// Base URL of the terminology server
    private let baseURL: URL

    /// Local terminology cache
    private let cache: TerminologyCache

    /// JSON decoder configured for FHIR responses
    private let decoder: JSONDecoder

    /// Creates a new terminology client
    ///
    /// - Parameters:
    ///   - session: URL session for HTTP communication
    ///   - baseURL: Base URL of the FHIR terminology server
    ///   - cache: Terminology cache instance (default: new cache with 1-hour TTL)
    public init(
        session: FHIRURLSession,
        baseURL: URL,
        cache: TerminologyCache = TerminologyCache()
    ) {
        self.session = session
        self.baseURL = baseURL
        self.cache = cache
        self.decoder = JSONDecoder()
    }

    // MARK: - CodeSystem Operations

    /// Look up a code in a code system
    ///
    /// Invokes the CodeSystem $lookup operation on the terminology server.
    ///
    /// - Parameters:
    ///   - code: The code to look up
    ///   - system: The code system URL
    ///   - version: Optional code system version
    /// - Returns: The lookup result with display, designations, and properties
    /// - Throws: `TerminologyServiceError` if the lookup fails
    public func lookup(
        code: String,
        system: String,
        version: String? = nil
    ) async throws -> CodeSystemLookupResult {
        let cacheKey = "\(system)|\(code)|\(version ?? "")"
        if let cached = await cache.getCachedLookup(key: cacheKey) {
            return cached
        }

        var params: [String: String] = [
            "code": code,
            "system": system,
        ]
        if let version = version {
            params["version"] = version
        }

        let url = try buildOperationURL(resourceType: "CodeSystem", operation: "$lookup", parameters: params)
        let request = buildRequest(url: url)
        let data = try await executeRequest(request)
        let result = try parseLookupResult(data: data, system: system)

        await cache.cacheLookup(result, key: cacheKey)
        return result
    }

    /// Validate a code in a code system
    ///
    /// Invokes the CodeSystem $validate-code operation on the terminology server.
    ///
    /// - Parameters:
    ///   - code: The code to validate
    ///   - system: The code system URL
    ///   - valueSet: Optional value set URL to validate against
    ///   - display: Optional display text to validate
    /// - Returns: The validation result
    /// - Throws: `TerminologyServiceError` if validation fails
    public func validateCode(
        code: String,
        system: String,
        valueSet: String? = nil,
        display: String? = nil
    ) async throws -> CodeValidationResult {
        let cacheKey = "\(system)|\(code)|\(valueSet ?? "")|\(display ?? "")"
        if let cached = await cache.getCachedValidation(key: cacheKey) {
            return cached
        }

        var params: [String: String] = [
            "code": code,
            "system": system,
        ]
        if let valueSet = valueSet {
            params["url"] = valueSet
        }
        if let display = display {
            params["display"] = display
        }

        let url = try buildOperationURL(resourceType: "CodeSystem", operation: "$validate-code", parameters: params)
        let request = buildRequest(url: url)
        let data = try await executeRequest(request)
        let result = try parseValidationResult(data: data)

        await cache.cacheValidation(result, key: cacheKey)
        return result
    }

    // MARK: - ValueSet Operations

    /// Expand a value set
    ///
    /// Invokes the ValueSet $expand operation on the terminology server.
    ///
    /// - Parameters:
    ///   - url: The canonical URL of the value set
    ///   - filter: Optional text filter for expansion
    ///   - offset: Pagination offset (default: 0)
    ///   - count: Maximum number of concepts to return (default: 100)
    /// - Returns: The value set expansion
    /// - Throws: `TerminologyServiceError` if expansion fails
    public func expandValueSet(
        url: String,
        filter: String? = nil,
        offset: Int? = nil,
        count: Int? = nil
    ) async throws -> ValueSetExpansion {
        let cacheKey = "\(url)|\(filter ?? "")|\(offset ?? 0)|\(count ?? 100)"
        if let cached = await cache.getCachedExpansion(key: cacheKey) {
            return cached
        }

        var params: [String: String] = ["url": url]
        if let filter = filter {
            params["filter"] = filter
        }
        if let offset = offset {
            params["offset"] = String(offset)
        }
        if let count = count {
            params["count"] = String(count)
        }

        let requestURL = try buildOperationURL(resourceType: "ValueSet", operation: "$expand", parameters: params)
        let request = buildRequest(url: requestURL)
        let data = try await executeRequest(request)
        let result = try parseExpansionResult(data: data)

        await cache.cacheExpansion(result, key: cacheKey)
        return result
    }

    /// Validate that a code is a member of a value set
    ///
    /// Invokes the ValueSet $validate-code operation on the terminology server.
    ///
    /// - Parameters:
    ///   - code: The code to validate
    ///   - system: The code system URL
    ///   - valueSet: The canonical URL of the value set
    /// - Returns: The validation result
    /// - Throws: `TerminologyServiceError` if validation fails
    public func validateValueSetMembership(
        code: String,
        system: String,
        valueSet: String
    ) async throws -> ValueSetValidationResult {
        let cacheKey = "vs|\(valueSet)|\(system)|\(code)"
        if let cachedValidation = await cache.getCachedValidation(key: cacheKey) {
            return ValueSetValidationResult(
                result: cachedValidation.result,
                message: cachedValidation.message,
                display: cachedValidation.display
            )
        }

        let params: [String: String] = [
            "code": code,
            "system": system,
            "url": valueSet,
        ]

        let url = try buildOperationURL(resourceType: "ValueSet", operation: "$validate-code", parameters: params)
        let request = buildRequest(url: url)
        let data = try await executeRequest(request)
        let result = try parseValueSetValidationResult(data: data)

        let codeResult = CodeValidationResult(
            result: result.result,
            message: result.message,
            display: result.display,
            code: code,
            system: system
        )
        await cache.cacheValidation(codeResult, key: cacheKey)
        return result
    }

    // MARK: - ConceptMap Operations

    /// Translate a code using a concept map
    ///
    /// Invokes the ConceptMap $translate operation on the terminology server.
    ///
    /// - Parameters:
    ///   - code: The code to translate
    ///   - system: The source code system URL
    ///   - source: The source value set URL
    ///   - target: The target value set URL
    /// - Returns: The translation result with matches
    /// - Throws: `TerminologyServiceError` if translation fails
    public func translate(
        code: String,
        system: String,
        source: String? = nil,
        target: String? = nil
    ) async throws -> ConceptMapTranslation {
        let cacheKey = "translate|\(system)|\(code)|\(source ?? "")|\(target ?? "")"
        if let cached = await cache.getCachedTranslation(key: cacheKey) {
            return cached
        }

        var params: [String: String] = [
            "code": code,
            "system": system,
        ]
        if let source = source {
            params["source"] = source
        }
        if let target = target {
            params["target"] = target
        }

        let url = try buildOperationURL(resourceType: "ConceptMap", operation: "$translate", parameters: params)
        let request = buildRequest(url: url)
        let data = try await executeRequest(request)
        let result = try parseTranslationResult(data: data)

        await cache.cacheTranslation(result, key: cacheKey)
        return result
    }

    // MARK: - Cache Management

    /// Clear all cached terminology results
    public func clearCache() async {
        await cache.clearCache()
    }

    // MARK: - URL Building

    /// Build a FHIR operation URL with query parameters
    private func buildOperationURL(
        resourceType: String,
        operation: String,
        parameters: [String: String]
    ) throws -> URL {
        let operationURL = baseURL
            .appendingPathComponent(resourceType)
            .appendingPathComponent(operation)

        guard var components = URLComponents(url: operationURL, resolvingAgainstBaseURL: false) else {
            throw TerminologyServiceError.invalidResponse("Failed to build URL for \(resourceType)/\(operation)")
        }
        components.queryItems = parameters.sorted(by: { $0.key < $1.key }).map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let url = components.url else {
            throw TerminologyServiceError.invalidResponse("Failed to construct URL from components")
        }
        return url
    }

    /// Build an HTTP GET request with standard FHIR headers
    private func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        return request
    }

    // MARK: - Request Execution

    /// Execute an HTTP request and return response data
    private func executeRequest(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TerminologyServiceError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TerminologyServiceError.invalidResponse("Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TerminologyServiceError.serverError(
                "HTTP \(httpResponse.statusCode): \(String(data: data, encoding: .utf8) ?? "No body")"
            )
        }

        return data
    }

    // MARK: - Response Parsing

    /// Parse a Parameters resource from a CodeSystem $lookup response
    private func parseLookupResult(data: Data, system: String) throws -> CodeSystemLookupResult {
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TerminologyServiceError.invalidResponse("Expected Parameters resource with parameter array")
        }
        guard let json = jsonObject as? [String: Any],
              let parameters = json["parameter"] as? [[String: Any]] else {
            throw TerminologyServiceError.invalidResponse("Expected Parameters resource with parameter array")
        }

        var code: String?
        var display: String?
        var designations: [CodeSystemDesignation] = []
        var properties: [CodeSystemProperty] = []

        for param in parameters {
            guard let name = param["name"] as? String else { continue }
            switch name {
            case "code":
                code = param["valueCode"] as? String ?? param["valueString"] as? String
            case "display":
                display = param["valueString"] as? String
            case "designation":
                if let parts = param["part"] as? [[String: Any]] {
                    designations.append(parseDesignation(parts: parts))
                }
            case "property":
                if let parts = param["part"] as? [[String: Any]] {
                    if let prop = parseProperty(parts: parts) {
                        properties.append(prop)
                    }
                }
            default:
                break
            }
        }

        guard let resolvedCode = code else {
            throw TerminologyServiceError.invalidResponse("Lookup response missing code parameter")
        }

        return CodeSystemLookupResult(
            code: resolvedCode,
            display: display,
            system: system,
            designations: designations,
            properties: properties
        )
    }

    /// Parse a designation from Parameters parts
    private func parseDesignation(parts: [[String: Any]]) -> CodeSystemDesignation {
        var language: String?
        var use: Coding?
        var value: String = ""

        for part in parts {
            guard let name = part["name"] as? String else { continue }
            switch name {
            case "language":
                language = part["valueCode"] as? String ?? part["valueString"] as? String
            case "use":
                if let coding = part["valueCoding"] as? [String: Any] {
                    use = Coding(
                        system: coding["system"] as? String,
                        code: coding["code"] as? String,
                        display: coding["display"] as? String
                    )
                }
            case "value":
                value = part["valueString"] as? String ?? ""
            default:
                break
            }
        }

        return CodeSystemDesignation(language: language, use: use, value: value)
    }

    /// Parse a property from Parameters parts
    private func parseProperty(parts: [[String: Any]]) -> CodeSystemProperty? {
        var code: String?
        var value: PropertyValue?
        var type: String = "string"

        for part in parts {
            guard let name = part["name"] as? String else { continue }
            switch name {
            case "code":
                code = part["valueCode"] as? String ?? part["valueString"] as? String
            case "value":
                if let s = part["valueString"] as? String {
                    value = .string(s)
                    type = "string"
                } else if let c = part["valueCode"] as? String {
                    value = .code(c)
                    type = "code"
                } else if let b = part["valueBoolean"] as? Bool {
                    value = .boolean(b)
                    type = "boolean"
                } else if let i = part["valueInteger"] as? Int {
                    value = .integer(i)
                    type = "integer"
                } else if let d = part["valueDecimal"] as? Double {
                    value = .decimal(d)
                    type = "decimal"
                }
            default:
                break
            }
        }

        guard let resolvedCode = code, let resolvedValue = value else { return nil }
        return CodeSystemProperty(code: resolvedCode, type: type, value: resolvedValue)
    }

    /// Parse a $validate-code response
    private func parseValidationResult(data: Data) throws -> CodeValidationResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parameters = json["parameter"] as? [[String: Any]] else {
            throw TerminologyServiceError.invalidResponse("Expected Parameters resource with parameter array")
        }

        var result: Bool = false
        var message: String?
        var display: String?
        var code: String?
        var system: String?

        for param in parameters {
            guard let name = param["name"] as? String else { continue }
            switch name {
            case "result":
                result = param["valueBoolean"] as? Bool ?? false
            case "message":
                message = param["valueString"] as? String
            case "display":
                display = param["valueString"] as? String
            case "code":
                code = param["valueCode"] as? String ?? param["valueString"] as? String
            case "system":
                system = param["valueUri"] as? String ?? param["valueString"] as? String
            default:
                break
            }
        }

        return CodeValidationResult(
            result: result,
            message: message,
            display: display,
            code: code,
            system: system
        )
    }

    /// Parse a ValueSet $expand response
    private func parseExpansionResult(data: Data) throws -> ValueSetExpansion {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expansion = json["expansion"] as? [String: Any] else {
            throw TerminologyServiceError.invalidResponse("Expected ValueSet resource with expansion")
        }

        let identifier = expansion["identifier"] as? String
        let total = expansion["total"] as? Int
        let offset = expansion["offset"] as? Int

        var timestamp: Date?
        if let ts = expansion["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: ts)
        }

        var contains: [ValueSetContains] = []
        if let containsArray = expansion["contains"] as? [[String: Any]] {
            contains = containsArray.map { parseValueSetContains($0) }
        }

        return ValueSetExpansion(
            identifier: identifier,
            timestamp: timestamp,
            total: total,
            offset: offset,
            contains: contains
        )
    }

    /// Parse a single ValueSetContains entry
    private func parseValueSetContains(_ json: [String: Any]) -> ValueSetContains {
        return ValueSetContains(
            system: json["system"] as? String,
            code: json["code"] as? String,
            display: json["display"] as? String,
            abstract: json["abstract"] as? Bool ?? false,
            inactive: json["inactive"] as? Bool ?? false,
            version: json["version"] as? String
        )
    }

    /// Parse a ValueSet $validate-code response
    private func parseValueSetValidationResult(data: Data) throws -> ValueSetValidationResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parameters = json["parameter"] as? [[String: Any]] else {
            throw TerminologyServiceError.invalidResponse("Expected Parameters resource with parameter array")
        }

        var result: Bool = false
        var message: String?
        var display: String?

        for param in parameters {
            guard let name = param["name"] as? String else { continue }
            switch name {
            case "result":
                result = param["valueBoolean"] as? Bool ?? false
            case "message":
                message = param["valueString"] as? String
            case "display":
                display = param["valueString"] as? String
            default:
                break
            }
        }

        return ValueSetValidationResult(result: result, message: message, display: display)
    }

    /// Parse a ConceptMap $translate response
    private func parseTranslationResult(data: Data) throws -> ConceptMapTranslation {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parameters = json["parameter"] as? [[String: Any]] else {
            throw TerminologyServiceError.invalidResponse("Expected Parameters resource with parameter array")
        }

        var result: Bool = false
        var message: String?
        var matches: [ConceptMapMatch] = []

        for param in parameters {
            guard let name = param["name"] as? String else { continue }
            switch name {
            case "result":
                result = param["valueBoolean"] as? Bool ?? false
            case "message":
                message = param["valueString"] as? String
            case "match":
                if let parts = param["part"] as? [[String: Any]] {
                    matches.append(parseConceptMapMatch(parts: parts))
                }
            default:
                break
            }
        }

        return ConceptMapTranslation(result: result, message: message, matches: matches)
    }

    /// Parse a single ConceptMap match from Parameters parts
    private func parseConceptMapMatch(parts: [[String: Any]]) -> ConceptMapMatch {
        var equivalence: ConceptMapEquivalence = .relatedto
        var concept: Coding?
        var source: String?
        var products: [ConceptMapProduct] = []

        for part in parts {
            guard let name = part["name"] as? String else { continue }
            switch name {
            case "equivalence":
                if let value = part["valueCode"] as? String,
                   let equiv = ConceptMapEquivalence(rawValue: value) {
                    equivalence = equiv
                }
            case "concept":
                if let coding = part["valueCoding"] as? [String: Any] {
                    concept = Coding(
                        system: coding["system"] as? String,
                        code: coding["code"] as? String,
                        display: coding["display"] as? String
                    )
                }
            case "source":
                source = part["valueUri"] as? String ?? part["valueString"] as? String
            case "product":
                if let productParts = part["part"] as? [[String: Any]] {
                    products.append(parseConceptMapProduct(parts: productParts))
                }
            default:
                break
            }
        }

        return ConceptMapMatch(
            equivalence: equivalence,
            concept: concept,
            source: source,
            product: products
        )
    }

    /// Parse a ConceptMap product from Parameters parts
    private func parseConceptMapProduct(parts: [[String: Any]]) -> ConceptMapProduct {
        var element: String?
        var concept: Coding?

        for part in parts {
            guard let name = part["name"] as? String else { continue }
            switch name {
            case "element":
                element = part["valueUri"] as? String ?? part["valueString"] as? String
            case "concept":
                if let coding = part["valueCoding"] as? [String: Any] {
                    concept = Coding(
                        system: coding["system"] as? String,
                        code: coding["code"] as? String,
                        display: coding["display"] as? String
                    )
                }
            default:
                break
            }
        }

        return ConceptMapProduct(element: element, concept: concept)
    }
}
