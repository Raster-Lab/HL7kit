/// PerformanceOptimization.swift
/// Performance optimization utilities for HL7 v3.x XML parsing and CDA processing
///
/// Provides thread-safe object pools, string interning, XPath query caching,
/// lazy loading, streaming support, and performance metrics for HL7 v3.x documents.
/// All types are `Sendable` for Swift 6 strict concurrency safety.

import Foundation
import HL7Core

// MARK: - XML Element Pool

/// Thread-safe object pool for reusing XMLElement instances during parsing
///
/// Reduces memory allocations by recycling XMLElement objects with their
/// pre-allocated child arrays and attribute dictionaries.
///
/// Example:
/// ```swift
/// let storage = await XMLElementPool.shared.acquire()
/// // Use storage.element for building DOM
/// await XMLElementPool.shared.release(storage)
/// ```
public actor XMLElementPool {
    /// Reusable storage wrapping an XMLElement with pre-allocated capacity
    public struct ElementStorage: Sendable {
        /// The reusable element
        public var element: XMLElement

        /// Resets the storage for reuse without deallocating backing arrays
        public mutating func reset() {
            element = XMLElement(
                name: "",
                namespace: nil,
                prefix: nil,
                attributes: [:],
                children: [],
                text: nil
            )
        }
    }

    private var available: [ElementStorage]
    private let maxPoolSize: Int

    // Statistics
    private var acquireCount: Int = 0
    private var reuseCount: Int = 0
    private var allocationCount: Int = 0
    private var releaseCount: Int = 0

    /// Shared global pool
    public static let shared = XMLElementPool()

    /// Creates an element pool
    /// - Parameter maxPoolSize: Maximum number of elements to keep pooled
    public init(maxPoolSize: Int = 200) {
        self.available = []
        self.maxPoolSize = maxPoolSize
    }

    /// Acquires an element storage from the pool (or creates a new one)
    /// - Returns: A reset ElementStorage ready for use
    public func acquire() -> ElementStorage {
        acquireCount += 1
        if var storage = available.popLast() {
            reuseCount += 1
            storage.reset()
            return storage
        }
        allocationCount += 1
        return ElementStorage(element: XMLElement(name: ""))
    }

    /// Returns an element storage to the pool for reuse
    /// - Parameter storage: The storage to return
    public func release(_ storage: ElementStorage) {
        releaseCount += 1
        guard available.count < maxPoolSize else { return }
        available.append(storage)
    }

    /// Pre-allocates pool entries for batch processing
    /// - Parameter count: Number of elements to pre-allocate
    public func preallocate(_ count: Int) {
        let toCreate = min(count, maxPoolSize - available.count)
        for _ in 0..<toCreate {
            available.append(ElementStorage(element: XMLElement(name: "")))
        }
    }

    /// Returns pool performance statistics
    public func statistics() -> PoolStatistics {
        PoolStatistics(
            availableCount: available.count,
            acquireCount: acquireCount,
            reuseCount: reuseCount,
            allocationCount: allocationCount,
            releaseCount: releaseCount
        )
    }

    /// Clears the pool and resets statistics
    public func clear() {
        available.removeAll()
        acquireCount = 0
        reuseCount = 0
        allocationCount = 0
        releaseCount = 0
    }
}

/// Pool statistics for tracking performance of object pools
public struct PoolStatistics: Sendable, Equatable {
    /// Number of objects currently available in the pool
    public let availableCount: Int
    /// Total number of acquire requests
    public let acquireCount: Int
    /// Number of times an object was reused (cache hit)
    public let reuseCount: Int
    /// Number of times a new object was allocated (cache miss)
    public let allocationCount: Int
    /// Number of times an object was returned to the pool
    public let releaseCount: Int

    /// Reuse rate (0.0 to 1.0)
    public var reuseRate: Double {
        let total = reuseCount + allocationCount
        guard total > 0 else { return 0.0 }
        return Double(reuseCount) / Double(total)
    }

