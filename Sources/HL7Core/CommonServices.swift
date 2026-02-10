/// Common Services for HL7kit
///
/// This module provides shared infrastructure services used across all HL7kit modules:
/// unified logging, security services, caching, configuration management,
/// metrics collection, and audit trail support.

import Foundation

// MARK: - Correlation ID

/// Unique identifier for correlating log entries across modules
public struct CorrelationID: Sendable, Hashable, CustomStringConvertible {
    /// The underlying identifier string
    public let value: String

    /// Human-readable description
    public var description: String { value }

    /// Creates a new correlation ID with the given value
    public init(_ value: String) {
        self.value = value
    }

    /// Generates a new unique correlation ID
    public static func generate() -> CorrelationID {
        CorrelationID(UUID().uuidString)
    }
}

// MARK: - Unified Logging Framework

/// Structured metadata for log entries
public struct LogMetadata: Sendable {
    /// Key-value metadata pairs
    public let values: [String: String]

    /// The correlation ID for tracing across modules
    public let correlationID: CorrelationID?

    /// The module that produced this log entry
    public let module: String?

    /// Creates log metadata
    public init(
        values: [String: String] = [:],
        correlationID: CorrelationID? = nil,
        module: String? = nil
    ) {
        self.values = values
        self.correlationID = correlationID
        self.module = module
    }
}

/// A unified log entry combining structured metadata with the existing log infrastructure
public struct UnifiedLogEntry: Sendable {
    /// The subsystem producing the log
    public let subsystem: String

    /// The category within the subsystem
    public let category: String

    /// Log level
    public let level: HL7LogLevel

    /// Log message
    public let message: String

    /// Timestamp of the log entry
    public let timestamp: Date

    /// Structured metadata
    public let metadata: LogMetadata

