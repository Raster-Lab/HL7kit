/// FHIRSearch.swift
/// FHIR Search & Query implementation
///
/// Provides type-safe search parameter types, result handling, chained search,
/// _include/_revinclude, compartment search, and validation per the FHIR search spec.
/// See: http://hl7.org/fhir/R4/search.html

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Search Parameter Types

/// FHIR search parameter types per the specification
///
/// Each search parameter is defined with a specific type that determines how values are
/// interpreted by the server.
/// See: http://hl7.org/fhir/R4/search.html#ptypes
public enum SearchParamType: String, Sendable, Equatable, Hashable {
    /// String search - case-insensitive, starts-with by default
    case string
    /// Token search - code/system pairs
    case token
    /// Reference search - references to other resources
    case reference
    /// Date search - date/dateTime/period/instant
    case date
    /// Number search - integer/decimal
    case number
    /// Quantity search - value with units
    case quantity
    /// Composite search - combinations of other parameter types
    case composite
    /// URI search - exact match
    case uri
    /// Special search - custom behavior (e.g., _near, _filter)
    case special
}

// MARK: - Search Modifiers

/// Modifiers applicable to search parameters
///
/// Modifiers change the behavior of a search parameter. They are appended to the
/// parameter name with a colon separator (e.g., `name:exact=John`).
/// See: http://hl7.org/fhir/R4/search.html#modifiers
public enum SearchModifier: String, Sendable, Equatable, Hashable {
    /// Exact string match (case-sensitive, full string)
    case exact
    /// Contains substring match
    case contains
    /// Text search using full-text search capabilities
    case text
    /// Negation - find resources where the parameter does NOT match
    case not
    /// Above the given code in a code system hierarchy
    case above
    /// Below the given code in a code system hierarchy
    case below
    /// Value is in the given value set
    case `in`
    /// Value is not in the given value set
    case notIn = "not-in"
    /// Match on the type of quantity
    case ofType = "of-type"
    /// Test for presence/absence of a parameter
    case missing
    /// Match on the identifier of a reference
    case identifier
    /// Restrict the reference to a specific target type
    case type
}

// MARK: - Date Prefix

/// Prefix operators for date, number, and quantity comparisons
///
/// These prefixes allow searches with comparison operators beyond simple equality.
/// See: http://hl7.org/fhir/R4/search.html#prefix
public enum DatePrefix: String, Sendable, Equatable, Hashable {
    /// Equal (default if no prefix)
    case eq
    /// Not equal
    case ne
    /// Greater than
    case gt
    /// Less than
    case lt
    /// Greater than or equal
    case ge
    /// Less than or equal
    case le
    /// Starts after
    case sa
    /// Ends before
    case eb
    /// Approximately equal (within 10%)
    case ap
}

// MARK: - Search Parameter Value

/// Typed union representing the value of a FHIR search parameter
///
/// Each case corresponds to a FHIR search parameter type and carries
/// the appropriate data for constructing the query string.
public enum SearchParameterValue: Sendable, Equatable {
    /// String search value
    case string(String)
    /// Token search value with optional system and required code
    case token(system: String?, code: String)
    /// Reference search value (e.g., "Patient/123" or absolute URL)
    case reference(String)
    /// Date search value with optional comparison prefix
    case date(prefix: DatePrefix?, value: String)
    /// Number search value with optional comparison prefix
    case number(prefix: DatePrefix?, value: String)
    /// Quantity search value with optional prefix, value, system, and code
    case quantity(prefix: DatePrefix?, value: String, system: String?, code: String?)
    /// Composite search value as key-value pairs joined with `$`
    case composite([(String, String)])
    /// Missing modifier value - tests for presence or absence
    case missing(Bool)

    /// Convert the value to its query string representation
    ///
    /// - Returns: The properly formatted value string for use in a URL query
    public func queryString() -> String {
        switch self {
        case .string(let value):
            return value
        case .token(let system, let code):
            if let system = system {
                return "\(system)|\(code)"
            }
            return code
        case .reference(let value):
            return value
        case .date(let prefix, let value):
            if let prefix = prefix {
                return "\(prefix.rawValue)\(value)"
            }
            return value
        case .number(let prefix, let value):
            if let prefix = prefix {
                return "\(prefix.rawValue)\(value)"
            }
            return value
        case .quantity(let prefix, let value, let system, let code):
            var result = ""
            if let prefix = prefix {
                result += prefix.rawValue
            }
            result += value
            result += "|"
            if let system = system {
                result += system
            }
            result += "|"
            if let code = code {
                result += code
            }
            return result
        case .composite(let pairs):
            return pairs.map { "\($0.0)$\($0.1)" }.joined(separator: ",")
        case .missing(let isMissing):
            return isMissing ? "true" : "false"
        }
    }