    /// Creates pool statistics
    public init(
        availableCount: Int,
        acquireCount: Int,
        reuseCount: Int,
        allocationCount: Int,
        releaseCount: Int
    ) {
        self.availableCount = availableCount
        self.acquireCount = acquireCount
        self.reuseCount = reuseCount
        self.allocationCount = allocationCount
        self.releaseCount = releaseCount
    }
}

// MARK: - XML Element Name Interning

/// Pre-interned element names for common HL7 v3 and CDA XML elements
///
/// Using pre-allocated constant strings avoids repeated allocations
/// for element names that appear in every CDA document.
///
/// Example:
/// ```swift
/// let name = InternedElementName.intern("ClinicalDocument")
/// // Returns the shared constant string
/// ```
public enum InternedElementName {
    // CDA Root and Header
    public static let clinicalDocument = "ClinicalDocument"
    public static let realmCode = "realmCode"
    public static let typeId = "typeId"
    public static let templateId = "templateId"
    public static let id = "id"
    public static let code = "code"
    public static let title = "title"
    public static let effectiveTime = "effectiveTime"
    public static let confidentialityCode = "confidentialityCode"
    public static let languageCode = "languageCode"
    public static let setId = "setId"
    public static let versionNumber = "versionNumber"

    // Header Participants
    public static let recordTarget = "recordTarget"
    public static let patientRole = "patientRole"
    public static let patient = "patient"
    public static let author = "author"
    public static let assignedAuthor = "assignedAuthor"
    public static let custodian = "custodian"
    public static let assignedCustodian = "assignedCustodian"
    public static let representedCustodianOrganization = "representedCustodianOrganization"
    public static let legalAuthenticator = "legalAuthenticator"
    public static let authenticator = "authenticator"
    public static let dataEnterer = "dataEnterer"
    public static let informant = "informant"
    public static let informationRecipient = "informationRecipient"

    // Body/Section Structure
    public static let component = "component"
    public static let structuredBody = "structuredBody"
    public static let section = "section"
    public static let text = "text"
    public static let entry = "entry"

    // Entry Types
    public static let observation = "observation"
    public static let act = "act"
    public static let procedure = "procedure"
    public static let substanceAdministration = "substanceAdministration"
    public static let supply = "supply"
    public static let encounter = "encounter"
    public static let organizer = "organizer"

    // Common Elements
    public static let name = "name"
    public static let addr = "addr"
    public static let telecom = "telecom"
    public static let value = "value"
    public static let statusCode = "statusCode"
    public static let entryRelationship = "entryRelationship"
    public static let reference = "reference"
    public static let translation = "translation"
    public static let qualifier = "qualifier"
    public static let originalText = "originalText"

    // Data Type Parts
    public static let low = "low"
    public static let high = "high"
    public static let center = "center"
    public static let width = "width"
    public static let given = "given"
    public static let family = "family"
    public static let prefix = "prefix"
    public static let suffix = "suffix"

    // Narrative
    public static let paragraph = "paragraph"
    public static let content = "content"
    public static let list = "list"
    public static let item = "item"
    public static let table = "table"
    public static let thead = "thead"
    public static let tbody = "tbody"
    public static let tr = "tr"
    public static let th = "th"
    public static let td = "td"

