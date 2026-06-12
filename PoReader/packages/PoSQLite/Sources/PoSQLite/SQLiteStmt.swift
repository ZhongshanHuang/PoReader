import Foundation
import SQLite3

@unsafe private let sqliteTransient = unsafe unsafeBitCast(unsafe OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

public enum SQLiteType: Int32, Sendable {
    case integer = 1    // SQLITE_INTEGER
    case float = 2      // SQLITE_FLOAT
    case text = 3       // SQLITE_TEXT
    case blob = 4       // SQLITE_BLOB
    case null = 5       // SQLITE_NULL
}

public enum SQLiteStepResult: Int32, Sendable {
    case row = 100      // SQLITE_ROW
    case done = 101     // SQLITE_DONE
}

@safe public struct SQLiteStmt: ~Copyable {
    @unsafe private var stat: SQLite3Statement!
    private let sql: String?
    var lease: SQLiteStatementLease?
    
    deinit {
        if unsafe self.stat != nil {
            unsafe sqlite3_finalize(self.stat)
        }
    }
    
    internal init(stat: SQLite3Statement, sql: String? = nil) {
        unsafe self.stat = stat
        self.sql = sql
    }
    
    public func reset(clearBindings: Bool = false) throws {
        try _checkResult(try _reset(), operation: "reset")
        if clearBindings {
            try self.clearBindings()
        }
    }

    public func clearBindings() throws {
        try _checkResult(try _clearBindings(), operation: "clear_bindings")
    }
    
    public mutating func finalize() throws {
        defer { self.lease = nil }
        try _finalize()
    }
    
    /// Returns `.row` when a row is available and `.done` when the statement has completed.
    @discardableResult
    public func step() throws -> SQLiteStepResult {
        let res = try _step()
        try _checkResult(res, isStep: true, operation: "step")
        guard let result = SQLiteStepResult(rawValue: res) else {
            throw SQLiteError(
                code: SQLITE_MISUSE,
                description: "Unexpected sqlite3_step result: \(res).",
                operation: "step",
                sql: sql
            )
        }
        return result
    }

    private func checkedBindPosition(_ position: Int) throws -> Int32 {
        guard let sqlitePosition = Int32(exactly: position) else {
            throw SQLiteError(
                code: SQLITE_RANGE,
                description: "Bind parameter position is out of range.",
                operation: "bind",
                sql: sql,
                bind: .position(position)
            )
        }
        return sqlitePosition
    }

    private func sqlitePosition(_ position: Int) -> Int32 {
        Int32(exactly: position) ?? (position < 0 ? Int32.min : Int32.max)
    }
    
    public func bindBlob(position: Int, bytes: Span<UInt8>) throws {
        try _checkResult(try _bindBlob(position: checkedBindPosition(position), bytes: bytes), operation: "bind", bind: .position(position))
    }
    
    public func bindZeroBlob(position: Int, count: Int) throws {
        try _checkResult(try _bindZeroBlob(position: checkedBindPosition(position), count: count), operation: "bind", bind: .position(position))
    }
    
    public func bindNull(position: Int) throws {
        try _checkResult(try _bindNull(position: checkedBindPosition(position)), operation: "bind", bind: .position(position))
    }

    public func bindBlob(name: String, bytes: Span<UInt8>) throws {
        try _checkResult(try _bindBlob(position: bindParameterIndex(name: name), bytes: bytes), operation: "bind", bind: .name(name))
    }
    
    public func bindZeroBlob(name: String, count: Int) throws {
        try _checkResult(try _bindZeroBlob(position: bindParameterIndex(name: name), count: count), operation: "bind", bind: .name(name))
    }
    
    public func bindNull(name: String) throws {
        try _checkResult(try _bindNull(position: bindParameterIndex(name: name)), operation: "bind", bind: .name(name))
    }

    func bindSQLiteValue(position: Int, _ value: SQLiteValue) throws {
        let sqlitePosition = try checkedBindPosition(position)
        let result: Int32
        switch value {
        case .null:
            result = try _bindNull(position: sqlitePosition)
        case .integer(let value):
            result = try _bindInt64(position: sqlitePosition, value)
        case .double(let value):
            result = try _bindDouble(position: sqlitePosition, value)
        case .text(let value):
            result = try _bindText(position: sqlitePosition, value)
        case .blob(let value):
            result = try _bindBlob(position: sqlitePosition, data: value)
        }
        try _checkResult(result, operation: "bind", bind: .position(position))
    }

    func bindSQLiteValue(name: String, _ value: SQLiteValue) throws {
        let sqlitePosition = try bindParameterIndex(name: name)
        let result: Int32
        switch value {
        case .null:
            result = try _bindNull(position: sqlitePosition)
        case .integer(let value):
            result = try _bindInt64(position: sqlitePosition, value)
        case .double(let value):
            result = try _bindDouble(position: sqlitePosition, value)
        case .text(let value):
            result = try _bindText(position: sqlitePosition, value)
        case .blob(let value):
            result = try _bindBlob(position: sqlitePosition, data: value)
        }
        try _checkResult(result, operation: "bind", bind: .name(name))
    }
    
    /// :name
    public func bindParameterIndex(name: String) throws -> Int32 {
        let idx = try _bindParameterIndex(name: name)
        if idx == 0 {
            throw SQLiteError(
                code: SQLITE_MISUSE,
                description: "The indicated bind parameter name was not found.",
                operation: "bind_parameter_index",
                sql: sql,
                bind: .name(name)
            )
        }
        return idx
    }

    public func bindParameterCount() throws -> Int {
        Int(try _bindParameterCount())
    }

    public func bindParameterName(position: Int) throws -> String? {
        try _bindParameterName(position: checkedBindPosition(position))
    }
    
    public func columnName(position: Int) -> String {
        _columnName(position: sqlitePosition(position))
    }
    
    public func columnDeclaredType(position: Int) -> String {
        _columnDeclaredType(position: sqlitePosition(position))
    }
    
    public func columnType(position: Int) -> SQLiteType {
        let res = _columnType(position: sqlitePosition(position))
        return SQLiteType(rawValue: res) ?? .null
    }
    
    public func columnCount() -> Int {
        Int(_columnCount())
    }

    public func columnValue(position: Int) -> SQLiteValue {
        let sqlitePosition = sqlitePosition(position)
        switch columnType(position: position) {
        case .integer:
            return .integer(_columnInt64(position: sqlitePosition))
        case .float:
            return .double(_columnDouble(position: sqlitePosition))
        case .text:
            return .text(_columnText(position: sqlitePosition))
        case .blob:
            return .blob(_columnData(position: sqlitePosition))
        case .null:
            return .null
        }
    }

    public func withColumnBlob<R>(position: Int, _ body: (Span<UInt8>) throws -> R) rethrows -> R {
        try _withColumnBlob(position: sqlitePosition(position), body)
    }

    private func _reset() throws -> Int32 {
        unsafe sqlite3_reset(try _statement())
    }

    private func _clearBindings() throws -> Int32 {
        unsafe sqlite3_clear_bindings(try _statement())
    }

    private mutating func _finalize() throws {
        guard let statement = unsafe self.stat else { return }

        let database = unsafe sqlite3_db_handle(statement)
        let result = unsafe sqlite3_finalize(statement)
        unsafe self.stat = nil

        try unsafe Self._checkResult(result, database: database, fallback: "sqlite3_finalize", operation: "finalize", sql: sql)
    }

    private func _step() throws -> Int32 {
        unsafe sqlite3_step(try _statement())
    }

    private func _bindDouble(position: Int32, _ value: Double) throws -> Int32 {
        unsafe sqlite3_bind_double(try _statement(), position, value)
    }

    private func _bindInt64(position: Int32, _ value: Int64) throws -> Int32 {
        unsafe sqlite3_bind_int64(try _statement(), position, value)
    }

    private func _bindText(position: Int32, _ value: String) throws -> Int32 {
        let statement = try unsafe _statement()
        return value.withCString { pointer in
            unsafe sqlite3_bind_text64(statement, position, pointer, UInt64(value.utf8.count), sqliteTransient, UInt8(SQLITE_UTF8))
        }
    }

    private func _bindBlobBuffer(statement: SQLite3Statement, position: Int32, bytes: UnsafeRawPointer?, count: Int) -> Int32 {
        guard count > 0 else {
            return unsafe sqlite3_bind_zeroblob64(statement, position, 0)
        }
        return unsafe sqlite3_bind_blob64(statement, position, bytes, UInt64(count), sqliteTransient)
    }

    private func _bindBlob(position: Int32, bytes: Span<UInt8>) throws -> Int32 {
        let statement = try unsafe _statement()
        return bytes.withUnsafeBufferPointer { buffer in
            let baseAddress = unsafe buffer.baseAddress.map { unsafe UnsafeRawPointer($0) }
            return unsafe _bindBlobBuffer(statement: statement, position: position, bytes: baseAddress, count: buffer.count)
        }
    }

    private func _bindBlob(position: Int32, data: Data) throws -> Int32 {
        let statement = try unsafe _statement()
        return unsafe data.withUnsafeBytes { buffer in
            unsafe _bindBlobBuffer(statement: statement, position: position, bytes: buffer.baseAddress, count: buffer.count)
        }
    }

    private func _bindZeroBlob(position: Int32, count: Int) throws -> Int32 {
        guard count >= 0 else { return SQLITE_RANGE }
        return unsafe sqlite3_bind_zeroblob64(try _statement(), position, UInt64(count))
    }

    private func _bindNull(position: Int32) throws -> Int32 {
        unsafe sqlite3_bind_null(try _statement(), position)
    }

    private func _bindParameterIndex(name: String) throws -> Int32 {
        unsafe sqlite3_bind_parameter_index(try _statement(), name)
    }

    private func _bindParameterCount() throws -> Int32 {
        unsafe sqlite3_bind_parameter_count(try _statement())
    }

    private func _bindParameterName(position: Int32) throws -> String? {
        guard let name = unsafe sqlite3_bind_parameter_name(try _statement(), position) else {
            return nil
        }
        return unsafe String(cString: name)
    }

    private func _columnName(position: Int32) -> String {
        guard let stat = unsafe stat, let name = unsafe sqlite3_column_name(stat, position) else { return "" }
        return unsafe String(cString: name)
    }

    private func _columnDeclaredType(position: Int32) -> String {
        guard let stat = unsafe stat, let type = unsafe sqlite3_column_decltype(stat, position) else { return "" }
        return unsafe String(cString: type)
    }

    private func _columnType(position: Int32) -> Int32 {
        guard let stat = unsafe stat else { return SQLITE_NULL }
        return unsafe sqlite3_column_type(stat, position)
    }

    private func _columnCount() -> Int32 {
        guard let stat = unsafe stat else { return 0 }
        return unsafe sqlite3_column_count(stat)
    }

    private func _columnData(position: Int32) -> Data {
        guard let stat = unsafe stat else { return Data() }
        let byteCount = unsafe Int(sqlite3_column_bytes(stat, position))
        guard byteCount > 0, let bytes = unsafe sqlite3_column_blob(stat, position) else { return Data() }
        return unsafe Data(bytes: bytes, count: byteCount)
    }

    private func _withColumnBlob<R>(position: Int32, _ body: (Span<UInt8>) throws -> R) rethrows -> R {
        guard let stat = unsafe stat else {
            return try [UInt8]().withUnsafeBufferPointer {
                try body(unsafe Span(_unsafeElements: $0))
            }
        }
        let byteCount = unsafe Int(sqlite3_column_bytes(stat, position))
        guard byteCount > 0, let bytes = unsafe sqlite3_column_blob(stat, position) else {
            return try [UInt8]().withUnsafeBufferPointer {
                try body(unsafe Span(_unsafeElements: $0))
            }
        }
        let buffer = unsafe UnsafeBufferPointer(start: bytes.assumingMemoryBound(to: UInt8.self), count: byteCount)
        return try body(unsafe Span(_unsafeElements: buffer))
    }

    private func _columnText(position: Int32) -> String {
        guard let stat = unsafe stat, let text = unsafe sqlite3_column_text(stat, position) else { return "" }
        let byteCount = unsafe Int(sqlite3_column_bytes(stat, position))
        let buffer = unsafe UnsafeRawBufferPointer(start: text, count: byteCount)
        return unsafe String(decoding: buffer, as: UTF8.self)
    }

    private func _columnDouble(position: Int32) -> Double {
        guard let stat = unsafe stat else { return 0 }
        return unsafe sqlite3_column_double(stat, position)
    }

    private func _columnInt64(position: Int32) -> Int64 {
        guard let stat = unsafe stat else { return 0 }
        return unsafe sqlite3_column_int64(stat, position)
    }

    private func _checkResult(
        _ res: Int32,
        isStep: Bool = false,
        operation: String? = nil,
        bind: SQLiteError.BindContext? = nil,
        funcName: StaticString = #function
    ) throws {
        var shouldThrow = false
        if isStep {
            shouldThrow = res != SQLITE_ROW && res != SQLITE_DONE
        } else {
            shouldThrow = res != SQLITE_OK
        }
        if shouldThrow {
            let database = unsafe self.stat.flatMap { unsafe sqlite3_db_handle($0) }
            try unsafe Self._checkResult(
                res,
                database: database,
                fallback: funcName.description,
                operation: operation ?? funcName.description,
                sql: sql,
                bind: bind
            )
        }
    }

    private func _statement(funcName: StaticString = #function) throws -> SQLite3Statement {
        guard let stat = unsafe stat else {
            throw SQLiteError(code: SQLITE_MISUSE, description: "\(funcName): statement has already been finalized.")
        }
        return unsafe stat
    }

    private static func _checkResult(
        _ res: Int32,
        database: SQLite3?,
        fallback: String,
        operation: String? = nil,
        sql: String? = nil,
        bind: SQLiteError.BindContext? = nil
    ) throws {
        guard res != SQLITE_OK else { return }

        let message: String
        if let database = unsafe database, let cMessage = unsafe sqlite3_errmsg(database) {
            message = unsafe String(cString: cMessage)
        } else {
            message = fallback
        }
        throw SQLiteError(
            code: res,
            extendedCode: unsafe _extendedCode(database: database),
            description: message.isEmpty ? fallback : message,
            operation: operation,
            sql: sql,
            bind: bind
        )
    }

    private static func _extendedCode(database: SQLite3?) -> Int32? {
        guard let database = unsafe database else { return nil }
        return unsafe sqlite3_extended_errcode(database)
    }

}