    /// Creates a unified log entry
    public init(
        subsystem: String,
        category: String,
        level: HL7LogLevel,
        message: String,
        timestamp: Date = Date(),
        metadata: LogMetadata = LogMetadata()
    ) {
        self.subsystem = subsystem
        self.category = category
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Unified logging actor that wraps `EnhancedLogger` and provides subsystem/category-based
/// logging with correlation IDs for cross-module tracing
public actor UnifiedLogger {
    /// Internal log storage for export capability
    private var logBuffer: [UnifiedLogEntry] = []

    /// Maximum number of entries to retain in the buffer
    private let maxBufferSize: Int

    /// Minimum log level
    private var logLevel: HL7LogLevel

    /// The underlying enhanced logger
    private let logger: EnhancedLogger

    /// Creates a unified logger
    /// - Parameters:
    ///   - maxBufferSize: Maximum log entries to retain for export (default 10000)
    ///   - logLevel: Minimum log level to record (default .info)
    public init(maxBufferSize: Int = 10_000, logLevel: HL7LogLevel = .info) {
        self.maxBufferSize = max(1, maxBufferSize)
        self.logLevel = logLevel
        self.logger = EnhancedLogger()
    }

    /// Set the minimum log level
    public func setLogLevel(_ level: HL7LogLevel) {
        self.logLevel = level
    }

    /// Log a message with subsystem and category
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The log message
    ///   - subsystem: The subsystem (e.g., "HL7v2Kit")
    ///   - category: The category within the subsystem
    ///   - metadata: Optional structured metadata
    public func log(
        _ level: HL7LogLevel,
        _ message: String,
        subsystem: String = "HL7kit",
        category: String = "default",
        metadata: LogMetadata = LogMetadata()
    ) {
        guard level.rawValue >= logLevel.rawValue else { return }

        let entry = UnifiedLogEntry(
            subsystem: subsystem,
            category: category,
            level: level,
            message: message,
            metadata: metadata
        )

        logBuffer.append(entry)
        if logBuffer.count > maxBufferSize {
            logBuffer.removeFirst(logBuffer.count - maxBufferSize)
        }
    }

    /// Export all buffered log entries
    /// - Returns: Array of unified log entries
    public func exportLogs() -> [UnifiedLogEntry] {
        logBuffer
    }

    /// Export log entries filtered by criteria
    /// - Parameters:
    ///   - subsystem: Optional subsystem filter
    ///   - category: Optional category filter
    ///   - level: Optional minimum log level filter
    ///   - correlationID: Optional correlation ID filter
    /// - Returns: Filtered array of log entries
    public func exportLogs(
        subsystem: String? = nil,
        category: String? = nil,
        level: HL7LogLevel? = nil,
        correlationID: CorrelationID? = nil
    ) -> [UnifiedLogEntry] {
        logBuffer.filter { entry in
            if let subsystem = subsystem, entry.subsystem != subsystem { return false }
            if let category = category, entry.category != category { return false }
            if let level = level, entry.level.rawValue < level.rawValue { return false }
            if let correlationID = correlationID,
               entry.metadata.correlationID != correlationID { return false }
            return true
        }
    }

    /// Clear the log buffer
    public func clearLogs() {
        logBuffer.removeAll()
    }

    /// Get the current number of buffered log entries
    public func logCount() -> Int {
        logBuffer.count
    }
}

// MARK: - Common Security Services

/// Result of input validation
public struct InputValidationResult: Sendable {
    /// Whether the input is valid
    public let isValid: Bool

    /// Validation errors, if any
    public let errors: [String]

    /// Creates a validation result
    public init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }

    /// A successful validation result
    public static let valid = InputValidationResult(isValid: true)
}

/// Security service actor providing data sanitization, validation, hashing, and secure random generation
public actor SecurityService {

    public init() {}

    // MARK: - PHI Data Sanitization

    /// Sanitizes text by masking potential PHI patterns (SSN, MRN, phone numbers, etc.)
    /// - Parameter text: The text to sanitize
    /// - Returns: Sanitized text with PHI patterns masked
    public func sanitizePHI(_ text: String) -> String {
        var result = text
        // Mask SSN patterns (XXX-XX-XXXX)
        result = replaceMatches(
            in: result,
            pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            replacement: "***-**-****"
        )
        // Mask phone number patterns (XXX-XXX-XXXX or (XXX) XXX-XXXX)
        result = replaceMatches(
            in: result,
            pattern: "\\b\\d{3}[-.\\s]?\\d{3}[-.\\s]?\\d{4}\\b",
            replacement: "***-***-****"
        )
        // Mask email addresses
        result = replaceMatches(
            in: result,
            pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            replacement: "****@****"
        )
        return result
    }

    /// Masks a string, revealing only the last N characters
    /// - Parameters:
    ///   - value: The value to mask
    ///   - visibleCount: Number of trailing characters to leave visible
    /// - Returns: Masked string
    public func maskValue(_ value: String, visibleCount: Int = 4) -> String {
        guard value.count > visibleCount, visibleCount >= 0 else {
            if visibleCount <= 0 {
                return String(repeating: "*", count: value.count)
            }
            return value
        }
        let masked = String(repeating: "*", count: value.count - visibleCount)
        let visible = String(value.suffix(visibleCount))
        return masked + visible
    }

    // MARK: - Input Validation

    /// Validates that a string is non-empty and within length bounds
    /// - Parameters:
    ///   - input: The string to validate
    ///   - minLength: Minimum acceptable length (default 1)
    ///   - maxLength: Maximum acceptable length (default 10000)
    /// - Returns: Validation result
    public func validateInput(
        _ input: String,
        minLength: Int = 1,
        maxLength: Int = 10_000
    ) -> InputValidationResult {
        var errors: [String] = []
        if input.count < minLength {
            errors.append("Input length \(input.count) is below minimum \(minLength)")
        }
        if input.count > maxLength {
            errors.append("Input length \(input.count) exceeds maximum \(maxLength)")
        }
        return InputValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    /// Validates that a string contains only safe characters (alphanumeric, spaces, basic punctuation)
    /// - Parameter input: The string to validate
    /// - Returns: Validation result
    public func validateSafeCharacters(_ input: String) -> InputValidationResult {
        let allowedSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ".-_,;:!?()[]{}/@#$%&*+=<>'\""))
        let inputSet = CharacterSet(charactersIn: input)
        if inputSet.isSubset(of: allowedSet) {
            return .valid
        }
        return InputValidationResult(
            isValid: false,
            errors: ["Input contains disallowed characters"]
        )
    }

    // MARK: - Secure Random Generation

