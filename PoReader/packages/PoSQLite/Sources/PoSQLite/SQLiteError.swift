import Foundation

public extension SQLiteError {
    
    static func warning(_ msg: String) {
#if DEBUG
        print("🔴🔔🔔🔴 \(msg)")
#endif
    }
}

public struct SQLiteError: Error, LocalizedError, CustomStringConvertible, Sendable {
    public struct BindContext: Equatable, Sendable {
        public let position: Int?
        public let name: String?

        public static func position(_ position: Int) -> Self {
            Self(position: position, name: nil)
        }

        public static func name(_ name: String) -> Self {
            Self(position: nil, name: name)
        }
    }

    public let code: Int32
    public let extendedCode: Int32?
    public let message: String
    public let operation: String?
    public let sql: String?
    public let bind: BindContext?
    public let description: String

    public var errorDescription: String? {
        description
    }

    public var localizedDescription: String {
        return description
    }
    public init(
        code: Int32,
        extendedCode: Int32? = nil,
        description: String,
        operation: String? = nil,
        sql: String? = nil,
        bind: BindContext? = nil
    ) {
        self.code = code
        self.extendedCode = extendedCode
        self.message = description
        self.operation = operation
        self.sql = sql
        self.bind = bind
        self.description = Self.makeDescription(
            message: description,
            code: code,
            extendedCode: extendedCode,
            operation: operation,
            sql: sql,
            bind: bind
        )
    }
    
    public init(
        code: Int,
        extendedCode: Int32? = nil,
        description: String,
        operation: String? = nil,
        sql: String? = nil,
        bind: BindContext? = nil
    ) {
        self.init(
            code: Int32(truncatingIfNeeded: code),
            extendedCode: extendedCode,
            description: description,
            operation: operation,
            sql: sql,
            bind: bind
        )
    }

    private static func makeDescription(
        message: String,
        code: Int32,
        extendedCode: Int32?,
        operation: String?,
        sql: String?,
        bind: BindContext?
    ) -> String {
        var parts = [message]
        parts.append("code=\(code)")
        if let extendedCode {
            parts.append("extendedCode=\(extendedCode)")
        }
        if let operation {
            parts.append("operation=\(operation)")
        }
        if let sql {
            parts.append("sql=\(sql)")
        }
        if let bind {
            if let position = bind.position {
                parts.append("bindPosition=\(position)")
            }
            if let name = bind.name {
                parts.append("bindName=\(name)")
            }
        }
        return parts.joined(separator: " | ")
    }
}

public struct SQLiteTransactionError: Error, LocalizedError, CustomStringConvertible {
    public let primaryError: any Error
    public let rollbackError: any Error

    public var description: String {
        "Transaction failed with primary error: \(primaryError). Rollback also failed with: \(rollbackError)."
    }

    public var errorDescription: String? {
        description
    }

    public init(primaryError: any Error, rollbackError: any Error) {
        self.primaryError = primaryError
        self.rollbackError = rollbackError
    }
}
