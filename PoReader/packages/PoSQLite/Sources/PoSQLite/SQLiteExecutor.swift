import Foundation

public protocol SQLiteExecutor: ~Copyable {
    var path: String { get }

    /// Executes one statement that does not return rows.
    func execute(_ sql: SQL) throws

    /// Executes one statement that does not return rows and returns its connection-local result.
    func executeResult(_ sql: SQL) throws -> SQLiteExecutionResult

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
            try sql.bind(to: statement)
            var result = try statement.step()
            var metadata: SQLiteRowMetadata?
            while result == .row {
                let rowMetadata: SQLiteRowMetadata
                if let metadata {
                    rowMetadata = metadata
                } else {
                    rowMetadata = SQLiteRowMetadata(statement: statement)
                    metadata = rowMetadata
                }
                try body(try SQLiteRow(statement: statement, metadata: rowMetadata))
                result = try statement.step()
            }
        }
    }

    func forEachBorrowedRow(_ sql: SQL, _ body: (_ row: borrowing SQLiteBorrowedRow) throws -> Void) throws {
        try withPreparedStatement(SQL(sql.statement)) { statement in
            try sql.bind(to: statement)
            var result = try statement.step()
            var metadata: SQLiteRowMetadata?
            while result == .row {
                let rowMetadata: SQLiteRowMetadata
                if let metadata {
                    rowMetadata = metadata
                } else {
                    rowMetadata = SQLiteRowMetadata(statement: statement)
                    metadata = rowMetadata
                }
                try statement.withBorrowedRow(metadata: rowMetadata, body)
                result = try statement.step()
            }
        }
    }

    func fetchBorrowed<T>(_ sql: SQL, map: (_ row: borrowing SQLiteBorrowedRow) throws -> T) throws -> [T] {
        var rows: [T] = []
        try forEachBorrowedRow(sql) { row in
            rows.append(try map(row))
        }
        return rows
    }

    func fetchOneBorrowed<T>(_ sql: SQL, map: (_ row: borrowing SQLiteBorrowedRow) throws -> T) throws -> T? {
        try withPreparedStatement(SQL(sql.statement)) { statement in
            try sql.bind(to: statement)
            guard try statement.step() == .row else {
                return nil
            }
            return try statement.withBorrowedRow(metadata: SQLiteRowMetadata(statement: statement), map)
        }
    }

    func fetchOne(_ sql: SQL) throws -> SQLiteRow? {
        try withPreparedStatement(SQL(sql.statement)) { statement in
            try sql.bind(to: statement)
            guard try statement.step() == .row else {
                return nil
            }
            return try SQLiteRow(statement: statement, metadata: SQLiteRowMetadata(statement: statement))
        }
    }

    func scalar(_ sql: SQL) throws -> SQLiteValue? {
        try withPreparedStatement(SQL(sql.statement)) { statement in
            try sql.bind(to: statement)
            guard try statement.step() == .row else {
                return nil
            }
            return try statement.columnValue(position: 0)
        }
    }
}