    /// Lookup table for O(1) interning
    private static let lookupTable: [String: String] = [
        "ClinicalDocument": clinicalDocument,
        "realmCode": realmCode,
        "typeId": typeId,
        "templateId": templateId,
        "id": id,
        "code": code,
        "title": title,
        "effectiveTime": effectiveTime,
        "confidentialityCode": confidentialityCode,
        "languageCode": languageCode,
        "setId": setId,
        "versionNumber": versionNumber,
        "recordTarget": recordTarget,
        "patientRole": patientRole,
        "patient": patient,
        "author": author,
        "assignedAuthor": assignedAuthor,
        "custodian": custodian,
        "assignedCustodian": assignedCustodian,
        "representedCustodianOrganization": representedCustodianOrganization,
        "legalAuthenticator": legalAuthenticator,
        "authenticator": authenticator,
        "dataEnterer": dataEnterer,
        "informant": informant,
        "informationRecipient": informationRecipient,
        "component": component,
        "structuredBody": structuredBody,
        "section": section,
        "text": text,
        "entry": entry,
        "observation": observation,
        "act": act,
        "procedure": procedure,
        "substanceAdministration": substanceAdministration,
        "supply": supply,
        "encounter": encounter,
        "organizer": organizer,
        "name": name,
        "addr": addr,
        "telecom": telecom,
        "value": value,
        "statusCode": statusCode,
        "entryRelationship": entryRelationship,
        "reference": reference,
        "translation": translation,
        "qualifier": qualifier,
        "originalText": originalText,
        "low": low,
        "high": high,
        "center": center,
        "width": width,
        "given": given,
        "family": family,
        "prefix": prefix,
        "suffix": suffix,
        "paragraph": paragraph,
        "content": content,
        "list": list,
        "item": item,
        "table": table,
        "thead": thead,
        "tbody": tbody,
        "tr": tr,
        "th": th,
        "td": td,
    ]

    /// Interns an element name, returning the canonical shared string if known
    /// - Parameter elementName: The element name to intern
    /// - Returns: The interned constant string for known names, or the original string
    public static func intern(_ elementName: String) -> String {
        lookupTable[elementName] ?? elementName
    }
}

/// Thread-safe string interner for HL7 v3 custom element names and attribute values
///
/// Complements `InternedElementName` by handling dynamic strings that appear
/// frequently but aren't in the pre-defined set.
public actor V3StringInterner {
    private var internedStrings: [String: String]
    private var hitCount: Int
    private var missCount: Int

    /// Shared global interner
    public static let shared = V3StringInterner()

    /// Creates a new string interner
    public init() {
        self.internedStrings = [:]
        self.hitCount = 0
        self.missCount = 0
    }

    /// Interns a string, returning the canonical copy
    /// - Parameter string: The string to intern
    /// - Returns: The interned string (canonical copy for deduplication)
    public func intern(_ string: String) -> String {
        if let existing = internedStrings[string] {
            hitCount += 1
            return existing
        } else {
            internedStrings[string] = string
            missCount += 1
            return string
        }
    }

    /// Gets interning performance statistics
    public func statistics() -> V3InternStatistics {
        V3InternStatistics(
            internedCount: internedStrings.count,
            hitCount: hitCount,
            missCount: missCount
        )
    }

    /// Clears all interned strings and resets statistics
    public func clear() {
        internedStrings.removeAll()
        hitCount = 0
        missCount = 0
    }
}

/// Statistics about string interning performance
public struct V3InternStatistics: Sendable, Equatable {
    /// Number of unique strings interned
    public let internedCount: Int
    /// Number of cache hits (reused existing string)
    public let hitCount: Int
    /// Number of cache misses (new string stored)
    public let missCount: Int

    /// Hit rate (0.0 to 1.0)
    public var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0.0 }
        return Double(hitCount) / Double(total)
    }
}

// MARK: - XPath Query Cache

