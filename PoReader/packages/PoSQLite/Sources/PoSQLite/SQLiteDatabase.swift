#if canImport(UIKit)
import UIKit
#endif
import Foundation
import SQLite3

public final class SQLiteDatabase {
    private let recyclableHandlePool: RecyclableHandlePool
    
    private var handlePool: SQLiteHandlePool {
        recyclableHandlePool.rawValue
    }
    
    public var path: String {
        handlePool.path
    }
    
    public convenience init(path: String) {
        self.init(fileURL: URL(fileURLWithPath: path))
    }
    
    public init(fileURL: URL) {
        self.recyclableHandlePool = SQLiteHandlePool.getHandlePool(with: fileURL.standardizedFileURL.path)

#if canImport(UIKit)
        DispatchQueue.once(name: "com.potato.sqlite.swift.purge", {
            let purgeFreeHandleQueue: DispatchQueue = DispatchQueue(label: "com.potato.sqlite.swift.purge")
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil,
                using: { (_) in
                    purgeFreeHandleQueue.async {
                        SQLiteDatabase.purge()
                    }
                })
        })
#endif
    }
    
    private static var threadedHandles = ThreadLocal<[String: RecyclableHandle]>(defaultValue: [:])
    
    func flowOut() throws -> RecyclableHandle {
        if let handle = Self.threadedHandles.value[path] {
            return handle
        }
        let handle = try handlePool.flowOut()
        return handle
    }

    /// Since It is using lazy initialization,
    /// `init(withPath:)`, `init(withFileURL:)` never failed even the database can't open.
    /// So you can call this to check whether the database can be opened.
    /// Return false if an error occurs during sqlite handle initialization.
    public var canOpen: Bool {
        return !handlePool.isDrained || ((try? handlePool.fillOne()) != nil)
    }

    /// Check database is already opened.
    public var isOpened: Bool {
        return !handlePool.isDrained
    }

    /// Check whether database is blockaded.
    public var isBlockaded: Bool {
        return handlePool.isBlockaded
    }
    
    public typealias OnClosed = () throws -> Void
    
    public func close(onClosed: OnClosed) rethrows {
        try handlePool.drain(onDrained: onClosed)
    }

    /// Close the database.
    public func close() {
        handlePool.drain()
    }

    /// Blockade the database.
    public func blockade() {
        handlePool.blockade()
    }

    /// Unblockade the database.
    public func unblockade() {
        handlePool.unblockade()
    }

    /// Purge all unused memory of this database.
    /// It will cache and reuse some sqlite handles to improve performance.
    /// The max count of free sqlite handles is same
    /// as the number of concurrent threads supported by the hardware implementation.
    /// You can call it to save some memory.
    public func purge() {
        handlePool.purgeFreeHandles()
    }

    /// Purge all unused memory of all databases.
    /// Note that It will call this interface automatically while it receives memory warning on iOS.
    public static func purge() {
        SQLiteHandlePool.purgeFreeHandlesInAllPools()
    }
    
}

// MARK: - Base Operations
extension SQLiteDatabase {
    
    public func prepare(statement stat: String) throws -> SQLiteStmt {
        let recyclableHandle = try flowOut()
        var stat = try recyclableHandle.rawValue.prepare(statement: stat)
        let path = path
        stat.onFinalize = {
            recyclableHandle.refCount -= 1
            if recyclableHandle.refCount == 0 {
                Self.threadedHandles.value.removeValue(forKey: path)
            }
        }
        recyclableHandle.refCount += 1
        if recyclableHandle.refCount == 1 {
            Self.threadedHandles.value[path] = recyclableHandle
        }
        return stat
    }
    
    // write: CREATE TABLE, DELETE, ALTER; INSERT, UPDATE, REPLACE
    public func execute(sql: String, isWrite: Bool) throws {
        if isWrite { handlePool.wLock() }
        defer { if isWrite { handlePool.wUnlock() } }
        let recyclableHandle = try flowOut()
        try recyclableHandle.rawValue.execute(sql: sql)
    }
    
    public func begin(_ transaction: SQLiteTransaction) throws {
        let recyclableHandle = try flowOut()
        try recyclableHandle.rawValue.begin(transaction)
        recyclableHandle.refCount += 1
        if recyclableHandle.refCount == 1 {
            Self.threadedHandles.value[path] = recyclableHandle
        }
    }
    
    public func commit() throws {
        let recyclableHandle = try flowOut()
        try recyclableHandle.rawValue.commit()
        recyclableHandle.refCount -= 1
        if recyclableHandle.refCount == 0 {
            Self.threadedHandles.value.removeValue(forKey: path)
        }
    }
    
    public func rollback() throws {
        let recyclableHandle = try flowOut()
        try recyclableHandle.rawValue.rollback()
        recyclableHandle.refCount -= 1
        if recyclableHandle.refCount == 0 {
            Self.threadedHandles.value.removeValue(forKey: path)
        }
    }
    
    public func lastInsertRowID() throws -> Int {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.lastInsertRowID()
    }
    
    /// 自数据库链接被打开起，通过insert，update，delete语句所影响的数据行数
    public func totalChanges() throws -> Int {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.totalChanges()
    }
    
    /// 最近一条insert，update，delete语句所影响的数据行数
    public func changes() throws -> Int {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.changes()
    }
    
    public func errCode() throws -> Int {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.errCode()
    }
    
    public func errMsg() throws -> String? {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.errMsg()
    }
    
}

// MARK: - Convenience Operations
extension SQLiteDatabase {
    /// write multi
    public func executeUpdatesInTransaction(_ transaction: SQLiteTransaction = .immediate, statement: String, doUpdatings: (_ stmt: borrowing SQLiteStmt) throws -> Void) throws {
        handlePool.wLock()
        defer { handlePool.wUnlock() }
        
        let stat = try prepare(statement: statement)
        do {
            try begin(transaction)
            try doUpdatings(stat)
            try commit()
        } catch {
            try? rollback()
        }
    }
    
    /// write single
    public func executeUpdate(statement: String, doUpdating: (borrowing SQLiteStmt) throws -> Void) throws {
        handlePool.wLock()
        defer { handlePool.wUnlock() }
        
        let stat = try prepare(statement: statement)
        try doUpdating(stat)
        try stat.step()
    }
    
    /// read
    public func executeQuery(statement: String, doBindings: (_ stmt: borrowing SQLiteStmt) throws -> Void, handleRow: (_ stmt: borrowing SQLiteStmt) throws -> Void) throws {
        var stat = try prepare(statement: statement)
        defer { try? stat.finalize() }
        try doBindings(stat)
        var res = try stat.step()
        
        while res == SQLITE_ROW {
            try handleRow(stat)
            res = try stat.step()
        }
    }
}

