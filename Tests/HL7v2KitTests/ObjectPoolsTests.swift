/// Unit tests for object pooling functionality
///
/// Tests for ObjectPool, SegmentPool, FieldPool, ComponentPool, and GlobalPools

import XCTest
@testable import HL7v2Kit
import HL7Core

final class ObjectPoolsTests: XCTestCase {
    
    // MARK: - Generic ObjectPool Tests
    
    func testObjectPoolBasicAcquireRelease() async throws {
        let pool = ObjectPool<Int>(maxPoolSize: 10) { 42 }
        
        let value1 = await pool.acquire()
        XCTAssertEqual(value1, 42)
        
        await pool.release(value1)
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 1)
        XCTAssertEqual(stats.acquireCount, 1)
        XCTAssertEqual(stats.releaseCount, 1)
    }
    
    func testObjectPoolReuse() async throws {
        let pool = ObjectPool<Int>(maxPoolSize: 10) {
            // Return a unique value each time
            return Int.random(in: 1...1000)
        }
        
        // Acquire and release multiple times
        let value1 = await pool.acquire()
        await pool.release(value1)
        
        let value2 = await pool.acquire()
        await pool.release(value2)
        
        let stats = await pool.statistics()
        XCTAssertGreaterThanOrEqual(stats.reuseCount, 1, "Should reuse at least once")
        XCTAssertEqual(stats.acquireCount, 2)
    }
    
    func testObjectPoolMaxSize() async throws {
        let pool = ObjectPool<Int>(maxPoolSize: 3) { 0 }
        
        // Release more objects than max pool size
        for i in 0..<10 {
            await pool.release(i)
        }
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 3, "Pool should not exceed max size")
    }
    
    func testObjectPoolReset() async throws {
        struct Counter: Sendable {
            var value: Int
        }
        
        let pool = ObjectPool<Counter>(
            maxPoolSize: 10,
            factory: { Counter(value: 0) },
            reset: { counter in counter.value = 0 }
        )
        
        var obj = await pool.acquire()
        obj.value = 99
        await pool.release(obj)
        
        let reused = await pool.acquire()
        XCTAssertEqual(reused.value, 0, "Object should be reset before reuse")
    }
    
    func testObjectPoolPreallocate() async throws {
        let pool = ObjectPool<Int>(maxPoolSize: 20) { 42 }
        
        await pool.preallocate(10)
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 10)
    }
    
    func testObjectPoolClear() async throws {
        let pool = ObjectPool<Int>(maxPoolSize: 10) { 42 }
        
        await pool.preallocate(5)
        let _ = await pool.acquire()
        
        await pool.clear()
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 0)
        XCTAssertEqual(stats.acquireCount, 0)
        XCTAssertEqual(stats.releaseCount, 0)
    }
    
    func testObjectPoolStatistics() async throws {
        let pool = ObjectPool<Int>(maxPoolSize: 10) { 42 }
        
        // Preallocate
        await pool.preallocate(3)
        
        // Acquire and release pattern
        let _ = await pool.acquire()  // reuse
        let _ = await pool.acquire()  // reuse
        let _ = await pool.acquire()  // reuse
        let _ = await pool.acquire()  // allocation
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.acquireCount, 4)
        XCTAssertEqual(stats.reuseCount, 3)
        XCTAssertEqual(stats.allocationCount, 1)
    }
    
    // MARK: - SegmentPool Tests
    
    func testSegmentPoolBasic() async throws {
        let pool = SegmentPool(maxPoolSize: 10)
        
        let storage = await pool.acquire()
        XCTAssertTrue(storage.segmentID.isEmpty)
        XCTAssertTrue(storage.fields.isEmpty)
        
        await pool.release(storage)
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 1)
    }
    
    func testSegmentPoolReset() async throws {
        let pool = SegmentPool(maxPoolSize: 10)
        
        var storage = await pool.acquire()
        storage.segmentID = "PID"
        storage.fields = [Field(repetitions: [], encodingCharacters: .standard)]
        
        await pool.release(storage)
        
        let reused = await pool.acquire()
        XCTAssertTrue(reused.segmentID.isEmpty, "Segment ID should be reset")
        XCTAssertTrue(reused.fields.isEmpty, "Fields should be reset")
    }
    
    // MARK: - FieldPool Tests
    
    func testFieldPoolBasic() async throws {
        let pool = FieldPool(maxPoolSize: 10)
        
        let storage = await pool.acquire()
        XCTAssertTrue(storage.repetitions.isEmpty)
        
        await pool.release(storage)
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 1)
    }
    
    func testFieldPoolReset() async throws {
        let pool = FieldPool(maxPoolSize: 10)
        
        var storage = await pool.acquire()
        storage.repetitions = [[Component(subcomponents: [], encodingCharacters: .standard)]]
        
        await pool.release(storage)
        
        let reused = await pool.acquire()
        XCTAssertTrue(reused.repetitions.isEmpty, "Repetitions should be reset")
    }
    
    // MARK: - ComponentPool Tests
    
    func testComponentPoolBasic() async throws {
        let pool = ComponentPool(maxPoolSize: 10)
        
        let storage = await pool.acquire()
        XCTAssertTrue(storage.subcomponents.isEmpty)
        
        await pool.release(storage)
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.availableCount, 1)
    }
    
    func testComponentPoolReset() async throws {
        let pool = ComponentPool(maxPoolSize: 10)
        
        var storage = await pool.acquire()
        storage.subcomponents = [Subcomponent(rawValue: "test", encodingCharacters: .standard)]
        
        await pool.release(storage)
        
        let reused = await pool.acquire()
        XCTAssertTrue(reused.subcomponents.isEmpty, "Subcomponents should be reset")
    }
    
    // MARK: - GlobalPools Tests
    
    func testGlobalPoolsAllStatistics() async throws {
        await GlobalPools.clearAll()
        await GlobalPools.preallocateAll(5)
        
        let stats = await GlobalPools.allStatistics()
        
        XCTAssertEqual(stats.segments.availableCount, 5)
        XCTAssertEqual(stats.fields.availableCount, 5)
        XCTAssertEqual(stats.components.availableCount, 5)
    }
    
    func testGlobalPoolsClearAll() async throws {
        await GlobalPools.preallocateAll(10)
        await GlobalPools.clearAll()
        
        let stats = await GlobalPools.allStatistics()
        
        XCTAssertEqual(stats.segments.availableCount, 0)
        XCTAssertEqual(stats.fields.availableCount, 0)
        XCTAssertEqual(stats.components.availableCount, 0)
    }
    
    func testGlobalPoolsThreadSafety() async throws {
        await GlobalPools.clearAll()
        
        // Concurrent access to global pools
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    for _ in 0..<100 {
                        let storage = await GlobalPools.segments.acquire()
                        await GlobalPools.segments.release(storage)
                    }
                }
            }
        }
        
        let stats = await GlobalPools.segments.statistics()
        XCTAssertGreaterThan(stats.reuseRate, 0.8, "Should have high reuse rate with concurrent access")
    }
    
    // MARK: - PoolStatistics Tests
    
    func testPoolStatisticsReuseRate() {
        let stats1 = PoolStatistics(
            availableCount: 5,
            acquireCount: 100,
            reuseCount: 80,
            allocationCount: 20,
            releaseCount: 100
        )
        XCTAssertEqual(stats1.reuseRate, 0.8, accuracy: 0.001)
        
        let stats2 = PoolStatistics(
            availableCount: 0,
            acquireCount: 0,
            reuseCount: 0,
            allocationCount: 0,
            releaseCount: 0
        )
        XCTAssertEqual(stats2.reuseRate, 0.0)
    }
    
    func testPoolStatisticsEquatable() {
        let stats1 = PoolStatistics(
            availableCount: 5,
            acquireCount: 10,
            reuseCount: 8,
            allocationCount: 2,
            releaseCount: 5
        )
        let stats2 = PoolStatistics(
            availableCount: 5,
            acquireCount: 10,
            reuseCount: 8,
            allocationCount: 2,
            releaseCount: 5
        )
        let stats3 = PoolStatistics(
            availableCount: 3,
            acquireCount: 10,
            reuseCount: 8,
            allocationCount: 2,
            releaseCount: 5
        )
        
        XCTAssertEqual(stats1, stats2)
        XCTAssertNotEqual(stats1, stats3)
    }
    
    // MARK: - Performance Tests
    
    func testPoolPerformanceVsDirectAllocation() async throws {
        let iterations = 1000
        
        // Direct allocation (no pooling)
        let directStart = Date()
        for _ in 0..<iterations {
            var storage = SegmentPool.SegmentStorage()
            storage.segmentID = "PID"
            _ = storage
        }
        let directDuration = Date().timeIntervalSince(directStart)
        
        // Using pool
        let pool = SegmentPool(maxPoolSize: 50)
        await pool.preallocate(50)
        
        let poolStart = Date()
        for _ in 0..<iterations {
            var storage = await pool.acquire()
            storage.segmentID = "PID"
            await pool.release(storage)
        }
        let poolDuration = Date().timeIntervalSince(poolStart)
        
        print("📊 Pool Performance:")
        print("   - Direct Allocation: \(String(format: "%.6f", directDuration))s")
        print("   - Pool Reuse: \(String(format: "%.6f", poolDuration))s")
        print("   - Speedup: \(String(format: "%.2f", directDuration / poolDuration))x")
    }
}
