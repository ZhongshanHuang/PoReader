import Foundation
import SQLite3

final class SQLiteHandlePool: @unchecked Sendable {
    struct Key: Hashable, Sendable {
        let path: String
        let configuration: SQLiteConfiguration
    }
    
    private static let pools = SQLiteMutex<[ObjectIdentifier: SQLiteHandlePool]>([:])
    private static let maxHardwareConcurrency = ProcessInfo.processInfo.processorCount
    
    static func makeHandlePool(with path: String, configuration: SQLiteConfiguration) -> SQLiteHandlePoolReference {
        let key = Key(path: path, configuration: configuration)
        let pool = SQLiteHandlePool(key: key)
        let identity = ObjectIdentifier(pool)

        pools.withLock { pools in
            pools[identity] = pool
        }
        return SQLiteHandlePoolReference(pool) {
            _ = Self.pools.withLock { pools in
                pools.removeValue(forKey: identity)
            }
        }
    }
    
    
    typealias HandleWrap = SQLiteHandle
    let key: Key
    var path: String { key.path }
    var configuration: SQLiteConfiguration { key.configuration }
    private let writeLock = SQLiteMutex<Void>(())

    func withWriteLock<T>(_ body: () throws -> T) rethrows -> T {
        try writeLock.withLock { _ in
            try body()
        }
    }
    
    private let stateLock = ConditionLock()
    private let maximumConnectionCount: Int
    private let maximumIdleConnectionCount: Int
    private var idleHandles: [HandleWrap] = []
    private var aliveHandleCount = 0
    private var activeHandleUseCount = 0
    private var closed = false
    
    private init(key: Key) {
        self.key = key
        self.maximumConnectionCount = Self.maximumConnectionCount(for: key)
        self.maximumIdleConnectionCount = Self.maximumIdleConnectionCount(for: key)
        self.idleHandles.reserveCapacity(maximumIdleConnectionCount)
    }
    
    var isDrained: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return aliveHandleCount == 0
    }

    var isClosed: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return closed
    }
    
    func fillOne() throws {
        let count = try reserveHandleUseForGeneration()
        warnIfNeeded(aliveHandleCount: count)

        let handle: HandleWrap
        do {
            handle = try generate()
        } catch {
            releaseReservedHandleUse()
            throw error
        }

        storeGeneratedIdleHandle(handle)
    }
    
    func flowOut() throws -> SQLitePooledHandleLease {
        var deadline: UInt64?
        var didResolveDeadline = false
        func resolvedDeadline() -> UInt64? {
            if !didResolveDeadline {
                deadline = checkoutDeadline()
                didResolveDeadline = true
            }
            return deadline
        }

        while true {
            stateLock.lock()

            if closed {
                stateLock.unlock()
                throw databaseClosedError()
            }

            if let handle = idleHandles.popLast() {
                activeHandleUseCount += 1
                stateLock.unlock()
                return SQLitePooledHandleLease(handle, onReturn: { self.flowBack(handle) })
            }

            if aliveHandleCount < maximumConnectionCount {
                aliveHandleCount += 1
                activeHandleUseCount += 1
                let count = aliveHandleCount
                stateLock.unlock()
                warnIfNeeded(aliveHandleCount: count)

                let handle: HandleWrap
                do {
                    handle = try generate()
                } catch {
                    releaseReservedHandleUse()
                    throw error
                }
                return SQLitePooledHandleLease(handle, onReturn: { self.flowBack(handle) })
            }

            guard let deadline = resolvedDeadline() else {
                stateLock.unlock()
                throw maximumConnectionCountError()
            }

            let now = DispatchTime.now().uptimeNanoseconds
            guard deadline > now else {
                stateLock.unlock()
                throw maximumConnectionCountError()
            }

            let timeout = TimeInterval(deadline - now) / 1_000_000_000
            stateLock.wait(timeout: timeout)
            stateLock.unlock()
        }
    }
    
    private func flowBack(_ handleWrap: HandleWrap) {
        stateLock.lock()
        assert(activeHandleUseCount > 0)
        activeHandleUseCount -= 1
        if closed || idleHandles.count >= maximumIdleConnectionCount {
            assert(aliveHandleCount > 0)
            aliveHandleCount -= 1
        } else {
            idleHandles.append(handleWrap)
        }
        stateLock.broadcast()
        stateLock.unlock()
    }
    
    private func generate() throws -> HandleWrap {
        let handle = SQLiteHandle(withPath: path, configuration: configuration)
        try handle.open()
        return handle
    }
    
    typealias OnDrained = () throws -> Void

    func close(onClosed: OnDrained) rethrows {
        var discardedHandles = closeAndDrainIdleHandles()
        discardedHandles.removeAll()
        try onClosed()
    }

    func close() {
        var discardedHandles = closeAndDrainIdleHandles()
        discardedHandles.removeAll()
    }

    func purgeFreeHandles() {
        var discardedHandles = removeIdleHandles()
        discardedHandles.removeAll()
    }

    func purgeStatementCaches() {
        stateLock.lock()
        defer { stateLock.unlock() }
        for handle in idleHandles {
            handle.purgeStatementCache()
        }
    }

    var cachedStatementCount: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        var total = 0
        for handle in idleHandles {
            total += handle.cachedStatementCount
        }
        return total
    }
    
    static func purgeFreeHandlesInAllPools() {
        let handlePools = pools.withLock { pools in
            Array(pools.values)
        }
        handlePools.forEach { $0.purgeFreeHandles() }
    }

    static func purgeStatementCachesInAllPools() {
        let handlePools = pools.withLock { pools in
            Array(pools.values)
        }
        handlePools.forEach { $0.purgeStatementCaches() }
    }

}

