import Foundation

public struct SQL: Equatable, Sendable, CustomStringConvertible {
    public let statement: String
    public let parameters: [SQLiteValue]

    public var description: String {
        statement
    }

    public init(_ statement: String, parameters: [SQLiteValue] = []) {
        self.statement = statement
        self.parameters = parameters
    }

    public static func quoteIdentifier(_ identifier: String) -> String {
        "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

extension SQL: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension SQL: ExpressibleByStringInterpolation {
    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.statement, parameters: stringInterpolation.parameters)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        var statement: String
        var parameters: [SQLiteValue]

        public init(literalCapacity: Int, interpolationCount: Int) {
            self.statement = ""
            self.statement.reserveCapacity(literalCapacity + interpolationCount)
            self.parameters = []
            self.parameters.reserveCapacity(interpolationCount)
        }

        public mutating func appendLiteral(_ literal: String) {
            statement += literal
        }

        public mutating func appendInterpolation<Value: SQLiteValueConvertible>(_ value: Value) {
            appendValue(value.sqliteValue)
        }

        public mutating func appendInterpolation<Value: SQLiteValueConvertible>(_ value: Value?) {
            appendValue(value?.sqliteValue ?? .null)
        }

        public mutating func appendInterpolation(raw sql: String) {
            statement += sql
        }

        public mutating func appendInterpolation(identifier value: String) {
            statement += SQL.quoteIdentifier(value)
        }

        private mutating func appendValue(_ value: SQLiteValue) {
            statement += "?"
            parameters.append(value)
        }
    }
}

public struct SQLiteExecutionResult: Equatable, Sendable {
    public let changes: Int
    public let lastInsertRowID: Int
}
