import XCTest
@testable import HL7Core

/// Tests for Common Services infrastructure
final class CommonServicesTests: XCTestCase {

    // MARK: - CorrelationID Tests

    func testCorrelationIDCreation() {
        let id = CorrelationID("test-123")
        XCTAssertEqual(id.value, "test-123")
        XCTAssertEqual(id.description, "test-123")
    }

    func testCorrelationIDGenerate() {
        let id1 = CorrelationID.generate()
        let id2 = CorrelationID.generate()
        XCTAssertNotEqual(id1, id2)
        XCTAssertFalse(id1.value.isEmpty)
    }

    func testCorrelationIDHashable() {
        let id1 = CorrelationID("abc")
        let id2 = CorrelationID("abc")
        let id3 = CorrelationID("def")
        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)

        var set = Set<CorrelationID>()
        set.insert(id1)
        set.insert(id2)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - LogMetadata Tests

    func testLogMetadataCreation() {
        let metadata = LogMetadata(
            values: ["key": "value"],
            correlationID: CorrelationID("corr-1"),
            module: "HL7v2Kit"
        )
        XCTAssertEqual(metadata.values["key"], "value")
        XCTAssertEqual(metadata.correlationID?.value, "corr-1")
        XCTAssertEqual(metadata.module, "HL7v2Kit")
    }

    func testLogMetadataDefaults() {
        let metadata = LogMetadata()
        XCTAssertTrue(metadata.values.isEmpty)
        XCTAssertNil(metadata.correlationID)
        XCTAssertNil(metadata.module)
    }

    // MARK: - UnifiedLogEntry Tests

    func testUnifiedLogEntryCreation() {
        let entry = UnifiedLogEntry(
            subsystem: "HL7kit",
            category: "parsing",
            level: .info,
            message: "Test message"
        )
        XCTAssertEqual(entry.subsystem, "HL7kit")
        XCTAssertEqual(entry.category, "parsing")
        XCTAssertEqual(entry.level, .info)
        XCTAssertEqual(entry.message, "Test message")
    }

    // MARK: - UnifiedLogger Tests

