import Foundation
import SQLite3

public protocol SQLiteBorrowedValueDecodable: SQLiteValueDecodable {
    static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> Self?
}

@safe public struct SQLiteBorrowedRow: ~Copyable {
    @unsafe private let statement: SQLite3Statement
    private let metadata: SQLiteRowMetadata

    internal init(statement: SQLite3Statement, metadata: SQLiteRowMetadata) {
        unsafe self.statement = statement
        self.metadata = metadata
    }

    public var count: Int {
        metadata.columnNames.count
    }

    public func columnName(at position: Int) throws -> String {
        let position = Int(try checkedColumnPosition(position))
        return metadata.columnNames[position]
    }

    public func columnIndex(named name: String) -> Int? {
        metadata.columnIndex(named: name)
    }

    public func value(at position: Int) throws -> SQLiteValue {
        let position = try checkedColumnPosition(position)
        switch columnType(at: position) {
        case .integer:
            return .integer(unsafe sqlite3_column_int64(statement, position))
        case .float:
            return .double(unsafe sqlite3_column_double(statement, position))
        case .text:
            return .text(columnText(at: position))
        case .blob:
            return .blob(columnData(at: position))
        case .null:
            return .null
        }
    }

    public func value(named name: String) throws -> SQLiteValue {
        try value(at: columnIndexOrThrow(named: name))
    }

    public func string(at position: Int) throws -> String? {
        let position = try checkedColumnPosition(position)
        switch columnType(at: position) {
        case .null:
            return nil
        case .text:
            return columnText(at: position)
        default:
            throw mismatch(column: "\(position)", expected: "TEXT", actual: try value(at: Int(position)))
        }
    }

    public func string(named name: String) throws -> String? {
        let position = try columnIndexOrThrow(named: name)
        switch columnType(at: Int32(position)) {
        case .null:
            return nil
        case .text:
            return columnText(at: Int32(position))
        default:
            throw mismatch(column: name, expected: "TEXT", actual: try value(at: position))
        }
    }

    public func int64(at position: Int) throws -> Int64? {
        let position = try checkedColumnPosition(position)
        switch columnType(at: position) {
        case .null:
            return nil
        case .integer:
            return unsafe sqlite3_column_int64(statement, position)
        default:
            throw mismatch(column: "\(position)", expected: "INTEGER", actual: try value(at: Int(position)))
        }
    }

    public func int64(named name: String) throws -> Int64? {
        let position = try columnIndexOrThrow(named: name)
        switch columnType(at: Int32(position)) {
        case .null:
            return nil
        case .integer:
            return unsafe sqlite3_column_int64(statement, Int32(position))
        default:
            throw mismatch(column: name, expected: "INTEGER", actual: try value(at: position))
        }
    }

    public func int(at position: Int) throws -> Int? {
        guard let value = try int64(at: position) else { return nil }
        guard value >= Int64(Int.min), value <= Int64(Int.max) else {
            throw SQLiteError(code: SQLITE_RANGE, description: "Column '\(position)' integer value is out of Int range.")
        }
        return Int(value)
    }

    public func int(named name: String) throws -> Int? {
        guard let value = try int64(named: name) else { return nil }
        guard value >= Int64(Int.min), value <= Int64(Int.max) else {
            throw SQLiteError(code: SQLITE_RANGE, description: "Column '\(name)' integer value is out of Int range.")
        }
        return Int(value)
    }

    public func double(at position: Int) throws -> Double? {
        let position = try checkedColumnPosition(position)
        switch columnType(at: position) {
        case .null:
            return nil
        case .float:
            return unsafe sqlite3_column_double(statement, position)
        case .integer:
            return Double(unsafe sqlite3_column_int64(statement, position))
        default:
            throw mismatch(column: "\(position)", expected: "REAL", actual: try value(at: Int(position)))
        }
    }

    public func double(named name: String) throws -> Double? {
        let position = try columnIndexOrThrow(named: name)
        switch columnType(at: Int32(position)) {
        case .null:
            return nil
        case .float:
            return unsafe sqlite3_column_double(statement, Int32(position))
        case .integer:
            return Double(unsafe sqlite3_column_int64(statement, Int32(position)))
        default:
            throw mismatch(column: name, expected: "REAL", actual: try value(at: position))
        }
    }

    public func bool(at position: Int) throws -> Bool? {
        let position = try checkedColumnPosition(position)
        switch columnType(at: position) {
        case .null:
            return nil
        case .integer:
            return unsafe sqlite3_column_int64(statement, position) != 0
        default:
            throw mismatch(column: "\(position)", expected: "INTEGER boolean", actual: try value(at: Int(position)))
        }
    }

