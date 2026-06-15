import Foundation

public protocol SQLiteExecutor: ~Copyable {
    var path: String { get }

    @discardableResult
    func execute(_ sql: SQL) throws -> SQLiteExecutionResult

    func withPreparedStatement<T>(
        _ sql: SQL,
        _ body: (_ statement: borrowing SQLiteStmt) throws -> T
    ) throws -> T
}

public extension SQLiteExecutor where Self: ~Copyable {
    func fetch<T>(_ sql: SQL, map: (SQLiteRow) throws -> T) throws -> [T] {
        var rows: [T] = []
        try forEachRow(sql) { row in
            rows.append(try map(row))
        }
        return rows
    }

    func fetch(_ sql: SQL) throws -> [SQLiteRow] {
        try fetch(sql) { $0 }
    }

    func forEachRow(_ sql: SQL, _ body: (SQLiteRow) throws -> Void) throws {
        try withPreparedStatement(SQL(sql.statement)) { statement in
            try statement.bind(sql.parameters)
            var result = try statement.step()
            while result == .row {
                try body(try SQLiteRow(statement: statement))
                result = try statement.step()
            }
        }
    }

    func fetchOne(_ sql: SQL) throws -> SQLiteRow? {
        try withPreparedStatement(SQL(sql.statement)) { statement in
            try statement.bind(sql.parameters)
            guard try statement.step() == .row else {
                return nil
            }
            return try SQLiteRow(statement: statement)
        }
    }

    func scalar(_ sql: SQL) throws -> SQLiteValue? {
        try fetchOne(sql)?[0]
    }
}
