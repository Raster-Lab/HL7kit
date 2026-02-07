import Foundation

/// # Memory-Efficient Parsing Strategies
///
/// This file defines the parsing strategies and protocols for memory-efficient processing
/// of HL7 messages across v2.x, v3.x, and FHIR standards.
///
/// ## Design Principles
///
/// 1. **Lazy Parsing**: Parse data on-demand rather than upfront
/// 2. **Streaming**: Process large documents without loading entirely into memory
/// 3. **Copy-on-Write**: Use value semantics with shared storage for immutable data
/// 4. **Object Pooling**: Reuse commonly created objects to reduce allocations
/// 5. **Buffer Management**: Efficiently manage memory buffers during parsing
///
/// ## Memory Optimization Strategies
///
/// ### Strategy 1: Lazy Parsing
/// Parse only what's needed when it's needed. Store raw data and defer parsing until accessed.
/// - Best for: Large messages where only specific fields are needed
/// - Trade-off: Slightly slower access time for better memory usage
///
/// ### Strategy 2: Streaming Parser
/// Process data incrementally without loading the entire message into memory.
/// - Best for: Very large files, batch processing, real-time message processing
/// - Trade-off: Limited random access, forward-only processing
///
/// ### Strategy 3: Chunked Parsing
/// Parse data in fixed-size chunks with configurable buffer sizes.
/// - Best for: Processing large datasets with predictable memory limits
/// - Trade-off: Complexity in handling records spanning chunk boundaries
///
/// ### Strategy 4: Indexed Parsing
/// Build a lightweight index of message structure without parsing content.
/// - Best for: Quick navigation and field extraction from large messages
/// - Trade-off: Two-pass process (index + parse on demand)

// MARK: - Buffer Management

/// Configuration for parsing buffer management
public struct BufferConfiguration: Sendable {
    /// Default buffer size for streaming operations (64 KB)
    public static let defaultBufferSize = 64 * 1024
    
    /// Size of the parsing buffer in bytes
    public let bufferSize: Int
    
    /// Maximum number of buffers to pool
    public let maxPoolSize: Int
    
    /// Whether to automatically grow buffers when needed
    public let autoGrow: Bool
    
    /// Maximum buffer size when auto-growing
    public let maxBufferSize: Int
    
    /// Creates a buffer configuration
    public init(
        bufferSize: Int = defaultBufferSize,
        maxPoolSize: Int = 10,
        autoGrow: Bool = true,
        maxBufferSize: Int = 1024 * 1024 // 1 MB
    ) {
        self.bufferSize = bufferSize
        self.maxPoolSize = maxPoolSize
        self.autoGrow = autoGrow
        self.maxBufferSize = maxBufferSize
    }
}

/// A reusable buffer for parsing operations
public struct ParsingBuffer: Sendable {
    /// The size of the buffer
    private let size: Int
    
    /// Current position in the buffer
    private(set) var position: Int
    
    /// Amount of valid data in the buffer
    private(set) var length: Int
    
    /// Creates a new parsing buffer
    /// - Parameter size: Size of the buffer in bytes
    public init(size: Int) {
        self.size = size
        self.position = 0
        self.length = 0
    }
    
    /// Resets the buffer for reuse
    public mutating func reset() {
        position = 0
        length = 0
    }
    
    /// Returns the available space in the buffer
    public var availableSpace: Int {
        size - length
    }
    
    /// Returns whether the buffer is full
    public var isFull: Bool {
        length >= size
    }
}

/// Thread-safe buffer pool for reusing parsing buffers
public actor BufferPool {
    private var availableBuffers: [ParsingBuffer]
    private let configuration: BufferConfiguration
    
    public init(configuration: BufferConfiguration = BufferConfiguration()) {
        self.configuration = configuration
        self.availableBuffers = []
    }
    
    /// Acquires a buffer from the pool or creates a new one
    public func acquire() -> ParsingBuffer {
        if let buffer = availableBuffers.popLast() {
            var mutableBuffer = buffer
            mutableBuffer.reset()
            return mutableBuffer
        }
        return ParsingBuffer(size: configuration.bufferSize)
    }
    
    /// Returns a buffer to the pool for reuse
    public func release(_ buffer: ParsingBuffer) {
        guard availableBuffers.count < configuration.maxPoolSize else {
            return // Pool is full, buffer will be deallocated
        }
        availableBuffers.append(buffer)
    }
    
    /// Clears all pooled buffers
    public func clear() {
        availableBuffers.removeAll()
    }
}