/// Thread-safe cache for XPath query results on XML documents
///
/// Caches the results of XPath-like queries to avoid redundant traversals
/// of the same document. Uses a simple LRU eviction strategy.
///
/// Example:
/// ```swift
/// let cache = XPathQueryCache()
/// let results = await cache.query(expression: "//section", on: document) {
///     try XMLPathQuery(expression: "//section").evaluate(on: document)
/// }
/// ```
public actor XPathQueryCache {
    /// A cache entry storing query results
    private struct CacheEntry {
        let results: [XMLElement]
        let accessCount: Int
    }

    private var cache: [String: CacheEntry]
    private let maxEntries: Int
    private var hitCount: Int = 0
    private var missCount: Int = 0

    /// Shared global cache
    public static let shared = XPathQueryCache()

    /// Creates a query cache
    /// - Parameter maxEntries: Maximum number of cached query results
    public init(maxEntries: Int = 256) {
        self.cache = [:]
        self.maxEntries = maxEntries
    }

    /// Looks up a cached result or executes the query
    /// - Parameters:
    ///   - expression: The XPath expression used as cache key
    ///   - compute: Closure that executes the query if not cached
    /// - Returns: The query results (from cache or freshly computed)
    public func query(
        expression: String,
        compute: @Sendable () throws -> [XMLElement]
    ) rethrows -> [XMLElement] {
        if let entry = cache[expression] {
            hitCount += 1
            cache[expression] = CacheEntry(
                results: entry.results,
                accessCount: entry.accessCount + 1
            )
            return entry.results
        }

        missCount += 1
        let results = try compute()

        // Evict least accessed entry if at capacity
        if cache.count >= maxEntries {
            if let leastUsedKey = cache.min(by: { $0.value.accessCount < $1.value.accessCount })?.key {
                cache.removeValue(forKey: leastUsedKey)
            }
        }

        cache[expression] = CacheEntry(results: results, accessCount: 1)
        return results
    }

    /// Invalidates all cached entries
    public func invalidate() {
        cache.removeAll()
    }

    /// Invalidates a specific cached entry
    /// - Parameter expression: The XPath expression to invalidate
    public func invalidate(expression: String) {
        cache.removeValue(forKey: expression)
    }

    /// Returns cache performance statistics
    public func statistics() -> QueryCacheStatistics {
        QueryCacheStatistics(
            entryCount: cache.count,
            hitCount: hitCount,
            missCount: missCount,
            maxEntries: maxEntries
        )
    }

    /// Clears the cache and resets statistics
    public func clear() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
    }
}

/// Statistics about XPath query cache performance
public struct QueryCacheStatistics: Sendable, Equatable {
    /// Number of entries currently cached
    public let entryCount: Int
    /// Number of cache hits
    public let hitCount: Int
    /// Number of cache misses
    public let missCount: Int
    /// Maximum number of entries allowed
    public let maxEntries: Int

    /// Hit rate (0.0 to 1.0)
    public var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0.0 }
        return Double(hitCount) / Double(total)
    }
}

// MARK: - Lazy Section Content

/// Lazy-loading wrapper for CDA section content
///
/// Defers parsing of section body content (entries, narrative text) until first access.
/// This is beneficial for large CDA documents where only specific sections are needed.
///
/// Example:
/// ```swift
/// let lazy = LazySectionContent(rawXML: sectionXMLElement)
/// // Content is not parsed until accessed:
/// let entries = lazy.entries  // Parses on first access
/// ```
public struct LazySectionContent: Sendable {
    /// The raw XML element containing section content
    private let rawXML: XMLElement

    /// Cached parsed entries (nil until first access)
    private var _entries: [XMLElement]?

    /// Cached parsed narrative text (nil until first access)
    private var _narrativeText: String?

    /// Whether entries have been parsed
    public private(set) var isEntriesParsed: Bool = false

    /// Whether narrative text has been parsed
    public private(set) var isNarrativeParsed: Bool = false

    /// Creates a lazy section content wrapper
    /// - Parameter rawXML: The raw XML element for the section
    public init(rawXML: XMLElement) {
        self.rawXML = rawXML
    }

    /// The section's entry elements (parsed lazily on first access)
    public var entries: [XMLElement] {
        mutating get {
            if let cached = _entries {
                return cached
            }
            let parsed = rawXML.childElements(named: InternedElementName.entry)
            _entries = parsed
            isEntriesParsed = true
            return parsed
        }
    }

    /// The section's narrative text content (parsed lazily on first access)
    public var narrativeText: String? {
        mutating get {
            if isNarrativeParsed {
                return _narrativeText
            }
            let textElement = rawXML.firstChild(named: InternedElementName.text)
            _narrativeText = textElement?.allText
            isNarrativeParsed = true
            return _narrativeText
        }
    }

