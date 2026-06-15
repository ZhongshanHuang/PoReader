import Foundation
import SQLite3

typealias SQLite3 = OpaquePointer
typealias SQLite3Statement = OpaquePointer

/// 未加锁(UNLOCKED)、共享 (SHARED)、保留(RESERVED)、未决(PENDING)、排它(EXCLUSIVE)
/// 事务获取锁的模式
public enum SQLiteTransactionMode: String, Sendable {
    case deferred = "BEGIN DEFERRED TRANSACTION" // UNLOCKED
    case immediate = "BEGIN IMMEDIATE TRANSACTION" // RESERVED
    case exclusive = "BEGIN EXCLUSIVE TRANSACTION" // EXCLUSIVE
}


@safe final class SQLiteHandle: @unchecked Sendable {
    @unsafe private var handle: SQLite3?
    public let path: String
    public let configuration: SQLiteConfiguration

    public init(withPath path: String, configuration: SQLiteConfiguration) {
        self.path = path
        self.configuration = configuration
    }
    
    public func open() throws {
        if configuration.shouldCreateContainingDirectory(for: path) {
            let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
            try File.createDirectoryWithIntermediateDirectories(atPath: directory)
        }
        
        let res = _open(flags: configuration.openFlags)
        if res != SQLITE_OK {
            throw _error(code: res, fallback: "sqlite3_open_v2 failed.", operation: "open")
        }

        if let busyTimeoutMilliseconds = configuration.busyTimeoutMilliseconds {
            try configBusyTimeout(busyTimeoutMilliseconds)
        }
        for statement in configuration.connectionPreparationStatements {
            try execute(sql: statement)
        }
    }
    
    public func close() throws {
        try _close()
    }
        
    deinit {
        try? close()
    }
}

// MARK: - Operations
extension SQLiteHandle {
    public func prepare(statement stat: String) throws -> SQLiteStmt {
        try _prepare(statement: stat)
    }
    
    public func execute(sql: String) throws {
        try _execute(sql: sql)
    }
    
    public func begin(_ transaction: SQLiteTransactionMode) throws {
        try execute(sql: transaction.rawValue)
    }
    
    public func commit() throws {
        try execute(sql: "COMMIT TRANSACTION;")
    }
    
    public func rollback() throws {
        try execute(sql: "ROLLBACK TRANSACTION;")
    }

    func savepoint(_ name: String) throws {
        try execute(sql: "SAVEPOINT \(Self.quotedSavepointName(name));")
    }

    func releaseSavepoint(_ name: String) throws {
        try execute(sql: "RELEASE SAVEPOINT \(Self.quotedSavepointName(name));")
    }

    func rollbackToSavepoint(_ name: String) throws {
        try execute(sql: "ROLLBACK TO SAVEPOINT \(Self.quotedSavepointName(name));")
    }
    
    public func lastInsertRowID() -> Int {
        Int(_lastInsertRowID())
    }
    
    /// 自数据库链接被打开起，通过insert，update，delete语句所影响的数据行数
    public func totalChanges() -> Int {
        Int(_totalChanges())
    }
    
    /// 最近一条insert，update，delete语句所影响的数据行数
    public func changes() -> Int {
        Int(_changes())
    }
    
    /// wal checkPoint
    /// - Returns: pnLog: size of WAL log in frames  pnCkpt: total number of frames checkpointed
    public func checkPoint() throws -> (pnLog: Int32, pnCkpt: Int32) {
        try _checkPoint()
    }
    
    /// default 1000
    public func configAutoCheckPoint(_ page: Int) throws {
        try execute(sql: "PRAGMA wal_autocheckpoint=\(page);")
    }
    
    /// default 10 * 1000
    public func configBusyTimeout(_ ms: Int) throws {
        try _configBusyTimeout(ms)
    }
    
    public func errCode() -> Int {
        Int(_errCode())
    }
    
    public func errMsg() -> String? {
        _errMsg()
    }

    private func _open(flags: Int32) -> Int32 {
        unsafe sqlite3_open_v2(path, &handle, flags, nil)
    }

    private func _close() throws {
        guard unsafe handle != nil else { return }

        var result: Int32 = 0
        var stmtFinalized = false
        var retry = false

        repeat {
            retry = false
            result = unsafe sqlite3_close_v2(handle)
            if result == SQLITE_BUSY || result == SQLITE_LOCKED {
                if !stmtFinalized {
                    var statement: SQLite3Statement?
                    unsafe statement = sqlite3_next_stmt(handle, nil)
                    while unsafe statement != nil {
                        unsafe sqlite3_finalize(statement)
                        retry = true
                        unsafe statement = sqlite3_next_stmt(handle, nil)
                    }
                    stmtFinalized = true
                }
            } else if result != SQLITE_OK {
                throw _error(code: result, fallback: "sqlite3_close_v2 failed.", operation: "close")
            }
        } while retry

        unsafe handle = nil
    }

