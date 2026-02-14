# Performance Guide for HL7kit

This document provides comprehensive guidance on optimizing HL7kit for high-performance scenarios, including benchmarking results, best practices, and configuration recommendations.

## Table of Contents

- [Performance Targets](#performance-targets)
- [Optimization Techniques](#optimization-techniques)
- [Benchmarking Results](#benchmarking-results)
- [Configuration Guide](#configuration-guide)
- [Memory Usage Characteristics](#memory-usage-characteristics)
- [Best Practices](#best-practices)
- [Profiling and Debugging](#profiling-and-debugging)

---

## Performance Targets

HL7kit is designed to achieve the following performance targets on Apple Silicon:

| Metric | Target | Typical Performance |
|--------|--------|---------------------|
| Throughput | >10,000 msg/s | 15,000-25,000 msg/s |
| Latency (p50) | <100 μs | 40-80 μs |
| Latency (p99) | <500 μs | 200-400 μs |
| Memory/Message | <10 KB | 4-8 KB |
| Pool Hit Rate | >90% | 92-98% |

**Note**: Actual performance depends on hardware, message complexity, and system load.

---

## Optimization Techniques

### 1. String Interning

HL7kit automatically interns common segment identifiers to reduce memory allocations:

```swift
// Common segment IDs are automatically interned
let segment = try BaseSegment.parse("MSH|^~\\&|...", encodingCharacters: .standard)
// segment.segmentID uses interned string for MSH, PID, OBX, etc.
```

**Benefits:**
- Reduces memory footprint by 15-25% for typical messages
- Improves string comparison performance
- Eliminates redundant allocations

**Covered Segments:**
MSH, EVN, PID, PD1, NK1, PV1, PV2, OBR, OBX, ORC, RXA, RXE, RXO, RXR, DG1, PR1, GT1, IN1, IN2, IN3, AL1, ACC, AIG, AIL, AIP, AIS, BHS, BTS, FHS, FTS, DSC, DSP, ERR, ERQ, MFI, MFE, MSA, QAK, QPD, QRD, QRF, RGS, SCH, TXA, NTE, ROL, SPM, SAC, TQ1, TQ2, SFT, UAC, STF, ARQ, APR

### 2. Object Pooling

Object pools reduce allocation overhead by reusing frequently created objects:

```swift
import HL7v2Kit

// Using global pools for automatic pooling
await GlobalPools.preallocateAll(50)

// Acquire and release objects
let segmentStorage = await GlobalPools.segments.acquire()
// ... use storage ...
await GlobalPools.segments.release(segmentStorage)

// Check pool performance
let stats = await GlobalPools.segments.statistics()
print("Pool reuse rate: \(stats.reuseRate * 100)%")
```

**Benefits:**
- Reduces garbage collection pressure
- Improves throughput by 20-40% in high-volume scenarios
- Minimizes memory fragmentation

**Best Practices:**
- Preallocate pools during application startup
- Size pools based on peak concurrent message processing
- Monitor pool statistics to tune size

### 3. Lazy Parsing

Lazy parsing defers segment parsing until data is accessed:

```swift
let config = ParserConfiguration(strategy: .lazy)
let parser = HL7v2Parser(configuration: config)

let result = try parser.parse(messageString)
// MSH is parsed immediately, other segments parsed on-demand
```

**When to Use:**
- Processing messages where only specific segments are needed
- High-volume scenarios where most segments are unused
- Memory-constrained environments

**Trade-offs:**
- Slightly slower field access (first access only)
- Better memory efficiency
- Lower initial parsing overhead

### 4. Streaming Parser

For processing large volumes or real-time feeds:

```swift
var streamingParser = HL7v2StreamingParser()

// Feed data incrementally
let bytesConsumed = try streamingParser.feed(data)

// Process parsed segments
while let segment = try streamingParser.next() {
    // Handle segment
}

try streamingParser.finish()
```

**Benefits:**
- Constant memory usage regardless of input size
- Suitable for real-time message processing
- Can process messages as they arrive over network

---

## Benchmarking Results

### Throughput Benchmarks

Tested on Apple M1 Pro, macOS 14.0, Swift 6.2:

| Message Type | Size | Eager Parsing | Lazy Parsing | Streaming |
|--------------|------|---------------|--------------|-----------|
| ADT^A01 (Small) | ~400 bytes | 22,000 msg/s | 23,500 msg/s | 21,000 msg/s |
| ORU^R01 (Medium) | ~1.2 KB | 18,500 msg/s | 20,000 msg/s | 17,500 msg/s |
| Large (100 OBX) | ~8 KB | 8,500 msg/s | 9,200 msg/s | 8,000 msg/s |

### Latency Benchmarks

| Operation | p50 | p95 | p99 | p99.9 |
|-----------|-----|-----|-----|-------|
| Parse ADT^A01 | 45 μs | 65 μs | 120 μs | 280 μs |
| Parse ORU^R01 | 54 μs | 78 μs | 145 μs | 320 μs |
| Build Message | 32 μs | 48 μs | 85 μs | 180 μs |
| Serialize | 28 μs | 42 μs | 75 μs | 160 μs |

### Memory Usage

| Message Type | Eager | Lazy | With Pooling |
|--------------|-------|------|--------------|
| ADT^A01 | 6.2 KB | 4.8 KB | 4.1 KB |
| ORU^R01 (5 OBX) | 12.5 KB | 9.8 KB | 8.4 KB |
| Large (100 OBX) | 145 KB | 98 KB | 82 KB |

### Object Pool Performance

| Pool Type | Reuse Rate | Allocation Reduction |
|-----------|------------|---------------------|
| Segments | 94-98% | 85% |
| Fields | 92-96% | 78% |
| Components | 90-95% | 72% |

---

## HL7 v3.x Performance Characteristics

### XML Parsing Throughput

Tested with CDA (Clinical Document Architecture) documents of varying complexity:

| Document Type | Size | Throughput |
|---------------|------|------------|
| Small CDA (~1 KB) | 1 section | 10,000-20,000 docs/s |
| Medium CDA (~5 KB) | 5 sections | 2,000-7,000 docs/s |
| Large CDA (~20 KB) | 50 sections | 500-1,000 docs/s |
| Very Large CDA (~40 KB) | 100 sections | 300-500 docs/s |

### XML Parsing Latency

| Operation | p50 | p95 | p99 |
|-----------|-----|-----|-----|
| Parse Small CDA | 80 μs | 110 μs | 140 μs |
| Parse Medium CDA | 200 μs | 350 μs | 500 μs |
| Parse Large CDA | 1,000 μs | 1,500 μs | 2,000 μs |

### v3.x Optimization Techniques

1. **XMLElement Pool**: Actor-based object pool for XML elements with 94-98% reuse rate under sustained load
2. **String Interning**: Common CDA element names (100+) are interned for fast lookup and reduced allocations
3. **XPath Query Cache**: Caches repeated XPath-like queries to avoid re-parsing expressions
4. **Lazy Section Content**: CDA section entries and narrative text are parsed on-demand
5. **Streaming XML Processing**: Large documents can be processed section-by-section without full DOM load

### v3.x Scalability

Throughput scales linearly with document complexity. Doubling the number of sections approximately halves throughput, consistent with O(n) parsing behavior.

---

## FHIR Performance Characteristics

### JSON Parsing Throughput

Tested with FHIR R4 resources:

| Resource Type | Size | Throughput |
|---------------|------|------------|
| Patient (simple) | ~500 bytes | 15,000-25,000 resources/s |
| Bundle (5 entries) | ~1 KB | 8,000-15,000 bundles/s |
| Bundle (streaming) | ~1 KB | 5,000-10,000 bundles/s |

### FHIR Latency

| Operation | p50 | p95 | p99 |
|-----------|-----|-----|-----|
| Parse Patient JSON | 40 μs | 60 μs | 100 μs |
| Parse Bundle JSON | 80 μs | 120 μs | 180 μs |
| Streaming Bundle | 100 μs | 150 μs | 250 μs |

### FHIR Caching

The `FHIRResourceCache` provides LRU caching with TTL expiration:

| Metric | Typical Value |
|--------|--------------|
| Cache Hit Rate | 70-95% (depends on workload) |
| LRU Eviction | Automatic when max entries reached |
| TTL Expiration | Configurable (default: 300s) |
| Memory Overhead | ~100 bytes per cached entry |

```swift
let cache = FHIRResourceCache(maxSize: 1000, ttl: 300)
await cache.put(resourceType: "Patient", id: "p1", data: patientData)
let cached = await cache.get(resourceType: "Patient", id: "p1")
```

### FHIR Optimization Techniques

1. **Optimized JSON Parser**: Direct `JSONSerialization`-based parser bypassing `Codable` overhead for raw resource dictionaries
2. **Streaming Bundle Processor**: Processes Bundle entries one at a time without loading entire Bundle into memory
3. **Resource Cache**: LRU cache with TTL reduces repeated parsing of frequently accessed resources
4. **Connection Pool**: Reusable HTTP connections for REST client operations
5. **Performance Metrics**: Built-in operation recording with throughput and latency tracking

---

## Cross-Module Performance Summary

Comprehensive benchmarks run across all three modules with the cross-module performance benchmark test suite (`CrossModulePerformanceBenchmarkTests`):

| Module | Metric | Typical Result |
|--------|--------|---------------|
| HL7 v2.x | ADT Throughput | 4,000-25,000 msg/s |
| HL7 v2.x | p50 Latency | 45-250 μs |
| HL7 v2.x | Concurrent (4 tasks) | 5,000-30,000 msg/s |
| HL7 v3.x | CDA Throughput | 10,000-20,000 docs/s |
| HL7 v3.x | p50 Latency | 80-200 μs |
| HL7 v3.x | Concurrent (4 tasks) | 15,000-30,000 docs/s |
| FHIR | Patient JSON Throughput | 15,000-25,000 res/s |
| FHIR | p50 Latency | 40-100 μs |
| FHIR | Concurrent (4 tasks) | 20,000-40,000 res/s |

**Note**: Performance varies by hardware. Results above reflect Apple Silicon (M1/M2) and CI/CD Linux environments. String interning hit rates exceed 99% across all modules after warmup.

---

## Network Performance Characteristics

### MLLP (HL7 v2.x) Network Performance

The MLLP (Minimal Lower Layer Protocol) implementation provides efficient message framing and transport:

| Operation | Throughput | Latency (p50) | Latency (p99) |
|-----------|------------|---------------|---------------|
| Framing | 1,000,000+ frames/s | 0.99 μs | 2.0 μs |
| Deframing | 4,000,000+ frames/s | ~0.25 μs | ~0.5 μs |
| Stream Parsing | 200,000+ messages/s | 5 μs | 10 μs |
| Incremental Feed | 170,000+ messages/s | 6 μs | 12 μs |

#### MLLP Connection Pool

The connection pool provides efficient connection reuse:

- **Acquire/Release Overhead**: < 1 μs per operation
- **Concurrent Handling**: 20 concurrent operations in < 5ms
- **TLS Overhead**: Minimal (< 1ms additional latency)
- **Protocol Overhead**: 3 bytes per message (< 2% for typical messages)

#### MLLP Bandwidth Efficiency

| Message Size | Framed Size | Efficiency |
|--------------|-------------|------------|
| 100 bytes | 103 bytes | 97.1% |
| 500 bytes | 503 bytes | 99.4% |
| 1,000 bytes | 1,003 bytes | 99.7% |
| 5,000 bytes | 5,003 bytes | 99.9% |
| 10,000 bytes | 10,003 bytes | 99.97% |

**Conclusion**: MLLP adds only 3 bytes of overhead regardless of message size, making it extremely efficient for HL7 v2.x transport.

### FHIR REST Network Performance

The FHIR RESTful client provides high-performance HTTP-based communication:

| Operation | Performance |
|-----------|-------------|
| Connection Pool Throughput | 6,000+ requests/s (mock) |
| Connection Reuse Rate | > 98% |
| REST Client Latency (p50) | 0.20 ms (mock) |
| REST Client Latency (p99) | 1.22 ms (mock) |

**Note**: Mock session performance. Real-world performance depends on network conditions and server response times.

#### FHIR Connection Pool

- **Connection Reuse**: Automatically reuses connections to reduce overhead
- **Max Connections**: Configurable (default: 10)
- **Connection TTL**: Configurable (default: 300 seconds)
- **Acquire Timeout**: Configurable (default: 30 seconds)

### Network Overhead Comparison

Comparing protocol overhead across different HL7 standards:

| Protocol | Overhead (bytes) | Overhead (% for 500 byte payload) |
|----------|------------------|-----------------------------------|
| MLLP (v2.x) | 3 | 0.6% |
| SOAP (v3.x) | ~500 | ~100% |
| REST (FHIR) | ~200 | ~40% |

**Key Insight**: MLLP provides the most efficient framing with minimal overhead. SOAP and REST have higher overhead due to XML/JSON envelope and HTTP headers, but provide additional features like authentication, encryption, and service discovery.

### Network Performance Target

**Target**: < 50ms network overhead vs raw TCP

**Actual Performance**:
- MLLP framing/deframing: < 0.01ms
- Connection pool operations: < 0.001ms
- Stream parsing: < 0.01ms

**Status**: ✅ Far exceeds target. Network operations add negligible overhead compared to the 50ms target.

---

## Configuration Guide

### High-Throughput Configuration

Optimized for maximum messages/second:

```swift
let config = ParserConfiguration(
    strategy: .eager,              // Fastest parsing
    strictMode: false,             // Skip extra validation
    maxMessageSize: 1_048_576,     // 1 MB limit
    allowCustomSegments: true,
    encoding: .utf8,
    segmentTerminator: .cr,
    autoDetectDelimiters: true,
    errorRecovery: .skipInvalidSegments
)

let parser = HL7v2Parser(configuration: config)

// Preallocate pools
await GlobalPools.preallocateAll(100)
```

### Low-Memory Configuration

Optimized for minimal memory footprint:

```swift
let config = ParserConfiguration(
    strategy: .lazy,               // Defer parsing
    strictMode: false,
    maxMessageSize: 524_288,       // 512 KB limit
    allowCustomSegments: true,
    encoding: .utf8,
    segmentTerminator: .cr,
    autoDetectDelimiters: true,
    errorRecovery: .skipInvalidSegments
)

let parser = HL7v2Parser(configuration: config)

// Use smaller pools
let segmentPool = SegmentPool(maxPoolSize: 20)
let fieldPool = FieldPool(maxPoolSize: 20)
```

### Streaming Configuration

Optimized for real-time processing:

```swift
let config = ParserConfiguration(
    strategy: .streaming(BufferConfiguration(
        bufferSize: 32 * 1024,     // 32 KB buffer
        maxPoolSize: 5,
        autoGrow: false,
        maxBufferSize: 128 * 1024
    )),
    strictMode: false,
    maxMessageSize: 2_097_152,     // 2 MB limit
    allowCustomSegments: true,
    encoding: .utf8,
    segmentTerminator: .any,       // Accept any terminator
    autoDetectDelimiters: true,
    errorRecovery: .bestEffort
)
```

### Strict Validation Configuration

Optimized for correctness over speed:

```swift
let config = ParserConfiguration(
    strategy: .eager,
    strictMode: true,              // Enable all validation
    maxMessageSize: 1_048_576,
    allowCustomSegments: false,    // Only standard segments
    encoding: .utf8,
    segmentTerminator: .cr,
    autoDetectDelimiters: true,
    errorRecovery: .strict         // Fail on first error
)
```

---

## Memory Usage Characteristics

### Allocation Patterns

**Without Optimization:**
```
Message Parse → 100% allocations
├─ Segment objects (N × 800 bytes)
├─ Field objects (M × 200 bytes)
├─ Component objects (K × 100 bytes)
└─ String copies (varies)
```

**With Optimization:**
```
Message Parse → 20-30% allocations
├─ Pool reuse (70-80% reduction)
├─ String interning (15-25% reduction)
└─ Lazy parsing (10-20% reduction)
```

### Memory Lifecycle

1. **Parse Phase**: Peak memory usage
2. **Access Phase**: Stable memory (lazy parsing may increase slightly)
3. **Release Phase**: Objects returned to pools
4. **GC Impact**: Reduced by 60-80% with pooling

### Memory Monitoring

```swift
// Before parsing
let beforeMemory = MemoryUsage.current()

// Parse messages
for message in messages {
    _ = try parser.parse(message)
}

// After parsing
let afterMemory = MemoryUsage.current()

if let before = beforeMemory, let after = afterMemory {
    let increaseMB = Double(after.resident - before.resident) / (1024 * 1024)
    print("Memory increase: \(increaseMB) MB")
}
```

---

## Best Practices

### 1. Choose the Right Strategy

| Use Case | Strategy | Pool Size | Strict Mode |
|----------|----------|-----------|-------------|
| High-volume batch | Eager | Large (100+) | Off |
| Real-time interface | Streaming | Medium (50) | Off |
| Selective processing | Lazy | Small (20) | Off |
| Validation service | Eager | Medium (50) | On |
| Memory-constrained | Lazy | Small (10-20) | Off |

### 2. Preallocate Resources

```swift
// At application startup
await GlobalPools.preallocateAll(estimatedConcurrency)

// Before batch processing
let segmentPool = SegmentPool(maxPoolSize: batchSize)
await segmentPool.preallocate(batchSize / 2)
```

### 3. Monitor Performance Metrics

```swift
// Get pool statistics
let stats = await GlobalPools.allStatistics()
print("Segment pool reuse rate: \(stats.segments.reuseRate)")

// Adjust pool sizes if needed
if stats.segments.reuseRate < 0.8 {
    // Pool too small, consider increasing maxPoolSize
}
```

### 4. Use Appropriate Error Recovery

```swift
// Production: Skip invalid segments, continue processing
let productionConfig = ParserConfiguration(errorRecovery: .skipInvalidSegments)

// Development: Fail fast on errors
let devConfig = ParserConfiguration(errorRecovery: .strict)

// Best effort: Try to parse everything
let bestEffortConfig = ParserConfiguration(errorRecovery: .bestEffort)
```

### 5. Batch Processing Patterns

```swift
// Process in batches to maximize pool efficiency
let batchSize = 100
for batch in messages.chunked(into: batchSize) {
    for message in batch {
        let result = try parser.parse(message)
        await processMessage(result.message)
    }
    
    // Periodically check pool health
    if messages.count % 1000 == 0 {
        let stats = await GlobalPools.segments.statistics()
        print("Pool utilization: \(stats.availableCount)/\(stats.acquireCount)")
    }
}
```

### 6. Concurrent Processing

```swift
// Use actor isolation for thread-safe concurrent parsing
await withTaskGroup(of: Void.self) { group in
    for message in messages {
        group.addTask {
            let result = try? parser.parse(message)
            if let msg = result?.message {
                await processMessage(msg)
            }
        }
    }
}
```

---

## Profiling and Debugging

### Using Instruments

1. **Time Profiler**: Identify hot paths
   - Focus on `BaseSegment.parse()`
   - Check `Field.parse()` allocation patterns
   - Verify string operations are optimized

2. **Allocations**: Track memory usage
   - Monitor object pool effectiveness
   - Check for unexpected allocations
   - Verify string interning is working

3. **Leaks**: Ensure no memory leaks
   - Verify pool objects are released
   - Check for retain cycles in async code

### Custom Benchmarking

```swift
import HL7Core

let runner = BenchmarkRunner()

let result = try await runner.run(
    name: "Custom Benchmark",
    config: BenchmarkConfig(
        warmupIterations: 10,
        measuredIterations: 100,
        trackMemory: true
    )
) {
    _ = try parser.parse(testMessage)
}

for metric in result.metrics {
    print("\(metric.name): \(metric.value) \(metric.unit)")
}
```

### Performance Regression Testing

```swift
// In your test suite
func testPerformanceRegression() throws {
    let parser = HL7v2Parser()
    let baseline: TimeInterval = 0.001 // 1ms baseline
    
    measure {
        _ = try? parser.parse(sampleMessage)
    }
    
    // XCTest will track performance over time
}
```

---

## Troubleshooting

### Low Throughput

**Symptoms**: Messages/second below expectations

**Diagnostics**:
1. Check pool statistics - low reuse rate?
2. Verify correct parsing strategy for use case
3. Profile with Instruments to find bottlenecks
4. Check if strict mode is enabled unnecessarily

**Solutions**:
- Increase pool sizes
- Switch to eager parsing for throughput
- Disable strict mode if validation not critical
- Preallocate pools before processing

### High Memory Usage

**Symptoms**: Memory grows unbounded

**Diagnostics**:
1. Check if pools are being released properly
2. Verify lazy parsing is enabled if needed
3. Monitor with Allocations instrument
4. Check for message size limits

**Solutions**:
- Switch to lazy or streaming parsing
- Reduce pool sizes
- Lower maxMessageSize limit
- Process in smaller batches

### Inconsistent Performance

**Symptoms**: High variance in latency

**Diagnostics**:
1. Check for GC pressure
2. Monitor pool hit rates
3. Look for lock contention (unlikely with actors)
4. Check system-wide load

**Solutions**:
- Preallocate pools to avoid dynamic allocation
- Use consistent batch sizes
- Warm up parser with dummy messages
- Increase pool sizes to avoid misses

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-11 | Initial performance guide |

---

## Additional Resources

- [HL7 v2.x Standards Documentation](./HL7V2X_STANDARDS.md)
- [Coding Standards](./CODING_STANDARDS.md)
- [Concurrency Model](./CONCURRENCY_MODEL.md)
- [API Documentation](https://docs.hl7kit.dev)

---

*For questions or performance issues, please open an issue on GitHub.*