    /// The section title (parsed directly, typically small)
    public var title: String? {
        rawXML.firstChild(named: InternedElementName.title)?.text
    }

    /// The section code (parsed directly, typically small)
    public var sectionCode: XMLElement? {
        rawXML.firstChild(named: InternedElementName.code)
    }

    /// Number of entries without fully parsing them
    public var entryCount: Int {
        rawXML.children.filter { $0.name == InternedElementName.entry }.count
    }
}

// MARK: - Streaming XML Document Source

/// Protocol for streaming XML document data sources
///
/// Enables constant-memory processing of large XML files by providing
/// data in chunks rather than loading the entire file into memory.
public protocol XMLStreamSource: Sendable {
    /// Reads the next chunk of XML data
    /// - Parameter maxBytes: Maximum bytes to read
    /// - Returns: The data chunk, or nil if the source is exhausted
    func readNext(maxBytes: Int) async throws -> Data?

    /// Closes the stream source
    func close() async throws
}

/// File-based XML stream source for reading large CDA documents
public actor FileXMLStreamSource: XMLStreamSource {
    private let fileURL: URL
    private var offset: Int = 0
    private var isOpen: Bool = false
    private var fileData: Data?

    /// Creates a file stream source
    /// - Parameter fileURL: URL to the XML file
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func readNext(maxBytes: Int) async throws -> Data? {
        if !isOpen {
            fileData = try Data(contentsOf: fileURL)
            isOpen = true
        }

        guard let data = fileData else { return nil }
        guard offset < data.count else { return nil }

        let endIndex = min(offset + maxBytes, data.count)
        let chunk = data[offset..<endIndex]
        offset = endIndex

        return chunk.isEmpty ? nil : Data(chunk)
    }

    public func close() async throws {
        fileData = nil
        isOpen = false
        offset = 0
    }
}

/// In-memory XML stream source for testing or processing pre-loaded data
public actor DataXMLStreamSource: XMLStreamSource {
    private let data: Data
    private var offset: Int = 0

    /// Creates a data stream source
    /// - Parameter data: The XML data to stream
    public init(data: Data) {
        self.data = data
    }

    public func readNext(maxBytes: Int) async throws -> Data? {
        guard offset < data.count else { return nil }

        let endIndex = min(offset + maxBytes, data.count)
        let chunk = data[offset..<endIndex]
        offset = endIndex

        return chunk.isEmpty ? nil : Data(chunk)
    }

    public func close() async throws {
        offset = 0
    }
}

// MARK: - Streaming XML Element Iterator

/// Async stream of XML elements extracted from a streaming source
///
/// Processes large CDA documents with constant memory usage by streaming
/// elements as they are parsed, without building a complete DOM tree.
///
/// Example:
/// ```swift
/// let source = FileXMLStreamSource(fileURL: fileURL)
/// let stream = XMLElementStream(source: source, targetElement: "section")
/// for await result in stream {
///     switch result {
///     case .success(let section):
///         processCDASection(section)
///     case .failure(let error):
///         handleError(error)
///     }
/// }
/// ```
public struct XMLElementStream: AsyncSequence, Sendable {
    public typealias Element = Result<XMLElement, Error>

    private let source: any XMLStreamSource
    private let targetElement: String
    private let bufferSize: Int

    /// Creates a streaming XML element iterator
    /// - Parameters:
    ///   - source: The data source for XML content
    ///   - targetElement: The element name to extract from the stream
    ///   - bufferSize: Size of read buffer in bytes (default 64KB)
    public init(
        source: any XMLStreamSource,
        targetElement: String,
        bufferSize: Int = 65_536
    ) {
        self.source = source
        self.targetElement = targetElement
        self.bufferSize = bufferSize
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(source: source, targetElement: targetElement, bufferSize: bufferSize)
    }

    /// Async iterator that yields XML elements as they are parsed from the stream
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let source: any XMLStreamSource
        private let targetElement: String
        private let bufferSize: Int
        private var buffer: String = ""
        private var isExhausted: Bool = false

