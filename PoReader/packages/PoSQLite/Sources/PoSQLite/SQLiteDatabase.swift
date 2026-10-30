#if canImport(UIKit)
import UIKit
#endif
import Foundation
import SQLite3

public final class SQLiteDatabase: SQLiteExecutor, @unchecked Sendable {
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
    
    private var identity: ObjectIdentifier {
        ObjectIdentifier(handlePool)
    }
    
    public convenience init(path: String, configuration: SQLiteConfiguration = .mobile) {
        self.init(resolvedPath: Self.resolvePath(path, configuration: configuration), configuration: configuration)
    }
    
    public convenience init(fileURL: URL, configuration: SQLiteConfiguration = .mobile) {
        self.init(resolvedPath: fileURL.standardizedFileURL.path, configuration: configuration)
    }

    private init(resolvedPath path: String, configuration: SQLiteConfiguration) {
        self.handlePoolReference = SQLiteHandlePool.makeHandlePool(with: path, configuration: configuration)

#if canImport(UIKit)
        DispatchQueue.once(name: "com.potato.sqlite.swift.purge", {
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil,
                using: { (_) in
                    DispatchQueue.global(qos: .userInteractive).async {
                        SQLiteDatabase.purgeAllIdleConnections()
                    }
                })
        })
#endif
    }
    
    private static let threadedHandles = ThreadLocal<[ObjectIdentifier: SQLitePooledHandleLease]>(defaultValue: [:])
    private static let threadedTransactionDepths = ThreadLocal<[ObjectIdentifier: Int]>(defaultValue: [:])
    
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
    public func purgeIdleConnections() {
        handlePool.purgeFreeHandles()
    }

    /// Purge cached prepared statements held by idle connections of this database.
    public func purgeStatementCache() {
        handlePool.purgeStatementCaches()
    }

    /// Purge all unused memory of all databases.
    /// Note that It will call this interface automatically while it receives memory warning on iOS.
    public static func purgeAllIdleConnections() {
        SQLiteHandlePool.purgeFreeHandlesInAllPools()
    }

    /// Purge cached prepared statements held by idle connections of all databases.
    public static func purgeAllStatementCaches() {
        SQLiteHandlePool.purgeStatementCachesInAllPools()
    }
    
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
        Self.threadedTransactionDepths.value[identity, default: 0] += 1
    }

    func decrementTransactionDepth() {
        Self.threadedTransactionDepths.withValue { depths in
            let nextDepth = (depths[identity] ?? 0) - 1
            if nextDepth > 0 {
                depths[identity] = nextDepth
            } else {
                depths.removeValue(forKey: identity)
            }
        }
    }

    func retainThreadedHandle(_ handleLease: SQLitePooledHandleLease) {
        handleLease.refCount += 1
        if handleLease.refCount == 1 {
            Self.threadedHandles.value[identity] = handleLease
        }
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
    
    private func makeStatement(
        _ statement: String,
        cached: Bool,
        handleLease: SQLitePooledHandleLease
    ) throws -> SQLiteStmt {
        var stat = cached
            ? try handleLease.handle.prepareCached(statement: statement)
            : try handleLease.handle.prepare(statement: statement)
        retainThreadedHandle(handleLease)
        stat.lease = SQLiteStatementLease {
            self.releaseThreadedHandle(handleLease)
        }
        return stat
    }

    private func makeStatement(_ statement: String, cached: Bool) throws -> SQLiteStmt {
        try makeStatement(statement, cached: cached, handleLease: flowOut())
    }

    /// Prepare a statement for manual lifetime management.
    ///
    /// This is an advanced escape hatch. Prefer `withPreparedStatement(_:_:)`,
    /// `execute(_:)`, and `fetch` APIs so PoSQLite can serialize writes and
    /// reuse cached statements safely.
    public func unsafePrepare(_ sql: borrowing SQL) throws -> SQLiteStmt {
        let statement = try makeStatement(sql.statement, cached: false)
        if sql.hasBoundParameters {
            try sql.bind(to: statement)
        }
        return statement
    }

    private func prepareBound(
        _ sql: borrowing SQL,
        handleLease: SQLitePooledHandleLease
    ) throws -> SQLiteStmt {
        let statement = try makeStatement(sql.statement, cached: true, handleLease: handleLease)
        try sql.bind(to: statement)
        return statement
    }

    private func prepareBound(_ sql: borrowing SQL) throws -> SQLiteStmt {
        try prepareBound(sql, handleLease: flowOut())
    }
    
    private func begin(_ transaction: SQLiteTransactionMode) throws -> SQLitePooledHandleLease {
        let handleLease = try flowOut()
        try handleLease.handle.begin(transaction)
        retainThreadedHandle(handleLease)
        return handleLease
    }
    
    private func commit(handleLease: SQLitePooledHandleLease) throws {
        try handleLease.handle.commit()
        releaseThreadedHandle(handleLease)
    }
    
    private func rollback(handleLease: SQLitePooledHandleLease) throws {
        defer {
            releaseThreadedHandle(handleLease)
        }
        try handleLease.handle.rollback()
    }
    
}

