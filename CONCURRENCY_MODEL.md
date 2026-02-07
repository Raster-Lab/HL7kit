# Actor-Based Concurrency Model for HL7kit

## Overview

This document defines the actor-based concurrency model for HL7kit, leveraging Swift 6.2's strict concurrency features to provide thread-safe, performant, and reliable HL7 message processing across all platforms.

## Design Principles

### 1. Data Race Safety by Default
- All public APIs use `Sendable` types to prevent data races at compile time
- Actors protect shared mutable state
- Value types with copy-on-write semantics for immutable data sharing

### 2. Structured Concurrency
- Use async/await for asynchronous operations
- Task groups for parallel processing
- Proper cancellation handling and cleanup

### 3. Performance-Oriented Design
- Minimize actor isolation boundaries where possible
- Use nonisolated access for immutable properties
- Leverage actor reentrancy for concurrent operations

### 4. Clear Ownership Model
- Single-owner actors for exclusive access patterns
- Shared immutable state across concurrent contexts
- Explicit isolation boundaries

## Actor Architecture

### Core Actor Types

#### 1. Message Processing Actors

##### `MessageProcessor` Actor
**Purpose**: Coordinate parsing, validation, and transformation of HL7 messages

```swift
/// Actor responsible for processing individual HL7 messages
public actor MessageProcessor {
    // State management
    private var processingCount: Int = 0
    private let parser: any HL7Parser
    private let validator: any Validator
    
    // Configuration
    private let options: ProcessingOptions
    
    // Metrics tracking
    private var metrics: ProcessingMetrics
    
    /// Process a message with full validation
    public func process(data: Data) async throws -> any HL7Message
    
    /// Process multiple messages concurrently
    public func processBatch(_ messages: [Data]) async throws -> [any HL7Message]
}
```

**Isolation Strategy**:
- Encapsulates parsing and validation state
- Protects concurrent access to metrics
- Supports reentrancy for independent message processing

##### `StreamProcessor` Actor
**Purpose**: Process large message streams with memory-efficient chunking

```swift
/// Actor for streaming message processing
public actor StreamProcessor {
    // Buffer management
    private let bufferPool: BufferPool
    private var activeBuffers: Set<BufferID>
    
    // Stream state
    private var position: Int = 0
    private var isProcessing: Bool = false
    
    /// Process data stream in chunks
    public func processStream<S: AsyncSequence>(
        _ stream: S
    ) async throws -> AsyncThrowingStream<any HL7Message, Error> where S.Element == Data
}
```

**Isolation Strategy**:
- Manages streaming state safely
- Coordinates buffer allocation and release
- Prevents concurrent stream processing from same actor

#### 2. Resource Management Actors

##### `BufferPool` Actor
**Purpose**: Manage reusable memory buffers for parsing operations

```swift
/// Actor managing a pool of reusable parsing buffers
public actor BufferPool {
    private var availableBuffers: [ParsingBuffer]
    private var configuration: BufferConfiguration
    
    /// Acquire a buffer from the pool
    public func acquire() async -> ParsingBuffer
    
    /// Release a buffer back to the pool
    public func release(_ buffer: ParsingBuffer) async
    
    /// Get pool statistics
    public nonisolated var statistics: PoolStatistics { get }
}
```

**Isolation Strategy**:
- Serializes buffer allocation/deallocation
- Prevents concurrent access to buffer pool
- Provides non-isolated access to immutable statistics

##### `ConnectionPool` Actor
**Purpose**: Manage network connections for HL7 v2.x MLLP and FHIR REST

```swift
/// Actor managing network connections
public actor ConnectionPool {
    // Connection management
    private var availableConnections: [ConnectionID: NetworkConnection]
    private var activeConnections: [ConnectionID: NetworkConnection]
    
    // Configuration
    private let maxConnections: Int
    private let keepAliveTimeout: Duration
    
    /// Acquire a connection from the pool
    public func acquireConnection(to endpoint: Endpoint) async throws -> NetworkConnection
    
    /// Release a connection back to the pool
    public func releaseConnection(_ connection: NetworkConnection) async
    
    /// Close all connections
    public func closeAll() async
}
```

**Isolation Strategy**:
- Prevents connection state races
- Manages connection lifecycle safely
- Supports concurrent connection acquisition

#### 3. Logging and Monitoring Actors

##### `EnhancedLogger` Actor
**Purpose**: Thread-safe logging with routing and filtering