// MARK: - Lazy Parsing Storage

/// Storage strategy for lazy-parsed data using copy-on-write semantics
public struct LazyStorage<T: Sendable>: Sendable {
    /// Thread-safe actor-based storage for lazy parsing
    private actor Storage {
        let rawData: Data
        var parsedValue: T?
        let parser: @Sendable (Data) throws -> T
        
        init(rawData: Data, parser: @escaping @Sendable (Data) throws -> T) {
            self.rawData = rawData
            self.parsedValue = nil
            self.parser = parser
        }
        
        /// Gets or parses the value (thread-safe, parses only once)
        func getValue() throws -> T {
            if let parsed = parsedValue {
                return parsed
            }
            
            let parsed = try parser(rawData)
            parsedValue = parsed
            return parsed
        }
        
        /// Returns whether the value has been parsed
        var isParsed: Bool {
            parsedValue != nil
        }
    }
    
    private let storage: Storage
    
    /// Creates lazy storage with raw data and a parser
    public init(rawData: Data, parser: @escaping @Sendable (Data) throws -> T) {
        self.storage = Storage(rawData: rawData, parser: parser)
    }
    
    /// The raw unparsed data
    public var rawData: Data {
        get async {
            await storage.rawData
        }
    }
    
    /// Gets the parsed value, parsing if necessary (thread-safe)
    public func value() async throws -> T {
        try await storage.getValue()
    }
    
    /// Whether the data has been parsed yet
    public var isParsed: Bool {
        get async {
            await storage.isParsed
        }
    }
}

// MARK: - Indexed Parsing

/// Represents an indexed segment or field location in a message
public struct ParsedIndex: Sendable {
    /// Offset in bytes from the start of the message
    public let offset: Int
    
    /// Length in bytes
    public let length: Int
    
    /// Optional identifier (segment name, field number, etc.)
    public let identifier: String?
    
    /// Creates a parsed index entry
    public init(offset: Int, length: Int, identifier: String? = nil) {
        self.offset = offset
        self.length = length
        self.identifier = identifier
    }
    
    /// Returns the range for this index
    public var range: Range<Int> {
        offset..<(offset + length)
    }
}

/// An index of message structure for quick navigation
public struct MessageIndex: Sendable {
    /// The indexed entries
    public let entries: [ParsedIndex]
    
    /// The original data length
    public let dataLength: Int
    
    /// Creates a message index
    public init(entries: [ParsedIndex], dataLength: Int) {
        self.entries = entries
        self.dataLength = dataLength
    }
    
    /// Finds entries matching a given identifier
    public func find(identifier: String) -> [ParsedIndex] {
        entries.filter { $0.identifier == identifier }
    }
    
    /// Gets an entry at a specific byte offset
    public func entry(at offset: Int) -> ParsedIndex? {
        entries.first { $0.range.contains(offset) }
    }
}

// MARK: - Streaming Parser Protocol

/// Protocol for parsers that can process data in a streaming fashion
public protocol StreamingMessageParser: Sendable {
    associatedtype Element: Sendable
    
    /// Feeds data to the parser
    /// - Parameter data: Data chunk to process
    /// - Returns: Number of bytes consumed
    mutating func feed(_ data: Data) throws -> Int
    
    /// Gets the next parsed element if available
    /// - Returns: The next element or nil if none is ready
    mutating func next() throws -> Element?
    
    /// Indicates no more data will be fed
    mutating func finish() throws
    
    /// Resets the parser to initial state
    mutating func reset()
    
    /// Whether the parser has finished processing
    var isFinished: Bool { get }
}

// MARK: - Chunked Parser Protocol

/// Configuration for chunked parsing
public struct ChunkConfiguration: Sendable {
    /// Size of each chunk in bytes
    public let chunkSize: Int
    