// MARK: - Convenience Operations
extension SQLiteDatabase {
    public func withPreparedStatement<T>(
        _ sql: borrowing SQL,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        try withPreparedStatement(sql, serializeWrites: true, body)
    }

    func withPreparedStatement<T>(
        _ sql: borrowing SQL,
        handleLease: SQLitePooledHandleLease,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        try withPreparedStatement(sql, handleLease: handleLease, serializeWrites: false, body)
    }

    private func withPreparedStatement<T>(
        _ sql: borrowing SQL,
        serializeWrites: Bool,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        try withPreparedStatement(sql, handleLease: flowOut(), serializeWrites: serializeWrites, body)
    }

    private func withPreparedStatement<T>(
        _ sql: borrowing SQL,
        handleLease: SQLitePooledHandleLease,
        serializeWrites: Bool,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        var statement = try makeStatement(sql.statement, cached: true, handleLease: handleLease)
        if sql.hasBoundParameters {
            try sql.bind(to: statement)
        }
        defer { try? statement.finalize() }

        if !serializeWrites {
            return try body(statement)
        }

        if try statement.isReadOnly() {
            return try body(statement)
        }

        return try withWriteLock {
            try body(statement)
        }
    }

    private func withBoundPreparedStatement<T>(
        _ sql: borrowing SQL,
        _ body: (_ statement: borrowing SQLiteStmt, _ handle: SQLiteHandle) throws -> T
    ) throws -> T {
        try withBoundPreparedStatement(sql, handleLease: flowOut(), serializeWrites: true, body)
    }

    private func withBoundPreparedStatement<T>(
        _ sql: borrowing SQL,
        handleLease: SQLitePooledHandleLease,
        serializeWrites: Bool,
        _ body: (_ statement: borrowing SQLiteStmt, _ handle: SQLiteHandle) throws -> T
    ) throws -> T {
        var statement = try prepareBound(sql, handleLease: handleLease)
        defer { try? statement.finalize() }

        if !serializeWrites {
            return try body(statement, handleLease.handle)
        }

        if try statement.isReadOnly() {
            return try body(statement, handleLease.handle)
        }

        return try withWriteLock {
            try body(statement, handleLease.handle)
        }
    }

    public func executeRawScript(_ sql: String) throws {
        try withWriteLock {
            let handleLease = try flowOut()
            try handleLease.handle.execute(sql: sql)
        }
    }

    private func executeStatement<Result>(
        _ sql: borrowing SQL,
        result: (_ handle: SQLiteHandle) throws -> Result
    ) throws -> Result {
        try executeStatement(sql, serializeWrites: true, result: result)
    }

    private func executeStatement<Result>(
        _ sql: borrowing SQL,
        handleLease: SQLitePooledHandleLease,
        result: (_ handle: SQLiteHandle) throws -> Result
    ) throws -> Result {
        try executeStatement(sql, handleLease: handleLease, serializeWrites: false, result: result)
    }

