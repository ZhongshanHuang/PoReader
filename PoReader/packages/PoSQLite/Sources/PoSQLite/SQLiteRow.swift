import Foundation
import SQLite3

final class SQLiteRowMetadata: Sendable {
    let columnNames: [String]
    private let columnIndexes: [String: Int]

    init(columnNames: [String], valueCount: Int) {
        self.columnNames = columnNames

        var columnIndexes: [String: Int] = [:]
        columnIndexes.reserveCapacity(min(columnNames.count, valueCount))
        for (index, name) in columnNames.enumerated() where index < valueCount && columnIndexes[name] == nil {
            columnIndexes[name] = index
        }
        self.columnIndexes = columnIndexes
    }

    init(statement: borrowing SQLiteStmt) {
        let count = statement.columnCount()
        var columnNames: [String] = []
        columnNames.reserveCapacity(count)

        var sqlitePosition: Int32 = 0
        for _ in 0..<count {
            columnNames.append(statement.columnName(sqlitePosition: sqlitePosition))
            sqlitePosition &+= 1
        }

        self.columnNames = columnNames

        var columnIndexes: [String: Int] = [:]
        columnIndexes.reserveCapacity(count)
        for (index, name) in columnNames.enumerated() where columnIndexes[name] == nil {
            columnIndexes[name] = index
        }
        self.columnIndexes = columnIndexes
    }

    @inline(__always)
    func columnIndex(named name: String) -> Int? {
        columnIndexes[name]
    }
}

public struct SQLiteRow: Equatable, Sendable {
    public let values: [SQLiteValue]

    private let metadata: SQLiteRowMetadata

    public var columnNames: [String] {
        metadata.columnNames
    }

    public var count: Int {
        values.count
    }

    public subscript(position: Int) -> SQLiteValue? {
        guard position >= 0, position < values.count else { return nil }
        return values[position]
    }

    public subscript(name: String) -> SQLiteValue? {
        guard let position = metadata.columnIndex(named: name) else { return nil }
        return values[position]
    }

    public init(columnNames: [String], values: [SQLiteValue]) {
        self.values = values
        self.metadata = SQLiteRowMetadata(columnNames: columnNames, valueCount: values.count)
    }

    init(metadata: SQLiteRowMetadata, values: [SQLiteValue]) {
        self.values = values
        self.metadata = metadata
    }

    public static func == (lhs: SQLiteRow, rhs: SQLiteRow) -> Bool {
        lhs.columnNames == rhs.columnNames && lhs.values == rhs.values
    }

    public func value(at position: Int) throws -> SQLiteValue {
        guard let value = self[position] else {
            throw SQLiteError(code: SQLITE_RANGE, description: "Column index \(position) is out of range.")
        }
        return value
    }

    public func value(named name: String) throws -> SQLiteValue {
        guard let value = self[name] else {
            throw SQLiteError(code: SQLITE_RANGE, description: "Column named '\(name)' was not found.")
        }
        return value
    }

    public func string(at position: Int) throws -> String? {
        try string(from: value(at: position), column: "\(position)")
    }

    public func string(named name: String) throws -> String? {
        try string(from: value(named: name), column: name)
    }

    public func int64(at position: Int) throws -> Int64? {
        try int64(from: value(at: position), column: "\(position)")
    }

    public func int64(named name: String) throws -> Int64? {
        try int64(from: value(named: name), column: name)
    }

    public func int(at position: Int) throws -> Int? {
        try int(from: value(at: position), column: "\(position)")
    }

    public func int(named name: String) throws -> Int? {
        try int(from: value(named: name), column: name)
    }

    public func double(at position: Int) throws -> Double? {
        try double(from: value(at: position), column: "\(position)")
    }

    public func double(named name: String) throws -> Double? {
        try double(from: value(named: name), column: name)
    }

    public func bool(at position: Int) throws -> Bool? {
        try bool(from: value(at: position), column: "\(position)")
    }

    public func bool(named name: String) throws -> Bool? {
        try bool(from: value(named: name), column: name)
    }

    public func blob(at position: Int) throws -> [UInt8]? {
        try blob(from: value(at: position), column: "\(position)")
    }

    public func blob(named name: String) throws -> [UInt8]? {
        try blob(from: value(named: name), column: name)
    }

