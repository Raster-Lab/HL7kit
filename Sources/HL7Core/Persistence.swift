/// Persistence layer for HL7kit
///
/// This module provides message archiving, storage, search/indexing, and
/// export/import capabilities for HL7 messages. All implementations use
/// in-memory storage suitable for any platform including Linux.
///
/// Future platform-specific implementations may leverage Core Data or CloudKit
/// for persistent on-disk storage and cloud synchronization.

import Foundation

// MARK: - Persistence Errors

/// Errors that can occur during persistence operations
public enum PersistenceError: Error, Sendable, Equatable {
    /// Entry not found for the given identifier
    case entryNotFound(String)

    /// Duplicate entry already exists
    case duplicateEntry(String)

    /// Data format is invalid for import
    case invalidData(String)

    /// Storage operation failed
    case storageError(String)
}

// MARK: - Archive Entry

/// Metadata and content for a stored HL7 message
public struct ArchiveEntry: Sendable, Codable, Equatable, Identifiable {
    /// Unique identifier for this archive entry
    public let id: String

    /// HL7 message type (e.g., "ADT", "ORM", "ORU")
    public let messageType: String

    /// HL7 version (e.g., "2.5.1", "3.0", "R4")
    public let version: String

    /// Timestamp when the message was archived
    public let timestamp: Date

    /// Source system that produced the message
    public let source: String

    /// Tags for categorization and filtering
    public let tags: Set<String>

    /// Raw message content
    public let content: String

    /// Creates a new archive entry
    public init(
        id: String,
        messageType: String,
        version: String,
        timestamp: Date = Date(),
        source: String = "",
        tags: Set<String> = [],
        content: String
    ) {
        self.id = id
        self.messageType = messageType
        self.version = version
        self.timestamp = timestamp
        self.source = source
        self.tags = tags
        self.content = content
    }
}

/// Statistics about the message archive
public struct ArchiveStatistics: Sendable, Equatable {
    /// Total number of entries
    public let totalEntries: Int

    /// Count of entries by message type
    public let entriesByType: [String: Int]

    /// Count of entries by version
    public let entriesByVersion: [String: Int]

    /// Oldest entry timestamp, if any
    public let oldestEntry: Date?

    /// Newest entry timestamp, if any
    public let newestEntry: Date?

    /// Creates archive statistics
    public init(
        totalEntries: Int,
        entriesByType: [String: Int],
        entriesByVersion: [String: Int],
        oldestEntry: Date?,
        newestEntry: Date?
    ) {
        self.totalEntries = totalEntries
        self.entriesByType = entriesByType
        self.entriesByVersion = entriesByVersion
        self.oldestEntry = oldestEntry
        self.newestEntry = newestEntry
    }
}

// MARK: - Message Archive