    private func _prepare(statement sql: String) throws -> SQLiteStmt {
        let handle = try unsafe requireOpenHandle()
        guard sql.utf8.count <= Int(Int32.max) else {
            throw SQLiteError(
                code: SQLITE_TOOBIG,
                description: "SQL statement is too large.",
                operation: "prepare",
                sql: sql
            )
        }

        var statement: SQLite3Statement?
        var tail: String = ""
        let result = sql.withCString { sqlPointer in
            var tailPointer: UnsafePointer<CChar>?
            let result = unsafe sqlite3_prepare_v2(handle, sqlPointer, Int32(sql.utf8.count), &statement, &tailPointer)
            if let tailPointer = unsafe tailPointer, unsafe tailPointer.pointee != 0 {
                tail = unsafe String(cString: tailPointer)
            }
            return result
        }
        if result != SQLITE_OK {
            throw unsafe Self.error(
                code: result,
                database: handle,
                fallback: "sqlite3_prepare_v2 failed.",
                operation: "prepare",
                sql: sql
            )
        }
        if Self.containsTrailingStatement(tail) {
            if let statement = unsafe statement {
                unsafe sqlite3_finalize(statement)
            }
            throw SQLiteError(
                code: SQLITE_MISUSE,
                description: "SQL APIs that prepare a statement accept exactly one statement.",
                operation: "prepare",
                sql: sql
            )
        }
        guard let statement = unsafe statement else {
            throw SQLiteError(
                code: SQLITE_MISUSE,
                description: "SQL statement is empty or contains only comments.",
                operation: "prepare",
                sql: sql
            )
        }
        return unsafe SQLiteStmt(stat: statement, sql: sql)
    }

    private func _execute(sql: String) throws {
        let handle = try unsafe requireOpenHandle()
        let result = unsafe sqlite3_exec(handle, sql, nil, nil, nil)
        if result != SQLITE_OK {
            throw unsafe Self.error(
                code: result,
                database: handle,
                fallback: "sqlite3_exec failed.",
                operation: "execute",
                sql: sql
            )
        }
    }

    private func _lastInsertRowID() -> Int64 {
        unsafe sqlite3_last_insert_rowid(handle)
    }

    private func _totalChanges() -> Int32 {
        unsafe sqlite3_total_changes(handle)
    }

    private func _changes() -> Int32 {
        unsafe sqlite3_changes(handle)
    }

    private func _checkPoint() throws -> (pnLog: Int32, pnCkpt: Int32) {
        let handle = try unsafe requireOpenHandle()
        var pnLog: Int32 = 0
        var pnCkpt: Int32 = 0
        let result = unsafe sqlite3_wal_checkpoint_v2(handle, nil, SQLITE_CHECKPOINT_TRUNCATE, &pnLog, &pnCkpt)
        if result != SQLITE_OK {
            throw unsafe Self.error(
                code: result,
                database: handle,
                fallback: "sqlite3_wal_checkpoint_v2 failed.",
                operation: "wal_checkpoint"
            )
        }
        return (pnLog, pnCkpt)
    }

    private func _configBusyTimeout(_ ms: Int) throws {
        let handle = try unsafe requireOpenHandle()
        let result = unsafe sqlite3_busy_timeout(handle, Int32(ms))
        if result != SQLITE_OK {
            throw unsafe Self.error(
                code: result,
                database: handle,
                fallback: "sqlite3_busy_timeout failed.",
                operation: "busy_timeout"
            )
        }
    }

    private func _errCode() -> Int32 {
        unsafe sqlite3_errcode(handle)
    }

    private func _errMsg() -> String? {
        guard let cString = unsafe sqlite3_errmsg(handle) else { return nil }
        return unsafe String(cString: cString)
    }

    private func _error(code: Int32, fallback: String, operation: String? = nil, sql: String? = nil) -> SQLiteError {
        unsafe Self.error(code: code, database: handle, fallback: fallback, operation: operation, sql: sql)
    }

    private func requireOpenHandle(funcName: StaticString = #function) throws -> SQLite3 {
        guard let handle = unsafe handle else {
            throw SQLiteError(
                code: SQLITE_MISUSE,
                description: "\(funcName): database handle is not open.",
                operation: funcName.description
            )
        }
        return unsafe handle
    }

    private static func error(
        code: Int32,
        database: SQLite3?,
        fallback: String,
        operation: String? = nil,
        sql: String? = nil,
        bind: SQLiteError.BindContext? = nil
    ) -> SQLiteError {
        SQLiteError(
            code: code,
            extendedCode: unsafe extendedCode(database: database),
            description: unsafe errorMessage(database: database, fallback: fallback),
            operation: operation,
            sql: sql,
            bind: bind
        )
    }

    private static func errorMessage(database: SQLite3?, fallback: String) -> String {
        guard let database = unsafe database, let message = unsafe sqlite3_errmsg(database) else { return fallback }
        let text = unsafe String(cString: message)
        return text.isEmpty ? fallback : text
    }

    private static func extendedCode(database: SQLite3?) -> Int32? {
        guard let database = unsafe database else { return nil }
        return unsafe sqlite3_extended_errcode(database)
    }

    private static func quotedSavepointName(_ name: String) -> String {
        SQL.quoteIdentifier(name)
    }

    private static func containsTrailingStatement(_ tail: String) -> Bool {
        var index = tail.startIndex

        while index < tail.endIndex {
            let character = tail[index]
            if character == ";" || character.isWhitespace {
                index = tail.index(after: index)
                continue
            }

            if tail[index...].hasPrefix("--") {
                index = tail.index(index, offsetBy: 2)
                while index < tail.endIndex, tail[index] != "\n" {
                    index = tail.index(after: index)
                }
                continue
            }

            if tail[index...].hasPrefix("/*") {
                index = tail.index(index, offsetBy: 2)
                guard let end = tail[index...].range(of: "*/") else {
                    return true
                }
                index = end.upperBound
                continue
            }

            return true
        }

        return false
    }
}