```swift
/// Actor-based logger with filtering and routing
public actor EnhancedLogger {
    private var destinations: [LogDestination]
    private var filters: [LogFilter]
    private var buffer: [LogEntry]
    
    /// Log a message with specified level
    public func log(
        _ message: String,
        level: HL7LogLevel,
        source: LogSource
    ) async
    
    /// Add a log destination
    public func addDestination(_ destination: LogDestination) async
}
```

**Isolation Strategy**:
- Serializes log writes
- Prevents log message interleaving
- Safely manages destination collection

##### `PerformanceTracker` Actor
**Purpose**: Collect and aggregate performance metrics

```swift
/// Actor for tracking performance metrics
public actor PerformanceTracker {
    private var operations: [String: [PerformanceMetrics]]
    private var activeOperations: [UUID: Date]
    
    /// Start tracking an operation
    public func startOperation(named: String) async -> UUID
    
    /// Complete tracking an operation
    public func completeOperation(_ id: UUID) async -> Duration
    
    /// Get statistics for an operation
    public func statistics(for operation: String) async -> PerformanceStatistics?
}
```

**Isolation Strategy**:
- Protects metrics collection
- Safely tracks concurrent operations
- Provides aggregate statistics

#### 4. Validation Actors

##### `ValidationAccumulator` Actor
**Purpose**: Collect validation issues during message processing

```swift
/// Actor for accumulating validation issues
public actor ValidationAccumulator {
    private var issues: [ValidationIssue]
    private var context: ValidationContext
    
    /// Add a validation issue
    public func add(_ issue: ValidationIssue) async
    
    /// Get all accumulated issues
    public func allIssues() async -> [ValidationIssue]
    
    /// Check if validation passed
    public nonisolated var hasErrors: Bool { get }
}
```

**Isolation Strategy**:
- Serializes issue collection
- Supports concurrent validators
- Provides non-isolated error checking

##### `ErrorCollector` Actor
**Purpose**: Collect and manage errors during processing

```swift
/// Actor for collecting errors during processing
public actor ErrorCollector {
    private var errors: [HL7Error]
    private var errorCount: [ErrorSeverity: Int]
    
    /// Record an error
    public func record(_ error: HL7Error, severity: ErrorSeverity) async
    
    /// Get errors by severity
    public func errors(withSeverity severity: ErrorSeverity) async -> [HL7Error]
}
```

**Isolation Strategy**:
- Protects error collection state
- Enables concurrent error reporting
- Aggregates error statistics

## Sendable Protocol Usage

### Value Types as Sendable

All data structures that cross actor boundaries must conform to `Sendable`:

```swift
// Protocols
public protocol HL7Message: Sendable { }
public protocol HL7Parser: Sendable { }
public protocol Validator: Sendable { }

// Enums
public enum HL7Error: Error, Sendable { }
public enum ValidationResult: Sendable { }

// Structs
public struct ValidationContext: Sendable { }
public struct ParseOptions: Sendable { }
public struct BenchmarkResult: Sendable { }
```

### Sendable Closures

Closures passed to actors or used in concurrent contexts must be `@Sendable`:

```swift
public struct LazyStorage<T: Sendable>: Sendable {
    private actor Storage {
        let parser: @Sendable (Data) throws -> T
    }
    
    public init(rawData: Data, parser: @escaping @Sendable (Data) throws -> T) {
        // ...
    }
}
```

### NonSendable Types

Some types cannot be made Sendable (e.g., file handles, network connections). These are isolated to actor context:

```swift
public actor NetworkManager {
    // Not Sendable - isolated to actor
    private var connections: [Connection]
    
    // Sendable - can be returned from actor
    public func connectionInfo() async -> ConnectionInfo { }
}
```

## Concurrency Patterns

### Pattern 1: Parallel Message Processing

Process multiple messages concurrently with bounded parallelism:

```swift
public actor MessageBatchProcessor {
    private let maxConcurrency: Int
    
    public func processBatch(_ messages: [Data]) async throws -> [any HL7Message] {
        return try await withThrowingTaskGroup(of: (Int, any HL7Message).self) { group in
            for (index, data) in messages.enumerated() {
                // Limit concurrency
                if group.taskCount >= maxConcurrency {
                    _ = try await group.next()
                }
                
                group.addTask {
                    let processor = MessageProcessor()
                    let message = try await processor.process(data: data)
                    return (index, message)
                }
            }
            
            // Collect results in order
            var results: [(Int, any HL7Message)] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}
```

### Pattern 2: Streaming with Back-pressure

Process streams with memory-safe back-pressure:

```swift
public func processMessageStream(
    _ input: AsyncStream<Data>
) -> AsyncThrowingStream<any HL7Message, Error> {
    AsyncThrowingStream { continuation in
        Task {
            let processor = StreamProcessor()
            
            do {
                for await data in input {
                    let message = try await processor.process(data: data)
                    continuation.yield(message)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```

