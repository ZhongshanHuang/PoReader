import Foundation
import SQLite3

final class SQLiteHandlePool: @unchecked Sendable {
    struct Key: Hashable, Sendable {
        let path: String
        let configuration: SQLiteConfiguration
    }
    
    private final class Wrap: @unchecked Sendable {
        let handlePool: SQLiteHandlePool
        var reference: Int = 0
        init(_ handlePool: SQLiteHandlePool) {
            self.handlePool = handlePool
        }
    }
    
    private static let pools = SQLiteMutex<[Key: Wrap]>([:])
    private static var maxHardwareConcurrency: Int { ProcessInfo.processInfo.processorCount }
    
    static func getHandlePool(with path: String, configuration: SQLiteConfiguration) -> SQLiteHandlePoolReference {
        let key = Key(path: path, configuration: configuration)

        return pools.withLock { pools in
            let wrap: Wrap
            if let existing = pools[key], !existing.handlePool.isClosed {
                wrap = existing
            } else {
                let handlePool = SQLiteHandlePool(key: key)
                wrap = Wrap(handlePool)
                pools[key] = wrap
            }

            wrap.reference += 1
            return SQLiteHandlePoolReference(wrap.handlePool) {
                Self.pools.withLock { pools in
                    wrap.reference -= 1
                    if wrap.reference == 0, let current = pools[key], current === wrap {
                        pools.removeValue(forKey: key)
                    }
                }
            }
        }
    }
    
    
    typealias HandleWrap = SQLiteHandle
    private let handles: ConcurrentList<HandleWrap>
    let key: Key
    var path: String { key.path }
    var configuration: SQLiteConfiguration { key.configuration }
    private let writeLock = SQLiteMutex<Void>(())

    func withWriteLock<T>(_ body: () throws -> T) rethrows -> T {
        try writeLock.withLock { _ in
            try body()
        }
    }
    
    private let rwlock = RWLock()
    private let checkoutLock = ConditionLock()
    private var aliveHandleCount = 0
    private var closed = false
    
    private init(key: Key) {
        self.key = key
        self.handles = ConcurrentList<HandleWrap>(capacity: Self.maximumIdleConnectionCount(for: key))
    }
    
    var isDrained: Bool {
        checkoutLock.lock()
        defer { checkoutLock.unlock() }
        return aliveHandleCount == 0
    }

    var isClosed: Bool {
        checkoutLock.lock()
        defer { checkoutLock.unlock() }
        return closed
    }
    
    func fillOne() throws {
        rwlock.lockRead()
        defer { rwlock.unlockRead() }
        try reserveAliveHandleSlot()

        let handle: HandleWrap
        do {
            handle = try generate()
        } catch {
            releaseAliveHandleSlots(1)
            throw error
        }

        if !handles.pushBack(handle) {
            releaseAliveHandleSlots(1)
        }
    }
    
    func flowOut() throws -> SQLitePooledHandleLease {
        let deadline = checkoutDeadline()
        while true {
            var unlockRead = true
            rwlock.lockRead()
            do {
                try throwIfClosed()

                if let handle = handles.popBack() {
                    unlockRead = false
                    return SQLitePooledHandleLease(handle, onReturn: { self.flowBack(handle) })
                }

                if try reserveAliveHandleSlotIfAvailable() {
                    let handle: HandleWrap
                    do {
                        handle = try generate()
                    } catch {
                        releaseAliveHandleSlots(1)
                        throw error
                    }
                    unlockRead = false
                    return SQLitePooledHandleLease(handle, onReturn: { self.flowBack(handle) })
                }
            } catch {
                if unlockRead {
                    rwlock.unlockRead()
                }
                throw error
            }

            rwlock.unlockRead()
            try waitForAvailableHandle(until: deadline)
        }
    }
    
    private func flowBack(_ handleWrap: HandleWrap) {
        let inserted = handles.pushBack(handleWrap)
        rwlock.unlockRead()
        if !inserted {
            releaseAliveHandleSlots(1)
        } else {
            signalCheckoutWaiter()
        }
    }
    