    public func data(at position: Int) throws -> Data? {
        try data(from: value(at: position), column: "\(position)")
    }

    public func data(named name: String) throws -> Data? {
        try data(from: value(named: name), column: name)
    }

    public func get<T: SQLiteValueDecodable>(_ position: Int, as type: T.Type = T.self) throws -> T? {
        try T.decodeSQLiteValue(value(at: position), column: "\(position)")
    }

    public func get<T: SQLiteValueDecodable>(_ name: String, as type: T.Type = T.self) throws -> T? {
        try T.decodeSQLiteValue(value(named: name), column: name)
    }

    public func require<T: SQLiteValueDecodable>(_ position: Int, as type: T.Type = T.self) throws -> T {
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
}

public protocol SQLiteValueDecodable {
    static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> Self?
}

extension SQLiteRow {
    init(statement: borrowing SQLiteStmt, metadata: SQLiteRowMetadata) throws {
        var values: [SQLiteValue] = []
        let count = metadata.columnNames.count

        values.reserveCapacity(count)

        var sqlitePosition: Int32 = 0
        for _ in 0..<count {
            values.append(statement.columnValue(sqlitePosition: sqlitePosition))
            sqlitePosition &+= 1
        }

        self.init(metadata: metadata, values: values)
    }
}

private extension SQLiteRow {
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

    func blob(from value: SQLiteValue, column: String) throws -> [UInt8]? {
        switch value {
        case .null:
            return nil
        case .blob(let value):
            return Array(value)
        default:
            throw mismatch(column: column, expected: "BLOB", actual: value)
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

extension SQLiteValue: SQLiteValueDecodable {
    public static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> SQLiteValue? {
        value
    }
}

extension String: SQLiteValueDecodable {
    public static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> String? {
        switch value {
        case .null:
            return nil
        case .text(let value):
            return value
        default:
            throw SQLiteRow.typeMismatch(column: column, expected: "TEXT", actual: value)
        }
    }
}

extension Int64: SQLiteValueDecodable {
    public static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> Int64? {
        switch value {
        case .null:
            return nil
        case .integer(let value):
            return value
        default:
            throw SQLiteRow.typeMismatch(column: column, expected: "INTEGER", actual: value)
        }
    }
}

extension Int: SQLiteValueDecodable {
    public static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> Int? {
        guard let value = try Int64.decodeSQLiteValue(value, column: column) else { return nil }
        guard value >= Int64(Int.min), value <= Int64(Int.max) else {
            throw SQLiteError(code: SQLITE_RANGE, description: "Column '\(column)' integer value is out of Int range.")
        }
        return Int(value)
    }
}

extension Double: SQLiteValueDecodable {
    public static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> Double? {
        switch value {
        case .null:
            return nil
        case .double(let value):
            return value
        case .integer(let value):
            return Double(value)
        default:
            throw SQLiteRow.typeMismatch(column: column, expected: "REAL", actual: value)
        }
    }
}

extension Bool: SQLiteValueDecodable {
    public static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> Bool? {
        switch value {
        case .null:
            return nil
        case .integer(let value):
            return value != 0
        default:
            throw SQLiteRow.typeMismatch(column: column, expected: "INTEGER boolean", actual: value)
        }
    }
}

extension Array: SQLiteValueDecodable where Element == UInt8 {
    public static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> [UInt8]? {
        switch value {
        case .null:
            return nil
        case .blob(let value):
            return Array(value)
        default:
            throw SQLiteRow.typeMismatch(column: column, expected: "BLOB", actual: value)
        }
    }
}

extension Data: SQLiteValueDecodable {
    public static func decodeSQLiteValue(_ value: SQLiteValue, column: String) throws -> Data? {
        switch value {
        case .null:
            return nil
        case .blob(let value):
            return value
        default:
            throw SQLiteRow.typeMismatch(column: column, expected: "BLOB", actual: value)
        }
    }
}

private extension SQLiteRow {
    static func typeMismatch(column: String, expected: String, actual: SQLiteValue) -> SQLiteError {
        SQLiteError(
            code: SQLITE_MISMATCH,
            description: "Column '\(column)' expected \(expected), got \(actual.storageDescription)."
        )
    }
}
