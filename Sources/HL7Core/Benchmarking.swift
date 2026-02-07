/// Performance benchmarking framework for HL7kit
///
/// This module provides utilities for benchmarking and profiling HL7 operations
/// to ensure performance targets are met.

import Foundation

/// Protocol for performance metrics
public protocol PerformanceMetric: Sendable {
    /// Name of the metric
    var name: String { get }
    
    /// Unit of measurement
    var unit: String { get }
    
    /// Measured value
    var value: Double { get }
}

/// Standard performance metrics
public struct DurationMetric: PerformanceMetric {
    public let name: String
    public let unit: String
    public let value: Double
    
    public init(name: String, seconds: TimeInterval) {
        self.name = name
        self.unit = "seconds"
        self.value = seconds
    }
}

public struct ThroughputMetric: PerformanceMetric {
    public let name: String
    public let unit: String
    public let value: Double
    
    public init(name: String, itemsPerSecond: Double) {
        self.name = name
        self.unit = "items/second"
        self.value = itemsPerSecond
    }
}

public struct MemoryMetric: PerformanceMetric {
    public let name: String
    public let unit: String
    public let value: Double
    
    public init(name: String, bytes: Int) {
        self.name = name
        self.unit = "bytes"
        self.value = Double(bytes)
    }
    
    /// Initialize with kilobytes
    public init(name: String, kilobytes: Double) {
        self.name = name
        self.unit = "KB"
        self.value = kilobytes
    }
    
    /// Initialize with megabytes
    public init(name: String, megabytes: Double) {
        self.name = name
        self.unit = "MB"
        self.value = megabytes
    }
}

/// Benchmark result
public struct BenchmarkResult: Sendable {
    /// Name of the benchmark
    public let name: String
    
    /// Collected metrics
    public let metrics: [any PerformanceMetric]
    
    /// Number of iterations
    public let iterations: Int
    
    /// Timestamp when benchmark was run
    public let timestamp: Date
    
    public init(
        name: String,
        metrics: [any PerformanceMetric],
        iterations: Int,
        timestamp: Date = Date()
    ) {
        self.name = name
        self.metrics = metrics
        self.iterations = iterations
        self.timestamp = timestamp
    }
}

/// Benchmark configuration
public struct BenchmarkConfig: Sendable {
    /// Number of warmup iterations (not measured)
    public let warmupIterations: Int
    
    /// Number of measured iterations
    public let measuredIterations: Int
    
    /// Whether to track memory usage
    public let trackMemory: Bool
    
    /// Minimum duration for benchmark (seconds)
    public let minimumDuration: TimeInterval?
    
    public init(
        warmupIterations: Int = 3,
        measuredIterations: Int = 10,
        trackMemory: Bool = false,
        minimumDuration: TimeInterval? = nil
    ) {
        self.warmupIterations = warmupIterations
        self.measuredIterations = measuredIterations
        self.trackMemory = trackMemory
        self.minimumDuration = minimumDuration
    }
    
    /// Default benchmark configuration
    public static let `default` = BenchmarkConfig()
    
    /// Quick benchmark configuration (fewer iterations)
    public static let quick = BenchmarkConfig(
        warmupIterations: 1,
        measuredIterations: 5
    )
    
    /// Thorough benchmark configuration (more iterations)
    public static let thorough = BenchmarkConfig(
        warmupIterations: 5,
        measuredIterations: 100
    )
}

/// Protocol for benchmarking
public protocol Benchmark: Sendable {
    /// Name of the benchmark
    var name: String { get }
    
    /// Run the benchmark
    /// - Parameter config: Benchmark configuration
    /// - Returns: Benchmark result
    func run(config: BenchmarkConfig) async throws -> BenchmarkResult
}

/// Actor for running benchmarks
public actor BenchmarkRunner {
    private var results: [BenchmarkResult] = []
    
    public init() {}
    
    /// Run a benchmark
    public func run(
        name: String,
        config: BenchmarkConfig = .default,
        block: @escaping () throws -> Void
    ) async throws -> BenchmarkResult {
        // Warmup phase
        for _ in 0..<config.warmupIterations {
            try block()
        }
        
        // Measurement phase
        var durations: [TimeInterval] = []
        let totalStart = Date()
        
        for _ in 0..<config.measuredIterations {
            let start = Date()
            try block()
            let duration = Date().timeIntervalSince(start)
            durations.append(duration)
        }
        
        let totalDuration = Date().timeIntervalSince(totalStart)
        
        // Calculate metrics
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let minDuration = durations.min() ?? 0
        let maxDuration = durations.max() ?? 0
        let throughput = Double(config.measuredIterations) / totalDuration
        
        let metrics: [any PerformanceMetric] = [
            DurationMetric(name: "Average Duration", seconds: avgDuration),
            DurationMetric(name: "Min Duration", seconds: minDuration),
            DurationMetric(name: "Max Duration", seconds: maxDuration),
            ThroughputMetric(name: "Throughput", itemsPerSecond: throughput)
        ]
        
        let result = BenchmarkResult(
            name: name,
            metrics: metrics,
            iterations: config.measuredIterations
        )
        
        results.append(result)
        return result
    }
    
    /// Run an async benchmark
    public func runAsync(
        name: String,
        config: BenchmarkConfig = .default,
        block: @escaping () async throws -> Void
    ) async throws -> BenchmarkResult {
        // Warmup phase
        for _ in 0..<config.warmupIterations {
            try await block()
        }
        
        // Measurement phase
        var durations: [TimeInterval] = []
        let totalStart = Date()
        
        for _ in 0..<config.measuredIterations {
            let start = Date()
            try await block()
            let duration = Date().timeIntervalSince(start)
            durations.append(duration)
        }
        
        let totalDuration = Date().timeIntervalSince(totalStart)
        
        // Calculate metrics
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let minDuration = durations.min() ?? 0
        let maxDuration = durations.max() ?? 0
        let throughput = Double(config.measuredIterations) / totalDuration
        
        let metrics: [any PerformanceMetric] = [
            DurationMetric(name: "Average Duration", seconds: avgDuration),
            DurationMetric(name: "Min Duration", seconds: minDuration),
            DurationMetric(name: "Max Duration", seconds: maxDuration),
            ThroughputMetric(name: "Throughput", itemsPerSecond: throughput)
        ]
        
        let result = BenchmarkResult(
            name: name,
            metrics: metrics,
            iterations: config.measuredIterations
        )
        
        results.append(result)
        return result
    }
    
    /// Get all benchmark results
    public func allResults() -> [BenchmarkResult] {
        results
    }
    
    /// Clear all results
    public func clear() {
        results.removeAll()
    }
}

/// Memory usage tracking utilities
public struct MemoryUsage: Sendable {
    public let allocated: Int
    public let resident: Int
    public let peak: Int
    
    public init(allocated: Int, resident: Int, peak: Int) {
        self.allocated = allocated
        self.resident = resident
        self.peak = peak
    }
    
    /// Get current memory usage
    public static func current() -> MemoryUsage? {
        #if os(Linux)
        // Linux implementation
        return nil
        #else
        // Darwin implementation
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        return MemoryUsage(
            allocated: Int(info.virtual_size),
            resident: Int(info.resident_size),
            peak: Int(info.resident_size_max)
        )
        #endif
    }
}