### Pattern 3: Actor Coordination

Multiple actors working together with clear communication:

```swift
public actor MessagePipeline {
    private let parser: MessageProcessor
    private let validator: ValidationEngine
    private let logger: EnhancedLogger
    
    public func process(_ data: Data) async throws -> any HL7Message {
        // Log start
        await logger.log("Starting message processing", level: .debug, source: .init(module: "Pipeline"))
        
        // Parse message
        let message = try await parser.process(data: data)
        
        // Validate message
        let result = await validator.validate(message: message)
        
        // Log completion
        await logger.log("Message processed", level: .info, source: .init(module: "Pipeline"))
        
        guard case .valid = result else {
            throw HL7Error.validationError("Message validation failed")
        }
        
        return message
    }
}
```

### Pattern 4: Lazy Actor Initialization

Defer actor creation until needed:

```swift
public struct LazyActorReference<T: Actor> {
    private var actor: T?
    private let factory: @Sendable () -> T
    
    public mutating func get() -> T {
        if let existing = actor {
            return existing
        }
        let new = factory()
        actor = new
        return new
    }
}
```

### Pattern 5: Actor Hierarchies

Parent actors managing child actors:

```swift
public actor MessageRouter {
    // Child actors for different message types
    private var v2Processor: V2MessageProcessor?
    private var v3Processor: V3MessageProcessor?
    private var fhirProcessor: FHIRProcessor?
    
    public func route(_ data: Data) async throws -> any HL7Message {
        // Detect message type
        let messageType = detectMessageType(data)
        
        // Route to appropriate processor
        switch messageType {
        case .v2:
            if v2Processor == nil {
                v2Processor = V2MessageProcessor()
            }
            return try await v2Processor!.process(data: data)
            
        case .v3:
            if v3Processor == nil {
                v3Processor = V3MessageProcessor()
            }
            return try await v3Processor!.process(data: data)
            
        case .fhir:
            if fhirProcessor == nil {
                fhirProcessor = FHIRProcessor()
            }
            return try await fhirProcessor!.process(data: data)
        }
    }
}
```

## Network Concurrency

### HL7 v2.x MLLP

MLLP (Minimal Lower Layer Protocol) connections require careful concurrency management:

```swift
public actor MLLPConnection {
    // Network state
    private var connection: NWConnection?
    private var isConnected: Bool = false
    
    // Message queue
    private var pendingMessages: [Data] = []
    
    /// Send a message over MLLP
    public func send(_ message: Data) async throws {
        guard isConnected else {
            throw HL7Error.networkError("Not connected")
        }
        
        // Add MLLP framing
        let framedMessage = frameMessage(message)
        
        // Send with backpressure handling
        try await sendData(framedMessage)
    }
    
    /// Receive messages as a stream
    public func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await receiveLoop(continuation: continuation)
            }
        }
    }
    
    private func receiveLoop(continuation: AsyncThrowingStream<Data, Error>.Continuation) async {
        // Implementation handles frame parsing and message extraction
    }
}
```

### FHIR REST Client

RESTful FHIR operations use structured concurrency:

```swift
public actor FHIRClient {
    private let session: URLSession
    private let baseURL: URL
    
    /// Fetch a resource
    public func read<R: FHIRResource>(
        _ type: R.Type,
        id: String
    ) async throws -> R {
        let url = baseURL.appendingPathComponent("\(R.resourceType)/\(id)")
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HL7Error.networkError("HTTP error")
        }
        
        return try JSONDecoder().decode(R.self, from: data)
    }
    
    /// Search for resources
    public func search<R: FHIRResource>(
        _ type: R.Type,
        parameters: [String: String]
    ) async throws -> FHIRBundle<R> {
        var components = URLComponents(url: baseURL.appendingPathComponent(R.resourceType), resolvingAgainstBaseURL: true)!
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode(FHIRBundle<R>.self, from: data)
    }
}
```

## Cancellation and Cleanup

### Proper Task Cancellation

All long-running operations must check for cancellation:

```swift
public actor LongRunningProcessor {
    public func process(largeDataset: [Data]) async throws -> [any HL7Message] {
        var results: [any HL7Message] = []
        
        for data in largeDataset {
            // Check for cancellation
            try Task.checkCancellation()
            
            // Process message
            let message = try await processMessage(data)
            results.append(message)
        }
        
        return results
    }
}
```

### Resource Cleanup

Actors must clean up resources properly:

```swift
public actor ResourceManager {
    private var resources: [Resource] = []
    
    deinit {
        // Cleanup synchronous resources
        for resource in resources {
            resource.close()
        }
    }
    
    /// Explicit async cleanup
    public func shutdown() async {
        for resource in resources {
            await resource.asyncClose()
        }
        resources.removeAll()
    }
}
```

## Performance Considerations

### 1. Actor Hop Minimization

Reduce actor context switches by batching operations:

```swift
// ❌ Bad: Multiple actor hops
for item in items {
    await actor.process(item)
}

// ✅ Good: Single actor hop
await actor.processBatch(items)
```

### 2. Nonisolated Access

Use `nonisolated` for immutable properties:

```swift
public actor Configuration {
    private let _settings: Settings // Immutable
    
    // No actor hop needed
    public nonisolated var settings: Settings {
        _settings
    }
    
    // Actor hop required
    public var mutableState: State {
        // ...
    }
}
```

### 3. Value Type Optimization

Use copy-on-write for efficient value passing:

```swift
public struct MessageData: Sendable {
    // COW storage
    private var storage: Storage
    
    // Efficient copying
    public mutating func modify() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
        storage.modify()
    }
}
```

### 4. Actor Priority

Use task priority for important operations:

```swift
public actor PriorityProcessor {
    public func processUrgent(_ data: Data) async throws -> any HL7Message {
        // Run at high priority
        try await withTaskPriority(.high) {
            try await process(data)
        }
    }
}
```

## Testing Concurrency

### Data Race Detection

Enable Thread Sanitizer in tests:

```bash
swift test --sanitize=thread
```

### Concurrency Testing Patterns

```swift
func testConcurrentAccess() async throws {
    let actor = MessageProcessor()
    
    // Process multiple messages concurrently
    try await withThrowingTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask {
                _ = try await actor.process(data: sampleData(i))
            }
        }
        
        try await group.waitForAll()
    }
}

func testActorIsolation() async {
    let logger = EnhancedLogger()
    
    // Multiple concurrent log calls
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<1000 {
            group.addTask {
                await logger.log("Message \(i)", level: .info, source: .init(module: "Test"))
            }
        }
    }
    
    // Verify all logs recorded
    // ...
}
```

## Migration Guidelines

### From Non-Concurrent Code

1. Identify shared mutable state
2. Wrap state in actors
3. Convert synchronous APIs to async
4. Add Sendable conformance
5. Update call sites to use await

### Example Migration

Before:
```swift
// Non-concurrent
class MessageCache {
    private var cache: [String: HL7Message] = [:]
    
    func store(_ message: HL7Message) {
        cache[message.messageID] = message
    }
    
    func retrieve(_ id: String) -> HL7Message? {
        cache[id]
    }
}
```

After:
```swift
// Concurrent
public actor MessageCache {
    private var cache: [String: any HL7Message] = [:]
    
    public func store(_ message: any HL7Message) async {
        cache[message.messageID] = message
    }
    
    public func retrieve(_ id: String) async -> (any HL7Message)? {
        cache[id]
    }
}
```

## Best Practices Summary

1. **Always use Sendable for cross-actor data**
   - Prevents data races at compile time
   - Documents concurrency boundaries

2. **Prefer actors over locks**
   - Safer and easier to reason about
   - Better integration with Swift concurrency

3. **Use structured concurrency**
   - Task groups for parallel work
   - Async/await for sequential work
   - Proper cancellation handling

4. **Minimize actor hops**
   - Batch operations when possible
   - Use nonisolated for immutable data

5. **Design for cancellation**
   - Check Task.isCancelled regularly
   - Clean up resources properly

6. **Test concurrency thoroughly**
   - Use Thread Sanitizer
   - Test with high concurrency
   - Verify actor isolation

7. **Document isolation domains**
   - Clear ownership of actors
   - Explicit isolation boundaries
   - Documented concurrency guarantees

## Future Enhancements

### Swift 6.2+ Features

As Swift evolves, consider:

1. **Custom Executors**: For fine-grained control over actor execution
2. **Actor Inheritance**: If/when supported by Swift
3. **Distributed Actors**: For multi-process HL7 processing
4. **Async Algorithms**: Standard library async sequences and algorithms

## References

- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Evolution: Strict Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md)
- [WWDC Sessions on Swift Concurrency](https://developer.apple.com/wwdc/)
- [Swift Concurrency Manifesto](https://gist.github.com/lattner/31ed37682ef1576b16bca1432ea9f782)

---

*This document is a living specification and will be updated as the project evolves and Swift concurrency features mature.*