    func testUnifiedLoggerBasicLogging() async {
        let logger = UnifiedLogger()
        await logger.log(.info, "Hello world", subsystem: "test", category: "unit")

        let count = await logger.logCount()
        XCTAssertEqual(count, 1)

        let logs = await logger.exportLogs()
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].message, "Hello world")
        XCTAssertEqual(logs[0].subsystem, "test")
        XCTAssertEqual(logs[0].category, "unit")
    }

    func testUnifiedLoggerLevelFiltering() async {
        let logger = UnifiedLogger(logLevel: .warning)
        await logger.log(.debug, "Debug message")
        await logger.log(.info, "Info message")
        await logger.log(.warning, "Warning message")
        await logger.log(.error, "Error message")

        let count = await logger.logCount()
        XCTAssertEqual(count, 2)
    }

    func testUnifiedLoggerSetLogLevel() async {
        let logger = UnifiedLogger(logLevel: .error)
        await logger.log(.info, "Should be filtered")
        let count1 = await logger.logCount()
        XCTAssertEqual(count1, 0)

        await logger.setLogLevel(.info)
        await logger.log(.info, "Should be logged")
        let count2 = await logger.logCount()
        XCTAssertEqual(count2, 1)
    }

    func testUnifiedLoggerBufferLimit() async {
        let logger = UnifiedLogger(maxBufferSize: 5, logLevel: .debug)
        for i in 0..<10 {
            await logger.log(.info, "Message \(i)")
        }
        let count = await logger.logCount()
        XCTAssertEqual(count, 5)

        let logs = await logger.exportLogs()
        XCTAssertEqual(logs[0].message, "Message 5")
        XCTAssertEqual(logs[4].message, "Message 9")
    }

    func testUnifiedLoggerExportFiltered() async {
        let logger = UnifiedLogger(logLevel: .debug)
        let corrID = CorrelationID("trace-1")

        await logger.log(.info, "A", subsystem: "HL7v2Kit", category: "parsing",
                         metadata: LogMetadata(correlationID: corrID))
        await logger.log(.debug, "B", subsystem: "FHIRkit", category: "parsing")
        await logger.log(.error, "C", subsystem: "HL7v2Kit", category: "validation")

        let v2Logs = await logger.exportLogs(subsystem: "HL7v2Kit")
        XCTAssertEqual(v2Logs.count, 2)

        let parsingLogs = await logger.exportLogs(category: "parsing")
        XCTAssertEqual(parsingLogs.count, 2)

        let errorLogs = await logger.exportLogs(level: .error)
        XCTAssertEqual(errorLogs.count, 1)

        let corrLogs = await logger.exportLogs(correlationID: corrID)
        XCTAssertEqual(corrLogs.count, 1)
        XCTAssertEqual(corrLogs[0].message, "A")
    }

    func testUnifiedLoggerClearLogs() async {
        let logger = UnifiedLogger()
        await logger.log(.info, "Test")
        let count1 = await logger.logCount()
        XCTAssertEqual(count1, 1)

        await logger.clearLogs()
        let count2 = await logger.logCount()
        XCTAssertEqual(count2, 0)
    }

    func testUnifiedLoggerCorrelationAcrossModules() async {
        let logger = UnifiedLogger(logLevel: .debug)
        let corrID = CorrelationID.generate()

        await logger.log(.info, "Received message", subsystem: "HL7v2Kit", category: "inbound",
                         metadata: LogMetadata(correlationID: corrID, module: "HL7v2Kit"))
        await logger.log(.info, "Transforming", subsystem: "HL7v3Kit", category: "transform",
                         metadata: LogMetadata(correlationID: corrID, module: "HL7v3Kit"))
        await logger.log(.info, "Converted to FHIR", subsystem: "FHIRkit", category: "convert",
                         metadata: LogMetadata(correlationID: corrID, module: "FHIRkit"))

        let tracedLogs = await logger.exportLogs(correlationID: corrID)
        XCTAssertEqual(tracedLogs.count, 3)
    }

    // MARK: - SecurityService Tests

    func testSanitizePHI_SSN() async {
        let security = SecurityService()
        let result = await security.sanitizePHI("Patient SSN: 123-45-6789")
        XCTAssertTrue(result.contains("***-**-****"))
        XCTAssertFalse(result.contains("123-45-6789"))
    }

    func testSanitizePHI_Email() async {
        let security = SecurityService()
        let result = await security.sanitizePHI("Contact: john@example.com")
        XCTAssertTrue(result.contains("****@****"))
        XCTAssertFalse(result.contains("john@example.com"))
    }

    func testSanitizePHI_NoMatch() async {
        let security = SecurityService()
        let result = await security.sanitizePHI("Hello world")
        XCTAssertEqual(result, "Hello world")
    }

    func testMaskValue() async {
        let security = SecurityService()
        let r1 = await security.maskValue("1234567890", visibleCount: 4)
        XCTAssertEqual(r1, "******7890")
        let r2 = await security.maskValue("AB", visibleCount: 4)
        XCTAssertEqual(r2, "AB")
        let r3 = await security.maskValue("", visibleCount: 4)
        XCTAssertEqual(r3, "")
        let r4 = await security.maskValue("ABCDE", visibleCount: 0)
        XCTAssertEqual(r4, "*****")
    }

    func testValidateInput() async {
        let security = SecurityService()

        let valid = await security.validateInput("Hello", minLength: 1, maxLength: 100)
        XCTAssertTrue(valid.isValid)
        XCTAssertTrue(valid.errors.isEmpty)

        let tooShort = await security.validateInput("", minLength: 1, maxLength: 100)
        XCTAssertFalse(tooShort.isValid)
        XCTAssertEqual(tooShort.errors.count, 1)

        let tooLong = await security.validateInput("ABCDEF", minLength: 1, maxLength: 3)
        XCTAssertFalse(tooLong.isValid)
    }

    func testValidateSafeCharacters() async {
        let security = SecurityService()

        let valid = await security.validateSafeCharacters("Hello, World! 123")
        XCTAssertTrue(valid.isValid)

        let invalid = await security.validateSafeCharacters("Hello\u{0000}World")
        XCTAssertFalse(invalid.isValid)
    }

    func testGenerateSecureRandomBytes() async {
        let security = SecurityService()
        let bytes = await security.generateSecureRandomBytes(32)
        XCTAssertEqual(bytes.count, 32)

        let bytes2 = await security.generateSecureRandomBytes(32)
        XCTAssertNotEqual(bytes, bytes2)
    }

    func testGenerateSecureRandomHex() async {
        let security = SecurityService()
        let hex = await security.generateSecureRandomHex(16)
        XCTAssertEqual(hex.count, 32)

        let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(hex.unicodeScalars.allSatisfy { hexChars.contains($0) })
    }

    func testSHA256String() async {
        let security = SecurityService()
        let hash = await security.sha256("hello")
        XCTAssertEqual(hash, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testSHA256Data() async {
        let security = SecurityService()
        let data = Data("hello".utf8)
        let hash = await security.sha256(data)
        XCTAssertEqual(hash, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testSHA256Empty() async {
        let security = SecurityService()
        let hash = await security.sha256("")
        XCTAssertEqual(hash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testSHA256Consistency() async {
        let security = SecurityService()
        let hash1 = await security.sha256("test data")
        let hash2 = await security.sha256("test data")
        XCTAssertEqual(hash1, hash2)
    }

    func testSHA256DifferentInputs() async {
        let security = SecurityService()
        let hash1 = await security.sha256("abc")
        let hash2 = await security.sha256("abd")
        XCTAssertNotEqual(hash1, hash2)
    }

    // MARK: - SharedCache Tests

    func testCacheSetAndGet() async {
        let cache = SharedCache<String, Int>(maxSize: 10)
        await cache.set("a", value: 1)
        let val = await cache.get("a")
        XCTAssertEqual(val, 1)
    }

    func testCacheMiss() async {
        let cache = SharedCache<String, Int>(maxSize: 10)
        let val = await cache.get("nonexistent")
        XCTAssertNil(val)
    }

    func testCacheOverwrite() async {
        let cache = SharedCache<String, Int>(maxSize: 10)
        await cache.set("key", value: 1)
        await cache.set("key", value: 2)
        let val = await cache.get("key")
        XCTAssertEqual(val, 2)
        let count = await cache.count()
        XCTAssertEqual(count, 1)
    }

    func testCacheLRUEviction() async {
        let cache = SharedCache<String, Int>(maxSize: 3)
        await cache.set("a", value: 1)
        await cache.set("b", value: 2)
        await cache.set("c", value: 3)
        _ = await cache.get("a")
        await cache.set("d", value: 4)

        let a = await cache.get("a")
        let b = await cache.get("b")
        let c = await cache.get("c")
        let d = await cache.get("d")
        XCTAssertNotNil(a)
        XCTAssertNil(b)
        XCTAssertNotNil(c)
        XCTAssertNotNil(d)
    }

    func testCacheTTLExpiration() async throws {
        let cache = SharedCache<String, Int>(maxSize: 10, defaultTTL: 0.1)
        await cache.set("key", value: 42)
        let val1 = await cache.get("key")
        XCTAssertEqual(val1, 42)

        try await Task.sleep(nanoseconds: 200_000_000)
        let val2 = await cache.get("key")
        XCTAssertNil(val2)
    }

    func testCacheCustomTTL() async throws {
        let cache = SharedCache<String, Int>(maxSize: 10)
        await cache.set("short", value: 1, ttl: 0.1)
        await cache.set("long", value: 2, ttl: 10.0)

        try await Task.sleep(nanoseconds: 200_000_000)

        let short = await cache.get("short")
        let long = await cache.get("long")
        XCTAssertNil(short)
        XCTAssertEqual(long, 2)
    }

    func testCacheRemove() async {
        let cache = SharedCache<String, Int>(maxSize: 10)
        await cache.set("key", value: 1)
        let removed = await cache.remove("key")
        XCTAssertEqual(removed, 1)
        let val = await cache.get("key")
        XCTAssertNil(val)
    }

    func testCacheRemoveNonexistent() async {
        let cache = SharedCache<String, Int>(maxSize: 10)
        let removed = await cache.remove("nope")
        XCTAssertNil(removed)
    }

    func testCacheClear() async {
        let cache = SharedCache<String, Int>(maxSize: 10)
        await cache.set("a", value: 1)
        await cache.set("b", value: 2)
        await cache.clear()
        let count = await cache.count()
        XCTAssertEqual(count, 0)
    }

    func testCacheContains() async {
        let cache = SharedCache<String, Int>(maxSize: 10)
        await cache.set("key", value: 1)
        let has = await cache.contains("key")
        XCTAssertTrue(has)
        let hasNot = await cache.contains("other")
        XCTAssertFalse(hasNot)
    }

    func testCacheContainsExpired() async throws {
        let cache = SharedCache<String, Int>(maxSize: 10, defaultTTL: 0.1)
        await cache.set("key", value: 1)
        try await Task.sleep(nanoseconds: 200_000_000)
        let has = await cache.contains("key")
        XCTAssertFalse(has)
    }

    func testCacheStatistics() async {
        let cache = SharedCache<String, Int>(maxSize: 3)
        await cache.set("a", value: 1)
        await cache.set("b", value: 2)
        _ = await cache.get("a")
        _ = await cache.get("b")
        _ = await cache.get("c")

        let stats = await cache.statistics()
        XCTAssertEqual(stats.hits, 2)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.count, 2)
        XCTAssertEqual(stats.hitRate, 200.0 / 3.0, accuracy: 0.01)
    }

    func testCacheEvictionStatistics() async {
        let cache = SharedCache<String, Int>(maxSize: 2)
        await cache.set("a", value: 1)
        await cache.set("b", value: 2)
        await cache.set("c", value: 3)

        let stats = await cache.statistics()
        XCTAssertEqual(stats.evictions, 1)
    }

    func testCacheRemoveExpired() async throws {
        let cache = SharedCache<String, Int>(maxSize: 10, defaultTTL: 0.1)
        await cache.set("a", value: 1)
        await cache.set("b", value: 2)

        try await Task.sleep(nanoseconds: 200_000_000)
        let removed = await cache.removeExpired()
        XCTAssertEqual(removed, 2)
        let count = await cache.count()
        XCTAssertEqual(count, 0)
    }

    func testCacheResetStatistics() async {
        let cache = SharedCache<String, Int>(maxSize: 10)
        await cache.set("a", value: 1)
        _ = await cache.get("a")
        _ = await cache.get("b")
        await cache.resetStatistics()

        let stats = await cache.statistics()
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 0)
        XCTAssertEqual(stats.evictions, 0)
    }

    func testCacheStatisticsHitRateZero() {
        let stats = CacheStatistics(hits: 0, misses: 0, evictions: 0, count: 0)
        XCTAssertEqual(stats.hitRate, 0)
    }

    func testCacheEmptyGet() async {
        let cache = SharedCache<Int, String>(maxSize: 5)
        let val = await cache.get(1)
        XCTAssertNil(val)
        let count = await cache.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - ConfigurationManager Tests

    func testConfigSetAndGet() async {
        let config = ConfigurationManager()
        await config.set("host", value: "localhost")
        let val = await config.get("host")
        XCTAssertEqual(val?.rawValue, "localhost")
        XCTAssertEqual(val?.source, "override")
    }

    func testConfigGetString() async {
        let config = ConfigurationManager()
        await config.set("name", value: "HL7kit")
        let name = await config.getString("name")
        XCTAssertEqual(name, "HL7kit")
        let missing = await config.getString("missing")
        XCTAssertNil(missing)
        let fallback = await config.getString("missing", default: "fallback")
        XCTAssertEqual(fallback, "fallback")
    }

    func testConfigGetInt() async {
        let config = ConfigurationManager()
        await config.set("port", value: "8080")
        let port = await config.getInt("port")
        XCTAssertEqual(port, 8080)
        let missing = await config.getInt("missing")
        XCTAssertNil(missing)
        let fallback = await config.getInt("missing", default: 3000)
        XCTAssertEqual(fallback, 3000)
    }

    func testConfigGetBool() async {
        let config = ConfigurationManager()
        await config.set("enabled", value: "true")
        await config.set("disabled", value: "false")
        await config.set("yes", value: "yes")
        await config.set("one", value: "1")
        await config.set("invalid", value: "maybe")

        let enabled = await config.getBool("enabled")
        XCTAssertEqual(enabled, true)
        let disabled = await config.getBool("disabled")
        XCTAssertEqual(disabled, false)
        let yes = await config.getBool("yes")
        XCTAssertEqual(yes, true)
        let one = await config.getBool("one")
        XCTAssertEqual(one, true)
        let invalid = await config.getBool("invalid")
        XCTAssertNil(invalid)
        let fallback = await config.getBool("missing", default: true)
        XCTAssertEqual(fallback, true)
    }

    func testConfigDefaults() async {
        let config = ConfigurationManager()
        await config.setDefault("port", value: "3000")
        let port = await config.getString("port")
        XCTAssertEqual(port, "3000")
        let portVal = await config.get("port")
        XCTAssertEqual(portVal?.source, "default")

        await config.set("port", value: "8080")
        let overridden = await config.getString("port")
        XCTAssertEqual(overridden, "8080")
    }

    func testConfigEnvironments() async {
        let config = ConfigurationManager(environment: .development)
        await config.set("url", value: "http://localhost")

        await config.setEnvironment(.production)
        await config.set("url", value: "https://prod.example.com")

        let prodUrl = await config.getString("url")
        XCTAssertEqual(prodUrl, "https://prod.example.com")

        await config.setEnvironment(.development)
        let devUrl = await config.getString("url")
        XCTAssertEqual(devUrl, "http://localhost")
    }

    func testConfigEnvironmentSpecific() async {
        let config = ConfigurationManager(environment: .development)
        await config.set("url", value: "http://staging", for: .staging)

        let devUrl = await config.getString("url")
        XCTAssertNil(devUrl)

        await config.setEnvironment(.staging)
        let stagingUrl = await config.getString("url")
        XCTAssertEqual(stagingUrl, "http://staging")
    }

    func testConfigGetEnvironment() async {
        let config = ConfigurationManager(environment: .staging)
        let env = await config.getEnvironment()
        XCTAssertEqual(env, .staging)
    }

    func testConfigRemove() async {
        let config = ConfigurationManager()
        await config.set("key", value: "value")
        await config.remove("key")
        let val = await config.get("key")
        XCTAssertNil(val)
    }

    func testConfigAllKeys() async {
        let config = ConfigurationManager()
        await config.setDefault("a", value: "1")
        await config.set("b", value: "2")
        let keys = await config.allKeys()
        XCTAssertTrue(keys.contains("a"))
        XCTAssertTrue(keys.contains("b"))
    }

    func testConfigValidation() async {
        let config = ConfigurationManager()
        await config.addRule(ConfigurationRule(
            key: "port",
            isRequired: true,
            description: "Port must be numeric"
        ) { value in Int(value) != nil })

        let result1 = await config.validate()
        XCTAssertFalse(result1.isValid)
        XCTAssertEqual(result1.errors.count, 1)

        await config.set("port", value: "8080")
        let result2 = await config.validate()
        XCTAssertTrue(result2.isValid)

        await config.set("port", value: "not-a-number")
        let result3 = await config.validate()
        XCTAssertFalse(result3.isValid)
    }

    func testConfigValidationNotRequired() async {
        let config = ConfigurationManager()
        await config.addRule(ConfigurationRule(
            key: "optional_key",
            isRequired: false,
            description: "Optional"
        ))
        let result = await config.validate()
        XCTAssertTrue(result.isValid)
    }

    func testConfigClear() async {
        let config = ConfigurationManager()
        await config.set("a", value: "1")
        await config.set("b", value: "2")
        await config.clear()
        let a = await config.get("a")
        let b = await config.get("b")
        XCTAssertNil(a)
        XCTAssertNil(b)
    }

    func testConfigClearAll() async {
        let config = ConfigurationManager()
        await config.set("a", value: "1")
        await config.setDefault("b", value: "2")
        await config.addRule(ConfigurationRule(key: "a", isRequired: true))
        await config.clearAll()
        let a = await config.get("a")
        let b = await config.get("b")
        XCTAssertNil(a)
        XCTAssertNil(b)
    }

    func testConfigurationValueTypes() {
        let intVal = ConfigurationValue(rawValue: "42")
        XCTAssertEqual(intVal.intValue, 42)
        XCTAssertEqual(intVal.doubleValue, 42.0)

        let boolTrue = ConfigurationValue(rawValue: "true")
        XCTAssertEqual(boolTrue.boolValue, true)

        let boolNo = ConfigurationValue(rawValue: "no")
        XCTAssertEqual(boolNo.boolValue, false)

        let boolZero = ConfigurationValue(rawValue: "0")
        XCTAssertEqual(boolZero.boolValue, false)

        let invalid = ConfigurationValue(rawValue: "abc")
        XCTAssertNil(invalid.intValue)
        XCTAssertNil(invalid.boolValue)
    }

    func testConfigurationValidationResultStatic() {
        let valid = ConfigurationValidationResult.valid
        XCTAssertTrue(valid.isValid)
        XCTAssertTrue(valid.errors.isEmpty)
    }

    func testDeploymentEnvironmentCases() {
        XCTAssertEqual(DeploymentEnvironment.allCases.count, 3)
        XCTAssertEqual(DeploymentEnvironment.development.rawValue, "development")
        XCTAssertEqual(DeploymentEnvironment.staging.rawValue, "staging")
        XCTAssertEqual(DeploymentEnvironment.production.rawValue, "production")
    }

    // MARK: - MetricsCollector Tests

    func testCounterIncrement() async {
        let metrics = MetricsCollector()
        await metrics.increment("requests")
        let val1 = await metrics.counterValue("requests")
        XCTAssertEqual(val1, 1)

        await metrics.increment("requests", by: 5)
        let val2 = await metrics.counterValue("requests")
        XCTAssertEqual(val2, 6)
    }

    func testCounterNonexistent() async {
        let metrics = MetricsCollector()
        let val = await metrics.counterValue("nope")
        XCTAssertNil(val)
    }

    func testGaugeSetAndGet() async {
        let metrics = MetricsCollector()
        await metrics.setGauge("temperature", value: 36.6)
        let val = await metrics.gaugeValue("temperature")
        XCTAssertEqual(val, 36.6)
    }

    func testGaugeAdjust() async {
        let metrics = MetricsCollector()
        await metrics.setGauge("connections", value: 10)
        await metrics.adjustGauge("connections", by: 5)
        let val1 = await metrics.gaugeValue("connections")
        XCTAssertEqual(val1, 15)

        await metrics.adjustGauge("connections", by: -3)
        let val2 = await metrics.gaugeValue("connections")
        XCTAssertEqual(val2, 12)
    }

    func testGaugeAdjustNonexistent() async {
        let metrics = MetricsCollector()
        await metrics.adjustGauge("new", by: 5)
        let val = await metrics.gaugeValue("new")
        XCTAssertEqual(val, 5)
    }

    func testGaugeNonexistent() async {
        let metrics = MetricsCollector()
        let val = await metrics.gaugeValue("nope")
        XCTAssertNil(val)
    }

    func testHistogramRecord() async {
        let metrics = MetricsCollector()
        await metrics.recordHistogram("latency", value: 0.1)
        await metrics.recordHistogram("latency", value: 0.2)
        await metrics.recordHistogram("latency", value: 0.3)

        let stats = await metrics.histogramStatistics("latency")
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.count, 3)
        XCTAssertEqual(stats!.min, 0.1, accuracy: 0.001)
        XCTAssertEqual(stats!.max, 0.3, accuracy: 0.001)
        XCTAssertEqual(stats!.mean, 0.2, accuracy: 0.001)
    }

    func testHistogramPercentiles() async {
        let metrics = MetricsCollector()
        for i in 1...100 {
            await metrics.recordHistogram("latency", value: Double(i))
        }

        let stats = await metrics.histogramStatistics("latency")
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats!.p50, 50, accuracy: 1)
        XCTAssertEqual(stats!.p95, 95, accuracy: 1)
        XCTAssertEqual(stats!.p99, 99, accuracy: 1)
    }

    func testHistogramNonexistent() async {
        let metrics = MetricsCollector()
        let stats = await metrics.histogramStatistics("nope")
        XCTAssertNil(stats)
    }

    func testRecordTiming() async {
        let metrics = MetricsCollector()
        await metrics.recordTiming("request_duration", duration: 0.5)
        let stats = await metrics.histogramStatistics("request_duration")
        XCTAssertEqual(stats?.count, 1)
        XCTAssertEqual(stats!.mean, 0.5, accuracy: 0.001)
    }

    func testMetricsSnapshot() async {
        let metrics = MetricsCollector()
        await metrics.increment("counter1", by: 10, labels: ["env": "prod"])
        await metrics.setGauge("gauge1", value: 42, labels: ["host": "a"])
        await metrics.recordHistogram("hist1", value: 1.0)
        await metrics.recordHistogram("hist1", value: 2.0)

        let snap = await metrics.snapshot()
        XCTAssertEqual(snap.metrics.count, 3)

        let counterSnap = snap.metrics.first { $0.name == "counter1" }
        XCTAssertNotNil(counterSnap)
        XCTAssertEqual(counterSnap?.type, .counter)
        XCTAssertEqual(counterSnap?.value, 10)
        XCTAssertEqual(counterSnap?.labels["env"], "prod")

        let gaugeSnap = snap.metrics.first { $0.name == "gauge1" }
        XCTAssertNotNil(gaugeSnap)
        XCTAssertEqual(gaugeSnap?.type, .gauge)
        XCTAssertEqual(gaugeSnap?.value, 42)

        let histSnap = snap.metrics.first { $0.name == "hist1" }
        XCTAssertNotNil(histSnap)
        XCTAssertEqual(histSnap?.type, .histogram)
        XCTAssertEqual(histSnap?.values.count, 2)
    }

    func testMetricsReset() async {
        let metrics = MetricsCollector()
        await metrics.increment("a")
        await metrics.setGauge("b", value: 1)
        await metrics.recordHistogram("c", value: 1)

        await metrics.reset()

        let a = await metrics.counterValue("a")
        let b = await metrics.gaugeValue("b")
        let c = await metrics.histogramStatistics("c")
        XCTAssertNil(a)
        XCTAssertNil(b)
        XCTAssertNil(c)
    }

    func testCounterWithLabels() async {
        let metrics = MetricsCollector()
        await metrics.increment("requests", by: 1, labels: ["method": "GET", "path": "/api"])
        let snap = await metrics.snapshot()
        let m = snap.metrics.first { $0.name == "requests" }
        XCTAssertEqual(m?.labels["method"], "GET")
    }

    // MARK: - AuditTrail Tests

    func testAuditRecordEvent() async {
        let audit = AuditTrail()
        let event = await audit.record(
            eventType: .create,
            principal: AuditPrincipal(identifier: "user1"),
            resource: "Patient/123",
            action: "Created patient record"
        )

        XCTAssertFalse(event.eventID.isEmpty)
        XCTAssertEqual(event.eventType, .create)
        XCTAssertEqual(event.principal.identifier, "user1")
        XCTAssertEqual(event.resource, "Patient/123")
        XCTAssertEqual(event.action, "Created patient record")
        XCTAssertFalse(event.eventHash.isEmpty)
        XCTAssertEqual(event.previousHash, "0")
    }

    func testAuditHashChain() async {
        let audit = AuditTrail()
        let event1 = await audit.record(
            eventType: .create,
            principal: .system(),
            resource: "R1",
            action: "Action 1"
        )
        let event2 = await audit.record(
            eventType: .modify,
            principal: .system(),
            resource: "R1",
            action: "Action 2"
        )

        XCTAssertEqual(event2.previousHash, event1.eventHash)
    }

    func testAuditVerifyIntegrity() async {
        let audit = AuditTrail()
        for i in 0..<5 {
            await audit.record(
                eventType: .access,
                principal: AuditPrincipal(identifier: "user\(i)"),
                resource: "Resource/\(i)",
                action: "Accessed resource \(i)"
            )
        }

        let isValid = await audit.verifyIntegrity()
        XCTAssertTrue(isValid)
    }

    func testAuditAllEvents() async {
        let audit = AuditTrail()
        await audit.record(eventType: .create, principal: .system(), resource: "R1", action: "A")
        await audit.record(eventType: .access, principal: .system(), resource: "R2", action: "B")

        let events = await audit.allEvents()
        XCTAssertEqual(events.count, 2)
    }

    func testAuditFilterByType() async {
        let audit = AuditTrail()
        await audit.record(eventType: .create, principal: .system(), resource: "R1", action: "A")
        await audit.record(eventType: .access, principal: .system(), resource: "R2", action: "B")
        await audit.record(eventType: .create, principal: .system(), resource: "R3", action: "C")

        let creates = await audit.events(ofType: .create)
        XCTAssertEqual(creates.count, 2)

        let accesses = await audit.events(ofType: .access)
        XCTAssertEqual(accesses.count, 1)
    }

    func testAuditFilterByPrincipal() async {
        let audit = AuditTrail()
        await audit.record(eventType: .access, principal: AuditPrincipal(identifier: "alice"),
                           resource: "R1", action: "A")
        await audit.record(eventType: .access, principal: AuditPrincipal(identifier: "bob"),
                           resource: "R2", action: "B")
        await audit.record(eventType: .modify, principal: AuditPrincipal(identifier: "alice"),
                           resource: "R3", action: "C")

        let aliceEvents = await audit.events(byPrincipal: "alice")
        XCTAssertEqual(aliceEvents.count, 2)
    }

    func testAuditFilterByResource() async {
        let audit = AuditTrail()
        await audit.record(eventType: .access, principal: .system(),
                           resource: "Patient/1", action: "A")
        await audit.record(eventType: .modify, principal: .system(),
                           resource: "Patient/1", action: "B")
        await audit.record(eventType: .access, principal: .system(),
                           resource: "Patient/2", action: "C")

        let patient1Events = await audit.events(forResource: "Patient/1")
        XCTAssertEqual(patient1Events.count, 2)
    }

    func testAuditCount() async {
        let audit = AuditTrail()
        let count0 = await audit.count()
        XCTAssertEqual(count0, 0)
        await audit.record(eventType: .create, principal: .system(), resource: "R", action: "A")
        let count1 = await audit.count()
        XCTAssertEqual(count1, 1)
    }

    func testAuditClear() async {
        let audit = AuditTrail()
        await audit.record(eventType: .create, principal: .system(), resource: "R", action: "A")
        await audit.clear()
        let count = await audit.count()
        XCTAssertEqual(count, 0)
    }

    func testAuditEventDetails() async {
        let audit = AuditTrail()
        let event = await audit.record(
            eventType: .export,
            principal: AuditPrincipal(identifier: "admin", type: "user", displayName: "Admin User"),
            resource: "Report/Q4",
            action: "Exported quarterly report",
            details: ["format": "PDF", "pages": "42"]
        )

        XCTAssertEqual(event.details["format"], "PDF")
        XCTAssertEqual(event.details["pages"], "42")
        XCTAssertEqual(event.principal.displayName, "Admin User")
        XCTAssertEqual(event.principal.type, "user")
    }

    func testAuditPrincipalSystem() {
        let principal = AuditPrincipal.system("myService")
        XCTAssertEqual(principal.identifier, "myService")
        XCTAssertEqual(principal.type, "system")
        XCTAssertEqual(principal.displayName, "myService")
    }

    func testAuditPrincipalDefault() {
        let principal = AuditPrincipal(identifier: "user1")
        XCTAssertEqual(principal.type, "user")
        XCTAssertNil(principal.displayName)
    }

    func testAuditEventTypes() {
        XCTAssertEqual(AuditEventType.allCases.count, 5)
        XCTAssertEqual(AuditEventType.access.rawValue, "access")
        XCTAssertEqual(AuditEventType.modify.rawValue, "modify")
        XCTAssertEqual(AuditEventType.create.rawValue, "create")
        XCTAssertEqual(AuditEventType.delete.rawValue, "delete")
        XCTAssertEqual(AuditEventType.export.rawValue, "export")
    }

    func testAuditIntegrityAfterClearAndReuse() async {
        let audit = AuditTrail()
        await audit.record(eventType: .create, principal: .system(), resource: "R1", action: "A")
        await audit.clear()

        await audit.record(eventType: .create, principal: .system(), resource: "R2", action: "B")
        let isValid = await audit.verifyIntegrity()
        XCTAssertTrue(isValid)

        let events = await audit.allEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].previousHash, "0")
    }

    func testAuditEmptyIntegrity() async {
        let audit = AuditTrail()
        let isValid = await audit.verifyIntegrity()
        XCTAssertTrue(isValid)
    }

    // MARK: - InputValidationResult Tests

    func testInputValidationResultValid() {
        let result = InputValidationResult.valid
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testInputValidationResultInvalid() {
        let result = InputValidationResult(isValid: false, errors: ["Error 1", "Error 2"])
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 2)
    }

    // MARK: - MetricType Tests

    func testMetricTypeRawValues() {
        XCTAssertEqual(MetricType.counter.rawValue, "counter")
        XCTAssertEqual(MetricType.gauge.rawValue, "gauge")
        XCTAssertEqual(MetricType.histogram.rawValue, "histogram")
    }

    // MARK: - Concurrent Access Tests

    func testCacheConcurrentAccess() async {
        let cache = SharedCache<Int, Int>(maxSize: 100)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await cache.set(i, value: i * 10)
                }
            }
        }

        var foundCount = 0
        for i in 0..<50 {
            if await cache.get(i) != nil {
                foundCount += 1
            }
        }
        XCTAssertEqual(foundCount, 50)
    }

    func testMetricsConcurrentAccess() async {
        let metrics = MetricsCollector()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await metrics.increment("concurrent_counter")
                }
            }
        }

        let val = await metrics.counterValue("concurrent_counter")
        XCTAssertEqual(val, 100)
    }

    func testLoggerConcurrentAccess() async {
        let logger = UnifiedLogger(logLevel: .debug)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await logger.log(.info, "Message \(i)")
                }
            }
        }

        let count = await logger.logCount()
        XCTAssertEqual(count, 50)
    }

    func testAuditConcurrentAccess() async {
        let audit = AuditTrail()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    await audit.record(
                        eventType: .access,
                        principal: .system(),
                        resource: "R\(i)",
                        action: "Action \(i)"
                    )
                }
            }
        }

        let count = await audit.count()
        XCTAssertEqual(count, 20)
        let isValid = await audit.verifyIntegrity()
        XCTAssertTrue(isValid)
    }

    // MARK: - Edge Case Tests

    func testCacheMaxSizeOne() async {
        let cache = SharedCache<String, Int>(maxSize: 1)
        await cache.set("a", value: 1)
        await cache.set("b", value: 2)
        let a = await cache.get("a")
        let b = await cache.get("b")
        XCTAssertNil(a)
        XCTAssertEqual(b, 2)
        let count = await cache.count()
        XCTAssertEqual(count, 1)
    }

    func testSHA256LongInput() async {
        let security = SecurityService()
        let longString = String(repeating: "a", count: 10_000)
        let hash = await security.sha256(longString)
        XCTAssertEqual(hash.count, 64)
        let hash2 = await security.sha256(longString)
        XCTAssertEqual(hash, hash2)
    }

    func testSanitizePHIMultiplePatterns() async {
        let security = SecurityService()
        let text = "SSN: 123-45-6789, Email: test@test.com"
        let sanitized = await security.sanitizePHI(text)
        XCTAssertFalse(sanitized.contains("123-45-6789"))
        XCTAssertFalse(sanitized.contains("test@test.com"))
    }

    func testConfigEnvironmentSwitchPreservesData() async {
        let config = ConfigurationManager(environment: .development)
        await config.set("key", value: "dev-value")
        await config.setEnvironment(.production)
        await config.set("key", value: "prod-value")

        await config.setEnvironment(.development)
        let devVal = await config.getString("key")
        XCTAssertEqual(devVal, "dev-value")
        await config.setEnvironment(.production)
        let prodVal = await config.getString("key")
        XCTAssertEqual(prodVal, "prod-value")
    }

    func testHistogramSingleValue() async {
        let metrics = MetricsCollector()
        await metrics.recordHistogram("single", value: 42.0)
        let stats = await metrics.histogramStatistics("single")
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.count, 1)
        XCTAssertEqual(stats!.min, 42.0)
        XCTAssertEqual(stats!.max, 42.0)
        XCTAssertEqual(stats!.mean, 42.0)
        XCTAssertEqual(stats!.p50, 42.0)
        XCTAssertEqual(stats!.p95, 42.0)
        XCTAssertEqual(stats!.p99, 42.0)
    }

    func testZeroByteRandomGeneration() async {
        let security = SecurityService()
        let data = await security.generateSecureRandomBytes(0)
        XCTAssertEqual(data.count, 0)
    }

    func testMaskValueEdgeCases() async {
        let security = SecurityService()
        let result = await security.maskValue("1234", visibleCount: 4)
        XCTAssertEqual(result, "1234")

        let result2 = await security.maskValue("12", visibleCount: 10)
        XCTAssertEqual(result2, "12")
    }

    func testUnifiedLogEntryWithMetadata() {
        let metadata = LogMetadata(
            values: ["key1": "val1"],
            correlationID: CorrelationID("c1"),
            module: "mod1"
        )
        let entry = UnifiedLogEntry(
            subsystem: "sub",
            category: "cat",
            level: .debug,
            message: "msg",
            metadata: metadata
        )
        XCTAssertEqual(entry.metadata.values["key1"], "val1")
        XCTAssertEqual(entry.metadata.correlationID?.value, "c1")
        XCTAssertEqual(entry.metadata.module, "mod1")
    }
}
