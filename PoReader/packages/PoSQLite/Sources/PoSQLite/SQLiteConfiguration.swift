import Foundation
import SQLite3

public struct SQLiteConfiguration: Hashable, Sendable {
    public enum AccessMode: Hashable, Sendable {
        case readOnly
        case readWrite
        case readWriteCreate
    }

    public enum MutexMode: Hashable, Sendable {
        case noMutex
        case fullMutex
    }

    public enum CacheMode: Hashable, Sendable {
        case `default`
        case `private`
        case shared
    }

    public enum JournalMode: String, Hashable, Sendable {
        case delete = "DELETE"
        case truncate = "TRUNCATE"
        case persist = "PERSIST"
        case memory = "MEMORY"
        case wal = "WAL"
        case off = "OFF"
    }

    public enum Synchronous: String, Hashable, Sendable {
        case off = "OFF"
        case normal = "NORMAL"
        case full = "FULL"
        case extra = "EXTRA"
    }

    public enum TempStore: String, Hashable, Sendable {
        case `default` = "DEFAULT"
        case file = "FILE"
        case memory = "MEMORY"
    }

    public static var defaultMaximumConnectionCount: Int {
        min(max(ProcessInfo.processInfo.processorCount, 4), 8)
    }

    public static var defaultMaximumIdleConnectionCount: Int {
        min(max(ProcessInfo.processInfo.processorCount / 2, 2), 4)
    }

    public static let defaultConnectionCheckoutTimeoutMilliseconds = 5_000

    public static let mobile = SQLiteConfiguration()

    public var accessMode: AccessMode
    public var mutexMode: MutexMode
    public var cacheMode: CacheMode
    public var usesURI: Bool
    public var busyTimeoutMilliseconds: Int?
    public var connectionCheckoutTimeoutMilliseconds: Int?
    public var maximumConnectionCount: Int
    public var maximumIdleConnectionCount: Int
    public var journalMode: JournalMode?
    public var synchronous: Synchronous?
    public var foreignKeys: Bool?
    public var walAutoCheckpointPages: Int?
    public var mmapSizeBytes: Int64?
    public var cacheSizeKiB: Int?
    public var tempStore: TempStore?
    public var journalSizeLimitBytes: Int64?
    public var additionalPragmas: [String]

    public init(
        accessMode: AccessMode = .readWriteCreate,
        mutexMode: MutexMode = .noMutex,
        cacheMode: CacheMode = .private,
        usesURI: Bool = false,
        busyTimeoutMilliseconds: Int? = 5_000,
        connectionCheckoutTimeoutMilliseconds: Int? = SQLiteConfiguration.defaultConnectionCheckoutTimeoutMilliseconds,
        maximumConnectionCount: Int = SQLiteConfiguration.defaultMaximumConnectionCount,
        maximumIdleConnectionCount: Int = SQLiteConfiguration.defaultMaximumIdleConnectionCount,
        journalMode: JournalMode? = .wal,
        synchronous: Synchronous? = .normal,
        foreignKeys: Bool? = true,
        walAutoCheckpointPages: Int? = 1_000,
        mmapSizeBytes: Int64? = 64 * 1024 * 1024,
        cacheSizeKiB: Int? = 8 * 1024,
        tempStore: TempStore? = .memory,
        journalSizeLimitBytes: Int64? = 16 * 1024 * 1024,
        additionalPragmas: [String] = []
    ) {
        let connectionCount = max(1, maximumConnectionCount)
        self.accessMode = accessMode
        self.mutexMode = mutexMode
        self.cacheMode = cacheMode
        self.usesURI = usesURI
        self.busyTimeoutMilliseconds = busyTimeoutMilliseconds.map { max(0, $0) }
        self.connectionCheckoutTimeoutMilliseconds = connectionCheckoutTimeoutMilliseconds.map { max(0, $0) }
        self.maximumConnectionCount = connectionCount
        self.maximumIdleConnectionCount = max(0, min(maximumIdleConnectionCount, connectionCount))
        // SQLite cannot change journal mode through a read-only handle.
        self.journalMode = accessMode == .readOnly ? nil : journalMode
        self.synchronous = synchronous
        self.foreignKeys = foreignKeys
        self.walAutoCheckpointPages = walAutoCheckpointPages.map { max(0, $0) }
        self.mmapSizeBytes = mmapSizeBytes.map { max(0, $0) }
        self.cacheSizeKiB = cacheSizeKiB
        self.tempStore = tempStore
        self.journalSizeLimitBytes = journalSizeLimitBytes.map { max(0, $0) }
        self.additionalPragmas = additionalPragmas
    }
}

extension SQLiteConfiguration {
    var openFlags: Int32 {
        var flags: Int32
        switch accessMode {
        case .readOnly:
            flags = SQLITE_OPEN_READONLY
        case .readWrite:
            flags = SQLITE_OPEN_READWRITE
        case .readWriteCreate:
            flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        }

        switch mutexMode {
        case .noMutex:
            flags |= SQLITE_OPEN_NOMUTEX
        case .fullMutex:
            flags |= SQLITE_OPEN_FULLMUTEX
        }

        switch cacheMode {
        case .default:
            break
        case .private:
            flags |= SQLITE_OPEN_PRIVATECACHE
        case .shared:
            flags |= SQLITE_OPEN_SHAREDCACHE
        }

        if usesURI {
            flags |= SQLITE_OPEN_URI
        }

        return flags
    }

    var connectionPreparationStatements: [String] {
        var statements: [String] = []

        if accessMode != .readOnly, let journalMode {
            statements.append("PRAGMA journal_mode=\(journalMode.rawValue);")
        }
        if let synchronous {
            statements.append("PRAGMA synchronous=\(synchronous.rawValue);")
        }
        if let foreignKeys {
            statements.append("PRAGMA foreign_keys=\(foreignKeys ? "ON" : "OFF");")
        }
        if let tempStore {
            statements.append("PRAGMA temp_store=\(tempStore.rawValue);")
        }
        if let mmapSizeBytes {
            statements.append("PRAGMA mmap_size=\(mmapSizeBytes);")
        }
        if let cacheSizeKiB {
            let cacheSize = cacheSizeKiB > 0 ? -cacheSizeKiB : cacheSizeKiB
            statements.append("PRAGMA cache_size=\(cacheSize);")
        }
        if let walAutoCheckpointPages {
            statements.append("PRAGMA wal_autocheckpoint=\(walAutoCheckpointPages);")
        }
        if let journalSizeLimitBytes {
            statements.append("PRAGMA journal_size_limit=\(journalSizeLimitBytes);")
        }

        statements.append(contentsOf: additionalPragmas)
        return statements
    }

    func shouldCreateContainingDirectory(for path: String) -> Bool {
        guard accessMode == .readWriteCreate else { return false }
        guard path != ":memory:" else { return false }
        guard !usesURI else { return false }
        return true
    }
}