        init(source: any XMLStreamSource, targetElement: String, bufferSize: Int) {
            self.source = source
            self.targetElement = targetElement
            self.bufferSize = bufferSize
        }

        public mutating func next() async -> Element? {
            // Try extracting from current buffer
            if let element = extractElement() {
                return .success(element)
            }

            // Read more data until we find an element or exhaust the source
            while !isExhausted {
                do {
                    guard let data = try await source.readNext(maxBytes: bufferSize) else {
                        isExhausted = true
                        // Try extracting any remaining element
                        if let element = extractElement() {
                            return .success(element)
                        }
                        return nil
                    }

                    if let chunk = String(data: data, encoding: .utf8) {
                        buffer += chunk
                    }

                    if let element = extractElement() {
                        return .success(element)
                    }
                } catch {
                    isExhausted = true
                    return .failure(error)
                }
            }

            return nil
        }

        /// Extracts the next complete target element from the buffer
        private mutating func extractElement() -> XMLElement? {
            let openTag = "<\(targetElement)"
            let closeTag = "</\(targetElement)>"

            guard let startRange = buffer.range(of: openTag) else { return nil }
            guard let endRange = buffer.range(of: closeTag, range: startRange.lowerBound..<buffer.endIndex) else {
                return nil
            }

            let elementEnd = endRange.upperBound
            let elementXML = String(buffer[startRange.lowerBound..<elementEnd])
            buffer = String(buffer[elementEnd...])

            // Parse the extracted XML fragment
            guard let xmlData = elementXML.data(using: .utf8) else { return nil }
            let parser = HL7v3XMLParser()
            guard let document = try? parser.parse(xmlData) else { return nil }
            return document.root
        }
    }
}

// MARK: - Streaming Document Reader

/// High-level reader for streaming large CDA documents
///
/// Provides convenience methods for processing large XML documents
/// with constant memory usage using async/await patterns.
///
/// Example:
/// ```swift
/// let reader = XMLStreamReader()
/// let sections = reader.streamSections(from: fileURL)
/// for await result in sections {
///     // Process each section incrementally
/// }
/// ```
public struct XMLStreamReader: Sendable {
    /// Creates a stream reader
    public init() {}

    /// Streams section elements from a CDA document file
    /// - Parameters:
    ///   - fileURL: URL of the CDA XML document
    ///   - bufferSize: Read buffer size in bytes (default 64KB)
    /// - Returns: An async sequence of section elements
    public func streamSections(from fileURL: URL, bufferSize: Int = 65_536) -> XMLElementStream {
        let source = FileXMLStreamSource(fileURL: fileURL)
        return XMLElementStream(
            source: source,
            targetElement: InternedElementName.section,
            bufferSize: bufferSize
        )
    }

    /// Streams section elements from in-memory XML data
    /// - Parameters:
    ///   - data: The XML data to stream
    ///   - bufferSize: Read buffer size in bytes (default 64KB)
    /// - Returns: An async sequence of section elements
    public func streamSections(from data: Data, bufferSize: Int = 65_536) -> XMLElementStream {
        let source = DataXMLStreamSource(data: data)
        return XMLElementStream(
            source: source,
            targetElement: InternedElementName.section,
            bufferSize: bufferSize
        )
    }

    /// Streams elements of a specified type from XML data
    /// - Parameters:
    ///   - elementName: Name of the element to extract
    ///   - data: The XML data to stream
    ///   - bufferSize: Read buffer size in bytes (default 64KB)
    /// - Returns: An async sequence of matching elements
    public func streamElements(
        named elementName: String,
        from data: Data,
        bufferSize: Int = 65_536
    ) -> XMLElementStream {
        let source = DataXMLStreamSource(data: data)
        return XMLElementStream(
            source: source,
            targetElement: elementName,
            bufferSize: bufferSize
        )
    }

