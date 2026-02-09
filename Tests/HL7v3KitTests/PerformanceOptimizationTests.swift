/// PerformanceOptimizationTests.swift
/// Tests for HL7 v3.x performance optimization utilities

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

final class PerformanceOptimizationTests: XCTestCase {

    // MARK: - XMLElementPool Tests

    func testXMLElementPoolAcquire() async {
        let pool = XMLElementPool(maxPoolSize: 10)
        let storage = await pool.acquire()
        XCTAssertEqual(storage.element.name, "")
        XCTAssertNil(storage.element.namespace)
        XCTAssertNil(storage.element.text)
        XCTAssertTrue(storage.element.children.isEmpty)
        XCTAssertTrue(storage.element.attributes.isEmpty)
    }

    func testXMLElementPoolReleaseAndReuse() async {
        let pool = XMLElementPool(maxPoolSize: 10)
        var storage = await pool.acquire()
        storage.element = XMLElement(name: "test", attributes: ["a": "1"], children: [], text: "hello")
        await pool.release(storage)

        // Next acquire should reuse the released storage (reset)
        let reused = await pool.acquire()
        XCTAssertEqual(reused.element.name, "")
        XCTAssertNil(reused.element.text)

        let stats = await pool.statistics()
        XCTAssertEqual(stats.acquireCount, 2)
        XCTAssertEqual(stats.reuseCount, 1)
        XCTAssertEqual(stats.allocationCount, 1)
        XCTAssertEqual(stats.releaseCount, 1)
    }

