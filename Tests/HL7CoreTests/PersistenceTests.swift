import XCTest
@testable import HL7Core

/// Tests for the Persistence layer
final class PersistenceTests: XCTestCase {

    // MARK: - ArchiveEntry Tests

    func testArchiveEntryCreation() {
        let date = Date()
        let entry = ArchiveEntry(
            id: "msg-001",
            messageType: "ADT",
            version: "2.5.1",
            timestamp: date,
            source: "HIS",
            tags: ["urgent", "admission"],
            content: "MSH|^~\\&|HIS|..."
        )
        XCTAssertEqual(entry.id, "msg-001")
        XCTAssertEqual(entry.messageType, "ADT")
        XCTAssertEqual(entry.version, "2.5.1")
        XCTAssertEqual(entry.timestamp, date)
        XCTAssertEqual(entry.source, "HIS")
        XCTAssertEqual(entry.tags, ["urgent", "admission"])
        XCTAssertEqual(entry.content, "MSH|^~\\&|HIS|...")
    }

    func testArchiveEntryDefaults() {
        let entry = ArchiveEntry(id: "e1", messageType: "ORM", version: "2.3", content: "data")
        XCTAssertEqual(entry.source, "")
        XCTAssertTrue(entry.tags.isEmpty)
    }

    func testArchiveEntryEquatable() {
        let date = Date()
        let e1 = ArchiveEntry(id: "a", messageType: "ADT", version: "2.5", timestamp: date, content: "c1")
        let e2 = ArchiveEntry(id: "a", messageType: "ADT", version: "2.5", timestamp: date, content: "c1")
        let e3 = ArchiveEntry(id: "b", messageType: "ADT", version: "2.5", timestamp: date, content: "c1")
        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }

    func testArchiveEntryCodable() throws {
        let entry = ArchiveEntry(
            id: "c1",
            messageType: "ORU",
            version: "2.5.1",
            source: "LAB",
            tags: ["lab"],
            content: "MSH|test"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ArchiveEntry.self, from: data)
        XCTAssertEqual(entry.id, decoded.id)
        XCTAssertEqual(entry.messageType, decoded.messageType)
        XCTAssertEqual(entry.version, decoded.version)
        XCTAssertEqual(entry.source, decoded.source)
        XCTAssertEqual(entry.tags, decoded.tags)
        XCTAssertEqual(entry.content, decoded.content)
    }

    func testArchiveEntryIdentifiable() {
        let entry = ArchiveEntry(id: "id-123", messageType: "ADT", version: "2.5", content: "x")
        XCTAssertEqual(entry.id, "id-123")
    }

    // MARK: - ArchiveStatistics Tests

    func testArchiveStatisticsCreation() {
        let stats = ArchiveStatistics(
            totalEntries: 5,
            entriesByType: ["ADT": 3, "ORM": 2],
            entriesByVersion: ["2.5": 5],
            oldestEntry: nil,
            newestEntry: nil
        )
        XCTAssertEqual(stats.totalEntries, 5)
        XCTAssertEqual(stats.entriesByType["ADT"], 3)
        XCTAssertNil(stats.oldestEntry)
    }

    // MARK: - MessageArchive Tests

    func testStoreAndRetrieve() async throws {
        let archive = MessageArchive()
        let entry = ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "data")
        try await archive.store(entry)