/// Actor managing the archival and retrieval of HL7 messages
///
/// Provides thread-safe storage, retrieval, and querying of archived messages.
/// Uses an in-memory store by default; future versions may support persistent
/// storage via Core Data or CloudKit on Apple platforms.
public actor MessageArchive {
    private var entries: [String: ArchiveEntry] = [:]

    /// Creates a new empty message archive
    public init() {}

    /// Archives a message entry
    /// - Parameter entry: The entry to archive
    /// - Throws: `PersistenceError.duplicateEntry` if an entry with the same ID exists
    public func store(_ entry: ArchiveEntry) throws {
        guard entries[entry.id] == nil else {
            throw PersistenceError.duplicateEntry(entry.id)
        }
        entries[entry.id] = entry
    }

    /// Retrieves an entry by its identifier
    /// - Parameter id: The entry identifier
    /// - Returns: The matching archive entry
    /// - Throws: `PersistenceError.entryNotFound` if no entry matches
    public func retrieve(id: String) throws -> ArchiveEntry {
        guard let entry = entries[id] else {
            throw PersistenceError.entryNotFound(id)
        }
        return entry
    }

    /// Retrieves all entries matching the given message type
    /// - Parameter messageType: The message type to filter by
    /// - Returns: Array of matching entries
    public func retrieve(byType messageType: String) -> [ArchiveEntry] {
        entries.values.filter { $0.messageType == messageType }
    }

    /// Retrieves entries within a date range
    /// - Parameters:
    ///   - start: Start of the date range (inclusive)
    ///   - end: End of the date range (inclusive)
    /// - Returns: Array of matching entries sorted by timestamp
    public func retrieve(from start: Date, to end: Date) -> [ArchiveEntry] {
        entries.values
            .filter { $0.timestamp >= start && $0.timestamp <= end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Retrieves entries matching any of the given tags
    /// - Parameter tags: Tags to search for
    /// - Returns: Array of entries that contain at least one of the specified tags
    public func retrieve(withTags tags: Set<String>) -> [ArchiveEntry] {
        entries.values.filter { !$0.tags.isDisjoint(with: tags) }
    }

    /// Retrieves all stored entries
    /// - Returns: Array of all archive entries
    public func allEntries() -> [ArchiveEntry] {
        Array(entries.values)
    }

    /// Deletes an entry by its identifier
    /// - Parameter id: The entry identifier
    /// - Throws: `PersistenceError.entryNotFound` if no entry matches
    @discardableResult
    public func delete(id: String) throws -> ArchiveEntry {
        guard let entry = entries.removeValue(forKey: id) else {
            throw PersistenceError.entryNotFound(id)
        }
        return entry
    }

    /// Deletes all entries matching the given message type
    /// - Parameter messageType: The message type to delete
    /// - Returns: Number of entries deleted
    @discardableResult
    public func delete(byType messageType: String) -> Int {
        let ids = entries.values.filter { $0.messageType == messageType }.map(\.id)
        for id in ids {
            entries.removeValue(forKey: id)
        }
        return ids.count
    }

    /// Removes all entries from the archive
    /// - Returns: Number of entries removed
    @discardableResult
    public func clear() -> Int {
        let count = entries.count
        entries.removeAll()
        return count
    }

    /// Returns the number of entries in the archive
    public func count() -> Int {
        entries.count
    }

    /// Returns statistics about the archive contents
    public func statistics() -> ArchiveStatistics {
        let allEntries = Array(entries.values)
        var byType: [String: Int] = [:]
        var byVersion: [String: Int] = [:]

        for entry in allEntries {
            byType[entry.messageType, default: 0] += 1
            byVersion[entry.version, default: 0] += 1
        }

        let timestamps = allEntries.map(\.timestamp)
        return ArchiveStatistics(
            totalEntries: allEntries.count,
            entriesByType: byType,
            entriesByVersion: byVersion,
            oldestEntry: timestamps.min(),
            newestEntry: timestamps.max()
        )
    }
}

// MARK: - Persistence Store Protocol

/// Protocol defining a generic key-value persistence store
///
/// Provides async CRUD operations for `Codable` values keyed by strings.
/// The default implementation is `InMemoryStore`. Future implementations may
/// use Core Data, CloudKit, or other platform-specific backends.
public protocol PersistenceStore: Sendable {
    /// Saves a value for the given key
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The storage key
    func save<T: Codable & Sendable>(_ value: T, forKey key: String) async throws

    /// Loads a value for the given key
    /// - Parameters:
    ///   - type: The expected type
    ///   - key: The storage key
    /// - Returns: The stored value, or nil if not found
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T?

    /// Deletes the value for the given key
    /// - Parameter key: The storage key
    /// - Returns: True if a value was deleted
    @discardableResult
    func delete(forKey key: String) async throws -> Bool

    /// Returns all keys currently in the store
    func allKeys() async -> [String]

    /// Removes all values from the store
    func clear() async
}

// MARK: - In-Memory Store

/// Thread-safe in-memory key-value store
///
/// Stores `Codable` values serialized as JSON `Data`. Suitable for all platforms
/// including Linux. Data is not persisted across process restarts.
public actor InMemoryStore: PersistenceStore {
    private var storage: [String: Data] = [:]

    /// Creates a new empty in-memory store
    public init() {}

    public func save<T: Codable & Sendable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        storage[key] = data
    }

    public func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = storage[key] else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    @discardableResult
    public func delete(forKey key: String) -> Bool {
        storage.removeValue(forKey: key) != nil
    }

    public func allKeys() -> [String] {
        Array(storage.keys)
    }

    public func clear() {
        storage.removeAll()
    }

    /// Returns the number of entries in the store
    public func count() -> Int {
        storage.count
    }
}

// MARK: - Export / Import

/// Container for exported archive data
public struct ExportedArchive: Sendable, Codable {
    /// Export format version
    public let formatVersion: String

    /// Timestamp of the export
    public let exportedAt: Date

    /// Number of entries in the export
    public let entryCount: Int

    /// The archived entries
    public let entries: [ArchiveEntry]

    /// Creates an exported archive container
    public init(entries: [ArchiveEntry], exportedAt: Date = Date()) {
        self.formatVersion = "1.0"
        self.exportedAt = exportedAt
        self.entryCount = entries.count
        self.entries = entries
    }
}

/// Result of a batch import operation
public struct ImportResult: Sendable, Equatable {
    /// Number of entries successfully imported
    public let imported: Int

    /// Number of entries skipped (e.g., duplicates)
    public let skipped: Int

    /// Errors encountered during import
    public let errors: [String]

    /// Creates an import result
    public init(imported: Int, skipped: Int, errors: [String] = []) {
        self.imported = imported
        self.skipped = skipped
        self.errors = errors
    }
}

/// Exports archived messages to JSON data
public struct DataExporter: Sendable {
    /// Creates a new data exporter
    public init() {}

    /// Exports all entries from the archive to JSON data
    /// - Parameter archive: The message archive to export from
    /// - Returns: JSON-encoded data representing the archive
    public func exportJSON(from archive: MessageArchive) async throws -> Data {
        let entries = await archive.allEntries()
        let exported = ExportedArchive(entries: entries)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exported)
    }

    /// Exports archive statistics to JSON data
    /// - Parameter archive: The message archive
    /// - Returns: JSON-encoded statistics
    public func exportStatistics(from archive: MessageArchive) async throws -> Data {
        let stats = await archive.statistics()
        let dict: [String: String] = [
            "totalEntries": "\(stats.totalEntries)",
            "oldestEntry": stats.oldestEntry.map { ISO8601DateFormatter().string(from: $0) } ?? "none",
            "newestEntry": stats.newestEntry.map { ISO8601DateFormatter().string(from: $0) } ?? "none",
        ]
        return try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        )
    }
}