    public func bool(named name: String) throws -> Bool? {
        let position = try columnIndexOrThrow(named: name)
        switch columnType(at: Int32(position)) {
        case .null:
            return nil
        case .integer:
            return unsafe sqlite3_column_int64(statement, Int32(position)) != 0
        default:
            throw mismatch(column: name, expected: "INTEGER boolean", actual: try value(at: position))
        }
    }

    public func data(at position: Int) throws -> Data? {
        let position = try checkedColumnPosition(position)
        switch columnType(at: position) {
        case .null:
            return nil
        case .blob:
            return columnData(at: position)
        default:
            throw mismatch(column: "\(position)", expected: "BLOB", actual: try value(at: Int(position)))
        }
    }

    public func data(named name: String) throws -> Data? {
        let position = try columnIndexOrThrow(named: name)
        switch columnType(at: Int32(position)) {
        case .null:
            return nil
        case .blob:
            return columnData(at: Int32(position))
        default:
            throw mismatch(column: name, expected: "BLOB", actual: try value(at: position))
        }
    }

    public func get<T: SQLiteValueDecodable>(_ position: Int, as type: T.Type = T.self) throws -> T? {
        try T.decodeSQLiteValue(value(at: position), column: "\(position)")
    }

    public func get<T: SQLiteBorrowedValueDecodable>(_ position: Int, as type: T.Type = T.self) throws -> T? {
        try T.decodeSQLiteBorrowedValue(self, position: position, column: "\(position)")
    }

    public func get<T: SQLiteValueDecodable>(_ name: String, as type: T.Type = T.self) throws -> T? {
        try T.decodeSQLiteValue(value(named: name), column: name)
    }

    public func get<T: SQLiteBorrowedValueDecodable>(_ name: String, as type: T.Type = T.self) throws -> T? {
        let position = try columnIndexOrThrow(named: name)
        return try T.decodeSQLiteBorrowedValue(self, position: position, column: name)
    }

    public func require<T: SQLiteValueDecodable>(_ position: Int, as type: T.Type = T.self) throws -> T {
        guard let value: T = try get(position, as: type) else {
            throw nullValue(column: "\(position)")
        }
        return value
    }

    public func require<T: SQLiteBorrowedValueDecodable>(_ position: Int, as type: T.Type = T.self) throws -> T {
        guard let value: T = try get(position, as: type) else {
            throw nullValue(column: "\(position)")
        }
        return value
    }

    public func require<T: SQLiteValueDecodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        guard let value: T = try get(name, as: type) else {
            throw nullValue(column: name)
        }
        return value
    }

    public func require<T: SQLiteBorrowedValueDecodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        guard let value: T = try get(name, as: type) else {
            throw nullValue(column: name)
        }
        return value
    }

    public func withBlob<R>(at position: Int, _ body: (Span<UInt8>) throws -> R) throws -> R? {
        let position = try checkedColumnPosition(position)
        switch columnType(at: position) {
        case .null:
            return nil
        case .blob:
            return try withBlobBytes(at: position, body)
        default:
            throw mismatch(column: "\(position)", expected: "BLOB", actual: try value(at: Int(position)))
        }
    }

    public func withBlob<R>(named name: String, _ body: (Span<UInt8>) throws -> R) throws -> R? {
        let position = try columnIndexOrThrow(named: name)
        return try withBlob(at: position, body)
    }
}

private extension SQLiteBorrowedRow {
    func checkedColumnPosition(_ position: Int) throws -> Int32 {
        guard position >= 0, position < count, let sqlitePosition = Int32(exactly: position) else {
            throw SQLiteError(code: SQLITE_RANGE, description: "Column index \(position) is out of range.")
        }
        return sqlitePosition
    }

    func columnIndexOrThrow(named name: String) throws -> Int {
        guard let position = columnIndex(named: name) else {
            throw SQLiteError(code: SQLITE_RANGE, description: "Column named '\(name)' was not found.")
        }
        return position
    }

    func columnType(at position: Int32) -> SQLiteType {
        SQLiteType(rawValue: unsafe sqlite3_column_type(statement, position)) ?? .null
    }

    func columnText(at position: Int32) -> String {
        guard let text = unsafe sqlite3_column_text(statement, position) else { return "" }
        let byteCount = unsafe Int(sqlite3_column_bytes(statement, position))
        let buffer = unsafe UnsafeRawBufferPointer(start: text, count: byteCount)
        return unsafe String(decoding: buffer, as: UTF8.self)
    }