        let retrieved = try await archive.retrieve(id: "1")
        XCTAssertEqual(retrieved, entry)
    }

    func testStoreDoesNotAllowDuplicates() async throws {
        let archive = MessageArchive()
        let entry = ArchiveEntry(id: "dup", messageType: "ADT", version: "2.5", content: "x")
        try await archive.store(entry)

        do {
            try await archive.store(entry)
            XCTFail("Expected duplicate error")
        } catch let error as PersistenceError {
            XCTAssertEqual(error, PersistenceError.duplicateEntry("dup"))
        }
    }

    func testRetrieveNotFound() async {
        let archive = MessageArchive()
        do {
            _ = try await archive.retrieve(id: "missing")
            XCTFail("Expected not found error")
        } catch let error as PersistenceError {
            XCTAssertEqual(error, PersistenceError.entryNotFound("missing"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRetrieveByType() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        try await archive.store(ArchiveEntry(id: "2", messageType: "ORM", version: "2.5", content: "b"))
        try await archive.store(ArchiveEntry(id: "3", messageType: "ADT", version: "2.5", content: "c"))

        let results = await archive.retrieve(byType: "ADT")
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.messageType == "ADT" })
    }

    func testRetrieveByTypeNoMatch() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        let results = await archive.retrieve(byType: "ORM")
        XCTAssertTrue(results.isEmpty)
    }

    func testRetrieveByDateRange() async throws {
        let archive = MessageArchive()
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let threeHoursAgo = now.addingTimeInterval(-10800)

        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", timestamp: threeHoursAgo, content: "old"))
        try await archive.store(ArchiveEntry(id: "2", messageType: "ADT", version: "2.5", timestamp: twoHoursAgo, content: "mid"))
        try await archive.store(ArchiveEntry(id: "3", messageType: "ADT", version: "2.5", timestamp: oneHourAgo, content: "new"))

        let results = await archive.retrieve(from: threeHoursAgo, to: twoHoursAgo)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.id, "1")
        XCTAssertEqual(results.last?.id, "2")
    }

    func testRetrieveByDateRangeEmpty() async {
        let archive = MessageArchive()
        let now = Date()
        let results = await archive.retrieve(from: now, to: now.addingTimeInterval(100))
        XCTAssertTrue(results.isEmpty)
    }

    func testRetrieveByTags() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", tags: ["urgent"], content: "a"))
        try await archive.store(ArchiveEntry(id: "2", messageType: "ORM", version: "2.5", tags: ["routine"], content: "b"))
        try await archive.store(ArchiveEntry(id: "3", messageType: "ORU", version: "2.5", tags: ["urgent", "lab"], content: "c"))

        let results = await archive.retrieve(withTags: ["urgent"])
        XCTAssertEqual(results.count, 2)
    }

    func testRetrieveByTagsNoMatch() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", tags: ["routine"], content: "a"))
        let results = await archive.retrieve(withTags: ["urgent"])
        XCTAssertTrue(results.isEmpty)
    }

    func testAllEntries() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        try await archive.store(ArchiveEntry(id: "2", messageType: "ORM", version: "2.5", content: "b"))

        let all = await archive.allEntries()
        XCTAssertEqual(all.count, 2)
    }

    func testAllEntriesEmpty() async {
        let archive = MessageArchive()
        let all = await archive.allEntries()
        XCTAssertTrue(all.isEmpty)
    }

    func testDeleteById() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        let deleted = try await archive.delete(id: "1")
        XCTAssertEqual(deleted.id, "1")
        let _val1 = await archive.count()
        XCTAssertEqual(_val1, 0)
    }

    func testDeleteByIdNotFound() async {
        let archive = MessageArchive()
        do {
            _ = try await archive.delete(id: "missing")
            XCTFail("Expected not found error")
        } catch let error as PersistenceError {
            XCTAssertEqual(error, PersistenceError.entryNotFound("missing"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeleteByType() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        try await archive.store(ArchiveEntry(id: "2", messageType: "ADT", version: "2.5", content: "b"))
        try await archive.store(ArchiveEntry(id: "3", messageType: "ORM", version: "2.5", content: "c"))

        let count = await archive.delete(byType: "ADT")
        XCTAssertEqual(count, 2)
        let _val2 = await archive.count()
        XCTAssertEqual(_val2, 1)
    }

    func testDeleteByTypeNoMatch() async {
        let archive = MessageArchive()
        let count = await archive.delete(byType: "ADT")
        XCTAssertEqual(count, 0)
    }

    func testClear() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        try await archive.store(ArchiveEntry(id: "2", messageType: "ORM", version: "2.5", content: "b"))

        let count = await archive.clear()
        XCTAssertEqual(count, 2)
        let _val3 = await archive.count()
        XCTAssertEqual(_val3, 0)
    }

    func testClearEmpty() async {
        let archive = MessageArchive()
        let count = await archive.clear()
        XCTAssertEqual(count, 0)
    }

    func testCount() async throws {
        let archive = MessageArchive()
        let _val4 = await archive.count()
        XCTAssertEqual(_val4, 0)
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        let _val5 = await archive.count()
        XCTAssertEqual(_val5, 1)
    }

    func testStatistics() async throws {
        let archive = MessageArchive()
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", timestamp: date1, content: "a"))
        try await archive.store(ArchiveEntry(id: "2", messageType: "ADT", version: "2.5", timestamp: date2, content: "b"))
        try await archive.store(ArchiveEntry(id: "3", messageType: "ORM", version: "2.3", timestamp: date2, content: "c"))

        let stats = await archive.statistics()
        XCTAssertEqual(stats.totalEntries, 3)
        XCTAssertEqual(stats.entriesByType["ADT"], 2)
        XCTAssertEqual(stats.entriesByType["ORM"], 1)
        XCTAssertEqual(stats.entriesByVersion["2.5"], 2)
        XCTAssertEqual(stats.entriesByVersion["2.3"], 1)
        XCTAssertEqual(stats.oldestEntry, date1)
        XCTAssertEqual(stats.newestEntry, date2)
    }

    func testStatisticsEmpty() async {
        let archive = MessageArchive()
        let stats = await archive.statistics()
        XCTAssertEqual(stats.totalEntries, 0)
        XCTAssertTrue(stats.entriesByType.isEmpty)
        XCTAssertNil(stats.oldestEntry)
        XCTAssertNil(stats.newestEntry)
    }

    // MARK: - PersistenceError Tests

    func testPersistenceErrorEquatable() {
        XCTAssertEqual(
            PersistenceError.entryNotFound("a"),
            PersistenceError.entryNotFound("a")
        )
        XCTAssertNotEqual(
            PersistenceError.entryNotFound("a"),
            PersistenceError.duplicateEntry("a")
        )
        XCTAssertEqual(
            PersistenceError.invalidData("bad"),
            PersistenceError.invalidData("bad")
        )
        XCTAssertEqual(
            PersistenceError.storageError("err"),
            PersistenceError.storageError("err")
        )
    }

    // MARK: - InMemoryStore Tests

    func testInMemoryStoreSaveAndLoad() async throws {
        let store = InMemoryStore()
        try await store.save("hello", forKey: "greeting")
        let value = try await store.load(String.self, forKey: "greeting")
        XCTAssertEqual(value, "hello")
    }

    func testInMemoryStoreLoadMissing() async throws {
        let store = InMemoryStore()
        let value = try await store.load(String.self, forKey: "missing")
        XCTAssertNil(value)
    }

    func testInMemoryStoreOverwrite() async throws {
        let store = InMemoryStore()
        try await store.save(1, forKey: "num")
        try await store.save(2, forKey: "num")
        let value = try await store.load(Int.self, forKey: "num")
        XCTAssertEqual(value, 2)
    }

    func testInMemoryStoreDelete() async throws {
        let store = InMemoryStore()
        try await store.save("val", forKey: "key")
        let deleted = await store.delete(forKey: "key")
        XCTAssertTrue(deleted)
        let value = try await store.load(String.self, forKey: "key")
        XCTAssertNil(value)
    }

    func testInMemoryStoreDeleteMissing() async {
        let store = InMemoryStore()
        let deleted = await store.delete(forKey: "nope")
        XCTAssertFalse(deleted)
    }

    func testInMemoryStoreAllKeys() async throws {
        let store = InMemoryStore()
        try await store.save(1, forKey: "a")
        try await store.save(2, forKey: "b")
        let keys = await store.allKeys()
        XCTAssertEqual(Set(keys), ["a", "b"])
    }

    func testInMemoryStoreClear() async throws {
        let store = InMemoryStore()
        try await store.save(1, forKey: "a")
        try await store.save(2, forKey: "b")
        await store.clear()
        let _val6 = await store.count()
        XCTAssertEqual(_val6, 0)
    }

    func testInMemoryStoreCount() async throws {
        let store = InMemoryStore()
        let _val7 = await store.count()
        XCTAssertEqual(_val7, 0)
        try await store.save("x", forKey: "k")
        let _val8 = await store.count()
        XCTAssertEqual(_val8, 1)
    }

    func testInMemoryStoreCodableStruct() async throws {
        struct TestItem: Codable, Equatable, Sendable {
            let name: String
            let value: Int
        }
        let store = InMemoryStore()
        let item = TestItem(name: "test", value: 42)
        try await store.save(item, forKey: "item1")
        let loaded = try await store.load(TestItem.self, forKey: "item1")
        XCTAssertEqual(loaded, item)
    }

    func testInMemoryStoreArchiveEntry() async throws {
        let store = InMemoryStore()
        let entry = ArchiveEntry(id: "e1", messageType: "ADT", version: "2.5", content: "data")
        try await store.save(entry, forKey: entry.id)
        let loaded = try await store.load(ArchiveEntry.self, forKey: entry.id)
        XCTAssertEqual(loaded?.id, "e1")
    }

    // MARK: - DataExporter Tests

    func testExportJSON() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "msg1"))
        try await archive.store(ArchiveEntry(id: "2", messageType: "ORM", version: "2.3", content: "msg2"))

        let exporter = DataExporter()
        let data = try await exporter.exportJSON(from: archive)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(ExportedArchive.self, from: data)
        XCTAssertEqual(exported.formatVersion, "1.0")
        XCTAssertEqual(exported.entryCount, 2)
        XCTAssertEqual(exported.entries.count, 2)
    }

    func testExportJSONEmpty() async throws {
        let archive = MessageArchive()
        let exporter = DataExporter()
        let data = try await exporter.exportJSON(from: archive)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(ExportedArchive.self, from: data)
        XCTAssertEqual(exported.entryCount, 0)
        XCTAssertTrue(exported.entries.isEmpty)
    }

    func testExportStatistics() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "msg"))

        let exporter = DataExporter()
        let data = try await exporter.exportStatistics(from: archive)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(dict?["totalEntries"], "1")
        XCTAssertNotNil(dict?["oldestEntry"])
        XCTAssertNotNil(dict?["newestEntry"])
    }

    func testExportStatisticsEmpty() async throws {
        let archive = MessageArchive()
        let exporter = DataExporter()
        let data = try await exporter.exportStatistics(from: archive)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(dict?["totalEntries"], "0")
        XCTAssertEqual(dict?["oldestEntry"], "none")
    }

    // MARK: - DataImporter Tests

    func testImportJSON() async throws {
        let archive = MessageArchive()
        let entry = ArchiveEntry(id: "imp1", messageType: "ADT", version: "2.5", content: "imported")
        let exported = ExportedArchive(entries: [entry])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exported)

        let importer = DataImporter()
        let result = try await importer.importJSON(data, into: archive)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertTrue(result.errors.isEmpty)

        let retrieved = try await archive.retrieve(id: "imp1")
        XCTAssertEqual(retrieved.content, "imported")
    }

    func testImportJSONInvalidData() async {
        let archive = MessageArchive()
        let importer = DataImporter()
        let badData = Data("not json".utf8)

        do {
            _ = try await importer.importJSON(badData, into: archive)
            XCTFail("Expected invalid data error")
        } catch let error as PersistenceError {
            if case .invalidData(let msg) = error {
                XCTAssertTrue(msg.contains("Failed to decode"))
            } else {
                XCTFail("Wrong error case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testImportDuplicatesSkipped() async throws {
        let archive = MessageArchive()
        let entry = ArchiveEntry(id: "d1", messageType: "ADT", version: "2.5", content: "x")
        try await archive.store(entry)

        let importer = DataImporter()
        let result = await importer.importEntries([entry], into: archive)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 1)
    }

    func testImportBatch() async throws {
        let archive = MessageArchive()
        let entries = (0..<5).map {
            ArchiveEntry(id: "batch-\($0)", messageType: "ADT", version: "2.5", content: "msg \($0)")
        }

        let importer = DataImporter()
        let result = await importer.importEntries(entries, into: archive)
        XCTAssertEqual(result.imported, 5)
        XCTAssertEqual(result.skipped, 0)
        let _val9 = await archive.count()
        XCTAssertEqual(_val9, 5)
    }

    func testImportBatchWithDuplicates() async throws {
        let archive = MessageArchive()
        try await archive.store(ArchiveEntry(id: "batch-0", messageType: "ADT", version: "2.5", content: "existing"))

        let entries = (0..<3).map {
            ArchiveEntry(id: "batch-\($0)", messageType: "ADT", version: "2.5", content: "new \($0)")
        }

        let importer = DataImporter()
        let result = await importer.importEntries(entries, into: archive)
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 1)
    }

    // MARK: - Export/Import Round-Trip Tests

    func testExportImportRoundTrip() async throws {
        let sourceArchive = MessageArchive()
        try await sourceArchive.store(ArchiveEntry(
            id: "rt-1", messageType: "ADT", version: "2.5",
            source: "HIS", tags: ["urgent"], content: "MSH|data1"
        ))
        try await sourceArchive.store(ArchiveEntry(
            id: "rt-2", messageType: "ORM", version: "2.3",
            source: "LIS", tags: ["routine", "lab"], content: "MSH|data2"
        ))

        let exporter = DataExporter()
        let jsonData = try await exporter.exportJSON(from: sourceArchive)

        let targetArchive = MessageArchive()
        let importer = DataImporter()
        let result = try await importer.importJSON(jsonData, into: targetArchive)
        XCTAssertEqual(result.imported, 2)

        let e1 = try await targetArchive.retrieve(id: "rt-1")
        XCTAssertEqual(e1.messageType, "ADT")
        XCTAssertEqual(e1.source, "HIS")
        XCTAssertEqual(e1.tags, ["urgent"])
        XCTAssertEqual(e1.content, "MSH|data1")

        let e2 = try await targetArchive.retrieve(id: "rt-2")
        XCTAssertEqual(e2.messageType, "ORM")
        XCTAssertEqual(e2.tags, ["routine", "lab"])
    }

    // MARK: - ExportedArchive Tests

    func testExportedArchiveCreation() {
        let entries = [
            ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"),
        ]
        let exported = ExportedArchive(entries: entries)
        XCTAssertEqual(exported.formatVersion, "1.0")
        XCTAssertEqual(exported.entryCount, 1)
        XCTAssertEqual(exported.entries.count, 1)
    }

    func testExportedArchiveEmpty() {
        let exported = ExportedArchive(entries: [])
        XCTAssertEqual(exported.entryCount, 0)
        XCTAssertTrue(exported.entries.isEmpty)
    }

    // MARK: - ImportResult Tests

    func testImportResultCreation() {
        let result = ImportResult(imported: 3, skipped: 1, errors: ["err1"])
        XCTAssertEqual(result.imported, 3)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.errors, ["err1"])
    }

    func testImportResultDefaults() {
        let result = ImportResult(imported: 0, skipped: 0)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testImportResultEquatable() {
        let r1 = ImportResult(imported: 1, skipped: 0)
        let r2 = ImportResult(imported: 1, skipped: 0)
        let r3 = ImportResult(imported: 2, skipped: 0)
        XCTAssertEqual(r1, r2)
        XCTAssertNotEqual(r1, r3)
    }

    // MARK: - ArchiveIndex Tests

    func testIndexAddAndSearch() async {
        let index = ArchiveIndex()
        let entry = ArchiveEntry(
            id: "idx-1", messageType: "ADT", version: "2.5",
            source: "HIS", tags: ["urgent"],
            content: "Patient John Smith admitted to cardiology"
        )
        await index.addEntry(entry)
        let _val10 = await index.count()
        XCTAssertEqual(_val10, 1)

        let results = await index.search(query: "patient john")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.entry.id, "idx-1")
        XCTAssertTrue(results.first!.score > 0)
    }

    func testIndexSearchEmptyQuery() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "data"))
        let results = await index.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexSearchNoMatch() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "hello world"))
        let results = await index.search(query: "zzzznotfound")
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexSearchByType() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        await index.addEntry(ArchiveEntry(id: "2", messageType: "ORM", version: "2.5", content: "b"))
        await index.addEntry(ArchiveEntry(id: "3", messageType: "ADT", version: "2.5", content: "c"))

        let results = await index.search(byType: "ADT")
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.entry.messageType == "ADT" })
    }

    func testIndexSearchByTypeNoMatch() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "a"))
        let results = await index.search(byType: "ORM")
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexSearchBySource() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", source: "HIS", content: "a"))
        await index.addEntry(ArchiveEntry(id: "2", messageType: "ADT", version: "2.5", source: "LIS", content: "b"))

        let results = await index.search(bySource: "HIS")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.entry.id, "1")
    }

    func testIndexSearchBySourceNoMatch() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", source: "HIS", content: "a"))
        let results = await index.search(bySource: "UNKNOWN")
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexSearchByTag() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", tags: ["urgent", "admission"], content: "a"))
        await index.addEntry(ArchiveEntry(id: "2", messageType: "ORM", version: "2.5", tags: ["routine"], content: "b"))

        let results = await index.search(byTag: "urgent")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.entry.id, "1")
    }

    func testIndexSearchByTagNoMatch() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", tags: ["routine"], content: "a"))
        let results = await index.search(byTag: "urgent")
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexCustomField() async {
        let index = ArchiveIndex()
        let entry = ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "data")
        await index.addEntry(entry)
        await index.indexField("patientId", value: "P-12345", forEntry: "1")

        let results = await index.search(byField: "patientId", value: "P-12345")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.entry.id, "1")
    }

    func testIndexCustomFieldNoMatch() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "data"))
        await index.indexField("patientId", value: "P-12345", forEntry: "1")

        let results = await index.search(byField: "patientId", value: "P-99999")
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexRemoveEntry() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", source: "HIS", tags: ["urgent"], content: "patient data"))
        let _val11 = await index.count()
        XCTAssertEqual(_val11, 1)

        let removed = await index.removeEntry(id: "1")
        XCTAssertTrue(removed)
        let _val12 = await index.count()
        XCTAssertEqual(_val12, 0)

        let byType = await index.search(byType: "ADT")
        XCTAssertTrue(byType.isEmpty)
        let bySource = await index.search(bySource: "HIS")
        XCTAssertTrue(bySource.isEmpty)
        let byTag = await index.search(byTag: "urgent")
        XCTAssertTrue(byTag.isEmpty)
        let byContent = await index.search(query: "patient")
        XCTAssertTrue(byContent.isEmpty)
    }

    func testIndexRemoveEntryNotFound() async {
        let index = ArchiveIndex()
        let removed = await index.removeEntry(id: "missing")
        XCTAssertFalse(removed)
    }

    func testIndexRebuild() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", source: "HIS", tags: ["urgent"], content: "patient john"))
        await index.addEntry(ArchiveEntry(id: "2", messageType: "ORM", version: "2.3", source: "LIS", tags: ["lab"], content: "order lab test"))

        await index.rebuild()

        let byType = await index.search(byType: "ADT")
        XCTAssertEqual(byType.count, 1)
        let bySource = await index.search(bySource: "LIS")
        XCTAssertEqual(bySource.count, 1)
        let byTag = await index.search(byTag: "urgent")
        XCTAssertEqual(byTag.count, 1)
        let byContent = await index.search(query: "patient")
        XCTAssertFalse(byContent.isEmpty)
    }

    func testIndexClear() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "data"))
        await index.addEntry(ArchiveEntry(id: "2", messageType: "ORM", version: "2.5", content: "data"))
        await index.clear()
        let _val13 = await index.count()
        XCTAssertEqual(_val13, 0)
    }

    func testIndexRelevanceScoring() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(
            id: "1", messageType: "ADT", version: "2.5",
            content: "patient patient patient lab result"
        ))
        await index.addEntry(ArchiveEntry(
            id: "2", messageType: "ORU", version: "2.5",
            content: "patient lab lab lab lab"
        ))

        let results = await index.search(query: "patient")
        XCTAssertFalse(results.isEmpty)
        // Both should match since both contain "patient"
        XCTAssertEqual(results.count, 2)
    }

    func testIndexEmptySource() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", source: "", content: "data"))
        let results = await index.search(bySource: "")
        // Empty source should not be indexed
        XCTAssertTrue(results.isEmpty)
    }

    func testIndexMultipleFieldValues() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(id: "1", messageType: "ADT", version: "2.5", content: "data"))
        await index.addEntry(ArchiveEntry(id: "2", messageType: "ORM", version: "2.5", content: "data"))
        await index.indexField("department", value: "cardiology", forEntry: "1")
        await index.indexField("department", value: "cardiology", forEntry: "2")
        await index.indexField("department", value: "radiology", forEntry: "2")

        let cardioResults = await index.search(byField: "department", value: "cardiology")
        XCTAssertEqual(cardioResults.count, 2)

        let radioResults = await index.search(byField: "department", value: "radiology")
        XCTAssertEqual(radioResults.count, 1)
    }

    // MARK: - SearchResult Tests

    func testSearchResultCreation() {
        let entry = ArchiveEntry(id: "s1", messageType: "ADT", version: "2.5", content: "data")
        let result = SearchResult(entry: entry, score: 0.95)
        XCTAssertEqual(result.entry.id, "s1")
        XCTAssertEqual(result.score, 0.95, accuracy: 0.001)
    }

    func testSearchResultEquatable() {
        let entry = ArchiveEntry(id: "s1", messageType: "ADT", version: "2.5", content: "data")
        let r1 = SearchResult(entry: entry, score: 1.0)
        let r2 = SearchResult(entry: entry, score: 1.0)
        let r3 = SearchResult(entry: entry, score: 0.5)
        XCTAssertEqual(r1, r2)
        XCTAssertNotEqual(r1, r3)
    }

    // MARK: - Integration Tests

    func testArchiveAndIndex() async throws {
        let archive = MessageArchive()
        let index = ArchiveIndex()

        let entries = [
            ArchiveEntry(id: "int-1", messageType: "ADT", version: "2.5", source: "HIS", tags: ["admission"], content: "Patient John Smith admitted"),
            ArchiveEntry(id: "int-2", messageType: "ORM", version: "2.5", source: "CPOE", tags: ["order"], content: "Lab order for CBC"),
            ArchiveEntry(id: "int-3", messageType: "ORU", version: "2.5", source: "LIS", tags: ["result"], content: "Lab result CBC normal"),
        ]

        for entry in entries {
            try await archive.store(entry)
            await index.addEntry(entry)
        }

        let _val14 = await archive.count()
        XCTAssertEqual(_val14, 3)
        let _val15 = await index.count()
        XCTAssertEqual(_val15, 3)

        let labResults = await index.search(query: "lab")
        XCTAssertEqual(labResults.count, 2)

        let adtResults = await index.search(byType: "ADT")
        XCTAssertEqual(adtResults.count, 1)
    }

    func testFullWorkflow() async throws {
        // Archive messages
        let archive = MessageArchive()
        for i in 0..<10 {
            let entry = ArchiveEntry(
                id: "wf-\(i)",
                messageType: i % 2 == 0 ? "ADT" : "ORM",
                version: "2.5",
                source: "SYS-\(i % 3)",
                tags: i < 5 ? ["batch1"] : ["batch2"],
                content: "Message content number \(i)"
            )
            try await archive.store(entry)
        }
        let _val16 = await archive.count()
        XCTAssertEqual(_val16, 10)

        // Export
        let exporter = DataExporter()
        let jsonData = try await exporter.exportJSON(from: archive)

        // Import into new archive
        let newArchive = MessageArchive()
        let importer = DataImporter()
        let result = try await importer.importJSON(jsonData, into: newArchive)
        XCTAssertEqual(result.imported, 10)

        // Verify stats match
        let origStats = await archive.statistics()
        let newStats = await newArchive.statistics()
        XCTAssertEqual(origStats.totalEntries, newStats.totalEntries)
        XCTAssertEqual(origStats.entriesByType, newStats.entriesByType)

        // Query the new archive
        let adtEntries = await newArchive.retrieve(byType: "ADT")
        XCTAssertEqual(adtEntries.count, 5)

        let batch1 = await newArchive.retrieve(withTags: ["batch1"])
        XCTAssertEqual(batch1.count, 5)

        // Delete and verify
        let deletedCount = await newArchive.delete(byType: "ADT")
        XCTAssertEqual(deletedCount, 5)
        let _val17 = await newArchive.count()
        XCTAssertEqual(_val17, 5)
    }

    // MARK: - PersistenceStore Protocol Conformance Tests

    func testInMemoryStoreConformsToPersistenceStore() async throws {
        let store: any PersistenceStore = InMemoryStore()
        try await store.save(42, forKey: "answer")
        let value = try await store.load(Int.self, forKey: "answer")
        XCTAssertEqual(value, 42)

        let deleted = try await store.delete(forKey: "answer")
        XCTAssertTrue(deleted)

        let keys = await store.allKeys()
        XCTAssertTrue(keys.isEmpty)

        await store.clear()
    }

    // MARK: - Edge Case Tests

    func testStoreEmptyContent() async throws {
        let archive = MessageArchive()
        let entry = ArchiveEntry(id: "empty", messageType: "ADT", version: "2.5", content: "")
        try await archive.store(entry)
        let retrieved = try await archive.retrieve(id: "empty")
        XCTAssertEqual(retrieved.content, "")
    }

    func testUnicodeContent() async throws {
        let archive = MessageArchive()
        let content = "患者 José García 入院 🏥"
        let entry = ArchiveEntry(id: "unicode", messageType: "ADT", version: "2.5", content: content)
        try await archive.store(entry)
        let retrieved = try await archive.retrieve(id: "unicode")
        XCTAssertEqual(retrieved.content, content)
    }

    func testLargeTagSet() async throws {
        let archive = MessageArchive()
        let tags = Set((0..<100).map { "tag-\($0)" })
        let entry = ArchiveEntry(id: "tagged", messageType: "ADT", version: "2.5", tags: tags, content: "data")
        try await archive.store(entry)

        let results = await archive.retrieve(withTags: ["tag-50"])
        XCTAssertEqual(results.count, 1)
    }

    func testIndexTokenizesCorrectly() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(
            id: "tok-1", messageType: "ADT", version: "2.5",
            content: "Hello, World! This is a test-message with numbers123."
        ))

        // "a" is single char, should be excluded from tokens
        let singleChar = await index.search(query: "a")
        XCTAssertTrue(singleChar.isEmpty)

        // Multi-char terms should work
        let hello = await index.search(query: "hello")
        XCTAssertFalse(hello.isEmpty)

        let world = await index.search(query: "world")
        XCTAssertFalse(world.isEmpty)
    }

    func testSearchSortedByRelevance() async {
        let index = ArchiveIndex()
        await index.addEntry(ArchiveEntry(
            id: "rel-1", messageType: "ADT", version: "2.5",
            content: "patient admitted to hospital ward cardiology department"
        ))
        await index.addEntry(ArchiveEntry(
            id: "rel-2", messageType: "ADT", version: "2.5",
            content: "patient transferred from hospital ward to ICU patient critical"
        ))

        let results = await index.search(query: "patient hospital ward")
        XCTAssertFalse(results.isEmpty)
        // Results should be sorted by descending score
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(results[i].score, results[i + 1].score)
        }
    }
}