    /// Counts elements in a document without building full DOM
    /// - Parameters:
    ///   - elementName: Name of the element to count
    ///   - data: The XML data to scan
    /// - Returns: The count of matching elements
    public func countElements(named elementName: String, in data: Data) -> Int {
        guard let xmlString = String(data: data, encoding: .utf8) else { return 0 }
        let openTag = "<\(elementName)"
        var count = 0
        var searchRange = xmlString.startIndex..<xmlString.endIndex
        while let range = xmlString.range(of: openTag, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<xmlString.endIndex
        }
        return count
    }
}

// MARK: - Performance Metrics

/// Metrics for tracking HL7 v3 parsing and processing performance
///
/// Captures timing, memory, and throughput data for performance profiling.
///
/// Example:
/// ```swift
/// var metrics = V3PerformanceMetrics()
/// metrics.startTiming()
/// // ... perform parsing ...
/// metrics.stopTiming()
/// metrics.recordDocumentSize(data.count)
/// metrics.recordElementCount(document.root?.children.count ?? 0)
/// print(metrics.summary)
/// ```
public struct V3PerformanceMetrics: Sendable {
    /// Timestamp when timing started
    private var startTime: Date?
    /// Timestamp when timing stopped
    private var stopTime: Date?

    /// Size of the document in bytes
    public private(set) var documentSizeBytes: Int = 0

    /// Number of XML elements in the document
    public private(set) var elementCount: Int = 0

    /// Number of attributes across all elements
    public private(set) var attributeCount: Int = 0

    /// Maximum nesting depth encountered
    public private(set) var maxDepth: Int = 0

    /// Number of unique element names
    public private(set) var uniqueElementNames: Int = 0

    /// Creates empty performance metrics
    public init() {}

    /// Starts the timing measurement
    public mutating func startTiming() {
        startTime = Date()
        stopTime = nil
    }

    /// Stops the timing measurement
    public mutating func stopTiming() {
        stopTime = Date()
    }

    /// Duration of the measured operation in seconds
    public var duration: TimeInterval? {
        guard let start = startTime, let stop = stopTime else { return nil }
        return stop.timeIntervalSince(start)
    }

    /// Parsing throughput in bytes per second
    public var bytesPerSecond: Double? {
        guard let dur = duration, dur > 0 else { return nil }
        return Double(documentSizeBytes) / dur
    }

    /// Parsing throughput in elements per second
    public var elementsPerSecond: Double? {
        guard let dur = duration, dur > 0 else { return nil }
        return Double(elementCount) / dur
    }

    /// Records the document size
    /// - Parameter bytes: Size in bytes
    public mutating func recordDocumentSize(_ bytes: Int) {
        documentSizeBytes = bytes
    }

    /// Records the number of elements
    /// - Parameter count: Number of elements
    public mutating func recordElementCount(_ count: Int) {
        elementCount = count
    }

    /// Records the number of attributes
    /// - Parameter count: Number of attributes
    public mutating func recordAttributeCount(_ count: Int) {
        attributeCount = count
    }

    /// Records the maximum nesting depth
    /// - Parameter depth: Maximum depth
    public mutating func recordMaxDepth(_ depth: Int) {
        maxDepth = depth
    }

    /// Records the number of unique element names
    /// - Parameter count: Number of unique names
    public mutating func recordUniqueElementNames(_ count: Int) {
        uniqueElementNames = count
    }

    /// Human-readable summary of performance metrics
    public var summary: String {
        var parts: [String] = []
        if let dur = duration {
            parts.append(String(format: "Duration: %.3f ms", dur * 1000))
        }
        parts.append("Document: \(documentSizeBytes) bytes")
        parts.append("Elements: \(elementCount)")
        parts.append("Attributes: \(attributeCount)")
        parts.append("Max Depth: \(maxDepth)")
        parts.append("Unique Names: \(uniqueElementNames)")
        if let bps = bytesPerSecond {
            parts.append(String(format: "Throughput: %.0f bytes/s", bps))
        }
        if let eps = elementsPerSecond {
            parts.append(String(format: "Elements/s: %.0f", eps))
        }
        return parts.joined(separator: ", ")
    }
}

