/// Object pooling for HL7 v2.x parser performance optimization
///
/// Provides thread-safe object pools for reusing frequently allocated objects
/// to reduce memory allocations and improve parsing throughput.

import Foundation
import HL7Core

// MARK: - Pool Statistics

/// Statistics about object pool performance
public struct PoolStatistics: Sendable, Equatable {
    /// Number of objects currently in the pool
    public let availableCount: Int
    /// Total number of times an object was acquired from the pool
    public let acquireCount: Int
    /// Number of times an object was reused (cache hit)
    public let reuseCount: Int
    /// Number of times a new object had to be created (cache miss)
    public let allocationCount: Int
    /// Total number of times an object was returned to the pool
    public let releaseCount: Int
    
    /// Reuse rate (0.0 to 1.0)
    public var reuseRate: Double {
        let total = reuseCount + allocationCount
        guard total > 0 else { return 0.0 }
        return Double(reuseCount) / Double(total)
    }
    
    /// Creates pool statistics
    public init(
        availableCount: Int,
        acquireCount: Int,
        reuseCount: Int,
        allocationCount: Int,
        releaseCount: Int
    ) {
        self.availableCount = availableCount
        self.acquireCount = acquireCount
        self.reuseCount = reuseCount
        self.allocationCount = allocationCount
        self.releaseCount = releaseCount
    }
}

// MARK: - Generic Object Pool

/// Thread-safe object pool for reusing objects
///
/// This generic pool can be used for any type that conforms to `Sendable`.
/// Objects are created on-demand and reused when available.
public actor ObjectPool<T: Sendable> {
    private var available: [T]
    private let maxPoolSize: Int
    private let factory: @Sendable () -> T
    private let reset: (@Sendable (inout T) -> Void)?
    
    // Statistics
    private var acquireCount: Int = 0
    private var reuseCount: Int = 0
    private var allocationCount: Int = 0
    private var releaseCount: Int = 0
    
    /// Creates an object pool
    /// - Parameters:
    ///   - maxPoolSize: Maximum number of objects to keep in the pool
    ///   - factory: Factory function to create new objects
    ///   - reset: Optional function to reset an object before reuse
    public init(
        maxPoolSize: Int = 100,
        factory: @escaping @Sendable () -> T,
        reset: (@Sendable (inout T) -> Void)? = nil
    ) {
        self.available = []
        self.maxPoolSize = maxPoolSize
        self.factory = factory
        self.reset = reset
    }
    
    /// Acquires an object from the pool
    /// - Returns: An object (either reused from pool or newly created)
    public func acquire() -> T {
        acquireCount += 1
        
        if var object = available.popLast() {
            reuseCount += 1
            // Reset the object if a reset function is provided
            if let resetFunc = reset {
                resetFunc(&object)
            }
            return object
        } else {
            allocationCount += 1
            return factory()
        }
    }
    
    /// Returns an object to the pool for reuse
    /// - Parameter object: The object to return
    public func release(_ object: T) {
        releaseCount += 1
        
        guard available.count < maxPoolSize else {
            // Pool is full, let the object be deallocated
            return
        }
        
        available.append(object)
    }
    
    /// Gets current pool statistics
    public func statistics() -> PoolStatistics {
        PoolStatistics(
            availableCount: available.count,
            acquireCount: acquireCount,
            reuseCount: reuseCount,
            allocationCount: allocationCount,
            releaseCount: releaseCount
        )
    }
    
    /// Clears all pooled objects and resets statistics
    public func clear() {
        available.removeAll()
        acquireCount = 0
        reuseCount = 0
        allocationCount = 0
        releaseCount = 0
    }
    
    /// Preallocates objects in the pool
    /// - Parameter count: Number of objects to preallocate
    public func preallocate(_ count: Int) {
        let toCreate = min(count, maxPoolSize - available.count)
        for _ in 0..<toCreate {
            available.append(factory())
        }
    }
}

// MARK: - Specialized Pools

/// Thread-safe pool for Field objects
public actor FieldPool {
    private let pool: ObjectPool<FieldStorage>
    
    /// Storage for pooled field data
    public struct FieldStorage: Sendable {
        public var repetitions: [[Component]]
        public var encodingCharacters: EncodingCharacters
        
        public init() {
            self.repetitions = []
            self.encodingCharacters = .standard
        }
        
        mutating func reset() {
            repetitions.removeAll(keepingCapacity: true)
            encodingCharacters = .standard
        }
    }
    
    /// Creates a field pool
    /// - Parameter maxPoolSize: Maximum number of fields to keep in the pool
    public init(maxPoolSize: Int = 100) {
        self.pool = ObjectPool(
            maxPoolSize: maxPoolSize,
            factory: { FieldStorage() },
            reset: { storage in storage.reset() }
        )
    }
    
    /// Acquires a field storage from the pool
    public func acquire() async -> FieldStorage {
        return await pool.acquire()
    }
    
    /// Returns field storage to the pool
    public func release(_ storage: FieldStorage) async {
        await pool.release(storage)
    }
    
    /// Gets pool statistics
    public func statistics() async -> PoolStatistics {
        return await pool.statistics()
    }
    
    /// Clears the pool
    public func clear() async {
        await pool.clear()
    }
    
    /// Preallocates field storage objects
    public func preallocate(_ count: Int) async {
        await pool.preallocate(count)
    }
}

