import Foundation

public protocol SQLiteRowDecodable {
    init(row: SQLiteRow) throws
}

public extension SQLiteDatabase {
    func fetch<T: SQLiteRowDecodable>(_ sql: SQL, as type: T.Type = T.self) throws -> [T] {
        try fetch(sql) { row in
            try T(row: row)
        }
    }

    func fetchOne<T: SQLiteRowDecodable>(_ sql: SQL, as type: T.Type = T.self) throws -> T? {
        guard let row = try fetchOne(sql) else { return nil }
        return try T(row: row)
    }

    func scalar<T: SQLiteValueDecodable>(_ sql: SQL, as type: T.Type = T.self) throws -> T? {
        let value: SQLiteValue? = try scalar(sql)
        guard let value else { return nil }
        return try T.decodeSQLiteValue(value, column: "0")
    }
}

public extension SQLiteTransactionContext {
    func fetch<T: SQLiteRowDecodable>(_ sql: SQL, as type: T.Type = T.self) throws -> [T] {
        try fetch(sql) { row in
            try T(row: row)
        }
    }

    func fetchOne<T: SQLiteRowDecodable>(_ sql: SQL, as type: T.Type = T.self) throws -> T? {
        guard let row = try fetchOne(sql) else { return nil }
        return try T(row: row)
    }

    func scalar<T: SQLiteValueDecodable>(_ sql: SQL, as type: T.Type = T.self) throws -> T? {
        let value: SQLiteValue? = try scalar(sql)
        guard let value else { return nil }
        return try T.decodeSQLiteValue(value, column: "0")
    }
}