private extension SQLiteHandlePool {
    func checkoutDeadline() -> UInt64? {
        guard let milliseconds = configuration.connectionCheckoutTimeoutMilliseconds else {
            return nil
        }
        let now = DispatchTime.now().uptimeNanoseconds
        let (nanoseconds, multiplicationOverflow) = UInt64(milliseconds).multipliedReportingOverflow(by: 1_000_000)
        guard !multiplicationOverflow else { return UInt64.max }
        let (deadline, additionOverflow) = now.addingReportingOverflow(nanoseconds)
        return additionOverflow ? UInt64.max : deadline
    }

    func reserveHandleUseForGeneration() throws -> Int {
        stateLock.lock()
        if closed {
            stateLock.unlock()
            throw databaseClosedError()
        }

        guard aliveHandleCount < maximumConnectionCount else {
            stateLock.unlock()
            throw maximumConnectionCountError()
        }

        aliveHandleCount += 1
        activeHandleUseCount += 1
        let count = aliveHandleCount
        stateLock.unlock()
        return count
    }

    func releaseReservedHandleUse() {
        stateLock.lock()
        assert(activeHandleUseCount > 0)
        assert(aliveHandleCount > 0)
        activeHandleUseCount -= 1
        aliveHandleCount -= 1
        stateLock.broadcast()
        stateLock.unlock()
    }

    func storeGeneratedIdleHandle(_ handle: HandleWrap) {
        stateLock.lock()
        assert(activeHandleUseCount > 0)
        activeHandleUseCount -= 1
        if closed || idleHandles.count >= maximumIdleConnectionCount {
            assert(aliveHandleCount > 0)
            aliveHandleCount -= 1
        } else {
            idleHandles.append(handle)
        }
        stateLock.broadcast()
        stateLock.unlock()
    }

    func closeAndDrainIdleHandles() -> [HandleWrap] {
        stateLock.lock()
        closed = true
        let discardedHandles = takeIdleHandlesLocked()
        stateLock.broadcast()

        while activeHandleUseCount > 0 {
            stateLock.wait()
        }

        stateLock.unlock()
        return discardedHandles
    }

    func removeIdleHandles() -> [HandleWrap] {
        stateLock.lock()
        let discardedHandles = takeIdleHandlesLocked()
        stateLock.broadcast()
        stateLock.unlock()
        return discardedHandles
    }

    func takeIdleHandlesLocked() -> [HandleWrap] {
        var discardedHandles: [HandleWrap] = []
        swap(&discardedHandles, &idleHandles)
        idleHandles.reserveCapacity(maximumIdleConnectionCount)
        assert(aliveHandleCount >= discardedHandles.count)
        aliveHandleCount -= discardedHandles.count
        return discardedHandles
    }

    func warnIfNeeded(aliveHandleCount count: Int) {
        if count > SQLiteHandlePool.maxHardwareConcurrency {
            var warning = "The concurrency of database: \(path) with \(count)"
            warning.append(" exceeds the concurrency of hardware: \(SQLiteHandlePool.maxHardwareConcurrency)")
            SQLiteError.warning(warning)
        }
    }

    func maximumConnectionCountError() -> SQLiteError {
        SQLiteError(
            code: SQLITE_BUSY,
            description: "Timed out waiting for an available database connection. The configured maximum connection count is \(maximumConnectionCount).",
            operation: "open_handle"
        )
    }

    func databaseClosedError() -> SQLiteError {
        SQLiteError(
            code: SQLITE_MISUSE,
            description: "Database is closed.",
            operation: "open_handle"
        )
    }

    static func maximumConnectionCount(for key: Key) -> Int {
        key.path == ":memory:" ? 1 : key.configuration.maximumConnectionCount
    }

    static func maximumIdleConnectionCount(for key: Key) -> Int {
        key.path == ":memory:" ? 1 : key.configuration.maximumIdleConnectionCount
    }
}
