import Foundation
import SQLite3

public enum SQLiteValue: Equatable, Sendable {
    case null
    case integer(Int64)
    case double(Double)
    case text(String)
    case blob(Data)

    public init(_ value: Int) {
        self = .integer(Int64(value))
    }

    public init(_ value: Int32) {
        self = .integer(Int64(value))
    }

    public init(_ value: Int64) {
        self = .integer(value)
    }

    public init(_ value: Double) {
        self = .double(value)
    }

    public init(_ value: String) {
        self = .text(value)
    }

    public init(_ value: Bool) {
        self = .integer(value ? 1 : 0)
    }

    public init(_ value: [UInt8]) {
        self = .blob(Data(value))
    }

    public init(_ value: Data) {
        self = .blob(value)
    }
}

public protocol SQLiteValueConvertible: Sendable {
    var sqliteValue: SQLiteValue { get }
}

extension SQLiteValue: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { self }
}

extension Int: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { SQLiteValue(self) }
}

extension Int32: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { SQLiteValue(self) }
}

extension Int64: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { SQLiteValue(self) }
}

extension Double: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { SQLiteValue(self) }
}

extension Bool: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { SQLiteValue(self) }
}

extension String: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { SQLiteValue(self) }
}

extension Data: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { SQLiteValue(self) }
}

extension Array: SQLiteValueConvertible where Element == UInt8 {
    public var sqliteValue: SQLiteValue { SQLiteValue(self) }
}

extension Optional: SQLiteValueConvertible where Wrapped: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue { self?.sqliteValue ?? .null }
}

extension SQLiteValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension SQLiteValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension SQLiteValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension SQLiteValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension SQLiteValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

public extension SQLiteStmt {
    func bind<Value: SQLiteValueConvertible>(position: Int, _ value: Value) throws {
        try bindSQLiteValue(position: position, value.sqliteValue)
    }

    func bind<Value: SQLiteValueConvertible>(name: String, _ value: Value) throws {
        try bindSQLiteValue(name: name, value.sqliteValue)
    }

    func bind(_ values: [SQLiteValue]) throws {
        try validatePositionalBindCount(values.count)
        for (offset, value) in values.enumerated() {
            try bind(position: offset + 1, value)
        }
    }

    func bind(_ values: [String: SQLiteValue]) throws {
        try validateNamedBindParameters(values.keys)
        for (name, value) in values {
            try bind(name: name, value)
        }
    }

    private func validatePositionalBindCount(_ count: Int) throws {
        let expected = try bindParameterCount()
        guard count == expected else {
            throw SQLiteError(
                code: SQLITE_RANGE,
                description: "Expected \(expected) bind parameters, got \(count).",
                operation: "bind_parameter_count"
            )
        }
    }

    private func validateNamedBindParameters(_ names: Dictionary<String, SQLiteValue>.Keys) throws {
        let expectedCount = try bindParameterCount()
        guard expectedCount > 0 || names.isEmpty else {
            throw SQLiteError(
                code: SQLITE_RANGE,
                description: "Expected 0 bind parameters, got \(names.count).",
                operation: "bind_parameter_count"
            )
        }

        var expectedNames = Set<String>()
        var hasAnonymousParameters = false
        if expectedCount > 0 {
            for position in 1...expectedCount {
                if let name = try bindParameterName(position: position) {
                    expectedNames.insert(name)
                } else {
                    hasAnonymousParameters = true
                }
            }
        }

        if hasAnonymousParameters {
            throw SQLiteError(
                code: SQLITE_RANGE,
                description: "Dictionary binding requires every SQL parameter to be named.",
                operation: "bind_parameter_names"
            )
        }

        let providedNames = Set(names)
        let missingNames = expectedNames.subtracting(providedNames).sorted()
        let extraNames = providedNames.subtracting(expectedNames).sorted()
        guard missingNames.isEmpty, extraNames.isEmpty else {
            var parts: [String] = []
            if !missingNames.isEmpty {
                parts.append("missing: \(missingNames.joined(separator: ", "))")
            }
            if !extraNames.isEmpty {
                parts.append("extra: \(extraNames.joined(separator: ", "))")
            }
            throw SQLiteError(
                code: SQLITE_RANGE,
                description: "Named bind parameters do not match SQL parameters (\(parts.joined(separator: "; "))).",
                operation: "bind_parameter_names"
            )
        }
    }
}