    /// Overlap between chunks to handle boundary cases
    public let overlap: Int
    
    /// Creates a chunk configuration
    public init(chunkSize: Int = 64 * 1024, overlap: Int = 1024) {
        self.chunkSize = chunkSize
        self.overlap = overlap
    }
}

/// Protocol for parsers that process data in chunks
public protocol ChunkedParser: Sendable {
    associatedtype Result: Sendable
    
    /// Processes a chunk of data
    /// - Parameters:
    ///   - chunk: The data chunk to process
    ///   - index: Index of this chunk
    ///   - isLast: Whether this is the last chunk
    /// - Returns: Parsing result for this chunk
    func processChunk(_ chunk: Data, index: Int, isLast: Bool) throws -> Result
}

// MARK: - Parser Strategy

/// Enumeration of available parsing strategies
public enum ParsingStrategy: Sendable {
    /// Parse everything upfront
    case eager
    
    /// Parse on-demand as fields are accessed
    case lazy
    
    /// Stream process without loading all into memory
    case streaming(BufferConfiguration)
    
    /// Process in chunks with optional overlap
    case chunked(ChunkConfiguration)
    
    /// Build index first, parse content on-demand
    case indexed
    
    /// Automatically select best strategy based on data size and available memory
    case automatic(threshold: Int = 1024 * 1024) // 1 MB
}

// MARK: - Parser Factory Protocol

/// Factory protocol for creating parsers with different strategies
public protocol ParserFactory: Sendable {
    associatedtype MessageType: HL7Message
    associatedtype Parser: HL7Parser where Parser.MessageType == MessageType
    
    /// Creates a parser with the specified strategy
    /// - Parameter strategy: The parsing strategy to use
    /// - Returns: A parser instance
    func makeParser(strategy: ParsingStrategy) -> Parser
}

// MARK: - Memory Metrics

/// Tracks memory usage during parsing
public struct ParsingMemoryMetrics: Sendable {
    /// Peak memory usage in bytes
    public let peakMemory: Int
    
    /// Average memory usage in bytes
    public let averageMemory: Int
    
    /// Number of buffer allocations
    public let allocations: Int
    
    /// Number of buffer reuses from pool
    public let poolHits: Int
    
    /// Creates memory metrics
    public init(peakMemory: Int, averageMemory: Int, allocations: Int, poolHits: Int) {
        self.peakMemory = peakMemory
        self.averageMemory = averageMemory
        self.allocations = allocations
        self.poolHits = poolHits
    }
    
    /// Pool hit rate (0.0 to 1.0)
    public var poolHitRate: Double {
        let total = allocations + poolHits
        guard total > 0 else { return 0.0 }
        return Double(poolHits) / Double(total)
    }
}

/// Actor for tracking memory metrics during parsing
public actor ParsingMetricsTracker {
    private var currentMemory: Int = 0
    private var peakMemory: Int = 0
    private var totalMemory: Int = 0
    private var measurements: Int = 0
    private var allocations: Int = 0
    private var poolHits: Int = 0
    
    /// Records a memory allocation
    public func recordAllocation(size: Int, fromPool: Bool) {
        currentMemory += size
        peakMemory = max(peakMemory, currentMemory)
        totalMemory += currentMemory
        measurements += 1
        
        if fromPool {
            poolHits += 1
        } else {
            allocations += 1
        }
    }
    
    /// Records a memory deallocation
    public func recordDeallocation(size: Int) {
        currentMemory = max(0, currentMemory - size)
    }
    
    /// Gets the current metrics snapshot
    public func snapshot() -> ParsingMemoryMetrics {
        let avgMemory = measurements > 0 ? totalMemory / measurements : 0
        return ParsingMemoryMetrics(
            peakMemory: peakMemory,
            averageMemory: avgMemory,
            allocations: allocations,
            poolHits: poolHits
        )
    }
    
    /// Resets all metrics
    public func reset() {
        currentMemory = 0
        peakMemory = 0
        totalMemory = 0
        measurements = 0
        allocations = 0
        poolHits = 0
    }
}