    func columnData(at position: Int32) -> Data {
        let byteCount = unsafe Int(sqlite3_column_bytes(statement, position))
        guard byteCount > 0, let bytes = unsafe sqlite3_column_blob(statement, position) else {
            return Data()
        }
        return unsafe Data(bytes: bytes, count: byteCount)
    }

    func withBlobBytes<R>(at position: Int32, _ body: (Span<UInt8>) throws -> R) throws -> R {
        let byteCount = unsafe Int(sqlite3_column_bytes(statement, position))
        guard byteCount > 0, let bytes = unsafe sqlite3_column_blob(statement, position) else {
            return try [UInt8]().withUnsafeBufferPointer {
                try body(unsafe Span(_unsafeElements: $0))
            }
        }

        let buffer = unsafe UnsafeBufferPointer(start: bytes.assumingMemoryBound(to: UInt8.self), count: byteCount)
        return try body(unsafe Span(_unsafeElements: buffer))
    }

    func string(from value: SQLiteValue, column: String) throws -> String? {
        switch value {
        case .null:
            return nil
        case .text(let value):
            return value
        default:
            throw mismatch(column: column, expected: "TEXT", actual: value)
        }
    }

    func int64(from value: SQLiteValue, column: String) throws -> Int64? {
        switch value {
        case .null:
            return nil
        case .integer(let value):
            return value
        default:
            throw mismatch(column: column, expected: "INTEGER", actual: value)
        }
    }

    func int(from value: SQLiteValue, column: String) throws -> Int? {
        guard let value = try int64(from: value, column: column) else { return nil }
        guard value >= Int64(Int.min), value <= Int64(Int.max) else {
            throw SQLiteError(code: SQLITE_RANGE, description: "Column '\(column)' integer value is out of Int range.")
        }
        return Int(value)
    }

    func double(from value: SQLiteValue, column: String) throws -> Double? {
        switch value {
        case .null:
            return nil
        case .double(let value):
            return value
        case .integer(let value):
            return Double(value)
        default:
            throw mismatch(column: column, expected: "REAL", actual: value)
        }
    }

    func bool(from value: SQLiteValue, column: String) throws -> Bool? {
        switch value {
        case .null:
            return nil
        case .integer(let value):
            return value != 0
        default:
            throw mismatch(column: column, expected: "INTEGER boolean", actual: value)
        }
    }

    func data(from value: SQLiteValue, column: String) throws -> Data? {
        switch value {
        case .null:
            return nil
        case .blob(let value):
            return value
        default:
            throw mismatch(column: column, expected: "BLOB", actual: value)
        }
    }

    func mismatch(column: String, expected: String, actual: SQLiteValue) -> SQLiteError {
        SQLiteError(
            code: SQLITE_MISMATCH,
            description: "Column '\(column)' expected \(expected), got \(actual.storageDescription)."
        )
    }

    func nullValue(column: String) -> SQLiteError {
        SQLiteError(
            code: SQLITE_MISMATCH,
            description: "Column '\(column)' is NULL."
        )
    }
}

private extension SQLiteValue {
    var storageDescription: String {
        switch self {
        case .null:
            return "NULL"
        case .integer:
            return "INTEGER"
        case .double:
            return "REAL"
        case .text:
            return "TEXT"
        case .blob:
            return "BLOB"
        }
    }
}

extension SQLiteValue: SQLiteBorrowedValueDecodable {
    public static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> SQLiteValue? {
        try row.value(at: position)
    }
}

extension String: SQLiteBorrowedValueDecodable {
    public static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> String? {
        try row.string(at: position)
    }
}

extension Int64: SQLiteBorrowedValueDecodable {
    public static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> Int64? {
        try row.int64(at: position)
    }
}

extension Int: SQLiteBorrowedValueDecodable {
    public static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> Int? {
        try row.int(at: position)
    }
}

extension Double: SQLiteBorrowedValueDecodable {
    public static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> Double? {
        try row.double(at: position)
    }
}

extension Bool: SQLiteBorrowedValueDecodable {
    public static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> Bool? {
        try row.bool(at: position)
    }
}

extension Array: SQLiteBorrowedValueDecodable where Element == UInt8 {
    public static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> [UInt8]? {
        guard let data = try row.data(at: position) else { return nil }
        return Array(data)
    }
}

extension Data: SQLiteBorrowedValueDecodable {
    public static func decodeSQLiteBorrowedValue(
        _ row: borrowing SQLiteBorrowedRow,
        position: Int,
        column: String
    ) throws -> Data? {
        try row.data(at: position)
    }
}
