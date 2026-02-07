/// Enhanced logging and debugging infrastructure for HL7kit
///
/// This module provides structured logging, performance tracking, and debugging
/// capabilities for HL7 message processing.

import Foundation

/// Structured log entry
public struct LogEntry: Sendable {
    /// Log level
    public let level: HL7LogLevel
    
    /// Log message
    public let message: String
    
    /// Timestamp
    public let timestamp: Date
    
    /// Source location (file, function, line)
    public let source: LogSource?
    
    /// Category for filtering
    public let category: String
    
    /// Additional metadata
    public let metadata: [String: String]
    
    public init(
        level: HL7LogLevel,
        message: String,
        timestamp: Date = Date(),
        source: LogSource? = nil,
        category: String = "default",
        metadata: [String: String] = [:]
    ) {
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.source = source
        self.category = category
        self.metadata = metadata
    }
}

/// Source location for log entries
public struct LogSource: Sendable {
    public let file: String
    public let function: String
    public let line: Int
    
    public init(file: String = #file, function: String = #function, line: Int = #line) {
        self.file = file
        self.function = function
        self.line = line
    }
}

/// Protocol for log destinations
public protocol LogDestination: Sendable {
    /// Write a log entry
    func write(_ entry: LogEntry)
}

/// Console log destination
public struct ConsoleLogDestination: LogDestination {
    public init() {}
    
    public func write(_ entry: LogEntry) {
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        var output = "[\(timestamp)] [\(entry.level)] [\(entry.category)] \(entry.message)"
        
        if let source = entry.source {
            let filename = (source.file as NSString).lastPathComponent
            output += " [\(filename):\(source.line)]"
        }
        
        if !entry.metadata.isEmpty {
            let metadataStr = entry.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            output += " {\(metadataStr)}"
        }
        
        print(output)
    }
}

/// Protocol for log filtering
public protocol LogFilter: Sendable {
    /// Check if log entry should be logged
    func shouldLog(_ entry: LogEntry) -> Bool
}

/// Level-based log filter
public struct LevelLogFilter: LogFilter {
    public let minimumLevel: HL7LogLevel
    
    public init(minimumLevel: HL7LogLevel) {
        self.minimumLevel = minimumLevel
    }
    
    public func shouldLog(_ entry: LogEntry) -> Bool {
        entry.level.rawValue >= minimumLevel.rawValue
    }
}

/// Category-based log filter
public struct CategoryLogFilter: LogFilter {
    public let allowedCategories: Set<String>
    
    public init(allowedCategories: Set<String>) {
        self.allowedCategories = allowedCategories
    }
    
    public func shouldLog(_ entry: LogEntry) -> Bool {
        allowedCategories.contains(entry.category)
    }
}

/// Enhanced logger with structured logging
public actor EnhancedLogger {
    private var destinations: [LogDestination] = [ConsoleLogDestination()]
    private var filters: [LogFilter] = []
    private var logLevel: HL7LogLevel = .info
    
    public init() {}
    
    /// Add a log destination
    public func addDestination(_ destination: LogDestination) {
        destinations.append(destination)
    }
    
    /// Add a log filter
    public func addFilter(_ filter: LogFilter) {
        filters.append(filter)
    }
    
    /// Set minimum log level
    public func setLogLevel(_ level: HL7LogLevel) {
        self.logLevel = level
    }
    
    /// Log an entry
    public func log(_ entry: LogEntry) {
        // Check level first
        guard entry.level.rawValue >= logLevel.rawValue else { return }
        
        // Check filters
        guard filters.isEmpty || filters.allSatisfy({ $0.shouldLog(entry) }) else {
            return
        }
        
        // Write to all destinations
        for destination in destinations {
            destination.write(entry)
        }
    }
    
    /// Convenience method to log a message
    public func log(
        _ level: HL7LogLevel,
        _ message: String,
        category: String = "default",
        source: LogSource? = nil,
        metadata: [String: String] = [:]
    ) {
        let entry = LogEntry(
            level: level,
            message: message,
            source: source,
            category: category,
            metadata: metadata
        )
        log(entry)
    }
}

/// Performance tracking utilities
public struct PerformanceMetrics: Sendable {
    /// Duration in seconds
    public let duration: TimeInterval
    
    /// Memory used in bytes
    public let memoryUsed: Int?
    
    /// Custom metrics
    public let customMetrics: [String: Double]
    
    public init(
        duration: TimeInterval,
        memoryUsed: Int? = nil,
        customMetrics: [String: Double] = [:]
    ) {
        self.duration = duration
        self.memoryUsed = memoryUsed
        self.customMetrics = customMetrics
    }
}

/// Performance tracker
public actor PerformanceTracker {
    private var measurements: [String: [PerformanceMetrics]] = [:]
    
    public init() {}
    
    /// Record a performance measurement
    public func record(operation: String, metrics: PerformanceMetrics) {
        measurements[operation, default: []].append(metrics)
    }
    
    /// Get statistics for an operation
    public func statistics(for operation: String) -> PerformanceStatistics? {
        guard let metrics = measurements[operation], !metrics.isEmpty else {
            return nil
        }
        
        let durations = metrics.map { $0.duration }
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let minDuration = durations.min() ?? 0
        let maxDuration = durations.max() ?? 0
        
        return PerformanceStatistics(
            operation: operation,
            count: metrics.count,
            averageDuration: avgDuration,
            minDuration: minDuration,
            maxDuration: maxDuration
        )
    }
    
    /// Get all recorded operations
    public func allOperations() -> [String] {
        Array(measurements.keys)
    }
    
    /// Clear all measurements
    public func clear() {
        measurements.removeAll()
    }
}

/// Performance statistics for an operation
public struct PerformanceStatistics: Sendable {
    public let operation: String
    public let count: Int
    public let averageDuration: TimeInterval
    public let minDuration: TimeInterval
    public let maxDuration: TimeInterval
}

/// Measure execution time of a block
@discardableResult
public func measure<T>(
    operation: String,
    tracker: PerformanceTracker? = nil,
    block: () throws -> T
) rethrows -> T {
    let start = Date()
    let result = try block()
    let duration = Date().timeIntervalSince(start)
    
    if let tracker = tracker {
        Task {
            await tracker.record(
                operation: operation,
                metrics: PerformanceMetrics(duration: duration)
            )
        }
    }
    
    return result
}

/// Measure async execution time
@discardableResult
public func measureAsync<T>(
    operation: String,
    tracker: PerformanceTracker? = nil,
    block: () async throws -> T
) async rethrows -> T {
    let start = Date()
    let result = try await block()
    let duration = Date().timeIntervalSince(start)
    
    if let tracker = tracker {
        await tracker.record(
            operation: operation,
            metrics: PerformanceMetrics(duration: duration)
        )
    }
    
    return result
}
