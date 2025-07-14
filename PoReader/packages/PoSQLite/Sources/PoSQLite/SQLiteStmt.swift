import Foundation
import SQLite3

public enum SQLiteType: Int32 {
    case integer = 1    // SQLITE_INTEGER
    case float = 2      // SQLITE_FLOAT
    case text = 3       // SQLITE_TEXT
    case blob = 4       // SQLITE_BLOB
    case null = 5       // SQLITE_NULL
}

public struct SQLiteStmt: ~Copyable {
    private var stat: SQLite3Statement!
    var onFinalize: (() -> Void)?
    
    deinit {
        if self.stat != nil {
            sqlite3_finalize(self.stat)
            self.onFinalize?()
        }
    }
    
    internal init(stat: SQLite3Statement) {
        self.stat = stat
    }
    
    public func reset() throws {
        try _checkResult(sqlite3_reset(self.stat))
    }
    
    public mutating func finalize() throws {
        if self.stat != nil {
            try _checkResult(sqlite3_finalize(self.stat))
            self.stat = nil
            self.onFinalize?()
            self.onFinalize = nil
        }
    }
    
    /// SQLITE_ROW 有数据，SQLITE_DONE 完成，其余的状态为失败
    @discardableResult
    public func step() throws -> Int32 {
        let res = sqlite3_step(stat)
        try _checkResult(res, isStep: true)
        return res
    }
    
    /* bind position */
    public func bind(position: Int, _ d: Double) throws {
        try _checkResult(sqlite3_bind_double(self.stat, Int32(position), d))
    }
    
    public func bind(position: Int, _ i: Int32) throws {
        try _checkResult(sqlite3_bind_int(self.stat, Int32(position), i))
    }
    
    public func bind(position: Int, _ i: Int) throws {
        try _checkResult(sqlite3_bind_int64(self.stat, Int32(position), Int64(i)))
    }
    
    public func bind(position: Int, _ i: Int64) throws {
        try _checkResult(sqlite3_bind_int64(self.stat, Int32(position), i))
    }
    
    public func bind(position: Int, _ s: String) throws {
        try _checkResult(sqlite3_bind_text(self.stat, Int32(position), s, Int32(s.utf8.count), unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)))
    }
    
    public func bind(position: Int, _ b: [Int8]) throws {
        try _checkResult(sqlite3_bind_blob(self.stat, Int32(position), b, Int32(b.count), unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)))
    }
    
    public func bind(position: Int, _ b: [UInt8]) throws {
        try _checkResult(sqlite3_bind_blob(self.stat, Int32(position), b, Int32(b.count), unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)))
    }
    
    public func bindZeroBlob(position: Int, count: Int) throws {
        try _checkResult(sqlite3_bind_zeroblob(self.stat, Int32(position), Int32(count)))
    }
    
    public func bindNull(position: Int) throws {
        try _checkResult(sqlite3_bind_null(self.stat, Int32(position)))
    }
    
    /* bind name */
    
    public func bind(name: String, _ d: Double) throws {
        try _checkResult(sqlite3_bind_double(self.stat, bindParameterIndex(name: name), d))
    }
    
    public func bind(name: String, _ i: Int32) throws {
        try _checkResult(sqlite3_bind_int(self.stat, bindParameterIndex(name: name), i))
    }
    
    public func bind(name: String, _ i: Int) throws {
        try _checkResult(sqlite3_bind_int64(self.stat, bindParameterIndex(name: name), Int64(i)))
    }
    
    public func bind(name: String, _ i: Int64) throws {
        try _checkResult(sqlite3_bind_int64(self.stat, bindParameterIndex(name: name), i))
    }
    
    public func bind(name: String, _ s: String) throws {
        try _checkResult(sqlite3_bind_text(self.stat, bindParameterIndex(name: name), s, Int32(s.utf8.count), unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)))
    }
    
    public func bind(name: String, _ b: [Int8]) throws {
        try _checkResult(sqlite3_bind_blob(self.stat, bindParameterIndex(name: name), b, Int32(b.count), unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)))
    }
    
    public func bind(name: String, _ b: [UInt8]) throws {
        try _checkResult(sqlite3_bind_blob(self.stat, bindParameterIndex(name: name), b, Int32(b.count), unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)))
    }
    
    public func bindZeroBlob(name: String, count: Int) throws {
        try _checkResult(sqlite3_bind_zeroblob(self.stat, bindParameterIndex(name: name), Int32(count)))
    }
    
    public func bindNull(name: String) throws {
        try _checkResult(sqlite3_bind_null(self.stat, bindParameterIndex(name: name)))
    }
    
    /// :name
    public func bindParameterIndex(name: String) throws -> Int32 {
        let idx = sqlite3_bind_parameter_index(self.stat, name)
        if idx == 0 {
            throw SQLiteError(code: SQLITE_MISUSE, description: "The indicated bind parameter name was not found.")
        }
        return idx
    }
    
    public func columnName(position: Int) -> String {
        return String(cString: sqlite3_column_name(self.stat, Int32(position)))
    }
    
    public func columnDeclaredType(position: Int) -> String {
        return String(cString: sqlite3_column_decltype(self.stat, Int32(position)))
    }
    
    public func columnType(position: Int) -> SQLiteType {
        let res = sqlite3_column_type(self.stat, Int32(position))
        return SQLiteType(rawValue: res)!
    }
    
    public func columnCount() -> Int {
        let res = sqlite3_column_count(self.stat)
        return Int(res)
    }
    
    public func columnIntBlob<I: BinaryInteger>(position: Int) -> [I] {
        let vp = sqlite3_column_blob(self.stat, Int32(position))
        let vpLen = Int(sqlite3_column_bytes(self.stat, Int32(position)))
        if vpLen <= 0 { return [] }
        
        var ret = [I]()
        if var bytesPtr = vp?.bindMemory(to: I.self, capacity: vpLen) {
            for _ in 0..<vpLen {
                ret.append(bytesPtr.pointee)
                bytesPtr = bytesPtr.successor()
            }
        }
        return ret
    }
    
    public func columnText(position: Int) -> String {
        if let res = sqlite3_column_text(self.stat, Int32(position)) {
            return String(cString: res)
        }
        return ""
    }
    
    public func columnDouble(position: Int) -> Double {
        return sqlite3_column_double(self.stat, Int32(position))
    }
    
    public func columnInt32(position: Int) -> Int32 {
        return sqlite3_column_int(self.stat, Int32(position))
    }
    
    public func columnInt(position: Int) -> Int {
        return Int(sqlite3_column_int64(self.stat, Int32(position)))
    }
    
    private func _checkResult(_ res: Int32, isStep: Bool = false, funcName: StaticString = #function) throws {
        var shouldThrow = false
        if isStep {
            shouldThrow = res != SQLITE_ROW && res != SQLITE_DONE
        } else {
            shouldThrow = res != SQLITE_OK
        }
        if shouldThrow { throw SQLiteError(code: res, description: funcName.description) }
    }

}
