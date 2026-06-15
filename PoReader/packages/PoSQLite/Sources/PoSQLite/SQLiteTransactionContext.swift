import Foundation

public struct SQLiteTransactionContext: SQLiteExecutor, ~Copyable {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    public var path: String {
        database.path
    }

    @discardableResult
    public func execute(_ sql: SQL) throws -> SQLiteExecutionResult {
        try database.execute(sql)
    }

    public func withPreparedStatement<T>(
        _ sql: SQL,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        try database.withPreparedStatement(sql, body)
    }

    @discardableResult
    public func withTransaction<T>(_ mode: SQLiteTransactionMode = .immediate, _ body: (_ transaction: borrowing SQLiteTransactionContext) throws -> T) throws -> T {
        try database.withTransaction(mode, body)
    }
}