/// Imports archived messages from JSON data
public struct DataImporter: Sendable {
    /// Creates a new data importer
    public init() {}

    /// Imports entries from JSON data into the archive
    /// - Parameters:
    ///   - data: JSON-encoded archive data
    ///   - archive: The destination archive
    /// - Returns: Result describing the import outcome
    public func importJSON(_ data: Data, into archive: MessageArchive) async throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exported: ExportedArchive
        do {
            exported = try decoder.decode(ExportedArchive.self, from: data)
        } catch {
            throw PersistenceError.invalidData("Failed to decode archive data: \(error.localizedDescription)")
        }

        return await importEntries(exported.entries, into: archive)
    }

    /// Imports an array of entries into the archive, skipping duplicates
    /// - Parameters:
    ///   - entries: The entries to import
    ///   - archive: The destination archive
    /// - Returns: Result describing the import outcome
    public func importEntries(_ entries: [ArchiveEntry], into archive: MessageArchive) async -> ImportResult {
        var imported = 0
        var skipped = 0
        var errors: [String] = []

        for entry in entries {
            do {
                try await archive.store(entry)
                imported += 1
            } catch let error as PersistenceError {
                if case .duplicateEntry = error {
                    skipped += 1
                } else {
                    errors.append("Entry \(entry.id): \(error)")
                }
            } catch {
                errors.append("Entry \(entry.id): \(error)")
            }
        }

        return ImportResult(imported: imported, skipped: skipped, errors: errors)
    }
}

// MARK: - Search and Indexing

/// A search result with relevance scoring
public struct SearchResult: Sendable, Equatable {
    /// The matching archive entry
    public let entry: ArchiveEntry

    /// Relevance score (higher is more relevant)
    public let score: Double

    /// Creates a search result
    public init(entry: ArchiveEntry, score: Double) {
        self.entry = entry
        self.score = score
    }
}

