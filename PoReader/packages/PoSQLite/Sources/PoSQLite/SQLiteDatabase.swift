//
//  SQLiteDatabase.swift
//  KitDemo
//
//  Created by 黄中山 on 2020/1/6.
//  Copyright © 2020 黄中山. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
import Foundation
import SQLite3

public protocol SQLiteDatabaseProtocol {
    
    var canOpen: Bool { get }
    var isOpened: Bool { get }
    func close()
    
    func prepare(statement stat: String) throws -> SQLiteStmt
    /// 除了更新和插入算write,，其余的算read，write无法并发执行，所以会主动加锁，防止失败
    func execute(sql: String, isWrite: Bool) throws
    
    func begin(_ transaction: SQLiteTransaction) throws
    func commit() throws
    func rollback() throws
    
    func lastInsertRowID() throws -> Int
    
    /// 自数据库链接被打开起，通过insert，update，delete语句所影响的数据行数
    func totalChanges() throws -> Int
    /// 最近一条insert，update，delete语句所影响的数据行数
    func changes() throws -> Int
    
    func errCode() throws -> Int
    
    func errMsg() throws -> String?
}

final class SQLiteDatabase {
    private let recyclableHandlePool: RecyclableHandlePool
    
    var handlePool: SQLiteHandlePool {
        recyclableHandlePool.rawValue
    }
    
    var path: String {
        handlePool.path
    }
    
    convenience init(path: String) {
        self.init(fileURL: URL(fileURLWithPath: path))
    }
    
    init(fileURL: URL) {
        self.recyclableHandlePool = SQLiteHandlePool.getHandlePool(with: fileURL.standardizedFileURL.path)
        
        DispatchQueue.once(name: "com.Potato.sqlite.swift.purge", {
#if canImport(UIKit)
            let purgeFreeHandleQueue: DispatchQueue = DispatchQueue(label: "com.Potato.sqlite.swift.purge")
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil,
                using: { (_) in
                    purgeFreeHandleQueue.async {
                        SQLiteDatabase.purge()
                    }
                })
#endif
        })
    }
    
    private static var threadedHandles = ThreadLocal<[String: RecyclableHandle]>(defaultValue: [:])
    
    func flowOut() throws -> RecyclableHandle {
        let threadedHandles = SQLiteDatabase.threadedHandles.value
        if let handle = threadedHandles[path] {
            return handle
        }
        return try handlePool.flowOut()
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
    
    public typealias OnClosed = SQLiteHandlePool.OnDrained
    
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

// MARK: - Operations
extension SQLiteDatabase: SQLiteDatabaseProtocol {
    
    func prepare(statement stat: String) throws -> SQLiteStmt {
        let recyclableHandle = try flowOut()
        return try recyclableHandle.rawValue.prepare(statement: stat)
    }
    
    func execute(sql: String, isWrite: Bool = false) throws {
        if isWrite { handlePool.wLock() }
        defer { if isWrite { handlePool.wUnlock() } }
        let recyclableHandle = try flowOut()
        try recyclableHandle.rawValue.execute(sql: sql)
    }
    
    func begin(_ transaction: SQLiteTransaction) throws {
        let recyclableHandle = try flowOut()
        try recyclableHandle.rawValue.begin(transaction)
        SQLiteDatabase.threadedHandles.value[path] = recyclableHandle
    }
    
    func commit() throws {
        let recyclableHandle = try flowOut()
        try recyclableHandle.rawValue.commit()
        SQLiteDatabase.threadedHandles.value.removeValue(forKey: path)
    }
    
    func rollback() throws {
        let recyclableHandle = try flowOut()
        try recyclableHandle.rawValue.rollback()
        SQLiteDatabase.threadedHandles.value.removeValue(forKey: path)
    }
    
    func lastInsertRowID() throws -> Int {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.lastInsertRowID()
    }
    
    /// 自数据库链接被打开起，通过insert，update，delete语句所影响的数据行数
    func totalChanges() throws -> Int {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.totalChanges()
    }
    
    /// 最近一条insert，update，delete语句所影响的数据行数
    func changes() throws -> Int {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.changes()
    }
    
    func errCode() throws -> Int {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.errCode()
    }
    
    func errMsg() throws -> String? {
        let recyclableHandle = try flowOut()
        return recyclableHandle.rawValue.errMsg()
    }
    
}

