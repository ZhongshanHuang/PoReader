#if canImport(UIKit)
import UIKit
#endif
import Foundation
import SQLite3

public final class SQLiteDatabase: @unchecked Sendable {
    private let handlePoolReference: SQLiteHandlePoolReference
    
    private var handlePool: SQLiteHandlePool {
        handlePoolReference.pool
    }
    
    public var path: String {
        handlePool.path
    }

    public var configuration: SQLiteConfiguration {
        handlePool.configuration
    }
    
    private var identity: SQLiteHandlePool.Key {
        handlePool.key
    }
    
    public convenience init(path: String, configuration: SQLiteConfiguration = .mobile) {
        self.init(resolvedPath: Self.resolvePath(path, configuration: configuration), configuration: configuration)
    }
    
    public convenience init(fileURL: URL, configuration: SQLiteConfiguration = .mobile) {
        self.init(resolvedPath: fileURL.standardizedFileURL.path, configuration: configuration)
    }

    private init(resolvedPath path: String, configuration: SQLiteConfiguration) {
        self.handlePoolReference = SQLiteHandlePool.getHandlePool(with: path, configuration: configuration)

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
    
    private static let threadedHandles = ThreadLocal<[SQLiteHandlePool.Key: SQLitePooledHandleLease]>(defaultValue: [:])
    private static let threadedTransactionDepths = ThreadLocal<[SQLiteHandlePool.Key: Int]>(defaultValue: [:])
    
    func flowOut() throws -> SQLitePooledHandleLease {
        if let handleLease = Self.threadedHandles.value[identity] {
            return handleLease
        }
        let handleLease = try handlePool.flowOut()
        return handleLease
    }

    /// Check whether the database currently has at least one opened connection.
    public var isOpen: Bool {
        return !handlePool.isClosed && !handlePool.isDrained
    }
    
    /// Force lazy connection initialization and surface the underlying SQLite error if opening fails.
    public func open() throws {
        if handlePool.isClosed || handlePool.isDrained {
            try handlePool.fillOne()
        }
    }

    private typealias OnClosed = () throws -> Void

    private func close(onClosed: OnClosed) throws {
        if Self.threadedHandles.value[identity] != nil {
            throw SQLiteError(
                code: SQLITE_BUSY,
                description: "Cannot close database while the current thread holds active statements or a transaction.",
                operation: "close"
            )
        }
        try handlePool.close(onClosed: onClosed)
    }

    /// Close the database.
    public func close() throws {
        try close(onClosed: {})
    }

    /// Purge all unused memory of this database.
    /// It will cache and reuse some sqlite handles to improve performance.
    /// The max count of free sqlite handles is controlled by
    /// `SQLiteConfiguration.maximumIdleConnectionCount`.
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

public enum SQLiteStatementAccess: Sendable {
    case read
    case write
}

private extension SQLiteDatabase {
    var isInTransactionOnCurrentThread: Bool {
        (Self.threadedTransactionDepths.value[identity] ?? 0) > 0
    }

    func withWriteLock<T>(_ body: () throws -> T) throws -> T {
        if isInTransactionOnCurrentThread {
            return try body()
        }

        return try handlePool.withWriteLock(body)
    }

    func incrementTransactionDepth() {
        var depths = Self.threadedTransactionDepths.value
        depths[identity, default: 0] += 1
        Self.threadedTransactionDepths.value = depths
    }

    func decrementTransactionDepth() {
        var depths = Self.threadedTransactionDepths.value
        let nextDepth = (depths[identity] ?? 0) - 1
        if nextDepth > 0 {
            depths[identity] = nextDepth
        } else {
            depths.removeValue(forKey: identity)
        }
        Self.threadedTransactionDepths.value = depths
    }

    func releaseThreadedHandle(_ handleLease: SQLitePooledHandleLease) {
        handleLease.refCount -= 1
        if handleLease.refCount == 0 {
            Self.threadedHandles.value.removeValue(forKey: identity)
        }
    }

    static func makeSavepointName() -> String {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "_")
        return "posqlite_savepoint_\(suffix)"
    }

    static func resolvePath(_ path: String, configuration: SQLiteConfiguration) -> String {
        if path == ":memory:" || configuration.usesURI {
            return path
        }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

// MARK: - Base Operations
extension SQLiteDatabase {
    
    private func makeStatement(_ statement: String) throws -> SQLiteStmt {
        let handleLease = try flowOut()
        var stat = try handleLease.handle.prepare(statement: statement)
        let identity = identity
        handleLease.refCount += 1
        if handleLease.refCount == 1 {
            Self.threadedHandles.value[identity] = handleLease
        }
        stat.lease = SQLiteStatementLease {
            handleLease.refCount -= 1
            if handleLease.refCount == 0 {
                Self.threadedHandles.value.removeValue(forKey: identity)
            }
        }
        return stat
    }

    public func prepare(_ sql: SQL) throws -> SQLiteStmt {
        let statement = try makeStatement(sql.statement)
        if !sql.parameters.isEmpty {
            try statement.bind(sql.parameters)
        }
        return statement
    }

    private func prepareBound(_ sql: SQL) throws -> SQLiteStmt {
        let statement = try makeStatement(sql.statement)
        try statement.bind(sql.parameters)
        return statement
    }
    
    private func begin(_ transaction: SQLiteTransaction) throws {
        let handleLease = try flowOut()
        try handleLease.handle.begin(transaction)
        handleLease.refCount += 1
        if handleLease.refCount == 1 {
            Self.threadedHandles.value[identity] = handleLease
        }
    }
    
    private func commit() throws {
        let handleLease = try flowOut()
        try handleLease.handle.commit()
        releaseThreadedHandle(handleLease)
    }
    
    private func rollback() throws {
        let handleLease = try flowOut()
        defer {
            releaseThreadedHandle(handleLease)
        }
        try handleLease.handle.rollback()
    }
    
    private func lastInsertRowID() throws -> Int {
        let handleLease = try flowOut()
        return handleLease.handle.lastInsertRowID()
    }
    
    /// 最近一条insert，update，delete语句所影响的数据行数
    private func changes() throws -> Int {
        let handleLease = try flowOut()
        return handleLease.handle.changes()
    }
}

// MARK: - Convenience Operations
extension SQLiteDatabase {
    public func withPreparedStatement<T>(
        _ sql: SQL,
        access: SQLiteStatementAccess = .read,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        switch access {
        case .read:
            var statement = try prepare(sql)
            defer { try? statement.finalize() }
            return try body(statement)
        case .write:
            return try withWriteLock {
                var statement = try self.prepare(sql)
                defer { try? statement.finalize() }
                return try body(statement)
            }
        }
    }

    private func withBoundPreparedStatement<T>(
        _ sql: SQL,
        access: SQLiteStatementAccess = .read,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        switch access {
        case .read:
            var statement = try prepareBound(sql)
            defer { try? statement.finalize() }
            return try body(statement)
        case .write:
            return try withWriteLock {
                var statement = try self.prepareBound(sql)
                defer { try? statement.finalize() }
                return try body(statement)
            }
        }
    }

    public func executeScript(_ sql: String) throws {
        try withWriteLock {
            let handleLease = try flowOut()
            try handleLease.handle.execute(sql: sql)
        }
    }

    @discardableResult
    public func execute(_ sql: SQL) throws -> SQLiteExecutionResult {
        try withBoundPreparedStatement(sql, access: .write) { statement in
            let result = try statement.step()
            guard result == .done else {
                throw SQLiteError(
                    code: SQLITE_MISUSE,
                    description: "Use fetch APIs for statements that return rows.",
                    operation: "execute",
                    sql: sql.statement
                )
            }

            return SQLiteExecutionResult(
                changes: try changes(),
                lastInsertRowID: try lastInsertRowID()
            )
        }
    }

    public func fetch<T>(_ sql: SQL, map: (SQLiteRow) throws -> T) throws -> [T] {
        var rows: [T] = []
        try forEachRow(sql) { row in
            rows.append(try map(row))
        }
        return rows
    }

    public func fetch(_ sql: SQL) throws -> [SQLiteRow] {
        try fetch(sql) { $0 }
    }

    public func forEachRow(_ sql: SQL, _ body: (SQLiteRow) throws -> Void) throws {
        try withBoundPreparedStatement(sql) { statement in
            var result = try statement.step()
            while result == .row {
                try body(try SQLiteRow(statement: statement))
                result = try statement.step()
            }
        }
    }

    public func fetchOne(_ sql: SQL) throws -> SQLiteRow? {
        try withBoundPreparedStatement(sql) { statement in
            guard try statement.step() == .row else {
                return nil
            }
            return try SQLiteRow(statement: statement)
        }
    }

    public func scalar(_ sql: SQL) throws -> SQLiteValue? {
        try fetchOne(sql)?[0]
    }

    @discardableResult
    public func transaction<T>(_ mode: SQLiteTransaction = .immediate, _ body: (_ transaction: borrowing SQLiteTransactionContext) throws -> T) throws -> T {
        try _transaction(mode) {
            try body(SQLiteTransactionContext(database: self))
        }
    }

    private func _transaction<T>(_ mode: SQLiteTransaction, _ body: () throws -> T) throws -> T {
        if isInTransactionOnCurrentThread {
            return try _savepoint(body)
        }

        return try handlePool.withWriteLock {
            try begin(mode)
            incrementTransactionDepth()
            do {
                let result = try body()
                try commit()
                decrementTransactionDepth()
                return result
            } catch {
                let rollbackError: (any Error)?
                do {
                    try rollback()
                    rollbackError = nil
                } catch {
                    rollbackError = error
                }
                decrementTransactionDepth()
                if let rollbackError {
                    throw SQLiteTransactionError(primaryError: error, rollbackError: rollbackError)
                }
                throw error
            }
        }
    }

    private func _savepoint<T>(_ body: () throws -> T) throws -> T {
        let savepointName = Self.makeSavepointName()
        let handleLease = try flowOut()

        try handleLease.handle.savepoint(savepointName)
        incrementTransactionDepth()
        do {
            let result = try body()
            try handleLease.handle.releaseSavepoint(savepointName)
            decrementTransactionDepth()
            return result
        } catch {
            let rollbackError: (any Error)?
            do {
                try handleLease.handle.rollbackToSavepoint(savepointName)
                try handleLease.handle.releaseSavepoint(savepointName)
                rollbackError = nil
            } catch {
                rollbackError = error
            }
            decrementTransactionDepth()
            if let rollbackError {
                throw SQLiteTransactionError(primaryError: error, rollbackError: rollbackError)
            }
            throw error
        }
    }

}
