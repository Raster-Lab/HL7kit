/// HL7v3Kit - Message Queue
///
/// Implements message queuing for asynchronous message processing.
/// Provides priority-based queuing, retry mechanisms, and batch processing.

import Foundation
import HL7Core

// MARK: - Message Queue

/// Message queue for asynchronous processing
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public actor MessageQueue {
    /// Queued message
    public struct QueuedMessage: Sendable {
        /// Message content
        public let content: String
        
        /// Destination endpoint
        public let endpoint: URL
        
        /// Additional headers
        public let headers: [String: String]
        
        /// Message priority
        public let priority: Priority
        
        /// Number of retry attempts
        public var retryCount: Int
        
        /// Maximum retries allowed
        public let maxRetries: Int
        
        /// Queued timestamp
        public let queuedAt: Date
        
        /// Message ID
        public let id: UUID
        
        /// Initialize queued message
        public init(
            content: String,
            endpoint: URL,
            headers: [String: String] = [:],
            priority: Priority = .normal,
            maxRetries: Int = 3
        ) {
            self.content = content
            self.endpoint = endpoint
            self.headers = headers
            self.priority = priority
            self.retryCount = 0
            self.maxRetries = maxRetries
            self.queuedAt = Date()
            self.id = UUID()
        }
    }
    
    /// Message priority
    public enum Priority: Int, Comparable, Sendable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
        
        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Queue state
    private var queue: [QueuedMessage] = []
    
    /// Maximum queue size
    private let maxSize: Int
    
    /// Transport for sending messages
    private let transport: HL7v3Transport
    
    /// Whether queue processing is active
    private var isProcessing: Bool = false
    
    /// Completed message count
    private var completedCount: Int = 0
    
    /// Failed message count
    private var failedCount: Int = 0
    
    /// Initialize message queue
    /// - Parameters:
    ///   - transport: Transport to use for sending messages
    ///   - maxSize: Maximum queue size (default: 1000)
    public init(transport: HL7v3Transport, maxSize: Int = 1000) {
        self.transport = transport
        self.maxSize = maxSize
    }
    
    /// Enqueue a message
    /// - Parameter message: Message to enqueue
    /// - Throws: TransportError.queueFull if queue is at capacity
    public func enqueue(_ message: QueuedMessage) throws {
        guard queue.count < maxSize else {
            throw TransportError.queueFull
        }
        
        // Insert in priority order
        let insertIndex = queue.firstIndex { $0.priority < message.priority } ?? queue.endIndex
        queue.insert(message, at: insertIndex)
    }
    
    /// Enqueue a message with convenience parameters
    /// - Parameters:
    ///   - content: Message content
    ///   - endpoint: Destination URL
    ///   - headers: HTTP headers
    ///   - priority: Message priority
    public func enqueue(
        content: String,
        to endpoint: URL,
        headers: [String: String] = [:],
        priority: Priority = .normal
    ) throws {
        let message = QueuedMessage(
            content: content,
            endpoint: endpoint,
            headers: headers,
            priority: priority
        )
        try enqueue(message)
    }
    
    /// Start processing the queue
    public func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task {
            await processQueue()
        }
    }
    
    /// Stop processing the queue
    public func stopProcessing() {
        isProcessing = false
    }
    
    /// Process queued messages
    private func processQueue() async {
        while isProcessing && !queue.isEmpty {
            guard var message = queue.first else { break }
            queue.removeFirst()
            
            do {
                // Send message
                _ = try await transport.send(
                    message.content,
                    to: message.endpoint,
                    headers: message.headers
                )
                
                // Success
                completedCount += 1
            } catch {
                // Failure - retry if possible
                message.retryCount += 1
                
                if message.retryCount < message.maxRetries {
                    // Re-queue for retry
                    try? enqueue(message)
                } else {
                    // Max retries exceeded
                    failedCount += 1
                }
            }
            
            // Small delay between messages
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        isProcessing = false
    }
    
    /// Get queue statistics
    public func statistics() -> QueueStatistics {
        return QueueStatistics(
            queuedCount: queue.count,
            completedCount: completedCount,
            failedCount: failedCount,
            isProcessing: isProcessing
        )
    }
    
    /// Clear the queue
    public func clear() {
        queue.removeAll()
    }
    
    /// Get queue size
    public func size() -> Int {
        return queue.count
    }
}