    /// Generates cryptographically secure random bytes using Swift's `SystemRandomNumberGenerator`,
    /// which delegates to platform CSPRNG (`arc4random_buf` on macOS, `/dev/urandom` on Linux)
    /// - Parameter count: Number of bytes to generate
    /// - Returns: Data containing random bytes
    public func generateSecureRandomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return Data(bytes)
    }

    /// Generates a secure random hex string
    /// - Parameter byteCount: Number of random bytes (hex string will be 2x this length)
    /// - Returns: Hex-encoded random string
    public func generateSecureRandomHex(_ byteCount: Int = 16) -> String {
        let data = generateSecureRandomBytes(byteCount)
        return data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Hash Computation

    /// Computes a SHA-256 hash of the given data
    /// - Parameter data: The data to hash
    /// - Returns: Hex-encoded SHA-256 hash string
    public func sha256(_ data: Data) -> String {
        SHA256Hasher.hash(data)
    }

    /// Computes a SHA-256 hash of a string (UTF-8 encoded)
    /// - Parameter string: The string to hash
    /// - Returns: Hex-encoded SHA-256 hash string
    public func sha256(_ string: String) -> String {
        SHA256Hasher.hash(string)
    }

    // MARK: - Private Helpers

    private func replaceMatches(in text: String, pattern: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}

// MARK: - SHA-256 Utility (nonisolated)

/// Computes SHA-256 hash without requiring actor isolation
private enum SHA256Hasher {
    static func hash(_ string: String) -> String {
        hash(Data(string.utf8))
    }

    static func hash(_ data: Data) -> String {
        digest(data).map { String(format: "%02x", $0) }.joined()
    }

    static func digest(_ data: Data) -> [UInt8] {
        let bytes = Array(data)
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
            0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
            0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
            0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
            0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
            0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
            0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
            0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
            0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]

        var h0: UInt32 = 0x6a09e667
        var h1: UInt32 = 0xbb67ae85
        var h2: UInt32 = 0x3c6ef372
        var h3: UInt32 = 0xa54ff53a
        var h4: UInt32 = 0x510e527f
        var h5: UInt32 = 0x9b05688c
        var h6: UInt32 = 0x1f83d9ab
        var h7: UInt32 = 0x5be0cd19

        let ml = bytes.count * 8
        var msg = bytes
        msg.append(0x80)
        while (msg.count % 64) != 56 {
            msg.append(0x00)
        }
        let mlBE = UInt64(ml)
        for i in stride(from: 56, through: 0, by: -8) {
            msg.append(UInt8((mlBE >> i) & 0xff))
        }

        let chunkCount = msg.count / 64
        for chunkIndex in 0..<chunkCount {
            let chunkStart = chunkIndex * 64
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let offset = chunkStart + i * 4
                w[i] = UInt32(msg[offset]) << 24
                    | UInt32(msg[offset + 1]) << 16
                    | UInt32(msg[offset + 2]) << 8
                    | UInt32(msg[offset + 3])
            }
            for i in 16..<64 {
                let s0 = rightRotate(w[i-15], by: 7) ^ rightRotate(w[i-15], by: 18) ^ (w[i-15] >> 3)
                let s1 = rightRotate(w[i-2], by: 17) ^ rightRotate(w[i-2], by: 19) ^ (w[i-2] >> 10)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }

            var a = h0, b = h1, c = h2, d = h3
            var e = h4, f = h5, g = h6, h = h7

            for i in 0..<64 {
                let s1 = rightRotate(e, by: 6) ^ rightRotate(e, by: 11) ^ rightRotate(e, by: 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rightRotate(a, by: 2) ^ rightRotate(a, by: 13) ^ rightRotate(a, by: 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj

                h = g; g = f; f = e
                e = d &+ temp1
                d = c; c = b; b = a
                a = temp1 &+ temp2
            }

            h0 = h0 &+ a; h1 = h1 &+ b; h2 = h2 &+ c; h3 = h3 &+ d
            h4 = h4 &+ e; h5 = h5 &+ f; h6 = h6 &+ g; h7 = h7 &+ h
        }

        var result = [UInt8]()
        for value in [h0, h1, h2, h3, h4, h5, h6, h7] {
            result.append(UInt8((value >> 24) & 0xff))
            result.append(UInt8((value >> 16) & 0xff))
            result.append(UInt8((value >> 8) & 0xff))
            result.append(UInt8(value & 0xff))
        }
        return result
    }

    private static func rightRotate(_ value: UInt32, by count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}

// MARK: - Shared Caching Infrastructure

/// Statistics for cache operations
public struct CacheStatistics: Sendable {
    /// Number of cache hits
    public let hits: Int

    /// Number of cache misses
    public let misses: Int

    /// Number of evictions
    public let evictions: Int

    /// Current number of entries
    public let count: Int

    /// Hit rate as a percentage (0-100)
    public var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total) * 100.0
    }
}