    func testXMLElementPoolMaxSize() async {
        let pool = XMLElementPool(maxPoolSize: 2)
        let s1 = await pool.acquire()
        let s2 = await pool.acquire()
        let s3 = await pool.acquire()

        await pool.release(s1)
        await pool.release(s2)
        await pool.release(s3) // This should be discarded (pool full)

        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 2) // Only 2 fit in pool
        XCTAssertEqual(stats.releaseCount, 3)
    }

    func testXMLElementPoolPreallocate() async {
        let pool = XMLElementPool(maxPoolSize: 10)
        await pool.preallocate(5)

        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 5)
    }

    func testXMLElementPoolPreallocateRespectsMaxSize() async {
        let pool = XMLElementPool(maxPoolSize: 3)
        await pool.preallocate(10) // Should only allocate 3

        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 3)
    }

    func testXMLElementPoolClear() async {
        let pool = XMLElementPool(maxPoolSize: 10)
        await pool.preallocate(5)
        _ = await pool.acquire()
        await pool.clear()

        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 0)
        XCTAssertEqual(stats.acquireCount, 0)
        XCTAssertEqual(stats.reuseCount, 0)
    }

    func testXMLElementPoolReuseRate() async {
        let pool = XMLElementPool(maxPoolSize: 10)

        // First acquire - allocation
        let s1 = await pool.acquire()
        await pool.release(s1)

        // Second acquire - reuse
        let s2 = await pool.acquire()
        await pool.release(s2)

        // Third acquire - reuse
        _ = await pool.acquire()

        let stats = await pool.statistics()
        XCTAssertEqual(stats.allocationCount, 1)
        XCTAssertEqual(stats.reuseCount, 2)
        XCTAssertEqual(stats.reuseRate, 2.0 / 3.0, accuracy: 0.001)
    }

    func testElementStorageReset() {
        var storage = XMLElementPool.ElementStorage(
            element: XMLElement(
                name: "test",
                namespace: "urn:test",
                prefix: "t",
                attributes: ["key": "value"],
                children: [XMLElement(name: "child")],
                text: "some text"
            )
        )

        storage.reset()

        XCTAssertEqual(storage.element.name, "")
        XCTAssertNil(storage.element.namespace)
        XCTAssertNil(storage.element.prefix)
        XCTAssertTrue(storage.element.attributes.isEmpty)
        XCTAssertTrue(storage.element.children.isEmpty)
        XCTAssertNil(storage.element.text)
    }

    // MARK: - PoolStatistics Tests

    func testPoolStatisticsReuseRate() {
        let stats = PoolStatistics(
            availableCount: 5,
            acquireCount: 100,
            reuseCount: 75,
            allocationCount: 25,
            releaseCount: 80
        )

        XCTAssertEqual(stats.reuseRate, 0.75, accuracy: 0.001)
    }

    func testPoolStatisticsZeroReuseRate() {
        let stats = PoolStatistics(
            availableCount: 0,
            acquireCount: 0,
            reuseCount: 0,
            allocationCount: 0,
            releaseCount: 0
        )

        XCTAssertEqual(stats.reuseRate, 0.0)
    }

    func testPoolStatisticsEquality() {
        let stats1 = PoolStatistics(
            availableCount: 1,
            acquireCount: 2,
            reuseCount: 3,
            allocationCount: 4,
            releaseCount: 5
        )
        let stats2 = PoolStatistics(
            availableCount: 1,
            acquireCount: 2,
            reuseCount: 3,
            allocationCount: 4,
            releaseCount: 5
        )

        XCTAssertEqual(stats1, stats2)
    }

    // MARK: - InternedElementName Tests

    func testInternedElementNameKnownNames() {
        XCTAssertEqual(InternedElementName.intern("ClinicalDocument"), "ClinicalDocument")
        XCTAssertEqual(InternedElementName.intern("section"), "section")
        XCTAssertEqual(InternedElementName.intern("entry"), "entry")
        XCTAssertEqual(InternedElementName.intern("observation"), "observation")
        XCTAssertEqual(InternedElementName.intern("recordTarget"), "recordTarget")
        XCTAssertEqual(InternedElementName.intern("component"), "component")
        XCTAssertEqual(InternedElementName.intern("templateId"), "templateId")
    }

    func testInternedElementNameUnknownNames() {
        let custom = "myCustomElement"
        XCTAssertEqual(InternedElementName.intern(custom), custom)
    }

    func testInternedElementNameReturnsSameInstance() {
        // Known names should return the static constant
        let result1 = InternedElementName.intern("ClinicalDocument")
        let result2 = InternedElementName.intern("ClinicalDocument")
        XCTAssertEqual(result1, result2)
    }

    func testInternedElementNameConstants() {
        XCTAssertEqual(InternedElementName.clinicalDocument, "ClinicalDocument")
        XCTAssertEqual(InternedElementName.typeId, "typeId")
        XCTAssertEqual(InternedElementName.effectiveTime, "effectiveTime")
        XCTAssertEqual(InternedElementName.structuredBody, "structuredBody")
        XCTAssertEqual(InternedElementName.substanceAdministration, "substanceAdministration")
        XCTAssertEqual(InternedElementName.table, "table")
        XCTAssertEqual(InternedElementName.paragraph, "paragraph")
    }

    func testInternedElementNameHeaderParticipants() {
        XCTAssertEqual(InternedElementName.intern("patientRole"), "patientRole")
        XCTAssertEqual(InternedElementName.intern("assignedAuthor"), "assignedAuthor")
        XCTAssertEqual(InternedElementName.intern("custodian"), "custodian")
        XCTAssertEqual(InternedElementName.intern("legalAuthenticator"), "legalAuthenticator")
    }

    func testInternedElementNameDataTypeParts() {
        XCTAssertEqual(InternedElementName.intern("low"), "low")
        XCTAssertEqual(InternedElementName.intern("high"), "high")
        XCTAssertEqual(InternedElementName.intern("given"), "given")
        XCTAssertEqual(InternedElementName.intern("family"), "family")
    }

    func testInternedElementNameNarrativeElements() {
        XCTAssertEqual(InternedElementName.intern("paragraph"), "paragraph")
        XCTAssertEqual(InternedElementName.intern("content"), "content")
        XCTAssertEqual(InternedElementName.intern("list"), "list")
        XCTAssertEqual(InternedElementName.intern("item"), "item")
        XCTAssertEqual(InternedElementName.intern("thead"), "thead")
        XCTAssertEqual(InternedElementName.intern("tbody"), "tbody")
        XCTAssertEqual(InternedElementName.intern("tr"), "tr")
        XCTAssertEqual(InternedElementName.intern("td"), "td")
    }

    // MARK: - V3StringInterner Tests

    func testV3StringInternerBasic() async {
        let interner = V3StringInterner()
        let result1 = await interner.intern("test")
        let result2 = await interner.intern("test")
        XCTAssertEqual(result1, "test")
        XCTAssertEqual(result2, "test")

        let stats = await interner.statistics()
        XCTAssertEqual(stats.internedCount, 1)
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
    }

    func testV3StringInternerMultipleStrings() async {
        let interner = V3StringInterner()
        _ = await interner.intern("alpha")
        _ = await interner.intern("beta")
        _ = await interner.intern("alpha")
        _ = await interner.intern("gamma")
        _ = await interner.intern("beta")

        let stats = await interner.statistics()
        XCTAssertEqual(stats.internedCount, 3)
        XCTAssertEqual(stats.hitCount, 2)
        XCTAssertEqual(stats.missCount, 3)
        XCTAssertEqual(stats.hitRate, 0.4, accuracy: 0.001)
    }

    func testV3StringInternerClear() async {
        let interner = V3StringInterner()
        _ = await interner.intern("test")
        await interner.clear()

        let stats = await interner.statistics()
        XCTAssertEqual(stats.internedCount, 0)
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
    }

    func testV3InternStatisticsHitRate() {
        let stats = V3InternStatistics(internedCount: 10, hitCount: 80, missCount: 20)
        XCTAssertEqual(stats.hitRate, 0.8, accuracy: 0.001)
    }

    func testV3InternStatisticsZeroHitRate() {
        let stats = V3InternStatistics(internedCount: 0, hitCount: 0, missCount: 0)
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    // MARK: - XPathQueryCache Tests

    func testXPathQueryCacheBasic() async {
        let cache = XPathQueryCache(maxEntries: 10)
        let element = XMLElement(name: "test", text: "hello")

        let result = await cache.query(expression: "//test") {
            [element]
        }

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "test")
    }

    func testXPathQueryCacheHit() async {
        let cache = XPathQueryCache(maxEntries: 10)
        let element = XMLElement(name: "test")

        _ = await cache.query(expression: "//test") { [element] }
        let result = await cache.query(expression: "//test") { [] } // Should use cache

        XCTAssertEqual(result.count, 1) // Cached result

        let stats = await cache.statistics()
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
    }

    func testXPathQueryCacheEviction() async {
        let cache = XPathQueryCache(maxEntries: 2)

        _ = await cache.query(expression: "//a") { [XMLElement(name: "a")] }
        _ = await cache.query(expression: "//b") { [XMLElement(name: "b")] }
        _ = await cache.query(expression: "//c") { [XMLElement(name: "c")] } // Should evict least used

        let stats = await cache.statistics()
        XCTAssertEqual(stats.entryCount, 2) // Only 2 entries kept
    }

    func testXPathQueryCacheInvalidate() async {
        let cache = XPathQueryCache(maxEntries: 10)
        _ = await cache.query(expression: "//test") { [XMLElement(name: "test")] }

        await cache.invalidate(expression: "//test")

        // Should miss now
        let result = await cache.query(expression: "//test") { [] }
        XCTAssertTrue(result.isEmpty)

        let stats = await cache.statistics()
        XCTAssertEqual(stats.missCount, 2)
    }

    func testXPathQueryCacheInvalidateAll() async {
        let cache = XPathQueryCache(maxEntries: 10)
        _ = await cache.query(expression: "//a") { [XMLElement(name: "a")] }
        _ = await cache.query(expression: "//b") { [XMLElement(name: "b")] }

        await cache.invalidate()

        let stats = await cache.statistics()
        XCTAssertEqual(stats.entryCount, 0)
    }

    func testXPathQueryCacheClear() async {
        let cache = XPathQueryCache(maxEntries: 10)
        _ = await cache.query(expression: "//a") { [XMLElement(name: "a")] }
        await cache.clear()

        let stats = await cache.statistics()
        XCTAssertEqual(stats.entryCount, 0)
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
    }

    func testQueryCacheStatisticsHitRate() {
        let stats = QueryCacheStatistics(entryCount: 5, hitCount: 90, missCount: 10, maxEntries: 100)
        XCTAssertEqual(stats.hitRate, 0.9, accuracy: 0.001)
    }

    func testQueryCacheStatisticsEquality() {
        let stats1 = QueryCacheStatistics(entryCount: 5, hitCount: 10, missCount: 5, maxEntries: 100)
        let stats2 = QueryCacheStatistics(entryCount: 5, hitCount: 10, missCount: 5, maxEntries: 100)
        XCTAssertEqual(stats1, stats2)
    }

    // MARK: - LazySectionContent Tests

    func testLazySectionContentEntries() {
        let sectionXML = XMLElement(
            name: "section",
            children: [
                XMLElement(name: "entry", children: [XMLElement(name: "observation")]),
                XMLElement(name: "entry", children: [XMLElement(name: "act")]),
                XMLElement(name: "text", text: "Narrative text"),
            ]
        )

        var lazy = LazySectionContent(rawXML: sectionXML)
        XCTAssertFalse(lazy.isEntriesParsed)

        let entries = lazy.entries
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(lazy.isEntriesParsed)
    }

    func testLazySectionContentNarrative() {
        let sectionXML = XMLElement(
            name: "section",
            children: [
                XMLElement(name: "text", text: "Patient presents with symptoms."),
            ]
        )

        var lazy = LazySectionContent(rawXML: sectionXML)
        XCTAssertFalse(lazy.isNarrativeParsed)

        let text = lazy.narrativeText
        XCTAssertEqual(text, "Patient presents with symptoms.")
        XCTAssertTrue(lazy.isNarrativeParsed)
    }

    func testLazySectionContentTitle() {
        let sectionXML = XMLElement(
            name: "section",
            children: [
                XMLElement(name: "title", text: "Vital Signs"),
            ]
        )

        let lazy = LazySectionContent(rawXML: sectionXML)
        XCTAssertEqual(lazy.title, "Vital Signs")
    }

    func testLazySectionContentCode() {
        let codeElement = XMLElement(
            name: "code",
            attributes: ["code": "8716-3", "codeSystem": "2.16.840.1.113883.6.1"]
        )
        let sectionXML = XMLElement(name: "section", children: [codeElement])

        let lazy = LazySectionContent(rawXML: sectionXML)
        let code = lazy.sectionCode
        XCTAssertNotNil(code)
        XCTAssertEqual(code?.attributes["code"], "8716-3")
    }

    func testLazySectionContentEntryCount() {
        let sectionXML = XMLElement(
            name: "section",
            children: [
                XMLElement(name: "entry"),
                XMLElement(name: "entry"),
                XMLElement(name: "entry"),
                XMLElement(name: "text"),
            ]
        )

        let lazy = LazySectionContent(rawXML: sectionXML)
        XCTAssertEqual(lazy.entryCount, 3)
        XCTAssertFalse(lazy.isEntriesParsed) // Count doesn't trigger full parse
    }

    func testLazySectionContentNoEntries() {
        let sectionXML = XMLElement(
            name: "section",
            children: [XMLElement(name: "text", text: "No entries")]
        )

        var lazy = LazySectionContent(rawXML: sectionXML)
        let entries = lazy.entries
        XCTAssertTrue(entries.isEmpty)
        XCTAssertTrue(lazy.isEntriesParsed)
    }

    func testLazySectionContentNoNarrative() {
        let sectionXML = XMLElement(
            name: "section",
            children: [XMLElement(name: "entry")]
        )

        var lazy = LazySectionContent(rawXML: sectionXML)
        XCTAssertNil(lazy.narrativeText)
        XCTAssertTrue(lazy.isNarrativeParsed)
    }

    // MARK: - Streaming Tests

    func testDataXMLStreamSourceReadNext() async throws {
        let xml = "<root><section>Hello</section></root>"
        let data = xml.data(using: .utf8)!
        let source = DataXMLStreamSource(data: data)

        var allData = Data()
        while let chunk = try await source.readNext(maxBytes: 10) {
            allData.append(chunk)
        }

        XCTAssertEqual(String(data: allData, encoding: .utf8), xml)
    }

    func testDataXMLStreamSourceExhaustion() async throws {
        let data = "small".data(using: .utf8)!
        let source = DataXMLStreamSource(data: data)

        _ = try await source.readNext(maxBytes: 100) // Read all
        let result = try await source.readNext(maxBytes: 100)
        XCTAssertNil(result)
    }

    func testXMLElementStreamBasic() async {
        let xml = """
        <root>
            <section><title>Section 1</title></section>
            <section><title>Section 2</title></section>
        </root>
        """
        let data = xml.data(using: .utf8)!
        let source = DataXMLStreamSource(data: data)
        let stream = XMLElementStream(source: source, targetElement: "section", bufferSize: 1024)

        var elements: [XMLElement] = []
        for await result in stream {
            if case .success(let element) = result {
                elements.append(element)
            }
        }

        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0].name, "section")
        XCTAssertEqual(elements[1].name, "section")
    }

    func testXMLElementStreamNoMatches() async {
        let xml = "<root><other>No sections</other></root>"
        let data = xml.data(using: .utf8)!
        let source = DataXMLStreamSource(data: data)
        let stream = XMLElementStream(source: source, targetElement: "section", bufferSize: 1024)

        var count = 0
        for await _ in stream {
            count += 1
        }

        XCTAssertEqual(count, 0)
    }

    func testXMLStreamReaderStreamSectionsFromData() async {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <component>
                <structuredBody>
                    <component><section><title>Vitals</title></section></component>
                    <component><section><title>Meds</title></section></component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """
        let data = xml.data(using: .utf8)!
        let reader = XMLStreamReader()
        let stream = reader.streamSections(from: data, bufferSize: 1024)

        var sections: [XMLElement] = []
        for await result in stream {
            if case .success(let element) = result {
                sections.append(element)
            }
        }

        XCTAssertEqual(sections.count, 2)
    }

    func testXMLStreamReaderCountElements() {
        let xml = """
        <root>
            <entry>1</entry>
            <entry>2</entry>
            <entry>3</entry>
        </root>
        """
        let data = xml.data(using: .utf8)!
        let reader = XMLStreamReader()

        let count = reader.countElements(named: "entry", in: data)
        XCTAssertEqual(count, 3)
    }

    func testXMLStreamReaderCountElementsNoMatch() {
        let xml = "<root><other>test</other></root>"
        let data = xml.data(using: .utf8)!
        let reader = XMLStreamReader()

        let count = reader.countElements(named: "entry", in: data)
        XCTAssertEqual(count, 0)
    }

    func testXMLStreamReaderCountElementsInvalidData() {
        let reader = XMLStreamReader()
        // Invalid UTF-8 data
        let data = Data([0xFF, 0xFE])
        let count = reader.countElements(named: "entry", in: data)
        XCTAssertEqual(count, 0)
    }

    // MARK: - V3PerformanceMetrics Tests

    func testPerformanceMetricsInitial() {
        let metrics = V3PerformanceMetrics()
        XCTAssertEqual(metrics.documentSizeBytes, 0)
        XCTAssertEqual(metrics.elementCount, 0)
        XCTAssertEqual(metrics.attributeCount, 0)
        XCTAssertEqual(metrics.maxDepth, 0)
        XCTAssertNil(metrics.duration)
        XCTAssertNil(metrics.bytesPerSecond)
        XCTAssertNil(metrics.elementsPerSecond)
    }

    func testPerformanceMetricsTiming() {
        var metrics = V3PerformanceMetrics()
        metrics.startTiming()
        // Simulate work
        Thread.sleep(forTimeInterval: 0.01)
        metrics.stopTiming()

        XCTAssertNotNil(metrics.duration)
        XCTAssertGreaterThan(metrics.duration!, 0)
    }

    func testPerformanceMetricsThroughput() {
        var metrics = V3PerformanceMetrics()
        metrics.startTiming()
        Thread.sleep(forTimeInterval: 0.01)
        metrics.stopTiming()

        metrics.recordDocumentSize(10_000)
        metrics.recordElementCount(500)

        XCTAssertNotNil(metrics.bytesPerSecond)
        XCTAssertNotNil(metrics.elementsPerSecond)
        XCTAssertGreaterThan(metrics.bytesPerSecond!, 0)
        XCTAssertGreaterThan(metrics.elementsPerSecond!, 0)
    }

    func testPerformanceMetricsRecording() {
        var metrics = V3PerformanceMetrics()
        metrics.recordDocumentSize(5000)
        metrics.recordElementCount(100)
        metrics.recordAttributeCount(50)
        metrics.recordMaxDepth(8)
        metrics.recordUniqueElementNames(15)

        XCTAssertEqual(metrics.documentSizeBytes, 5000)
        XCTAssertEqual(metrics.elementCount, 100)
        XCTAssertEqual(metrics.attributeCount, 50)
        XCTAssertEqual(metrics.maxDepth, 8)
        XCTAssertEqual(metrics.uniqueElementNames, 15)
    }

    func testPerformanceMetricsSummary() {
        var metrics = V3PerformanceMetrics()
        metrics.recordDocumentSize(5000)
        metrics.recordElementCount(100)

        let summary = metrics.summary
        XCTAssertTrue(summary.contains("5000 bytes"))
        XCTAssertTrue(summary.contains("Elements: 100"))
    }

    // MARK: - XMLDocumentAnalyzer Tests

    func testDocumentAnalyzerSimple() {
        let root = XMLElement(
            name: "root",
            attributes: ["id": "1"],
            children: [
                XMLElement(name: "child", attributes: ["type": "a"], text: "hello"),
                XMLElement(name: "child", attributes: ["type": "b"], text: "world"),
            ]
        )

        let stats = XMLDocumentAnalyzer.analyze(root)
        XCTAssertEqual(stats.totalElements, 3)
        XCTAssertEqual(stats.totalAttributes, 3)
        XCTAssertEqual(stats.maxDepth, 2)
        XCTAssertEqual(stats.uniqueElementNames, 2) // "root" and "child"
        XCTAssertEqual(stats.totalTextLength, 10) // "hello" + "world"
    }

    func testDocumentAnalyzerDeepNesting() {
        let level3 = XMLElement(name: "level3", text: "deep")
        let level2 = XMLElement(name: "level2", children: [level3])
        let level1 = XMLElement(name: "level1", children: [level2])
        let root = XMLElement(name: "root", children: [level1])

        let stats = XMLDocumentAnalyzer.analyze(root)
        XCTAssertEqual(stats.maxDepth, 4)
        XCTAssertEqual(stats.totalElements, 4)
        XCTAssertEqual(stats.uniqueElementNames, 4)
    }

    func testDocumentAnalyzerCDALikeStructure() {
        let observation = XMLElement(
            name: "observation",
            attributes: ["classCode": "OBS", "moodCode": "EVN"],
            children: [
                XMLElement(name: "code", attributes: ["code": "8480-6"]),
                XMLElement(name: "value", attributes: ["value": "120", "unit": "mmHg"]),
            ]
        )
        let entry = XMLElement(name: "entry", children: [observation])
        let section = XMLElement(
            name: "section",
            children: [
                XMLElement(name: "title", text: "Vital Signs"),
                XMLElement(name: "text", text: "BP: 120/80"),
                entry,
            ]
        )
        let root = XMLElement(name: "ClinicalDocument", children: [section])

        let stats = XMLDocumentAnalyzer.analyze(root)
        XCTAssertEqual(stats.totalElements, 8)
        XCTAssertGreaterThan(stats.totalAttributes, 0)
        XCTAssertEqual(stats.maxDepth, 5)
    }

    func testDocumentAnalyzerSingleElement() {
        let root = XMLElement(name: "root")
        let stats = XMLDocumentAnalyzer.analyze(root)
        XCTAssertEqual(stats.totalElements, 1)
        XCTAssertEqual(stats.totalAttributes, 0)
        XCTAssertEqual(stats.maxDepth, 1)
        XCTAssertEqual(stats.uniqueElementNames, 1)
        XCTAssertEqual(stats.totalTextLength, 0)
    }

    // MARK: - V3Pools Tests

    func testV3PoolsPreallocateAll() async {
        await V3Pools.clearAll()
        await V3Pools.preallocateAll(10)

        let (poolStats, _, _) = await V3Pools.allStatistics()
        XCTAssertEqual(poolStats.availableCount, 10)
    }

    func testV3PoolsClearAll() async {
        await V3Pools.preallocateAll(5)
        _ = await V3Pools.interner.intern("test")
        _ = await V3Pools.queryCache.query(expression: "//test") { [] }

        await V3Pools.clearAll()

        let (poolStats, internStats, cacheStats) = await V3Pools.allStatistics()
        XCTAssertEqual(poolStats.availableCount, 0)
        XCTAssertEqual(internStats.internedCount, 0)
        XCTAssertEqual(cacheStats.entryCount, 0)
    }

    func testV3PoolsStatisticsAggregation() async {
        await V3Pools.clearAll()

        _ = await V3Pools.elements.acquire()
        _ = await V3Pools.interner.intern("test1")
        _ = await V3Pools.interner.intern("test2")
        _ = await V3Pools.queryCache.query(expression: "//x") { [] }

        let (poolStats, internStats, cacheStats) = await V3Pools.allStatistics()
        XCTAssertEqual(poolStats.acquireCount, 1)
        XCTAssertEqual(internStats.internedCount, 2)
        XCTAssertEqual(cacheStats.entryCount, 1)
    }

    // MARK: - Integration Tests

    func testParseAndAnalyzeCDADocument() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4"/>
            <code code="11506-3" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Progress Note</title>
            <effectiveTime value="20240101"/>
            <recordTarget>
                <patientRole>
                    <id root="2.16.840.1.113883.19.5" extension="12345"/>
                </patientRole>
            </recordTarget>
            <component>
                <structuredBody>
                    <component>
                        <section>
                            <title>Vital Signs</title>
                            <entry>
                                <observation classCode="OBS" moodCode="EVN">
                                    <code code="8480-6"/>
                                    <value value="120" unit="mmHg"/>
                                </observation>
                            </entry>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """

        let data = xml.data(using: .utf8)!
        let parser = HL7v3XMLParser()

        var metrics = V3PerformanceMetrics()
        metrics.startTiming()
        let document = try parser.parse(data)
        metrics.stopTiming()
        metrics.recordDocumentSize(data.count)

        let root = document.root!
        let stats = XMLDocumentAnalyzer.analyze(root)
        metrics.recordElementCount(stats.totalElements)
        metrics.recordAttributeCount(stats.totalAttributes)
        metrics.recordMaxDepth(stats.maxDepth)
        metrics.recordUniqueElementNames(stats.uniqueElementNames)

        XCTAssertGreaterThan(stats.totalElements, 10)
        XCTAssertGreaterThan(stats.maxDepth, 3)
        XCTAssertNotNil(metrics.duration)
        XCTAssertGreaterThan(metrics.bytesPerSecond!, 0)
    }

    func testLazyLoadingWithParsedDocument() throws {
        let xml = """
        <section xmlns="urn:hl7-org:v3">
            <title>Medications</title>
            <code code="10160-0" codeSystem="2.16.840.1.113883.6.1"/>
            <text>Patient is on aspirin.</text>
            <entry>
                <substanceAdministration classCode="SBADM" moodCode="EVN">
                    <consumable>
                        <manufacturedProduct>
                            <manufacturedMaterial>
                                <code code="1191" codeSystem="2.16.840.1.113883.6.88" displayName="Aspirin"/>
                            </manufacturedMaterial>
                        </manufacturedProduct>
                    </consumable>
                </substanceAdministration>
            </entry>
        </section>
        """

        let data = xml.data(using: .utf8)!
        let parser = HL7v3XMLParser()
        let document = try parser.parse(data)

        guard let sectionElement = document.root else {
            XCTFail("No root element")
            return
        }

        var lazy = LazySectionContent(rawXML: sectionElement)

        // Title is always available (lightweight)
        XCTAssertEqual(lazy.title, "Medications")

        // Entry count without full parsing
        XCTAssertEqual(lazy.entryCount, 1)
        XCTAssertFalse(lazy.isEntriesParsed)

        // Full entry parsing only on access
        let entries = lazy.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(lazy.isEntriesParsed)

        // Narrative
        let text = lazy.narrativeText
        XCTAssertEqual(text, "Patient is on aspirin.")
    }

    func testInternedNamesUsedInParsing() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4"/>
        </ClinicalDocument>
        """

        let data = xml.data(using: .utf8)!
        let parser = HL7v3XMLParser()
        let document = try parser.parse(data)

        let root = document.root!
        XCTAssertEqual(root.name, InternedElementName.clinicalDocument)

        let typeIdElements = root.childElements(named: InternedElementName.typeId)
        XCTAssertEqual(typeIdElements.count, 1)

        let idElements = root.childElements(named: InternedElementName.id)
        XCTAssertEqual(idElements.count, 1)
    }

    func testXPathQueryCacheWithRealDocument() async throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4"/>
            <component>
                <structuredBody>
                    <component>
                        <section>
                            <entry><observation classCode="OBS"/></entry>
                            <entry><observation classCode="OBS"/></entry>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """

        let data = xml.data(using: .utf8)!
        let parser = HL7v3XMLParser()
        let document = try parser.parse(data)

        let cache = XPathQueryCache(maxEntries: 50)

        // First query - cache miss
        let result1 = await cache.query(expression: "//observation") {
            try! XMLPathQuery(expression: "//observation").evaluate(on: document)
        }

        // Second query - cache hit
        let result2 = await cache.query(expression: "//observation") {
            [] // Should not be called
        }

        XCTAssertEqual(result1.count, 2)
        XCTAssertEqual(result2.count, 2) // From cache

        let stats = await cache.statistics()
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.hitRate, 0.5, accuracy: 0.001)
    }

    // MARK: - Performance Measurement Tests

    func testXMLParsingPerformance() throws {
        // Create a moderately sized CDA document
        var sections = ""
        for i in 0..<20 {
            sections += """
            <component>
                <section>
                    <title>Section \(i)</title>
                    <entry>
                        <observation classCode="OBS" moodCode="EVN">
                            <code code="\(i)" codeSystem="2.16.840.1.113883.6.1"/>
                            <value value="\(i * 10)" unit="mmHg"/>
                        </observation>
                    </entry>
                </section>
            </component>
            """
        }

        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4"/>
            <component>
                <structuredBody>
                    \(sections)
                </structuredBody>
            </component>
        </ClinicalDocument>
        """

        let data = xml.data(using: .utf8)!
        let parser = HL7v3XMLParser()

        var metrics = V3PerformanceMetrics()
        metrics.startTiming()

        // Parse multiple times to measure consistency
        for _ in 0..<10 {
            _ = try parser.parse(data)
        }

        metrics.stopTiming()
        metrics.recordDocumentSize(data.count * 10)

        XCTAssertNotNil(metrics.duration)
        XCTAssertGreaterThan(metrics.bytesPerSecond!, 0)
    }
}