// MARK: - Queue Statistics

/// Statistics for message queue
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct QueueStatistics: Sendable {
    /// Number of messages in queue
    public let queuedCount: Int
    
    /// Number of successfully sent messages
    public let completedCount: Int
    
    /// Number of failed messages
    public let failedCount: Int
    
    /// Whether queue is actively processing
    public let isProcessing: Bool
    
    /// Total messages processed
    public var totalProcessed: Int {
        return completedCount + failedCount
    }
    
    /// Success rate (0.0 to 1.0)
    public var successRate: Double {
        let total = totalProcessed
        guard total > 0 else { return 0.0 }
        return Double(completedCount) / Double(total)
    }
}

// MARK: - Batch Queue

/// Batch message queue for high-throughput scenarios
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public actor BatchMessageQueue {
    /// Batch of messages
    public struct MessageBatch: Sendable {
        /// Messages in this batch
        public let messages: [MessageQueue.QueuedMessage]
        
        /// Batch ID
        public let id: UUID
        
        /// Created timestamp
        public let createdAt: Date
        
        /// Initialize batch
        public init(messages: [MessageQueue.QueuedMessage]) {
            self.messages = messages
            self.id = UUID()
            self.createdAt = Date()
        }
    }
    
    /// Pending messages
    private var pendingMessages: [MessageQueue.QueuedMessage] = []
    
    /// Batch size
    private let batchSize: Int
    
    /// Transport for sending
    private let transport: HL7v3Transport
    
    /// Batch timeout (flush after this duration even if not full)
    private let batchTimeout: TimeInterval
    
    /// Last batch time
    private var lastBatchTime: Date = Date()
    
    /// Initialize batch queue
    /// - Parameters:
    ///   - transport: Transport to use
    ///   - batchSize: Number of messages per batch
    ///   - batchTimeout: Maximum time to wait before flushing incomplete batch
    public init(
        transport: HL7v3Transport,
        batchSize: Int = 100,
        batchTimeout: TimeInterval = 5.0
    ) {
        self.transport = transport
        self.batchSize = batchSize
        self.batchTimeout = batchTimeout
    }
    
    /// Add message to batch
    /// - Parameter message: Message to add
    /// - Returns: Created batch if this message completed a batch
    public func add(_ message: MessageQueue.QueuedMessage) -> MessageBatch? {
        pendingMessages.append(message)
        
        // Check if batch is full
        if pendingMessages.count >= batchSize {
            return flush()
        }
        
        return nil
    }
    
    /// Flush pending messages as a batch
    /// - Returns: Created batch if there were pending messages
    public func flush() -> MessageBatch? {
        guard !pendingMessages.isEmpty else { return nil }
        
        let batch = MessageBatch(messages: pendingMessages)
        pendingMessages.removeAll()
        lastBatchTime = Date()
        
        return batch
    }
    
    /// Check if batch should be flushed due to timeout
    public func shouldFlush() -> Bool {
        guard !pendingMessages.isEmpty else { return false }
        return Date().timeIntervalSince(lastBatchTime) >= batchTimeout
    }
    
    /// Process a batch
    /// - Parameter batch: Batch to process
    /// - Returns: Number of successful sends
    public func process(_ batch: MessageBatch) async -> Int {
        var successCount = 0
        
        // Process messages concurrently in batch
        await withTaskGroup(of: Bool.self) { group in
            for message in batch.messages {
                group.addTask {
                    do {
                        _ = try await self.transport.send(
                            message.content,
                            to: message.endpoint,
                            headers: message.headers
                        )
                        return true
                    } catch {
                        return false
                    }
                }
            }
            
            for await success in group {
                if success {
                    successCount += 1
                }
            }
        }
        
        return successCount
    }
}
