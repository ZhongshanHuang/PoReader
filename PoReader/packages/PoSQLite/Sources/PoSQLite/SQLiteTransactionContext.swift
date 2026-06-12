import Foundation

public struct SQLiteTransactionContext: ~Copyable {
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

    public func fetch<T>(_ sql: SQL, map: (SQLiteRow) throws -> T) throws -> [T] {
        try database.fetch(sql, map: map)
    }

    public func fetch(_ sql: SQL) throws -> [SQLiteRow] {
        try database.fetch(sql)
    }

    public func forEachRow(_ sql: SQL, _ body: (SQLiteRow) throws -> Void) throws {
        try database.forEachRow(sql, body)
    }

    public func fetchOne(_ sql: SQL) throws -> SQLiteRow? {
        try database.fetchOne(sql)
    }

    public func scalar(_ sql: SQL) throws -> SQLiteValue? {
        try database.scalar(sql)
    }

    public func withPreparedStatement<T>(
        _ sql: SQL,
        access: SQLiteStatementAccess = .read,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T {
        try database.withPreparedStatement(sql, access: access, body)
    }

    public func executeScript(_ sql: String) throws {
        try database.executeScript(sql)
    }

    @discardableResult
    public func transaction<T>(_ mode: SQLiteTransaction = .immediate, _ body: (_ transaction: borrowing SQLiteTransactionContext) throws -> T) throws -> T {
        try database.transaction(mode, body)
    }
}