/// A generic LRU cache with TTL-based expiration and size limits
public actor SharedCache<Key: Hashable & Sendable, Value: Sendable> {
    /// Cached entry with expiration
    private struct CacheEntry {
        let value: Value
        let expiresAt: Date?
        var lastAccessed: Date
    }

    /// Maximum number of entries
    private let maxSize: Int

    /// Default time-to-live for entries
    private let defaultTTL: TimeInterval?

    /// The cache storage
    private var storage: [Key: CacheEntry] = [:]

    /// Ordered keys for LRU tracking (most recently used at end)
    private var accessOrder: [Key] = []

    /// Statistics
    private var hits: Int = 0
    private var misses: Int = 0
    private var evictions: Int = 0

    /// Creates a shared cache
    /// - Parameters:
    ///   - maxSize: Maximum number of entries (default 1000)
    ///   - defaultTTL: Default time-to-live in seconds (nil = no expiration)
    public init(maxSize: Int = 1000, defaultTTL: TimeInterval? = nil) {
        self.maxSize = max(1, maxSize)
        self.defaultTTL = defaultTTL
    }

    /// Gets a value from the cache
    /// - Parameter key: The cache key
    /// - Returns: The cached value, or nil if not found or expired
    public func get(_ key: Key) -> Value? {
        guard var entry = storage[key] else {
            misses += 1
            return nil
        }

        // Check expiration
        if let expiresAt = entry.expiresAt, Date() >= expiresAt {
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            misses += 1
            return nil
        }

        // Update access order for LRU
        entry.lastAccessed = Date()
        storage[key] = entry
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)

        hits += 1
        return entry.value
    }

    /// Sets a value in the cache
    /// - Parameters:
    ///   - key: The cache key
    ///   - value: The value to cache
    ///   - ttl: Optional TTL override for this entry
    public func set(_ key: Key, value: Value, ttl: TimeInterval? = nil) {
        let effectiveTTL = ttl ?? defaultTTL
        let expiresAt = effectiveTTL.map { Date().addingTimeInterval($0) }

        let entry = CacheEntry(
            value: value,
            expiresAt: expiresAt,
            lastAccessed: Date()
        )

        // If key already exists, update it
        if storage[key] != nil {
            accessOrder.removeAll { $0 == key }
        }

        storage[key] = entry
        accessOrder.append(key)

        // Evict if over size limit
        while storage.count > maxSize {
            evictLRU()
        }
    }

    /// Removes a value from the cache
    /// - Parameter key: The cache key
    /// - Returns: The removed value, or nil if not found
    @discardableResult
    public func remove(_ key: Key) -> Value? {
        guard let entry = storage.removeValue(forKey: key) else { return nil }
        accessOrder.removeAll { $0 == key }
        return entry.value
    }

    /// Removes all entries from the cache
    public func clear() {
        storage.removeAll()
        accessOrder.removeAll()
    }

    /// Returns the current number of entries
    public func count() -> Int {
        storage.count
    }

    /// Returns whether the cache contains the given key (and it is not expired)
    public func contains(_ key: Key) -> Bool {
        guard let entry = storage[key] else { return false }
        if let expiresAt = entry.expiresAt, Date() >= expiresAt {
            return false
        }
        return true
    }

    /// Returns cache statistics
    public func statistics() -> CacheStatistics {
        CacheStatistics(
            hits: hits,
            misses: misses,
            evictions: evictions,
            count: storage.count
        )
    }

    /// Removes all expired entries
    /// - Returns: The number of entries removed
    @discardableResult
    public func removeExpired() -> Int {
        let now = Date()
        var removed = 0
        let expiredKeys = storage.compactMap { key, entry -> Key? in
            guard let expiresAt = entry.expiresAt, now >= expiresAt else { return nil }
            return key
        }
        for key in expiredKeys {
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            removed += 1
        }
        return removed
    }

    /// Resets statistics counters
    public func resetStatistics() {
        hits = 0
        misses = 0
        evictions = 0
    }

    // MARK: - Private

    private func evictLRU() {
        guard let lruKey = accessOrder.first else { return }
        storage.removeValue(forKey: lruKey)
        accessOrder.removeFirst()
        evictions += 1
    }
}