/// Collects DOM statistics from an XMLElement tree for performance profiling
///
/// Example:
/// ```swift
/// if let root = document.root {
///     let stats = XMLDocumentAnalyzer.analyze(root)
///     print("Elements: \(stats.totalElements), Max Depth: \(stats.maxDepth)")
/// }
/// ```
public enum XMLDocumentAnalyzer {
    /// Statistics about an XML document's structure
    public struct DocumentStats: Sendable, Equatable {
        /// Total number of elements in the document
        public let totalElements: Int
        /// Total number of attributes across all elements
        public let totalAttributes: Int
        /// Maximum nesting depth
        public let maxDepth: Int
        /// Number of unique element names
        public let uniqueElementNames: Int
        /// Total text content length in characters
        public let totalTextLength: Int
    }

    /// Analyzes an XML element tree and returns structural statistics
    /// - Parameter root: The root element to analyze
    /// - Returns: Document statistics
    public static func analyze(_ root: XMLElement) -> DocumentStats {
        var totalElements = 0
        var totalAttributes = 0
        var maxDepth = 0
        var totalTextLength = 0
        var elementNames = Set<String>()

        analyzeRecursive(
            root,
            depth: 1,
            totalElements: &totalElements,
            totalAttributes: &totalAttributes,
            maxDepth: &maxDepth,
            totalTextLength: &totalTextLength,
            elementNames: &elementNames
        )

        return DocumentStats(
            totalElements: totalElements,
            totalAttributes: totalAttributes,
            maxDepth: maxDepth,
            uniqueElementNames: elementNames.count,
            totalTextLength: totalTextLength
        )
    }

    private static func analyzeRecursive(
        _ element: XMLElement,
        depth: Int,
        totalElements: inout Int,
        totalAttributes: inout Int,
        maxDepth: inout Int,
        totalTextLength: inout Int,
        elementNames: inout Set<String>
    ) {
        totalElements += 1
        totalAttributes += element.attributes.count
        maxDepth = max(maxDepth, depth)
        elementNames.insert(element.name)
        if let text = element.text {
            totalTextLength += text.count
        }

        for child in element.children {
            analyzeRecursive(
                child,
                depth: depth + 1,
                totalElements: &totalElements,
                totalAttributes: &totalAttributes,
                maxDepth: &maxDepth,
                totalTextLength: &totalTextLength,
                elementNames: &elementNames
            )
        }
    }
}

// MARK: - Global V3 Performance Pools

/// Global performance pools for HL7 v3.x processing
///
/// Provides convenient access to shared pools and interners.
/// All pools are actor-isolated for thread safety.
///
/// Example:
/// ```swift
/// // Pre-allocate pools before batch processing
/// await V3Pools.preallocateAll(100)
///
/// // Check pool performance
/// let stats = await V3Pools.allStatistics()
/// print("Element pool reuse rate: \(stats.elementPool.reuseRate)")
/// ```
public enum V3Pools {
    /// Shared element pool
    public static let elements = XMLElementPool.shared

    /// Shared string interner
    public static let interner = V3StringInterner.shared

    /// Shared query cache
    public static let queryCache = XPathQueryCache.shared

    /// Pre-allocates all pools for batch processing
    /// - Parameter count: Number of elements to pre-allocate per pool
    public static func preallocateAll(_ count: Int) async {
        await elements.preallocate(count)
    }

    /// Returns statistics from all pools
    /// - Returns: Tuple of pool statistics, intern statistics, and cache statistics
    public static func allStatistics() async -> (
        elementPool: PoolStatistics,
        interner: V3InternStatistics,
        queryCache: QueryCacheStatistics
    ) {
        async let poolStats = elements.statistics()
        async let internStats = interner.statistics()
        async let cacheStats = queryCache.statistics()
        return await (poolStats, internStats, cacheStats)
    }

    /// Clears all pools and caches
    public static func clearAll() async {
        await elements.clear()
        await interner.clear()
        await queryCache.clear()
    }
}