    /// Equatable conformance for composite values
    public static func == (lhs: SearchParameterValue, rhs: SearchParameterValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)):
            return a == b
        case (.token(let sysA, let codeA), .token(let sysB, let codeB)):
            return sysA == sysB && codeA == codeB
        case (.reference(let a), .reference(let b)):
            return a == b
        case (.date(let pA, let vA), .date(let pB, let vB)):
            return pA == pB && vA == vB
        case (.number(let pA, let vA), .number(let pB, let vB)):
            return pA == pB && vA == vB
        case (.quantity(let pA, let vA, let sA, let cA), .quantity(let pB, let vB, let sB, let cB)):
            return pA == pB && vA == vB && sA == sB && cA == cB
        case (.composite(let a), .composite(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.missing(let a), .missing(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Search Parameter

/// A single FHIR search parameter with name, optional modifier, and typed value
///
/// Represents a key-value pair in a FHIR search query. The parameter name may include
/// a modifier (e.g., `name:exact`) and the value is typed according to the FHIR spec.
///
/// Example:
/// ```swift
/// let param = SearchParameter(name: "name", modifier: .exact, value: .string("Smith"))
/// // Produces: name:exact=Smith
/// ```
public struct SearchParameter: Sendable, Equatable {
    /// The parameter name (e.g., "name", "birthdate", "code")
    public let name: String
    /// Optional modifier (e.g., :exact, :contains, :missing)
    public let modifier: SearchModifier?
    /// The typed parameter value
    public let value: SearchParameterValue

    /// Creates a new search parameter
    ///
    /// - Parameters:
    ///   - name: The parameter name
    ///   - modifier: Optional search modifier
    ///   - value: The typed parameter value
    public init(name: String, modifier: SearchModifier? = nil, value: SearchParameterValue) {
        self.name = name
        self.modifier = modifier
        self.value = value
    }

    /// Convert this parameter to a URLQueryItem
    ///
    /// - Returns: A URLQueryItem with the properly formatted name and value
    public func toQueryItem() -> URLQueryItem {
        let paramName: String
        if let modifier = modifier {
            paramName = "\(name):\(modifier.rawValue)"
        } else {
            paramName = name
        }
        return URLQueryItem(name: paramName, value: value.queryString())
    }
}

// MARK: - Include Parameters

/// Represents an _include or _revinclude search parameter
///
/// Used to request that the server include related resources in the search results.
/// See: http://hl7.org/fhir/R4/search.html#include
///
/// Example:
/// ```swift
/// let include = IncludeParameter(sourceType: "MedicationRequest", searchParameter: "patient")
/// // Produces: _include=MedicationRequest:patient
/// ```
public struct IncludeParameter: Sendable, Equatable {
    /// The source resource type (e.g., "MedicationRequest")
    public let sourceType: String
    /// The search parameter that defines the relationship (e.g., "patient")
    public let searchParameter: String
    /// Optional target resource type to restrict includes (e.g., "Patient")
    public let targetType: String?
    /// Whether to use :iterate for recursive includes
    public let iterate: Bool

    /// Creates a new include parameter
    ///
    /// - Parameters:
    ///   - sourceType: The source resource type
    ///   - searchParameter: The search parameter defining the relationship
    ///   - targetType: Optional target resource type restriction
    ///   - iterate: Whether to iterate (follow chains of includes)
    public init(
        sourceType: String,
        searchParameter: String,
        targetType: String? = nil,
        iterate: Bool = false
    ) {
        self.sourceType = sourceType
        self.searchParameter = searchParameter
        self.targetType = targetType
        self.iterate = iterate
    }

    /// Convert to the query string value (e.g., "MedicationRequest:patient:Patient")
    ///
    /// - Returns: The formatted include value string
    public func queryValue() -> String {
        var value = "\(sourceType):\(searchParameter)"
        if let targetType = targetType {
            value += ":\(targetType)"
        }
        return value
    }

    /// The query parameter name (e.g., "_include" or "_include:iterate")
    ///
    /// - Parameter isRevInclude: Whether this is a _revinclude
    /// - Returns: The parameter name string
    public func queryName(isRevInclude: Bool) -> String {
        let base = isRevInclude ? "_revinclude" : "_include"
        return iterate ? "\(base):iterate" : base
    }
}

// MARK: - Sort Parameters

/// Represents a _sort search parameter for ordering results
///
/// See: http://hl7.org/fhir/R4/search.html#sort
public struct SortParameter: Sendable, Equatable {
    /// The field to sort by
    public let field: String
    /// Sort direction (true = ascending, false = descending)
    public let ascending: Bool

    /// Creates a new sort parameter
    ///
    /// - Parameters:
    ///   - field: The field name to sort by
    ///   - ascending: Sort direction (default: true for ascending)
    public init(field: String, ascending: Bool = true) {
        self.field = field
        self.ascending = ascending
    }

    /// The sort value with direction prefix
    ///
    /// Ascending uses no prefix, descending uses "-" prefix.
    /// - Returns: The formatted sort value
    public func queryValue() -> String {
        ascending ? field : "-\(field)"
    }
}

// MARK: - Summary & Total Modes

/// The _summary parameter controls the amount of data returned
///
/// See: http://hl7.org/fhir/R4/search.html#summary
public enum SummaryMode: String, Sendable, Equatable, Hashable {
    /// Return only those elements marked as "summary" in the base definition
    case `true` = "true"
    /// Return only the text, id, meta, and top-level mandatory elements
    case text
    /// Remove the text element
    case data
    /// Search only - return count of matching resources
    case count
    /// Return all parts of the resource
    case `false` = "false"
}

/// The _total parameter controls whether the server returns a total count
///
/// See: http://hl7.org/fhir/R4/search.html#total
public enum TotalMode: String, Sendable, Equatable, Hashable {
    /// Do not return a total
    case none
    /// Return an estimated total
    case estimate
    /// Return an accurate total
    case accurate
}

// MARK: - FHIR Search Query Builder

/// Type-safe FHIR search query builder
///
/// Provides a fluent API for constructing FHIR search queries with proper
/// parameter types, modifiers, includes, sorting, and pagination.
///
/// Usage:
/// ```swift
/// let query = FHIRSearchQuery(resourceType: "Patient")
///     .where("name", .string("Smith"))
///     .where("birthdate", modifier: .missing, .missing(false))
///     .include("Patient", parameter: "general-practitioner", targetType: nil)
///     .sorted(by: "birthdate", ascending: false)
///     .limited(to: 10)
/// ```
public struct FHIRSearchQuery: Sendable {
    /// The FHIR resource type name (e.g., "Patient", "Observation")
    public let resourceType: String
    /// Search parameters
    public private(set) var parameters: [SearchParameter]
    /// _include parameters
    public private(set) var includes: [IncludeParameter]
    /// _revinclude parameters
    public private(set) var revIncludes: [IncludeParameter]
    /// Sort parameters
    public private(set) var sort: [SortParameter]?
    /// Maximum number of results (_count)
    public private(set) var count: Int?
    /// Result offset for pagination (_offset)
    public private(set) var offset: Int?
    /// Summary mode (_summary)
    public private(set) var summary: SummaryMode?
    /// Element filter (_elements)
    public private(set) var elements: [String]?
    /// Total mode (_total)
    public private(set) var total: TotalMode?

    /// Creates a new search query for the specified resource type
    ///
    /// - Parameter resourceType: The FHIR resource type name
    public init(resourceType: String) {
        self.resourceType = resourceType
        self.parameters = []
        self.includes = []
        self.revIncludes = []
    }

    /// Internal initializer for builder pattern (copies all fields)
    private init(
        resourceType: String,
        parameters: [SearchParameter],
        includes: [IncludeParameter],
        revIncludes: [IncludeParameter],
        sort: [SortParameter]?,
        count: Int?,
        offset: Int?,
        summary: SummaryMode?,
        elements: [String]?,
        total: TotalMode?
    ) {
        self.resourceType = resourceType
        self.parameters = parameters
        self.includes = includes
        self.revIncludes = revIncludes
        self.sort = sort
        self.count = count
        self.offset = offset
        self.summary = summary
        self.elements = elements
        self.total = total
    }

    // MARK: Builder Methods

    /// Add a search parameter without a modifier
    ///
    /// - Parameters:
    ///   - name: The parameter name
    ///   - value: The typed parameter value
    /// - Returns: A new query with the parameter added
    public func `where`(_ name: String, _ value: SearchParameterValue) -> FHIRSearchQuery {
        var copy = self
        copy.parameters.append(SearchParameter(name: name, value: value))
        return copy
    }

    /// Add a search parameter with a modifier
    ///
    /// - Parameters:
    ///   - name: The parameter name
    ///   - modifier: The search modifier to apply
    ///   - value: The typed parameter value
    /// - Returns: A new query with the parameter added
    public func `where`(
        _ name: String, modifier: SearchModifier, _ value: SearchParameterValue
    ) -> FHIRSearchQuery {
        var copy = self
        copy.parameters.append(SearchParameter(name: name, modifier: modifier, value: value))
        return copy
    }

    /// Add an _include parameter to include related resources
    ///
    /// - Parameters:
    ///   - resourceType: The source resource type
    ///   - parameter: The search parameter defining the relationship
    ///   - targetType: Optional target resource type restriction
    ///   - iterate: Whether to recursively follow includes
    /// - Returns: A new query with the include added
    public func include(
        _ resourceType: String,
        parameter: String,
        targetType: String? = nil,
        iterate: Bool = false
    ) -> FHIRSearchQuery {
        var copy = self
        copy.includes.append(IncludeParameter(
            sourceType: resourceType,
            searchParameter: parameter,
            targetType: targetType,
            iterate: iterate
        ))
        return copy
    }

    /// Add a _revinclude parameter to include referring resources
    ///
    /// - Parameters:
    ///   - resourceType: The source resource type to include
    ///   - parameter: The search parameter on the source type that references this
    ///   - targetType: Optional target resource type restriction
    ///   - iterate: Whether to recursively follow includes
    /// - Returns: A new query with the revinclude added
    public func revInclude(
        _ resourceType: String,
        parameter: String,
        targetType: String? = nil,
        iterate: Bool = false
    ) -> FHIRSearchQuery {
        var copy = self
        copy.revIncludes.append(IncludeParameter(
            sourceType: resourceType,
            searchParameter: parameter,
            targetType: targetType,
            iterate: iterate
        ))
        return copy
    }

    /// Add a chained search parameter
    ///
    /// Chained searches allow searching on a property of a referenced resource.
    /// For example, searching for Observations where the subject's name is "Smith":
    /// `subject.name=Smith` becomes `subject:Patient.name=Smith`
    ///
    /// - Parameters:
    ///   - chain: The chained parameter path (e.g., "subject:Patient.name")
    ///   - value: The search value
    /// - Returns: A new query with the chained parameter added
    public func chained(_ chain: String, _ value: SearchParameterValue) -> FHIRSearchQuery {
        var copy = self
        copy.parameters.append(SearchParameter(name: chain, value: value))
        return copy
    }

    /// Add a reverse chained search parameter (_has)
    ///
    /// Reverse chained searches find resources that are referenced by other resources
    /// matching certain criteria. For example, find Patients that have Observations
    /// with a specific code.
    ///
    /// - Parameters:
    ///   - targetType: The resource type that references this resource
    ///   - parameter: The reference parameter on the target type
    ///   - searchParam: The search parameter on the target to filter by
    ///   - value: The value to match
    /// - Returns: A new query with the reverse chain parameter added
    public func reverseChained(
        targetType: String,
        parameter: String,
        searchParam: String,
        value: SearchParameterValue
    ) -> FHIRSearchQuery {
        let hasName = "_has:\(targetType):\(parameter):\(searchParam)"
        var copy = self
        copy.parameters.append(SearchParameter(name: hasName, value: value))
        return copy
    }

    /// Set the sort order for results
    ///
    /// - Parameters:
    ///   - field: The field to sort by
    ///   - ascending: Sort direction (true = ascending)
    /// - Returns: A new query with sort applied
    public func sorted(by field: String, ascending: Bool = true) -> FHIRSearchQuery {
        var copy = self
        var currentSort = copy.sort ?? []
        currentSort.append(SortParameter(field: field, ascending: ascending))
        copy.sort = currentSort
        return copy
    }

    /// Set the maximum number of results to return
    ///
    /// - Parameter count: Maximum result count
    /// - Returns: A new query with the count limit
    public func limited(to count: Int) -> FHIRSearchQuery {
        var copy = self
        copy.count = count
        return copy
    }

    /// Set the result offset for pagination
    ///
    /// - Parameter offset: The number of results to skip
    /// - Returns: A new query with the offset
    public func offset(_ offset: Int) -> FHIRSearchQuery {
        var copy = self
        copy.offset = offset
        return copy
    }

    /// Set the summary mode for controlling returned data
    ///
    /// - Parameter mode: The summary mode
    /// - Returns: A new query with the summary mode
    public func withSummary(_ mode: SummaryMode) -> FHIRSearchQuery {
        var copy = self
        copy.summary = mode
        return copy
    }

    /// Set specific elements to return in the response
    ///
    /// - Parameter elements: List of element names to include
    /// - Returns: A new query with the elements filter
    public func withElements(_ elements: [String]) -> FHIRSearchQuery {
        var copy = self
        copy.elements = elements
        return copy
    }

    /// Set the total count mode
    ///
    /// - Parameter mode: The total counting mode
    /// - Returns: A new query with the total mode
    public func withTotal(_ mode: TotalMode) -> FHIRSearchQuery {
        var copy = self
        copy.total = mode
        return copy
    }

    // MARK: Query Conversion

    /// Convert search query to URLQueryItems
    ///
    /// Produces an array of URLQueryItem values representing all parameters,
    /// includes, sort, pagination, and other modifiers.
    ///
    /// - Returns: Array of URLQueryItem values
    public func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        // Search parameters
        for param in parameters {
            items.append(param.toQueryItem())
        }

        // Includes
        for inc in includes {
            items.append(URLQueryItem(
                name: inc.queryName(isRevInclude: false),
                value: inc.queryValue()
            ))
        }

        // RevIncludes
        for rev in revIncludes {
            items.append(URLQueryItem(
                name: rev.queryName(isRevInclude: true),
                value: rev.queryValue()
            ))
        }

        // Sort
        if let sort = sort, !sort.isEmpty {
            let sortValue = sort.map { $0.queryValue() }.joined(separator: ",")
            items.append(URLQueryItem(name: "_sort", value: sortValue))
        }

        // Count
        if let count = count {
            items.append(URLQueryItem(name: "_count", value: String(count)))
        }

        // Offset
        if let offset = offset {
            items.append(URLQueryItem(name: "_offset", value: String(offset)))
        }

        // Summary
        if let summary = summary {
            items.append(URLQueryItem(name: "_summary", value: summary.rawValue))
        }

        // Elements
        if let elements = elements, !elements.isEmpty {
            items.append(URLQueryItem(name: "_elements", value: elements.joined(separator: ",")))
        }

        // Total
        if let total = total {
            items.append(URLQueryItem(name: "_total", value: total.rawValue))
        }

        return items
    }

    /// Convert search query to a flat dictionary compatible with existing search methods
    ///
    /// Note: When multiple parameters share the same name (e.g., multiple includes),
    /// only the last value is preserved in the dictionary. Use `toQueryItems()` for
    /// full fidelity.
    ///
    /// - Returns: Dictionary of parameter name to value
    public func toQueryParameters() -> [String: String] {
        var params: [String: String] = [:]
        for item in toQueryItems() {
            params[item.name] = item.value ?? ""
        }
        return params
    }
}

// MARK: - Compartment Search

/// Represents a FHIR compartment-based search
///
/// Compartment searches retrieve resources associated with a specific entity,
/// typically a patient. The search is scoped to a compartment path like
/// `Patient/123/Observation`.
///
/// See: http://hl7.org/fhir/R4/compartmentdefinition.html
///
/// Example:
/// ```swift
/// let search = CompartmentSearch(
///     compartmentType: "Patient",
///     compartmentId: "123",
///     resourceType: "Observation"
/// )
/// print(search.path()) // "Patient/123/Observation"
/// ```
public struct CompartmentSearch: Sendable, Equatable {
    /// The compartment type (e.g., "Patient", "Encounter", "Practitioner")
    public let compartmentType: String
    /// The compartment instance id (e.g., "123")
    public let compartmentId: String
    /// Optional resource type within the compartment (e.g., "Observation")
    public let resourceType: String?

    /// Creates a new compartment search
    ///
    /// - Parameters:
    ///   - compartmentType: The compartment type
    ///   - compartmentId: The compartment instance id
    ///   - resourceType: Optional resource type to search within
    public init(
        compartmentType: String,
        compartmentId: String,
        resourceType: String? = nil
    ) {
        self.compartmentType = compartmentType
        self.compartmentId = compartmentId
        self.resourceType = resourceType
    }

    /// Build the compartment search path
    ///
    /// Returns the URL path segment for this compartment search.
    /// - Returns: The compartment path (e.g., "Patient/123/Observation")
    public func path() -> String {
        if let resourceType = resourceType {
            return "\(compartmentType)/\(compartmentId)/\(resourceType)"
        }
        return "\(compartmentType)/\(compartmentId)"
    }
}

// MARK: - Search Results

/// A typed entry from a search result Bundle
///
/// Wraps a resource from a Bundle entry with its search metadata.
public struct SearchResultEntry<T: Resource & Codable & Sendable>: Sendable {
    /// The decoded resource
    public let resource: T
    /// The full URL of the resource on the server
    public let fullUrl: String?
    /// The search mode (match, include, or outcome)
    public let searchMode: String?
    /// The search relevance score (0.0 to 1.0)
    public let searchScore: Decimal?

    /// Creates a new search result entry
    ///
    /// - Parameters:
    ///   - resource: The decoded resource
    ///   - fullUrl: The full URL
    ///   - searchMode: The search mode
    ///   - searchScore: The relevance score
    public init(
        resource: T,
        fullUrl: String? = nil,
        searchMode: String? = nil,
        searchScore: Decimal? = nil
    ) {
        self.resource = resource
        self.fullUrl = fullUrl
        self.searchMode = searchMode
        self.searchScore = searchScore
    }
}

/// Typed wrapper around a FHIR search result Bundle
///
/// Provides convenient access to search results, pagination info, and metadata.
///
/// Example:
/// ```swift
/// let response = try await client.search(Patient.self, query: query)
/// let result = SearchResult(bundle: response.resource, type: Patient.self)
/// for entry in result.entries {
///     print(entry.resource.id)
/// }
/// ```
public struct SearchResult<T: Resource & Codable & Sendable>: Sendable {
    /// The underlying Bundle resource
    public let bundle: Bundle
    /// Total number of matching resources (may be nil if server doesn't provide it)
    public let total: Int32?
    /// The typed resource entries from the search
    public let entries: [SearchResultEntry<T>]
    /// Whether there is a next page of results
    public let hasNextPage: Bool
    /// Whether there is a previous page of results
    public let hasPreviousPage: Bool

    /// Creates a SearchResult from a Bundle and target resource type
    ///
    /// Entries that cannot be decoded as the target type are silently skipped.
    ///
    /// - Parameters:
    ///   - bundle: The search result Bundle
    ///   - type: The expected resource type
    public init(bundle: Bundle, type: T.Type) {
        self.bundle = bundle
        self.total = bundle.total
        self.hasNextPage = bundle.link?.contains(where: { $0.relation == "next" }) ?? false
        self.hasPreviousPage = bundle.link?.contains(where: {
            $0.relation == "previous" || $0.relation == "prev"
        }) ?? false

        var entries: [SearchResultEntry<T>] = []
        if let bundleEntries = bundle.entry {
            for entry in bundleEntries {
                if let resourceContainer = entry.resource {
                    if let resource = Self.extractResource(from: resourceContainer, as: type) {
                        entries.append(SearchResultEntry(
                            resource: resource,
                            fullUrl: entry.fullUrl,
                            searchMode: entry.search?.mode,
                            searchScore: entry.search?.score
                        ))
                    }
                }
            }
        }
        self.entries = entries
    }

    /// Attempt to extract a typed resource from a ResourceContainer
    private static func extractResource(
        from container: ResourceContainer,
        as type: T.Type
    ) -> T? {
        // Try to extract by matching the container's resource to the expected type
        switch container {
        case .patient(let r): return r as? T
        case .observation(let r): return r as? T
        case .practitioner(let r): return r as? T
        case .organization(let r): return r as? T
        case .condition(let r): return r as? T
        case .allergyIntolerance(let r): return r as? T
        case .encounter(let r): return r as? T
        case .medicationRequest(let r): return r as? T
        case .diagnosticReport(let r): return r as? T
        case .appointment(let r): return r as? T
        case .schedule(let r): return r as? T
        case .medicationStatement(let r): return r as? T
        case .documentReference(let r): return r as? T
        case .bundle(let r): return r as? T
        case .operationOutcome(let r): return r as? T
        }
    }
}

// MARK: - Search Parameter Validation

/// Validation issue found during search query validation
///
/// Contains the severity, message, and optionally the parameter name
/// that caused the issue.
public struct SearchValidationIssue: Sendable, Equatable {
    /// Severity level of the validation issue
    public enum Severity: String, Sendable, Equatable {
        /// Error - the query is invalid
        case error
        /// Warning - the query may produce unexpected results
        case warning
    }

    /// The severity of this issue
    public let severity: Severity
    /// Human-readable description of the issue
    public let message: String
    /// The parameter name that caused the issue, if applicable
    public let parameter: String?

    /// Creates a new validation issue
    ///
    /// - Parameters:
    ///   - severity: The severity level
    ///   - message: Description of the issue
    ///   - parameter: The parameter that caused the issue
    public init(severity: Severity, message: String, parameter: String? = nil) {
        self.severity = severity
        self.message = message
        self.parameter = parameter
    }
}

/// Validates FHIR search queries against known parameter definitions
///
/// Provides static methods for validating search queries and individual parameters.
/// Includes a registry of common search parameters for standard FHIR resource types.
///
/// Example:
/// ```swift
/// let query = FHIRSearchQuery(resourceType: "Patient")
///     .where("invalid-param", .string("value"))
/// let issues = SearchParameterValidator.validate(query)
/// ```
public struct SearchParameterValidator: Sendable {

    /// Common search parameters defined per resource type
    ///
    /// This covers the most commonly used parameters. Custom or implementation-specific
    /// parameters may not be included but will generate warnings (not errors).
    public static let commonParameters: [String: Set<String>] = [
        "Patient": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "active", "address", "address-city", "address-country", "address-postalcode",
            "address-state", "address-use", "birthdate", "death-date", "deceased",
            "email", "family", "gender", "general-practitioner", "given",
            "identifier", "language", "link", "name", "organization", "phone",
            "phonetic", "telecom"
        ],
        "Observation": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "based-on", "category", "code", "code-value-concept", "code-value-date",
            "code-value-quantity", "code-value-string", "combo-code",
            "combo-code-value-concept", "combo-code-value-quantity", "combo-data-absent-reason",
            "combo-value-concept", "combo-value-quantity", "component-code",
            "component-code-value-concept", "component-code-value-quantity",
            "component-data-absent-reason", "component-value-concept",
            "component-value-quantity", "data-absent-reason", "date",
            "derived-from", "device", "encounter", "focus", "has-member",
            "identifier", "method", "part-of", "patient", "performer",
            "specimen", "status", "subject", "value-concept", "value-date",
            "value-quantity", "value-string"
        ],
        "Condition": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "abatement-age", "abatement-date", "abatement-string", "asserter",
            "body-site", "category", "clinical-status", "code", "encounter",
            "evidence", "evidence-detail", "identifier", "onset-age", "onset-date",
            "onset-info", "patient", "recorded-date", "severity", "stage",
            "subject", "verification-status"
        ],
        "Encounter": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "account", "appointment", "based-on", "class", "date",
            "diagnosis", "episode-of-care", "identifier", "length",
            "location", "location-period", "part-of", "participant",
            "participant-type", "patient", "practitioner", "reason-code",
            "reason-reference", "service-provider", "special-arrangement",
            "status", "subject", "type"
        ],
        "Practitioner": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "active", "address", "address-city", "address-country",
            "address-postalcode", "address-state", "address-use",
            "communication", "email", "family", "gender", "given",
            "identifier", "name", "phone", "phonetic", "telecom"
        ],
        "Organization": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "active", "address", "address-city", "address-country",
            "address-postalcode", "address-state", "address-use",
            "endpoint", "identifier", "name", "partof", "phonetic",
            "type"
        ],
        "MedicationRequest": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "authoredon", "category", "code", "date", "encounter",
            "identifier", "intended-dispenser", "intended-performer",
            "intended-performertype", "intent", "medication", "patient",
            "priority", "requester", "status", "subject"
        ],
        "DiagnosticReport": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "based-on", "category", "code", "conclusion", "date",
            "encounter", "identifier", "issued", "media", "patient",
            "performer", "result", "results-interpreter", "specimen",
            "status", "subject"
        ],
        "AllergyIntolerance": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security", "_text", "_content",
            "asserter", "category", "clinical-status", "code", "criticality",
            "date", "identifier", "last-date", "manifestation", "onset",
            "patient", "recorder", "route", "severity", "type",
            "verification-status"
        ],
        "Bundle": [
            "_id", "_lastUpdated", "_tag", "_profile", "_security",
            "composition", "identifier", "message", "timestamp", "type"
        ]
    ]

    /// Common parameters available on all resource types
    private static let globalParameters: Set<String> = [
        "_id", "_lastUpdated", "_tag", "_profile", "_security",
        "_text", "_content", "_list", "_has", "_type",
        "_sort", "_count", "_offset", "_include", "_revinclude",
        "_summary", "_elements", "_total", "_contained", "_containedType"
    ]

    /// Validate a search query for known issues
    ///
    /// Checks each parameter against the known parameter definitions for the
    /// resource type. Unknown parameters generate warnings, invalid structures
    /// generate errors.
    ///
    /// - Parameter query: The search query to validate
    /// - Returns: Array of validation issues found
    public static func validate(_ query: FHIRSearchQuery) -> [SearchValidationIssue] {
        var issues: [SearchValidationIssue] = []

        // Validate resource type
        if query.resourceType.isEmpty {
            issues.append(SearchValidationIssue(
                severity: .error,
                message: "Resource type cannot be empty"
            ))
        }

        // Validate parameters
        for param in query.parameters {
            // Extract the base parameter name (before any chaining dots)
            let baseName = extractBaseName(from: param.name)

            // Skip _has parameters and chained parameters (complex validation)
            if param.name.hasPrefix("_has:") {
                continue
            }

            // Check if parameter is valid for the resource type
            if !isValidParameter(baseName, for: query.resourceType) {
                issues.append(SearchValidationIssue(
                    severity: .warning,
                    message: "Parameter '\(param.name)' is not a known search parameter for \(query.resourceType)",
                    parameter: param.name
                ))
            }

            // Validate modifier compatibility
            if let modifier = param.modifier {
                let modifierIssues = validateModifier(modifier, for: param)
                issues.append(contentsOf: modifierIssues)
            }
        }

        // Validate count is positive
        if let count = query.count, count <= 0 {
            issues.append(SearchValidationIssue(
                severity: .error,
                message: "_count must be a positive integer, got \(count)",
                parameter: "_count"
            ))
        }

        // Validate offset is non-negative
        if let offset = query.offset, offset < 0 {
            issues.append(SearchValidationIssue(
                severity: .error,
                message: "_offset must be non-negative, got \(offset)",
                parameter: "_offset"
            ))
        }

        return issues
    }

    /// Check if a parameter name is valid for a given resource type
    ///
    /// Checks against both resource-specific parameters and global parameters.
    ///
    /// - Parameters:
    ///   - name: The parameter name to check
    ///   - resourceType: The FHIR resource type
    /// - Returns: True if the parameter is known for this resource type
    public static func isValidParameter(_ name: String, for resourceType: String) -> Bool {
        // Global parameters are valid for all types
        if globalParameters.contains(name) {
            return true
        }

        // Check resource-specific parameters
        if let knownParams = commonParameters[resourceType] {
            return knownParams.contains(name)
        }

        // Unknown resource type - allow all parameters
        return true
    }

    /// Extract the base parameter name from a potentially chained parameter
    ///
    /// For "subject.name", returns "subject". For "name", returns "name".
    private static func extractBaseName(from name: String) -> String {
        if let dotIndex = name.firstIndex(of: ".") {
            return String(name[name.startIndex..<dotIndex])
        }
        // Handle modifier in name (e.g., from chained: "subject:Patient.name")
        if let colonIndex = name.firstIndex(of: ":") {
            return String(name[name.startIndex..<colonIndex])
        }
        return name
    }

    /// Validate a modifier is appropriate for the parameter
    private static func validateModifier(
        _ modifier: SearchModifier,
        for param: SearchParameter
    ) -> [SearchValidationIssue] {
        var issues: [SearchValidationIssue] = []

        switch modifier {
        case .exact, .contains:
            // Only valid for string parameters
            switch param.value {
            case .string:
                break
            default:
                issues.append(SearchValidationIssue(
                    severity: .warning,
                    message: "Modifier ':\(modifier.rawValue)' is typically used with string parameters",
                    parameter: param.name
                ))
            }
        case .missing:
            // Missing modifier should have a missing value
            switch param.value {
            case .missing:
                break
            default:
                issues.append(SearchValidationIssue(
                    severity: .warning,
                    message: "Parameter with :missing modifier should use .missing(Bool) value",
                    parameter: param.name
                ))
            }
        default:
            break
        }

        return issues
    }
}
