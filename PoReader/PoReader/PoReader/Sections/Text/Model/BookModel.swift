import Foundation

nonisolated
struct BookModel: BookResourceProtocal, Identifiable {
    static let tableName: String = "book_list"
    /// 创建好表格和索引
    static let scheme: String = "CREATE TABLE IF NOT EXISTS \(tableName) (name TEXT PRIMARY KEY, last_access REAL DEFAULT 0, chapter_index INTEGER DEFAULT 0, subrange_index INTEGER DEFAULT 0, progress REAL DEFAULT 0); CREATE INDEX IF NOT EXISTS \(tableName)_index ON \(tableName) (name, last_access);"

    let id: String
    let name: String
    var lastAccessDate: Double
    var progress: Double
    
    let localPath: URL
    
    init(name: String, lastAccessDate: Double, progress: Double, localPath: URL) {
        self.id = name.md5
        self.name = name
        self.lastAccessDate = lastAccessDate
        self.progress = progress
        self.localPath = localPath
    }
}

extension BookModel: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BookModel, rhs: BookModel) -> Bool {
        lhs.id == rhs.id
    }
    
}