// MARK: - Configuration Management

/// Deployment environment
public enum DeploymentEnvironment: String, Sendable, CaseIterable {
    case development
    case staging
    case production
}

/// A typed configuration value
public struct ConfigurationValue: Sendable {
    /// The string representation of the value
    public let rawValue: String

    /// The source of the value (default, override, environment)
    public let source: String

    /// Creates a configuration value
    public init(rawValue: String, source: String = "default") {
        self.rawValue = rawValue
        self.source = source
    }

    /// Converts to Int
    public var intValue: Int? { Int(rawValue) }

    /// Converts to Double
    public var doubleValue: Double? { Double(rawValue) }

    /// Converts to Bool
    public var boolValue: Bool? {
        switch rawValue.lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default: return nil
        }
    }
}

/// Configuration validation rule
public struct ConfigurationRule: Sendable {
    /// The key to validate
    public let key: String

    /// Whether this key is required
    public let isRequired: Bool

    /// Optional validator closure description (for human readability)
    public let description: String

    /// The validation function
    public let validate: @Sendable (String) -> Bool

    /// Creates a configuration rule
    public init(
        key: String,
        isRequired: Bool = false,
        description: String = "",
        validate: @escaping @Sendable (String) -> Bool = { _ in true }
    ) {
        self.key = key
        self.isRequired = isRequired
        self.description = description
        self.validate = validate
    }
}

/// Configuration validation result
public struct ConfigurationValidationResult: Sendable {
    /// Whether the configuration is valid
    public let isValid: Bool

    /// Validation errors
    public let errors: [String]

    /// A valid result
    public static let valid = ConfigurationValidationResult(isValid: true, errors: [])
}

