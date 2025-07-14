import Foundation

typealias RecyclableHandle = Recyclable<SQLiteHandlePool.HandleWrap>
typealias RecyclableHandlePool = Recyclable<SQLiteHandlePool>

final class SQLiteHandlePool {
    
    private final class Wrap {
        let handlePool: SQLiteHandlePool
        var reference: Int = 0
        init(_ handlePool: SQLiteHandlePool) {
            self.handlePool = handlePool
        }
    }
    
    private static let spin = Spin()
    private static var pools: [String: Wrap] = [:]
    private static let maxConcurrency = max(maxHardwareConcurrency, 64)
    private static let maxHardwareConcurrency = ProcessInfo.processInfo.processorCount
    
    static func getHandlePool(with path: String) -> RecyclableHandlePool {
        spin.lock()
        defer { spin.unlock() }
        
        var idx = pools.index(forKey: path)
        if idx == nil {
            let handlePool = SQLiteHandlePool(path: path)
            pools[path] = Wrap(handlePool)
            idx = pools.index(forKey: path)
        }
        
        let node = pools[idx!]
        node.value.reference += 1
        let path = node.key
        return RecyclableHandlePool(node.value.handlePool) {
            spin.lock()
            defer { spin.unlock() }
            let wrap = pools[path]!
            wrap.reference -= 1
            if wrap.reference == 0 {
                pools.removeValue(forKey: path)
            }
        }
    }
    
    
    typealias HandleWrap = SQLiteHandle
    private var handles = ConcurrentList<HandleWrap>(capacity: maxHardwareConcurrency)
    let path: String
    private let wwlock = UnfairLock()
    
    func wLock() {
        wwlock.lock()
    }
    
    func wUnlock() {
        wwlock.unlock()
    }
    
    private let rwlock = RWLock()
    private let aliveHandleCount = Atomic<Int>(0)
    
    private init(path: String) {
        self.path = path
    }
    
    var isDrained: Bool {
        return aliveHandleCount == 0
    }
    
    func fillOne() throws {
        rwlock.lockRead()
        defer { rwlock.unlockRead() }
        let handle = try generate()
        if handles.pushBack(handle) {
            aliveHandleCount += 1
        }
    }
    
    func flowOut() throws -> RecyclableHandle {
        var unlock = true
        rwlock.lockRead()
        defer { if unlock { rwlock.unlockRead() } }
        var handleWrap = handles.popBack()
        if handleWrap == nil {
            guard aliveHandleCount < SQLiteHandlePool.maxConcurrency else { throw SQLiteError(code: 0, description: "The concurrency of database exceeds the max concurrency") }
            handleWrap = try generate()
            aliveHandleCount += 1
            if aliveHandleCount > SQLiteHandlePool.maxHardwareConcurrency {
                var warning = "The concurrency of database: \(path) with \(aliveHandleCount)"
                warning.append(" exceeds the concurrency of hardware: \(SQLiteHandlePool.maxHardwareConcurrency)")
                SQLiteError.warning(warning)
            }
        }
        unlock = false
        
        return RecyclableHandle(handleWrap!, onRecycled: { self.flowBack(handleWrap!) })
    }
    
    private func flowBack(_ handleWrap: HandleWrap) {
        let inserted = handles.pushBack(handleWrap)
        rwlock.unlockRead()
        if !inserted {
            aliveHandleCount -= 1
        }
    }
    
    private func generate() throws -> HandleWrap {
        let handle = SQLiteHandle(withPath: path)
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

    func drain(onDrained: OnDrained) rethrows {
        blockade()
        defer { unblockade() }
        let size = handles.clear()
        aliveHandleCount -= size
        try onDrained()
    }

    func drain() {
        blockade()
        defer { unblockade() }
        let size = handles.clear()
        aliveHandleCount -= size
    }

    func purgeFreeHandles() {
        rwlock.lockRead()
        defer { rwlock.unlockRead() }
        let size = handles.clear()
        aliveHandleCount -= size
    }
    
    static func purgeFreeHandlesInAllPools() {
        let handlePools: [SQLiteHandlePool]!
        do {
            spin.lock()
            defer { spin.unlock() }
            handlePools = pools.values.reduce(into: []) { $0.append($1.handlePool) }
        }
        handlePools.forEach { $0.purgeFreeHandles() }
    }

}
