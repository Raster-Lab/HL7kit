import Foundation

/// # Actor Patterns for HL7 Message Processing
///
/// This file provides concrete actor implementations demonstrating the concurrency
/// patterns defined in CONCURRENCY_MODEL.md.
///
/// These actors serve as reference implementations and can be used directly or
/// extended for specific use cases.

// MARK: - Message Processing Actors

/// Configuration options for message processing
public struct ProcessingOptions: Sendable {
    /// Maximum time to wait for processing
    public let timeout: Duration
    
    /// Whether to perform strict validation
    public let strictValidation: Bool
    
    /// Whether to collect detailed metrics
    public let collectMetrics: Bool
    
    public init(
        timeout: Duration = .seconds(30),
        strictValidation: Bool = true,
        collectMetrics: Bool = false
    ) {
        self.timeout = timeout
        self.strictValidation = strictValidation
        self.collectMetrics = collectMetrics
    }
}

/// Processing metrics collected during message processing
public struct ProcessingMetrics: Sendable {
    public let messagesProcessed: Int
    public let totalDuration: Duration
    public let averageDuration: Duration
    public let errorCount: Int
    
    public init(
        messagesProcessed: Int,
        totalDuration: Duration,
        averageDuration: Duration,
        errorCount: Int
    ) {
        self.messagesProcessed = messagesProcessed
        self.totalDuration = totalDuration
        self.averageDuration = averageDuration
        self.errorCount = errorCount
    }
}