/// Actor providing full-text search and field-based indexing of archived messages
///
/// Maintains inverted indexes for fast lookups by message type, source, tags,
/// and content terms. Supports relevance-scored search results.
public actor ArchiveIndex {
    private var entries: [String: ArchiveEntry] = [:]
    private var typeIndex: [String: Set<String>] = [:]
    private var sourceIndex: [String: Set<String>] = [:]
    private var tagIndex: [String: Set<String>] = [:]
    private var contentIndex: [String: Set<String>] = [:]
    private var fieldIndex: [String: Set<String>] = [:]

    /// Creates a new empty message index
    public init() {}

    /// Adds an entry to the index
    /// - Parameter entry: The archive entry to index
    public func addEntry(_ entry: ArchiveEntry) {
        entries[entry.id] = entry
        typeIndex[entry.messageType, default: []].insert(entry.id)
        if !entry.source.isEmpty {
            sourceIndex[entry.source, default: []].insert(entry.id)
        }
        for tag in entry.tags {
            tagIndex[tag, default: []].insert(entry.id)
        }
        let terms = tokenize(entry.content)
        for term in terms {
            contentIndex[term, default: []].insert(entry.id)
        }
    }

    /// Removes an entry from the index
    /// - Parameter id: The entry identifier to remove
    /// - Returns: True if the entry was found and removed
    @discardableResult
    public func removeEntry(id: String) -> Bool {
        guard let entry = entries.removeValue(forKey: id) else { return false }
        typeIndex[entry.messageType]?.remove(id)
        sourceIndex[entry.source]?.remove(id)
        for tag in entry.tags {
            tagIndex[tag]?.remove(id)
        }
        let terms = tokenize(entry.content)
        for term in terms {
            contentIndex[term]?.remove(id)
        }
        cleanupEmptyIndexEntries()
        return true
    }

    /// Performs a full-text search across message content
    /// - Parameter query: The search query string
    /// - Returns: Matching results sorted by relevance score (descending)
    public func search(query: String) -> [SearchResult] {
        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty else { return [] }

        var scores: [String: Double] = [:]
        let totalDocs = Double(max(entries.count, 1))

        for term in queryTerms {
            guard let matchingIds = contentIndex[term] else { continue }
            // TF-IDF inspired scoring
            let idf = log(totalDocs / Double(max(matchingIds.count, 1))) + 1.0
            for id in matchingIds {
                scores[id, default: 0] += idf
            }
        }

        return scores.compactMap { id, score in
            guard let entry = entries[id] else { return nil }
            return SearchResult(entry: entry, score: score)
        }.sorted { $0.score > $1.score }
    }

    /// Searches entries by message type
    /// - Parameter messageType: The type to search for
    /// - Returns: Matching results
    public func search(byType messageType: String) -> [SearchResult] {
        let ids = typeIndex[messageType] ?? []
        return ids.compactMap { id in
            guard let entry = entries[id] else { return nil }
            return SearchResult(entry: entry, score: 1.0)
        }
    }

    /// Searches entries by source
    /// - Parameter source: The source to search for
    /// - Returns: Matching results
    public func search(bySource source: String) -> [SearchResult] {
        let ids = sourceIndex[source] ?? []
        return ids.compactMap { id in
            guard let entry = entries[id] else { return nil }
            return SearchResult(entry: entry, score: 1.0)
        }
    }

    /// Searches entries by tag
    /// - Parameter tag: The tag to search for
    /// - Returns: Matching results
    public func search(byTag tag: String) -> [SearchResult] {
        let ids = tagIndex[tag] ?? []
        return ids.compactMap { id in
            guard let entry = entries[id] else { return nil }
            return SearchResult(entry: entry, score: 1.0)
        }
    }

    /// Indexes a custom field value for an entry
    /// - Parameters:
    ///   - field: The field name (e.g., "patientId", "orderId")
    ///   - value: The field value
    ///   - entryId: The archive entry identifier
    public func indexField(_ field: String, value: String, forEntry entryId: String) {
        let key = "\(field):\(value)"
        fieldIndex[key, default: []].insert(entryId)
    }

    /// Searches entries by a custom indexed field
    /// - Parameters:
    ///   - field: The field name
    ///   - value: The field value
    /// - Returns: Matching results
    public func search(byField field: String, value: String) -> [SearchResult] {
        let key = "\(field):\(value)"
        let ids = fieldIndex[key] ?? []
        return ids.compactMap { id in
            guard let entry = entries[id] else { return nil }
            return SearchResult(entry: entry, score: 1.0)
        }
    }

    /// Rebuilds all indexes from the currently stored entries
    public func rebuild() {
        typeIndex.removeAll()
        sourceIndex.removeAll()
        tagIndex.removeAll()
        contentIndex.removeAll()
        fieldIndex.removeAll()

        let current = entries
        for entry in current.values {
            typeIndex[entry.messageType, default: []].insert(entry.id)
            if !entry.source.isEmpty {
                sourceIndex[entry.source, default: []].insert(entry.id)
            }
            for tag in entry.tags {
                tagIndex[tag, default: []].insert(entry.id)
            }
            let terms = tokenize(entry.content)
            for term in terms {
                contentIndex[term, default: []].insert(entry.id)
            }
        }
    }

    /// Returns the number of indexed entries
    public func count() -> Int {
        entries.count
    }

    /// Removes all entries and indexes
    public func clear() {
        entries.removeAll()
        typeIndex.removeAll()
        sourceIndex.removeAll()
        tagIndex.removeAll()
        contentIndex.removeAll()
        fieldIndex.removeAll()
    }

    // MARK: - Private Helpers

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count >= 2 }
    }

    private func cleanupEmptyIndexEntries() {
        typeIndex = typeIndex.filter { !$0.value.isEmpty }
        sourceIndex = sourceIndex.filter { !$0.value.isEmpty }
        tagIndex = tagIndex.filter { !$0.value.isEmpty }
        contentIndex = contentIndex.filter { !$0.value.isEmpty }
        fieldIndex = fieldIndex.filter { !$0.value.isEmpty }
    }
}
