import Foundation
import SQLite3

@safe final class SQLiteStatementCache {
    private let capacity: Int
    @unsafe private var statements: FastLRUCache<String, SQLite3Statement>

    init(capacity: Int) {
        self.capacity = max(0, capacity)
        unsafe self.statements = FastLRUCache(capacity: self.capacity)
    }

    deinit {
        clear()
    }

    var count: Int {
        unsafe statements.count
    }

    func take(statement sql: String) -> SQLite3Statement? {
        unsafe statements.removeValue(forKey: sql)
    }

    func store(_ statement: SQLite3Statement, sql: String) -> SQLiteStatementDisposalResult {
        let database = unsafe sqlite3_db_handle(statement)
        let resetResult = unsafe sqlite3_reset(statement)
        guard resetResult == SQLITE_OK else {
            unsafe sqlite3_finalize(statement)
            return unsafe SQLiteStatementDisposalResult(
                code: resetResult,
                database: database,
                operation: "reset",
                fallback: "sqlite3_reset failed while caching statement."
            )
        }

        let clearResult = unsafe sqlite3_clear_bindings(statement)
        guard clearResult == SQLITE_OK else {
            unsafe sqlite3_finalize(statement)
            return unsafe SQLiteStatementDisposalResult(
                code: clearResult,
                database: database,
                operation: "clear_bindings",
                fallback: "sqlite3_clear_bindings failed while caching statement."
            )
        }

        guard capacity > 0 else {
            return unsafe finalize(statement, operation: "finalize")
        }

        if let discarded = unsafe statements.insertValue(statement, forKey: sql) {
            unsafe sqlite3_finalize(discarded)
        }

        return unsafe SQLiteStatementDisposalResult(
            code: SQLITE_OK,
            database: database,
            operation: "cache_statement",
            fallback: "Cached statement."
        )
    }

    func clear() {
        while let statement = unsafe statements.removeLeastRecentlyUsedValue() {
            unsafe sqlite3_finalize(statement)
        }
    }

    private func finalize(_ statement: SQLite3Statement, operation: String) -> SQLiteStatementDisposalResult {
        let database = unsafe sqlite3_db_handle(statement)
        let result = unsafe sqlite3_finalize(statement)
        return unsafe SQLiteStatementDisposalResult(
            code: result,
            database: database,
            operation: operation,
            fallback: "sqlite3_finalize failed."
        )
    }
}

@safe struct SQLiteStatementDisposalResult {
    let code: Int32
    @unsafe let database: SQLite3?
    let operation: String
    let fallback: String
}

enum SQLiteStatementDisposal {
    case finalize
    case cache(SQLiteStatementCache, sql: String)
}