/// Actor responsible for processing individual HL7 messages
///
/// This actor demonstrates:
/// - Safe concurrent message processing
/// - Metrics collection
/// - Batch processing with bounded concurrency
/// - Proper error handling and recovery
public actor MessageProcessor {
    // MARK: - State Management
    
    private var processingCount: Int = 0
    private let options: ProcessingOptions
    private var totalProcessed: Int = 0
    private var totalErrors: Int = 0
    private var cumulativeDuration: Duration = .zero
    
    // MARK: - Initialization
    
    /// Initialize a message processor with options
    public init(options: ProcessingOptions = ProcessingOptions()) {
        self.options = options
    }
    
    // MARK: - Single Message Processing
    
    /// Process a single message
    /// - Parameter data: Raw message data
    /// - Returns: Processing result with parsed message
    /// - Throws: HL7Error if processing fails
    public func process(data: Data) async throws -> ProcessingResult {
        let startTime = ContinuousClock.now
        processingCount += 1
        
        defer {
            processingCount -= 1
        }
        
        do {
            // Simulate processing (replace with actual parsing logic)
            try await Task.sleep(for: .milliseconds(10))
            
            // Update metrics
            let duration = ContinuousClock.now - startTime
            totalProcessed += 1
            cumulativeDuration += duration
            
            return ProcessingResult(
                success: true,
                duration: duration,
                messageData: data
            )
        } catch {
            totalErrors += 1
            throw HL7Error.parsingError("Failed to process message: \(error)")
        }
    }
    
    // MARK: - Batch Processing
    
    /// Process multiple messages concurrently with bounded parallelism
    /// - Parameters:
    ///   - messages: Array of message data to process
    ///   - maxConcurrency: Maximum number of concurrent operations
    /// - Returns: Array of processing results
    public func processBatch(
        _ messages: [Data],
        maxConcurrency: Int = 4
    ) async throws -> [ProcessingResult] {
        try await withThrowingTaskGroup(of: (Int, ProcessingResult).self) { group in
            var results: [(Int, ProcessingResult)] = []
            results.reserveCapacity(messages.count)
            
            for (index, data) in messages.enumerated() {
                // Limit concurrency by waiting for a task to complete
                if index >= maxConcurrency {
                    if let result = try await group.next() {
                        results.append(result)
                    }
                }
                
                group.addTask { [weak self] in
                    guard let self = self else {
                        throw HL7Error.unknown("Processor deallocated")
                    }
                    let result = try await self.process(data: data)
                    return (index, result)
                }
            }
            
            // Collect remaining results
            for try await result in group {
                results.append(result)
            }
            
            // Sort by original index to maintain order
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    // MARK: - Metrics Access
    
    /// Get current processing metrics
    public func metrics() -> ProcessingMetrics {
        let avgDuration = totalProcessed > 0
            ? cumulativeDuration / totalProcessed
            : .zero
        
        return ProcessingMetrics(
            messagesProcessed: totalProcessed,
            totalDuration: cumulativeDuration,
            averageDuration: avgDuration,
            errorCount: totalErrors
        )
    }
    
    /// Get current active processing count (nonisolated for performance)
    public nonisolated var activeCount: Int {
        get async {
            await processingCount
        }
    }
    
    /// Reset metrics
    public func resetMetrics() {
        totalProcessed = 0
        totalErrors = 0
        cumulativeDuration = .zero
    }
}

/// Result of message processing
public struct ProcessingResult: Sendable {
    public let success: Bool
    public let duration: Duration
    public let messageData: Data
    
    public init(success: Bool, duration: Duration, messageData: Data) {
        self.success = success
        self.duration = duration
        self.messageData = messageData
    }
}

// MARK: - Stream Processing Actor

/// Actor for streaming message processing with back-pressure
///
/// This actor demonstrates:
/// - Streaming data processing
/// - Memory-efficient chunked processing
/// - Back-pressure handling
/// - Buffer management
public actor StreamProcessor {
    // MARK: - State
    
    private let bufferPool: BufferPool
    private var activeBuffers: Set<UUID> = []
    private var position: Int = 0
    private var isProcessing: Bool = false
    
    // MARK: - Initialization
    
    public init(bufferPool: BufferPool = BufferPool()) {
        self.bufferPool = bufferPool
    }
    
    // MARK: - Stream Processing
    
    /// Process a stream of data chunks
    /// - Parameter stream: AsyncSequence of data chunks
    /// - Returns: AsyncThrowingStream of processing results
    public func processStream<S: AsyncSequence>(
        _ stream: S
    ) async throws -> AsyncThrowingStream<ProcessingResult, Error> where S.Element == Data {
        guard !isProcessing else {
            throw HL7Error.invalidState("Stream processing already in progress")
        }
        
        isProcessing = true
        
        return AsyncThrowingStream { continuation in
            Task {
                defer {
                    Task { await self.markProcessingComplete() }
                }
                
                do {
                    for try await chunk in stream {
                        // Check for cancellation
                        try Task.checkCancellation()
                        
                        // Get buffer from pool
                        let buffer = await bufferPool.acquire()
                        let bufferID = UUID()
                        await self.trackBuffer(bufferID)
                        
                        // Process chunk
                        let result = try await self.processChunk(chunk, buffer: buffer)
                        continuation.yield(result)
                        
                        // Release buffer
                        await bufferPool.release(buffer)
                        await self.untrackBuffer(bufferID)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func processChunk(_ data: Data, buffer: ParsingBuffer) async throws -> ProcessingResult {
        let startTime = ContinuousClock.now
        
        // Simulate processing
        try await Task.sleep(for: .milliseconds(5))
        
        let duration = ContinuousClock.now - startTime
        position += data.count
        
        return ProcessingResult(
            success: true,
            duration: duration,
            messageData: data
        )
    }
    
    private func trackBuffer(_ id: UUID) {
        activeBuffers.insert(id)
    }
    
    private func untrackBuffer(_ id: UUID) {
        activeBuffers.remove(id)
    }
    
    private func markProcessingComplete() {
        isProcessing = false
    }
    
    // MARK: - Status
    
    /// Get current stream position
    public nonisolated var currentPosition: Int {
        get async {
            await position
        }
    }
    
    /// Check if currently processing
    public nonisolated var processingActive: Bool {
        get async {
            await isProcessing
        }
    }
}

// MARK: - Message Pipeline Actor

/// Actor coordinating multiple processing stages
///
/// This actor demonstrates:
/// - Actor coordination
/// - Multi-stage processing
/// - Error propagation
/// - Logging integration
public actor MessagePipeline {
    // MARK: - Dependencies
    
    private let processor: MessageProcessor
    private let logger: EnhancedLogger
    
    // MARK: - State
    
    private var pipelineMetrics: PipelineMetrics
    
    // MARK: - Initialization
    
    public init(
        processor: MessageProcessor? = nil,
        logger: EnhancedLogger? = nil
    ) {
        self.processor = processor ?? MessageProcessor()
        self.logger = logger ?? EnhancedLogger()
        self.pipelineMetrics = PipelineMetrics()
    }
    
    // MARK: - Pipeline Processing
    
    /// Process a message through the pipeline
    /// - Parameter data: Raw message data
    /// - Returns: Processing result
    public func process(_ data: Data) async throws -> ProcessingResult {
        let startTime = ContinuousClock.now
        
        // Log start
        await logger.log(LogEntry(
            level: .debug,
            message: "Starting pipeline processing",
            source: LogSource(function: #function),
            category: "MessagePipeline"
        ))
        
        do {
            // Stage 1: Parse
            let result = try await processor.process(data: data)
            
            // Stage 2: Validate (simulated)
            try await validate(result: result)
            
            // Update metrics
            let duration = ContinuousClock.now - startTime
            await updateMetrics(success: true, duration: duration)
            
            // Log completion
            await logger.log(LogEntry(
                level: .info,
                message: "Pipeline processing completed",
                source: LogSource(function: #function),
                category: "MessagePipeline"
            ))
            
            return result
        } catch {
            // Update metrics
            let duration = ContinuousClock.now - startTime
            await updateMetrics(success: false, duration: duration)
            
            // Log error
            await logger.log(LogEntry(
                level: .error,
                message: "Pipeline processing failed: \(error)",
                source: LogSource(function: #function),
                category: "MessagePipeline"
            ))
            
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func validate(result: ProcessingResult) async throws {
        // Simulate validation
        try await Task.sleep(for: .milliseconds(5))
        
        if !result.success {
            throw HL7Error.validationError("Message validation failed")
        }
    }
    
    private func updateMetrics(success: Bool, duration: Duration) {
        if success {
            pipelineMetrics.successCount += 1
        } else {
            pipelineMetrics.failureCount += 1
        }
        pipelineMetrics.totalDuration += duration
    }
    
    // MARK: - Metrics
    
    /// Get pipeline metrics
    public func getMetrics() -> PipelineMetrics {
        pipelineMetrics
    }
}

/// Metrics for pipeline processing
public struct PipelineMetrics: Sendable {
    public var successCount: Int = 0
    public var failureCount: Int = 0
    public var totalDuration: Duration = .zero
    
    public var totalProcessed: Int {
        successCount + failureCount
    }
    
    public var averageDuration: Duration {
        guard totalProcessed > 0 else { return .zero }
        return totalDuration / totalProcessed
    }
}

// MARK: - Message Router Actor

/// Message type detection result
public enum MessageType: Sendable {
    case v2
    case v3
    case fhir
    case unknown
}

/// Actor for routing messages to appropriate processors
///
/// This actor demonstrates:
/// - Actor hierarchies
/// - Lazy actor initialization
/// - Type-based routing
/// - Resource management
public actor MessageRouter {
    // MARK: - Child Actors (lazy initialization)
    
    private var v2Processor: MessageProcessor?
    private var v3Processor: MessageProcessor?
    private var fhirProcessor: MessageProcessor?
    
    // MARK: - State
    
    private var routingStats: [MessageType: Int] = [:]
    
    // MARK: - Routing
    
    /// Route a message to the appropriate processor
    /// - Parameter data: Raw message data
    /// - Returns: Processing result
    public func route(_ data: Data) async throws -> ProcessingResult {
        let messageType = detectMessageType(data)
        
        // Update stats
        routingStats[messageType, default: 0] += 1
        
        // Route to appropriate processor
        switch messageType {
        case .v2:
            return try await routeToV2(data)
        case .v3:
            return try await routeToV3(data)
        case .fhir:
            return try await routeToFHIR(data)
        case .unknown:
            throw HL7Error.invalidFormat("Unknown message type")
        }
    }
    
    // MARK: - Private Routing Methods
    
    private func routeToV2(_ data: Data) async throws -> ProcessingResult {
        if v2Processor == nil {
            v2Processor = MessageProcessor()
        }
        return try await v2Processor!.process(data: data)
    }
    
    private func routeToV3(_ data: Data) async throws -> ProcessingResult {
        if v3Processor == nil {
            v3Processor = MessageProcessor()
        }
        return try await v3Processor!.process(data: data)
    }
    
    private func routeToFHIR(_ data: Data) async throws -> ProcessingResult {
        if fhirProcessor == nil {
            fhirProcessor = MessageProcessor()
        }
        return try await fhirProcessor!.process(data: data)
    }
    
    private func detectMessageType(_ data: Data) -> MessageType {
        // Simple detection based on first few bytes
        guard let firstChar = data.first else {
            return .unknown
        }
        
        // HL7 v2.x typically starts with ASCII segment name (e.g., "MSH")
        if firstChar == 0x4D { // 'M'
            return .v2
        }
        
        // HL7 v3.x is XML, starts with '<'
        if firstChar == 0x3C { // '<'
            return .v3
        }
        
        // FHIR is JSON, starts with '{'
        if firstChar == 0x7B { // '{'
            return .fhir
        }
        
        return .unknown
    }
    
    // MARK: - Statistics
    
    /// Get routing statistics
    public func statistics() -> [MessageType: Int] {
        routingStats
    }
    
    /// Reset statistics
    public func resetStatistics() {
        routingStats.removeAll()
    }
}

// MARK: - Helper Extensions

extension HL7Error {
    static func invalidState(_ message: String) -> HL7Error {
        .unknown(message)
    }
}
