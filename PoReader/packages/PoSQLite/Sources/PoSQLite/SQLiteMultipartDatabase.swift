//
//  SQLiteMultipartDatabase.swift
//  PoSQLiteDemo
//
//  Created by HzS on 2022/9/4.
//

import Foundation
import SQLite3

public final class SQLiteMultipartDatabase {
    private let database: SQLiteDatabase
    public var path: String {
        database.handlePool.path
    }
    
    public init(path: String) {
        database = SQLiteDatabase(path: path)
    }
    
    public init(fileURL: URL) {
        database = SQLiteDatabase(fileURL: fileURL)
    }
    
    public func close() {
        database.close()
    }
    
    public func inTransaction(_ transaction: SQLiteTransaction = .exclusive, _ exec: (_ db: any SQLiteDatabaseProtocol, _ rollback: UnsafeMutablePointer<Bool>) throws -> Void) {
        var shouldRollback = false
        do {
            try database.begin(transaction)
            try exec(database, &shouldRollback)
            if shouldRollback {
                try database.rollback()
            } else {
                try database.commit()
            }
        } catch {
            try? database.rollback()
        }
    }
    
    public func executeUpdate(statement: String, doBindings: (SQLiteStmt) throws -> Void) throws {
        database.handlePool.wLock()
        defer { database.handlePool.wUnlock() }
        
        let recyclableHandle = try database.flowOut()
        let stat = try recyclableHandle.rawValue.prepare(statement: statement)
        
        try doBindings(stat)
        try stat.step()
    }
    
    public func executeQuery(statement: String, doBindings: (SQLiteStmt) throws -> Void, handleRow: (_ stmt: SQLiteStmt, _ stop: UnsafeMutablePointer<Bool>) throws -> Void) throws {
        let recyclableHandle = try database.flowOut()
        let stat = try recyclableHandle.rawValue.prepare(statement: statement)
        
        try doBindings(stat)
        var res = try stat.step()
        var stop = false
        while res == SQLITE_ROW {
            try handleRow(stat, &stop)
            
            if stop == true { return }
            res = try stat.step()
        }
    }
    
    public func doWithTransaction(_ transaction: SQLiteTransaction = .deferred, _ closure: (any SQLiteDatabaseProtocol) throws -> Void) {
        do {
            try database.begin(transaction)
            try closure(database)
            try database.commit()
        } catch {
            try? database.rollback()
        }
    }
}
