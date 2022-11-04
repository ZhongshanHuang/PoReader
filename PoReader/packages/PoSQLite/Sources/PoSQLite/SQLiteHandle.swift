//
//  SQLiteHandle.swift
//  PoSQLiteDemo
//
//  Created by HzS on 2022/8/15.
//

import Foundation
import SQLite3
import SQLiteBridging

typealias SQLite3 = OpaquePointer
typealias SQLite3Statement = OpaquePointer

/// 事务获取锁的模式
public enum SQLiteTransaction: String {
    case exclusive = "BEGIN EXCLUSIVE TRANSACTION"
    case deferred = "BEGIN DEFERRED TRANSACTION"
    case immediate = "BEGIN IMMEDIATE TRANSACTION"
}


final class SQLiteHandle {
    private var handle: SQLite3?
    let path: String
    init(withPath path: String) {
        DispatchQueue.once(name: "com.potato.posqlite.handle") {
            sqlite3_config_multithread()
            sqlite3_config_memstatus(Int32(truncating: false))
            sqlite3_config_log({ (_, code, message) in
                let msg = (message != nil) ? String(cString: message!) : ""
                SQLiteError.reportSQLiteGlobal(code: Int(code), msg: msg)
            }, nil)
        }
        self.path = path
    }
    
    func open() throws {
        let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
        try File.createDirectoryWithIntermediateDirectories(atPath: directory)
        
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_SHAREDCACHE
        let res = sqlite3_open_v2(path, &handle, flags, nil)
        if res != SQLITE_OK {
            throw SQLiteError(code: res, description: String(cString: sqlite3_errmsg(handle)))
        } else {
            try execute(sql: "pragma journal_mode = wal;pragma synchronous = normal;pragma locking_mode = normal")
        }
    }
    
    func close() throws {
        if handle != nil {
            var res: Int32 = 0
            var stmtFinalized = false
            var retry = false
            
            repeat {
                retry = false
                res = sqlite3_close_v2(handle)
                if res == SQLITE_BUSY || res == SQLITE_LOCKED { // Some stmts have not be finalized.
                    if !stmtFinalized {
                        var stmt: OpaquePointer?
                        stmt = sqlite3_next_stmt(handle, nil) // Find the stmt that has not be finalized.
                        while stmt != nil  {
                            sqlite3_finalize(stmt)
                            retry = true
                            stmt = sqlite3_next_stmt(handle, nil)
                        }
                        stmtFinalized = true
                    }
                } else if res != SQLITE_OK {
                    throw SQLiteError(code: res, description: String(cString: sqlite3_errmsg(handle)))
                }
            } while retry
            
            handle = nil
        }
    }
        
    deinit {
        try? close()
    }
}

// MARK: - Operations
extension SQLiteHandle {
    func prepare(statement stat: String) throws -> SQLiteStmt {
        var statPtr = OpaquePointer(bitPattern: 0)
        /**
        参数
        1.句柄
        2.sql字符串
        3.要执行sql的以字节为单位的长度，如果传-1，sqlite会自动计算
        4.stmt 与编译的指令句柄，后续针对本次查询的所有操作全部基于此，句柄一定要释放
        5.stmt 尾部参数的指针，通常nil
        */
        let res = sqlite3_prepare_v2(handle, stat, Int32(stat.utf8.count), &statPtr, nil)
        if res != SQLITE_OK {
            throw SQLiteError(code: res, description: String(cString: sqlite3_errmsg(handle)))
        }
        return SQLiteStmt(stat: statPtr!)
    }
    
    func execute(sql: String) throws {
        /**
         参数
           1.数据库全局句柄
           2.要执行的SQL
           3.callback,执行SQL后的回调
           4.callback参数的地址
           5.错误信息
         返回值
           SQLITE_OK 表示成功，其余表示失败
        */
        let res = sqlite3_exec(handle, sql, nil, nil, nil)
        if res != SQLITE_OK {
            throw SQLiteError(code: res, description: String(cString: sqlite3_errmsg(handle)))
        }
    }
    
    func begin(_ transaction: SQLiteTransaction) throws {
        try execute(sql: transaction.rawValue)
    }
    
    func commit() throws {
        try execute(sql: "COMMIT TRANSACTION")
    }
    
    func rollback() throws {
        try execute(sql: "ROLLBACK TRANSACTION")
    }
    
    func lastInsertRowID() -> Int {
        let res = sqlite3_last_insert_rowid(handle)
        return Int(res)
    }
    
    /// 自数据库链接被打开起，通过insert，update，delete语句所影响的数据行数
    func totalChanges() -> Int {
        let res = sqlite3_total_changes(handle)
        return Int(res)
    }
    
    /// 最近一条insert，update，delete语句所影响的数据行数
    func changes() -> Int {
        let res = sqlite3_changes(handle)
        return Int(res)
    }
    
    func errCode() -> Int {
        return Int(sqlite3_errcode(handle))
    }
    
    func errMsg() -> String? {
        if let cString = sqlite3_errmsg(handle) {
            return String(cString: cString)
        }
        return nil
    }
}