/// Configuration manager actor providing key-value configuration with environment support
public actor ConfigurationManager {
    /// Current deployment environment
    private var environment: DeploymentEnvironment

    /// Configuration storage per environment
    private var configurations: [DeploymentEnvironment: [String: ConfigurationValue]] = [:]

    /// Default values
    private var defaults: [String: ConfigurationValue] = [:]

    /// Validation rules
    private var rules: [ConfigurationRule] = []

    /// Creates a configuration manager
    /// - Parameter environment: The deployment environment (default .development)
    public init(environment: DeploymentEnvironment = .development) {
        self.environment = environment
    }

    /// Sets the active deployment environment
    public func setEnvironment(_ environment: DeploymentEnvironment) {
        self.environment = environment
    }

    /// Gets the active deployment environment
    public func getEnvironment() -> DeploymentEnvironment {
        environment
    }

    /// Sets a configuration value for the current environment
    /// - Parameters:
    ///   - key: Configuration key
    ///   - value: Configuration value string
    ///   - source: Source of the value (default "override")
    public func set(_ key: String, value: String, source: String = "override") {
        let configValue = ConfigurationValue(rawValue: value, source: source)
        configurations[environment, default: [:]][key] = configValue
    }

    /// Sets a configuration value for a specific environment
    /// - Parameters:
    ///   - key: Configuration key
    ///   - value: Configuration value string
    ///   - environment: Target environment
    ///   - source: Source of the value
    public func set(
        _ key: String,
        value: String,
        for environment: DeploymentEnvironment,
        source: String = "override"
    ) {
        let configValue = ConfigurationValue(rawValue: value, source: source)
        configurations[environment, default: [:]][key] = configValue
    }

    /// Sets a default value for a key
    /// - Parameters:
    ///   - key: Configuration key
    ///   - value: Default value string
    public func setDefault(_ key: String, value: String) {
        defaults[key] = ConfigurationValue(rawValue: value, source: "default")
    }

    /// Gets a configuration value for the current environment
    /// - Parameter key: Configuration key
    /// - Returns: The configuration value, or the default, or nil
    public func get(_ key: String) -> ConfigurationValue? {
        if let envValue = configurations[environment]?[key] {
            return envValue
        }
        return defaults[key]
    }

    /// Gets a string value, with an optional fallback
    /// - Parameters:
    ///   - key: Configuration key
    ///   - defaultValue: Fallback value if key is not set
    /// - Returns: The configuration string value
    public func getString(_ key: String, default defaultValue: String? = nil) -> String? {
        get(key)?.rawValue ?? defaultValue
    }

    /// Gets an integer value
    public func getInt(_ key: String, default defaultValue: Int? = nil) -> Int? {
        get(key)?.intValue ?? defaultValue
    }

    /// Gets a boolean value
    public func getBool(_ key: String, default defaultValue: Bool? = nil) -> Bool? {
        get(key)?.boolValue ?? defaultValue
    }

    /// Removes a configuration value for the current environment
    public func remove(_ key: String) {
        configurations[environment]?[key] = nil
    }

    /// Returns all keys for the current environment (including defaults)
    public func allKeys() -> Set<String> {
        var keys = Set(defaults.keys)
        if let envKeys = configurations[environment]?.keys {
            keys.formUnion(envKeys)
        }
        return keys
    }

    /// Adds a validation rule
    public func addRule(_ rule: ConfigurationRule) {
        rules.append(rule)
    }

    /// Validates the current configuration against all rules
    /// - Returns: Validation result
    public func validate() -> ConfigurationValidationResult {
        var errors: [String] = []
        for rule in rules {
            if let value = get(rule.key) {
                if !rule.validate(value.rawValue) {
                    errors.append("Validation failed for key '\(rule.key)': \(rule.description)")
                }
            } else if rule.isRequired {
                errors.append("Required key '\(rule.key)' is missing")
            }
        }
        return ConfigurationValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    /// Clears all configuration for the current environment
    public func clear() {
        configurations[environment] = [:]
    }

    /// Clears all configuration and defaults
    public func clearAll() {
        configurations.removeAll()
        defaults.removeAll()
        rules.removeAll()
    }
}

// MARK: - Monitoring and Metrics

/// Types of metrics
public enum MetricType: String, Sendable {
    case counter
    case gauge
    case histogram
}

/// A snapshot of a single metric
public struct MetricSnapshot: Sendable {
    /// The metric name
    public let name: String

    /// The metric type
    public let type: MetricType

    /// Current value (for counters and gauges)
    public let value: Double

    /// All recorded values (for histograms)
    public let values: [Double]

    /// Labels/tags for the metric
    public let labels: [String: String]
}

/// A snapshot of all metrics at a point in time
public struct MetricsSnapshot: Sendable {
    /// Timestamp of the snapshot
    public let timestamp: Date

    /// All metric snapshots
    public let metrics: [MetricSnapshot]
}

/// Metrics collector actor for counters, gauges, and histograms
public actor MetricsCollector {
    /// Counter values
    private var counters: [String: Double] = [:]

    /// Gauge values
    private var gauges: [String: Double] = [:]

    /// Histogram values
    private var histograms: [String: [Double]] = [:]

    /// Labels for metrics
    private var labels: [String: [String: String]] = [:]

    public init() {}

    // MARK: - Counter Metrics

    /// Increments a counter by a given amount
    /// - Parameters:
    ///   - name: Counter name
    ///   - amount: Amount to increment (default 1)
    ///   - labels: Optional metric labels
    public func increment(_ name: String, by amount: Double = 1, labels: [String: String] = [:]) {
        counters[name, default: 0] += amount
        if !labels.isEmpty {
            self.labels[name] = labels
        }
    }

    /// Gets the current value of a counter
    /// - Parameter name: Counter name
    /// - Returns: Current counter value, or nil if not set
    public func counterValue(_ name: String) -> Double? {
        counters[name]
    }

    // MARK: - Gauge Metrics

    /// Sets a gauge to a specific value
    /// - Parameters:
    ///   - name: Gauge name
    ///   - value: The value to set
    ///   - labels: Optional metric labels
    public func setGauge(_ name: String, value: Double, labels: [String: String] = [:]) {
        gauges[name] = value
        if !labels.isEmpty {
            self.labels[name] = labels
        }
    }

    /// Adjusts a gauge by a delta
    /// - Parameters:
    ///   - name: Gauge name
    ///   - delta: Amount to add (can be negative)
    public func adjustGauge(_ name: String, by delta: Double) {
        gauges[name, default: 0] += delta
    }

    /// Gets the current value of a gauge
    /// - Parameter name: Gauge name
    /// - Returns: Current gauge value, or nil if not set
    public func gaugeValue(_ name: String) -> Double? {
        gauges[name]
    }

    // MARK: - Histogram / Timing Metrics

    /// Records a value in a histogram
    /// - Parameters:
    ///   - name: Histogram name
    ///   - value: The value to record
    ///   - labels: Optional metric labels
    public func recordHistogram(_ name: String, value: Double, labels: [String: String] = [:]) {
        histograms[name, default: []].append(value)
        if !labels.isEmpty {
            self.labels[name] = labels
        }
    }

    /// Records a timing duration in a histogram
    /// - Parameters:
    ///   - name: Timer name
    ///   - duration: Duration in seconds
    public func recordTiming(_ name: String, duration: TimeInterval) {
        recordHistogram(name, value: duration)
    }

    /// Gets histogram statistics
    /// - Parameter name: Histogram name
    /// - Returns: Tuple of (count, min, max, mean, p50, p95, p99) or nil
    public func histogramStatistics(_ name: String)
        -> (count: Int, min: Double, max: Double, mean: Double, p50: Double, p95: Double, p99: Double)?
    {
        guard let values = histograms[name], !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let count = sorted.count
        let sum = sorted.reduce(0, +)
        return (
            count: count,
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            mean: sum / Double(count),
            p50: percentile(sorted, 0.50),
            p95: percentile(sorted, 0.95),
            p99: percentile(sorted, 0.99)
        )
    }

    // MARK: - Export / Snapshot

    /// Creates a snapshot of all current metrics
    /// - Returns: A metrics snapshot
    public func snapshot() -> MetricsSnapshot {
        var metrics: [MetricSnapshot] = []

        for (name, value) in counters {
            metrics.append(MetricSnapshot(
                name: name,
                type: .counter,
                value: value,
                values: [],
                labels: labels[name] ?? [:]
            ))
        }

        for (name, value) in gauges {
            metrics.append(MetricSnapshot(
                name: name,
                type: .gauge,
                value: value,
                values: [],
                labels: labels[name] ?? [:]
            ))
        }

        for (name, values) in histograms {
            metrics.append(MetricSnapshot(
                name: name,
                type: .histogram,
                value: values.reduce(0, +) / max(Double(values.count), 1),
                values: values,
                labels: labels[name] ?? [:]
            ))
        }

        return MetricsSnapshot(timestamp: Date(), metrics: metrics)
    }

    /// Resets all metrics
    public func reset() {
        counters.removeAll()
        gauges.removeAll()
        histograms.removeAll()
        labels.removeAll()
    }

    // MARK: - Private

    private func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = Int(Double(sorted.count - 1) * p)
        return sorted[min(index, sorted.count - 1)]
    }
}

