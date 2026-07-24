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
            try dababase.executeRawScript(BookModel.scheme)
            try dababase.executeRawScript(AudioModel.scheme)
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
        try database.fetch("SELECT name, last_access, progress FROM \(identifier: BookModel.tableName) ORDER BY last_access DESC;") { row in
            let name = try row.require(0, as: String.self)
            let lastAccess = try row.require(1, as: Double.self)
            let progress = try row.require(2, as: Double.self)
            let localPath = (Constants.localBookDirectory as NSString).appendingPathComponent(name)
            return BookModel(
                name: name,
                lastAccessDate: lastAccess,
                progress: progress,
                localPath: URL(fileURLWithPath: localPath)
            )
        }
    }
    
    
    /// 将书籍保存到数据库
    /// - Parameter name: book name
    func addBook(_ name: String) throws {
        try database.execute("INSERT OR REPLACE INTO \(identifier: BookModel.tableName) (name) VALUES (\(name));")
    }
    
    
    /// 从数据库删除书籍记录
    /// - Parameter name: book name
    func removeBook(_ name: String) throws {
        try database.execute("DELETE FROM \(identifier: BookModel.tableName) WHERE name=\(name);")
    }
    
    /// 保存最近一次看书时间
    /// - Parameters:
    ///   - accessDate: timeIntervalSince1970
    ///   - name: book name
    func updateAccessDate(_ accessDate: Double, forBook name: String) throws {
        try database.execute("UPDATE \(identifier: BookModel.tableName) SET last_access=\(accessDate) WHERE name=\(name);")
    }
    
    /// 获取页码
    func pageLocation(forBook name: String) throws -> PageLocation {
        var location = PageLocation()
        try database.forEachRow("SELECT chapter_index, subrange_index, progress FROM \(identifier: BookModel.tableName) WHERE name=\(name);") { row in
            location.chapterIndex = try row.require(0, as: Int.self)
            location.subrangeIndex = try row.require(1, as: Int.self)
            location.progress = try row.require(2, as: Double.self)
        }
        return location
    }
    
    /// 保存页码
    func updatePageLocation(_ pageLocation: PageLocation, forBook name: String) throws {
        try database.execute("""
        UPDATE \(identifier: BookModel.tableName)
        SET chapter_index=\(pageLocation.chapterIndex), subrange_index=\(pageLocation.subrangeIndex), progress=\(pageLocation.progress)
        WHERE name=\(name);
        """)
    }
}

// MARK: - Audio

extension Database {
    /// 获取音频列表
    func loadAudioList() throws -> [AudioModel] {
        try database.fetch("SELECT name, last_access, progress FROM \(identifier: AudioModel.tableName) ORDER BY last_access DESC;") { row in
            let name = try row.require(0, as: String.self)
            let lastAccess = try row.require(1, as: Double.self)
            let progress = try row.require(2, as: Double.self)
            let localPath = (Constants.localAudioDirectory as NSString).appendingPathComponent(name)
            return AudioModel(
                name: name,
                lastAccessDate: lastAccess,
                progress: progress,
                localPath: URL(fileURLWithPath: localPath)
            )
        }
    }
    
    
    /// 将音频保存到数据库
    /// - Parameter name: book name
    func addAudio(_ name: String) throws {
        try database.execute("INSERT OR REPLACE INTO \(identifier: AudioModel.tableName) (name) VALUES (\(name));")
    }
    
    
    /// 从数据库删除音频记录
    /// - Parameter name: book name
    func removeAudio(_ name: String) throws {
        try database.execute("DELETE FROM \(identifier: AudioModel.tableName) WHERE name=\(name);")
    }
    
    /// 保存最近一次听音频时间
    /// - Parameters:
    ///   - accessDate: timeIntervalSince1970
    ///   - name: book name
    func updateAccessDate(_ accessDate: Double, forAudio name: String) throws {
        try database.execute("UPDATE \(identifier: AudioModel.tableName) SET last_access=\(accessDate) WHERE name=\(name);")
    }
    
    /// 获取进度
    func progress(forAudio name: String) throws -> Double {
        let progress = try database.scalar("SELECT progress FROM \(identifier: AudioModel.tableName) WHERE name=\(name);", as: Double.self)
        return progress ?? 0
    }
    
    /// 保存进度
    func updateProgress(_ progress: Double, forAudio name: String) throws {
        try database.execute("UPDATE \(identifier: AudioModel.tableName) SET progress=\(progress) WHERE name=\(name);")
    }
    
}