    private func generate() throws -> HandleWrap {
        let handle = SQLiteHandle(withPath: path, configuration: configuration)
        try handle.open()
        return handle
    }
    
    func blockade() {
        rwlock.lockWrite()
    }

    func unblockade() {
        rwlock.unlockWrite()
    }

    var isBlockaded: Bool {
        return rwlock.isWriting
    }

    typealias OnDrained = () throws -> Void

    func close(onClosed: OnDrained) rethrows {
        blockade()
        defer { unblockade() }
        markClosed()
        let size = handles.clear()
        releaseAliveHandleSlots(size)
        try onClosed()
    }

    func close() {
        blockade()
        defer { unblockade() }
        markClosed()
        let size = handles.clear()
        releaseAliveHandleSlots(size)
    }

    func purgeFreeHandles() {
        rwlock.lockRead()
        defer { rwlock.unlockRead() }
        let size = handles.clear()
        releaseAliveHandleSlots(size)
    }
    
    static func purgeFreeHandlesInAllPools() {
        let handlePools = pools.withLock { pools in
            Array(pools.values.map(\.handlePool))
        }
        handlePools.forEach { $0.purgeFreeHandles() }
    }

}

private extension SQLiteHandlePool {
    func checkoutDeadline() -> Date? {
        guard let milliseconds = configuration.connectionCheckoutTimeoutMilliseconds else {
            return nil
        }
        return Date().addingTimeInterval(Double(milliseconds) / 1_000)
    }

    func throwIfClosed() throws {
        checkoutLock.lock()
        defer { checkoutLock.unlock() }
        try throwIfClosedLocked()
    }

    func throwIfClosedLocked() throws {
        if closed {
            throw databaseClosedError()
        }
    }

    func reserveAliveHandleSlot() throws {
        guard try reserveAliveHandleSlotIfAvailable() else {
            throw maximumConnectionCountError()
        }
    }

    func reserveAliveHandleSlotIfAvailable() throws -> Bool {
        checkoutLock.lock()
        if closed {
            checkoutLock.unlock()
            throw databaseClosedError()
        }

        guard aliveHandleCount < maximumConnectionCount else {
            checkoutLock.unlock()
            return false
        }
        aliveHandleCount += 1
        let count = aliveHandleCount
        checkoutLock.unlock()

        if count > SQLiteHandlePool.maxHardwareConcurrency {
            var warning = "The concurrency of database: \(path) with \(count)"
            warning.append(" exceeds the concurrency of hardware: \(SQLiteHandlePool.maxHardwareConcurrency)")
            SQLiteError.warning(warning)
        }
        return true
    }

    func releaseAliveHandleSlots(_ count: Int) {
        guard count > 0 else { return }

        checkoutLock.lock()
        aliveHandleCount = max(0, aliveHandleCount - count)
        checkoutLock.broadcast()
        checkoutLock.unlock()
    }

    func markClosed() {
        checkoutLock.lock()
        closed = true
        checkoutLock.broadcast()
        checkoutLock.unlock()
    }

    func waitForAvailableHandle(until deadline: Date?) throws {
        guard let deadline else {
            throw maximumConnectionCountError()
        }

        checkoutLock.lock()
        defer { checkoutLock.unlock() }
        try throwIfClosedLocked()

        if !handles.isEmpty || aliveHandleCount < maximumConnectionCount {
            return
        }

        let timeout = deadline.timeIntervalSinceNow
        guard timeout > 0 else {
            throw maximumConnectionCountError()
        }
        checkoutLock.wait(timeout: timeout)
        try throwIfClosedLocked()
    }

    func signalCheckoutWaiter() {
        checkoutLock.lock()
        checkoutLock.signal()
        checkoutLock.unlock()
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

    var maximumConnectionCount: Int {
        path == ":memory:" ? 1 : configuration.maximumConnectionCount
    }

    static func maximumIdleConnectionCount(for key: Key) -> Int {
        key.path == ":memory:" ? 1 : key.configuration.maximumIdleConnectionCount
    }
}
