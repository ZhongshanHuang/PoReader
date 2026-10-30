import Foundation

public struct SQLiteTransactionContext: SQLiteExecutor, ~Copyable {
    private let database: SQLiteDatabase
    private let handleLease: SQLitePooledHandleLease

    init(database: SQLiteDatabase, handleLease: SQLitePooledHandleLease) {
        self.database = database
        self.handleLease = handleLease
    }

    public var path: String {
        database.path
    }

    public func execute(_ sql: borrowing SQL) throws {
        try database.execute(sql, handleLease: handleLease)
    }

    public func executeResult(_ sql: borrowing SQL) throws -> SQLiteExecutionResult {
        try database.executeResult(sql, handleLease: handleLease)
    }

    public func withPreparedStatement<T>(
        _ sql: borrowing SQL,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        try database.withPreparedStatement(sql, handleLease: handleLease, body)
    }

    @discardableResult
    public func withTransaction<T>(
        _ mode: SQLiteTransactionMode = .immediate,
        _ body: (_ transaction: borrowing SQLiteTransactionContext) throws -> T
    ) throws -> T {
        try database.withSavepoint(handleLease: handleLease, body)
    }
}
