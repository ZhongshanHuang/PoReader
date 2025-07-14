//
//  Database.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/27.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation
import PoSQLite
import UIKit

final class Database {
    
    static let shared = Database()
    
    /// 数据库
    private let database: SQLiteDatabase = {
        let path = (Constants.databaseDirectory as NSString).appendingPathComponent("reader.db")
        let dababase = SQLiteDatabase(path: path)
        do {
            try dababase.execute(sql: "CREATE TABLE IF NOT EXISTS book_list (name TEXT PRIMARY KEY, last_access REAL DEFAULT 0, chapter_index INTEGER DEFAULT 0, subrange_index INTEGER DEFAULT 0, progress REAL DEFAULT 0);", isWrite: true)
            try dababase.execute(sql: "CREATE INDEX IF NOT EXISTS book_list_name_index ON book_list (name);", isWrite: true)
        } catch {
            debugPrint("创建表格失败")
        }
        return dababase
    }()
    
    /// 获取书本列表
    func loadBookList() -> [BookModel] {
        var books = [BookModel]()
        try? database.executeQuery(statement: "SELECT name, last_access, progress FROM book_list;") { _ in
            
        } handleRow: { stmt in
            let name = stmt.columnText(position: 0)
            let lastAccess = stmt.columnDouble(position: 1)
            let progress = stmt.columnDouble(position: 2)
            let localPath = (Constants.localBookDirectory as NSString).appendingPathComponent(name)
            books.append(BookModel(name: name,
                                   localPath: URL(fileURLWithPath: localPath),
                                   lastAccessDate: lastAccess,
                                   progress: progress))
        }
        
        return books.sorted(by: { (v1, v2) -> Bool in
            return v1.lastAccessDate > v2.lastAccessDate
        })
    }
    
    
    /// 将书籍保存到数据库
    /// - Parameter name: book name
    func addBook(_ name: String) {
        try? database.executeUpdate(statement: "INSERT OR REPLACE INTO book_list (name) VALUES (?);") { stmt in
            try stmt.bind(position: 1, name)
        }
    }
    
    
    /// 从数据库删除书籍记录
    /// - Parameter name: book name
    func removeBook(_ name: String) {
        try? database.executeUpdate(statement: "DELETE FROM book_list WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, name)
        })
    }
    
    /// 保存最近一次看书时间
    /// - Parameters:
    ///   - accessDate: timeIntervalSince1970
    ///   - name: book name
    func save(_ accessDate: Double, forBook name: String) {
        try? database.executeUpdate(statement: "UPDATE book_list SET last_access=? WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, accessDate)
            try stmt.bind(position: 2, name)
        })
    }
    
    /// 获取页码
    func pageLocation(forBook name: String) -> PageLocation {
        var location = PageLocation()
        try? database.executeQuery(statement: "SELECT chapter_index, subrange_index, progress FROM book_list WHERE name=?;", doBindings: { stmt in
            try stmt.bind(position: 1, name)
        }, handleRow: { stmt in
            location.chapterIndex = stmt.columnInt(position: 0)
            location.subrangeIndex = stmt.columnInt(position: 1)
            location.progress = stmt.columnDouble(position: 2)
        })
        return location
    }
    
    /// 保存页码
    func save(_ pageLocation: PageLocation, forBook name: String) {
        try? database.executeUpdate(statement: "UPDATE book_list SET chapter_index=?, subrange_index=?, progress=? WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, pageLocation.chapterIndex)
            try stmt.bind(position: 2, pageLocation.subrangeIndex)
            try stmt.bind(position: 3, pageLocation.progress)
            try stmt.bind(position: 4, name)
        })
    }
    
    /// 删除页码
    func removePageLocation(ofBook name: String) {
        try? database.executeUpdate(statement: "DELETE FROM book_list WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, name)
        })
    }
    
}



// MARK: - PageLocation

struct PageLocation {
    var chapterIndex: Int = 0
    var subrangeIndex: Int = 0
    var progress: Double = 0
}