    private func executeStatement<Result>(
        _ sql: borrowing SQL,
        serializeWrites: Bool,
        result: (_ handle: SQLiteHandle) throws -> Result
    ) throws -> Result {
        try executeStatement(sql, handleLease: flowOut(), serializeWrites: serializeWrites, result: result)
    }

    private func executeStatement<Result>(
        _ sql: borrowing SQL,
        handleLease: SQLitePooledHandleLease,
        serializeWrites: Bool,
        result: (_ handle: SQLiteHandle) throws -> Result
    ) throws -> Result {
        try withBoundPreparedStatement(sql, handleLease: handleLease, serializeWrites: serializeWrites) { statement, handle in
            guard statement.columnCount() == 0 else {
                throw SQLiteError(
                    code: SQLITE_MISUSE,
                    description: "Use fetch APIs for statements that return rows.",
                    operation: "execute",
                    sql: sql.statement
                )
            }

            let stepResult = try statement.step()
            guard stepResult == .done else {
                throw SQLiteError(
                    code: SQLITE_MISUSE,
                    description: "Use fetch APIs for statements that return rows.",
                    operation: "execute",
                    sql: sql.statement
                )
            }

            return try result(handle)
        }
    }

    public func execute(_ sql: borrowing SQL) throws {
        try executeStatement(sql) { _ in }
    }

    func execute(
        _ sql: borrowing SQL,
        handleLease: SQLitePooledHandleLease
    ) throws {
        try executeStatement(sql, handleLease: handleLease) { _ in }
    }

    public func executeResult(_ sql: borrowing SQL) throws -> SQLiteExecutionResult {
        try executeStatement(sql) { handle in
            return SQLiteExecutionResult(
                changes: handle.changes(),
                lastInsertRowID: handle.lastInsertRowID()
            )
        }
    }

    func executeResult(
        _ sql: borrowing SQL,
        handleLease: SQLitePooledHandleLease
    ) throws -> SQLiteExecutionResult {
        try executeStatement(sql, handleLease: handleLease) { handle in
            SQLiteExecutionResult(
                changes: handle.changes(),
                lastInsertRowID: handle.lastInsertRowID()
            )
        }
    }

    @discardableResult
    public func withTransaction<T>(
        _ mode: SQLiteTransactionMode = .immediate,
        _ body: (_ transaction: borrowing SQLiteTransactionContext) throws -> T
    ) throws -> T {
        if isInTransactionOnCurrentThread, let handleLease = Self.threadedHandles.value[identity] {
            return try _savepoint(handleLease: handleLease) {
                try body(SQLiteTransactionContext(database: self, handleLease: handleLease))
            }
        }

        return try _withTransaction(mode, body)
    }

    private func _withTransaction<T>(
        _ mode: SQLiteTransactionMode,
        _ body: (_ transaction: borrowing SQLiteTransactionContext) throws -> T
    ) throws -> T {
        return try handlePool.withWriteLock {
            let handleLease = try begin(mode)
            incrementTransactionDepth()
            do {
                let result = try body(SQLiteTransactionContext(database: self, handleLease: handleLease))
                try commit(handleLease: handleLease)
                decrementTransactionDepth()
                return result
            } catch {
                let rollbackError: (any Error)?
                do {
                    try rollback(handleLease: handleLease)
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

    func withSavepoint<T>(
        handleLease: SQLitePooledHandleLease,
        _ body: (_ transaction: borrowing SQLiteTransactionContext) throws -> T
    ) throws -> T {
        try _savepoint(handleLease: handleLease) {
            try body(SQLiteTransactionContext(database: self, handleLease: handleLease))
        }
    }

    private func _savepoint<T>(
        handleLease: SQLitePooledHandleLease,
        _ body: () throws -> T
    ) throws -> T {
        let savepointName = Self.makeSavepointName()

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

extension SQLiteDatabase {
    var cachedStatementCount: Int {
        handlePool.cachedStatementCount
    }
}