// MARK: - Audit Trail Support

/// Types of audit events
public enum AuditEventType: String, Sendable, CaseIterable {
    case access
    case modify
    case create
    case delete
    case export
}

/// Represents who performed an audit action
public struct AuditPrincipal: Sendable {
    /// User or system identifier
    public let identifier: String

    /// Type of principal (user, system, service)
    public let type: String

    /// Display name
    public let displayName: String?

    /// Creates an audit principal
    public init(identifier: String, type: String = "user", displayName: String? = nil) {
        self.identifier = identifier
        self.type = type
        self.displayName = displayName
    }

    /// Creates a system principal
    public static func system(_ name: String = "system") -> AuditPrincipal {
        AuditPrincipal(identifier: name, type: "system", displayName: name)
    }
}

/// A single audit event record
public struct AuditEvent: Sendable {
    /// Unique event identifier
    public let eventID: String

    /// When the event occurred
    public let timestamp: Date

    /// Type of event
    public let eventType: AuditEventType

    /// Who performed the action
    public let principal: AuditPrincipal

    /// What resource was affected
    public let resource: String

    /// Description of the action
    public let action: String

    /// Additional details
    public let details: [String: String]

    /// Hash of this event (for tamper evidence)
    public let eventHash: String

    /// Hash of the previous event (chain link)
    public let previousHash: String

