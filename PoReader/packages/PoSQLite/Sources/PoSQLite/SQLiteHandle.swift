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


public final class SQLiteHandle {
    private var handle: SQLite3?
    public let path: String
    public init(withPath path: String) {
        DispatchQueue.once(name: "com.potato.sqlite.handle") {
            // 多线程模式
            sqlite3_config_multithread()
            // 禁用内存统计
            sqlite3_config_memstatus(0)
            // 打印日志
            sqlite3_config_log({ (_, code, message) in
                let msg = (message != nil) ? String(cString: message!) : ""
                SQLiteError.reportSQLiteGlobal(code: Int(code), msg: msg)
            }, nil)
        }
        self.path = path
    }
    
    public func open() throws {
        let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
        try File.createDirectoryWithIntermediateDirectories(atPath: directory)
        
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_SHAREDCACHE
        let res = sqlite3_open_v2(path, &handle, flags, nil)
        if res != SQLITE_OK {
            throw SQLiteError(code: res, description: String(cString: sqlite3_errmsg(handle)))
        } else {
            try execute(sql: "PRAGMA journal_mode=wal;PRAGMA synchronous=normal;PRAGMA locking_mode=normal;PRAGMA mmap_size=268435456;PRAGMA busy_timeout=10000;")
        }
    }
    
    public func close() throws {
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
    public func prepare(statement stat: String) throws -> SQLiteStmt {
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
    
    public func execute(sql: String) throws {
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
    
    public func begin(_ transaction: SQLiteTransaction) throws {
        try execute(sql: transaction.rawValue)
    }
    
    public func commit() throws {
        try execute(sql: "COMMIT TRANSACTION;")
    }
    
    public func rollback() throws {
        try execute(sql: "ROLLBACK TRANSACTION;")
    }
    
    public func lastInsertRowID() -> Int {
        let res = sqlite3_last_insert_rowid(handle)
        return Int(res)
    }
    
    /// 自数据库链接被打开起，通过insert，update，delete语句所影响的数据行数
    public func totalChanges() -> Int {
        let res = sqlite3_total_changes(handle)
        return Int(res)
    }
    
    /// 最近一条insert，update，delete语句所影响的数据行数
    public func changes() -> Int {
        let res = sqlite3_changes(handle)
        return Int(res)
    }
    
    /// wal checkPoint
    /// - Returns: pnLog: size of WAL log in frames  pnCkpt: total number of frames checkpointed
    public func checkPoint() throws -> (pnLog: Int32, pnCkpt: Int32) {
        var pnLog: Int32 = 0
        var pnCkpt: Int32 = 0
        let res = sqlite3_wal_checkpoint_v2(handle, nil, SQLITE_CHECKPOINT_TRUNCATE, &pnLog, &pnCkpt)
        if res != SQLITE_OK {
            throw SQLiteError(code: res, description: String(cString: sqlite3_errmsg(handle)))
        }
        return (pnLog, pnCkpt)
    }
    
    /// default 1000
    public func configAutoCheckPoint(_ page: Int) throws {
        try execute(sql: "PRAGMA wal_autocheckpoint=\(page);")
    }
    
    /// default 10 * 1000
    public func configBusyTimeout(_ ms: Int) throws {
        let res = sqlite3_busy_timeout(handle, Int32(ms))
        if res != SQLITE_OK {
            throw SQLiteError(code: res, description: String(cString: sqlite3_errmsg(handle)))
        }
    }
    
    public func errCode() -> Int {
        return Int(sqlite3_errcode(handle))
    }
    
    public func errMsg() -> String? {
        if let cString = sqlite3_errmsg(handle) {
            return String(cString: cString)
        }
        return nil
    }
}
