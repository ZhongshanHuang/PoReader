import Foundation

enum File {
    static func remove(files: [String]) throws {
        let fileManager = FileManager.default
        try files.forEach { (file) in
            do {
                if fileManager.fileExists(atPath: file) {
                    try FileManager.default.removeItem(atPath: file)
                }
            } catch let error as NSError {
                throw SQLiteError(code: error.code, description: error.localizedDescription)
            }
        }
    }

    static func getSize(ofFiles files: [String]) throws -> UInt64 {
        let fileManager = FileManager.default
        return try files.reduce(into: 0, { (filesSize, file) in
            do {
                filesSize += (try fileManager.attributesOfItem(atPath: file)[.size] as? UInt64) ?? 0
            } catch let error as NSError {
                throw SQLiteError(code: error.code, description: error.localizedDescription)
            }
        })
    }

    static func isExists(atPath path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    static func createDirectoryWithIntermediateDirectories(atPath path: String) throws {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            throw SQLiteError(code: error.code, description: error.localizedDescription)
        }
    }

}