    /// Creates an audit event
    public init(
        eventID: String,
        timestamp: Date,
        eventType: AuditEventType,
        principal: AuditPrincipal,
        resource: String,
        action: String,
        details: [String: String] = [:],
        eventHash: String = "",
        previousHash: String = ""
    ) {
        self.eventID = eventID
        self.timestamp = timestamp
        self.eventType = eventType
        self.principal = principal
        self.resource = resource
        self.action = action
        self.details = details
        self.eventHash = eventHash
        self.previousHash = previousHash
    }
}

/// Tamper-evident audit trail actor using hash chain
public actor AuditTrail {
    /// All audit events in order
    private var events: [AuditEvent] = []

    /// Hash of the last event for chain linking
    private var lastHash: String = "0"

    /// Creates an audit trail
    public init() {}

    /// Records an audit event
    /// - Parameters:
    ///   - eventType: The type of event
    ///   - principal: Who performed the action
    ///   - resource: What resource was affected
    ///   - action: Description of the action
    ///   - details: Additional details
    /// - Returns: The recorded audit event
    @discardableResult
    public func record(
        eventType: AuditEventType,
        principal: AuditPrincipal,
        resource: String,
        action: String,
        details: [String: String] = [:]
    ) -> AuditEvent {
        let eventID = UUID().uuidString
        let timestamp = Date()

        // Build the hash content
        let hashContent = "\(eventID)|\(timestamp.timeIntervalSince1970)|\(eventType.rawValue)|\(principal.identifier)|\(resource)|\(action)|\(lastHash)"
        let eventHash = SHA256Hasher.hash(hashContent)

        let event = AuditEvent(
            eventID: eventID,
            timestamp: timestamp,
            eventType: eventType,
            principal: principal,
            resource: resource,
            action: action,
            details: details,
            eventHash: eventHash,
            previousHash: lastHash
        )

        events.append(event)
        lastHash = eventHash
        return event
    }

    /// Returns all audit events
    public func allEvents() -> [AuditEvent] {
        events
    }

    /// Returns events filtered by type
    /// - Parameter eventType: The event type to filter by
    /// - Returns: Filtered events
    public func events(ofType eventType: AuditEventType) -> [AuditEvent] {
        events.filter { $0.eventType == eventType }
    }

    /// Returns events for a specific principal
    /// - Parameter identifier: The principal identifier
    /// - Returns: Filtered events
    public func events(byPrincipal identifier: String) -> [AuditEvent] {
        events.filter { $0.principal.identifier == identifier }
    }

    /// Returns events for a specific resource
    /// - Parameter resource: The resource identifier
    /// - Returns: Filtered events
    public func events(forResource resource: String) -> [AuditEvent] {
        events.filter { $0.resource == resource }
    }

    /// Verifies the integrity of the audit trail by checking the hash chain
    /// - Returns: True if the chain is intact, false if tampered
    public func verifyIntegrity() -> Bool {
        var expectedPreviousHash = "0"
        for event in events {
            if event.previousHash != expectedPreviousHash {
                return false
            }
            let hashContent = "\(event.eventID)|\(event.timestamp.timeIntervalSince1970)|\(event.eventType.rawValue)|\(event.principal.identifier)|\(event.resource)|\(event.action)|\(event.previousHash)"
            let computedHash = SHA256Hasher.hash(hashContent)
            if event.eventHash != computedHash {
                return false
            }
            expectedPreviousHash = event.eventHash
        }
        return true
    }

    /// Returns the total number of audit events
    public func count() -> Int {
        events.count
    }

    /// Clears all audit events (use with caution)
    public func clear() {
        events.removeAll()
        lastHash = "0"
    }
}
