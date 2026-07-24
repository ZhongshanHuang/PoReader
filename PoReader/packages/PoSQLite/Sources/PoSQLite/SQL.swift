import Foundation

public struct SQL: Equatable, Sendable, CustomStringConvertible {
    public let statement: String
    public let parameters: [SQLiteValue]
    /// Named SQLite bind values keyed by their complete placeholder names.
    /// `nil` indicates positional binding.
    public let namedParameters: [String: SQLiteValue]?

    public var description: String {
        statement
    }

    public init(_ statement: String, parameters: [SQLiteValue] = []) {
        self.statement = statement
        self.parameters = parameters
        self.namedParameters = nil
    }

    /// Creates a statement whose values are bound by SQLite parameter name.
    public init(_ statement: String, namedParameters: [String: SQLiteValue]) {
        self.statement = statement
        self.parameters = []
        self.namedParameters = namedParameters
    }

    public static func quoteIdentifier(_ identifier: String) -> String {
        "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    var hasBoundParameters: Bool {
        !parameters.isEmpty || namedParameters != nil
    }

    func bind(to statement: borrowing SQLiteStmt) throws {
        if let namedParameters {
            try statement.bind(namedParameters)
        } else {
            try statement.bind(parameters)
        }
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

        public mutating func appendInterpolation(unsafeRaw sql: String) {
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
