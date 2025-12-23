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
            try dababase.execute(sql: BookModel.scheme, isWrite: true)
            try dababase.execute(sql: AudioModel.scheme, isWrite: true)
        } catch {
            print("创建表格失败")
        }
        return dababase
    }()
}

// MARK: - Book
struct PageLocation {
    var chapterIndex: Int = 0
    var subrangeIndex: Int = 0
    var progress: Double = 0
}

extension Database {
    /// 获取书本列表
    func loadBookList() throws -> [BookModel] {
        let sql = "SELECT name, last_access, progress FROM \(BookModel.tableName) ORDER BY last_access DESC;"
        
        var books = [BookModel]()
        try database.executeQuery(statement: sql) { stmt in
        } handleRow: { stmt in
            let name = stmt.columnText(position: 0)
            let lastAccess = stmt.columnDouble(position: 1)
            let progress = stmt.columnDouble(position: 2)
            let localPath = (Constants.localBookDirectory as NSString).appendingPathComponent(name)
            books.append(BookModel(name: name,
                                   lastAccessDate: lastAccess,
                                   progress: progress,
                                   localPath: URL(fileURLWithPath: localPath)))
        }
        
        return books
    }
    
    
    /// 将书籍保存到数据库
    /// - Parameter name: book name
    func addBook(_ name: String) throws {
        try database.executeUpdate(statement: "INSERT OR REPLACE INTO \(BookModel.tableName) (name) VALUES (?);") { stmt in
            try stmt.bind(position: 1, name)
        }
    }
    
    
    /// 从数据库删除书籍记录
    /// - Parameter name: book name
    func removeBook(_ name: String) throws {
        try database.executeUpdate(statement: "DELETE FROM \(BookModel.tableName) WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, name)
        })
    }
    
    /// 保存最近一次看书时间
    /// - Parameters:
    ///   - accessDate: timeIntervalSince1970
    ///   - name: book name
    func updateAccessDate(_ accessDate: Double, forBook name: String) throws {
        try database.executeUpdate(statement: "UPDATE \(BookModel.tableName) SET last_access=? WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, accessDate)
            try stmt.bind(position: 2, name)
        })
    }
    
    /// 获取页码
    func pageLocation(forBook name: String) throws -> PageLocation {
        var location = PageLocation()
        try database.executeQuery(statement: "SELECT chapter_index, subrange_index, progress FROM \(BookModel.tableName) WHERE name=?;", doBindings: { stmt in
            try stmt.bind(position: 1, name)
        }, handleRow: { stmt in
            location.chapterIndex = stmt.columnInt(position: 0)
            location.subrangeIndex = stmt.columnInt(position: 1)
            location.progress = stmt.columnDouble(position: 2)
        })
        return location
    }
    
    /// 保存页码
    func updatePageLocation(_ pageLocation: PageLocation, forBook name: String) throws {
        try database.executeUpdate(statement: "UPDATE \(BookModel.tableName) SET chapter_index=?, subrange_index=?, progress=? WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, pageLocation.chapterIndex)
            try stmt.bind(position: 2, pageLocation.subrangeIndex)
            try stmt.bind(position: 3, pageLocation.progress)
            try stmt.bind(position: 4, name)
        })
    }
}

// MARK: - Audio

extension Database {
    /// 获取音频列表
    func loadAudioList() throws -> [AudioModel] {
        let sql = "SELECT name, last_access, progress FROM \(AudioModel.tableName) ORDER BY last_access DESC;"
        
        var books = [AudioModel]()
        try database.executeQuery(statement: sql) { stmt in
        } handleRow: { stmt in
            let name = stmt.columnText(position: 0)
            let lastAccess = stmt.columnDouble(position: 1)
            let progress = stmt.columnDouble(position: 2)
            let localPath = (Constants.localAudioDirectory as NSString).appendingPathComponent(name)
            books.append(AudioModel(name: name,
                                    lastAccessDate: lastAccess,
                                    progress: progress,
                                    localPath: URL(fileURLWithPath: localPath)))
        }
        
        return books
    }
    
    
    /// 将音频保存到数据库
    /// - Parameter name: book name
    func addAudio(_ name: String) throws {
        try database.executeUpdate(statement: "INSERT OR REPLACE INTO \(AudioModel.tableName) (name) VALUES (?);") { stmt in
            try stmt.bind(position: 1, name)
        }
    }
    
    
    /// 从数据库删除音频记录
    /// - Parameter name: book name
    func removeAudio(_ name: String) throws {
        try database.executeUpdate(statement: "DELETE FROM \(AudioModel.tableName) WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, name)
        })
    }
    
    /// 保存最近一次听音频时间
    /// - Parameters:
    ///   - accessDate: timeIntervalSince1970
    ///   - name: book name
    func updateAccessDate(_ accessDate: Double, forAudio name: String) throws {
        try database.executeUpdate(statement: "UPDATE \(AudioModel.tableName) SET last_access=? WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, accessDate)
            try stmt.bind(position: 2, name)
        })
    }
    
    /// 获取进度
    func progress(forAudio name: String) throws -> Double {
        var progress: Double = 0
        try database.executeQuery(statement: "SELECT progress, progress FROM \(AudioModel.tableName) WHERE name=?;", doBindings: { stmt in
            try stmt.bind(position: 1, name)
        }, handleRow: { stmt in
            progress = stmt.columnDouble(position: 0)
        })
        return progress
    }
    
    /// 保存进度
    func updateProgress(_ progress: Double, forAudio name: String) throws {
        try database.executeUpdate(statement: "UPDATE \(AudioModel.tableName) SET progress=? WHERE name=?;", doUpdating: { stmt in
            try stmt.bind(position: 1, progress)
            try stmt.bind(position: 2, name)
        })
    }
    
}