/// Thread-safe pool for Component objects
public actor ComponentPool {
    private let pool: ObjectPool<ComponentStorage>
    
    /// Storage for pooled component data
    public struct ComponentStorage: Sendable {
        public var subcomponents: [Subcomponent]
        public var encodingCharacters: EncodingCharacters
        
        public init() {
            self.subcomponents = []
            self.encodingCharacters = .standard
        }
        
        mutating func reset() {
            subcomponents.removeAll(keepingCapacity: true)
            encodingCharacters = .standard
        }
    }
    
    /// Creates a component pool
    /// - Parameter maxPoolSize: Maximum number of components to keep in the pool
    public init(maxPoolSize: Int = 100) {
        self.pool = ObjectPool(
            maxPoolSize: maxPoolSize,
            factory: { ComponentStorage() },
            reset: { storage in storage.reset() }
        )
    }
    
    /// Acquires component storage from the pool
    public func acquire() async -> ComponentStorage {
        return await pool.acquire()
    }
    
    /// Returns component storage to the pool
    public func release(_ storage: ComponentStorage) async {
        await pool.release(storage)
    }
    
    /// Gets pool statistics
    public func statistics() async -> PoolStatistics {
        return await pool.statistics()
    }
    
    /// Clears the pool
    public func clear() async {
        await pool.clear()
    }
    
    /// Preallocates component storage objects
    public func preallocate(_ count: Int) async {
        await pool.preallocate(count)
    }
}

/// Thread-safe pool for BaseSegment objects
public actor SegmentPool {
    private let pool: ObjectPool<SegmentStorage>
    
    /// Storage for pooled segment data
    public struct SegmentStorage: Sendable {
        public var segmentID: String
        public var fields: [Field]
        public var encodingCharacters: EncodingCharacters
        
        public init() {
            self.segmentID = ""
            self.fields = []
            self.encodingCharacters = .standard
        }
        
        mutating func reset() {
            segmentID = ""
            fields.removeAll(keepingCapacity: true)
            encodingCharacters = .standard
        }
    }
    
    /// Creates a segment pool
    /// - Parameter maxPoolSize: Maximum number of segments to keep in the pool
    public init(maxPoolSize: Int = 100) {
        self.pool = ObjectPool(
            maxPoolSize: maxPoolSize,
            factory: { SegmentStorage() },
            reset: { storage in storage.reset() }
        )
    }
    
    /// Acquires segment storage from the pool
    public func acquire() async -> SegmentStorage {
        return await pool.acquire()
    }
    
    /// Returns segment storage to the pool
    public func release(_ storage: SegmentStorage) async {
        await pool.release(storage)
    }
    
    /// Gets pool statistics
    public func statistics() async -> PoolStatistics {
        return await pool.statistics()
    }
    
    /// Clears the pool
    public func clear() async {
        await pool.clear()
    }
    
    /// Preallocates segment storage objects
    public func preallocate(_ count: Int) async {
        await pool.preallocate(count)
    }
}

// MARK: - Global Pools

/// Shared pools for the HL7v2Kit module
///
/// These global pools can be used throughout the module for object reuse.
/// They are particularly useful during high-throughput message parsing.
public struct GlobalPools {
    /// Shared segment pool
    public static let segments = SegmentPool()
    
    /// Shared field pool
    public static let fields = FieldPool()
    
    /// Shared component pool
    public static let components = ComponentPool()
    
    /// Gets combined statistics from all pools
    public static func allStatistics() async -> (
        segments: PoolStatistics,
        fields: PoolStatistics,
        components: PoolStatistics
    ) {
        async let segStats = segments.statistics()
        async let fieldStats = fields.statistics()
        async let compStats = components.statistics()
        
        return await (segStats, fieldStats, compStats)
    }
    
    /// Clears all global pools
    public static func clearAll() async {
        await segments.clear()
        await fields.clear()
        await components.clear()
    }
    
    /// Preallocates objects in all pools
    /// - Parameter count: Number of objects to preallocate in each pool
    public static func preallocateAll(_ count: Int) async {
        await segments.preallocate(count)
        await fields.preallocate(count)
        await components.preallocate(count)
    }
}
