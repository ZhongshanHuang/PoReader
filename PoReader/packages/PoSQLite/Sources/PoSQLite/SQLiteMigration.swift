import Foundation

/// One atomic schema migration identified by a positive, monotonically increasing version.
public struct SQLiteMigration: Sendable {
    public let version: Int
    private let body: @Sendable (_ transaction: borrowing SQLiteTransactionContext) throws -> Void

    public init(
        version: Int,
        _ body: @escaping @Sendable (_ transaction: borrowing SQLiteTransactionContext) throws -> Void
    ) {
        self.version = version
        self.body = body
    }

    func run(in transaction: borrowing SQLiteTransactionContext) throws {
        try body(transaction)
    }
}

public enum SQLiteMigrationError: Error, LocalizedError, Equatable, Sendable {
    case invalidVersion(Int)
    case duplicateVersion(Int)
    case databaseVersionIsNewer(current: Int, latestMigration: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidVersion(let version):
            return "Migration versions must be between 1 and \(Int32.max). Invalid version: \(version)."
        case .duplicateVersion(let version):
            return "Migration version \(version) is registered more than once."
        case .databaseVersionIsNewer(let current, let latestMigration):
            return "Database version \(current) is newer than the latest migration \(latestMigration)."
        }
    }
}

public extension SQLiteDatabase {
    /// Applies pending migrations and updates `PRAGMA user_version` in one transaction.
    func migrate(_ migrations: [SQLiteMigration]) throws {
        let migrations = try Self.validatedMigrations(migrations)

        try withTransaction(.immediate) { transaction in
            let currentVersion = try transaction.scalar("PRAGMA user_version", as: Int.self) ?? 0
            let latestVersion = migrations.last?.version ?? 0
            guard currentVersion <= latestVersion else {
                throw SQLiteMigrationError.databaseVersionIsNewer(
                    current: currentVersion,
                    latestMigration: latestVersion
                )
            }

            for migration in migrations where migration.version > currentVersion {
                try migration.run(in: transaction)
                let version = String(migration.version)
                try transaction.execute("PRAGMA user_version = \(unsafeRaw: version)")
            }
        }
    }
}

private extension SQLiteDatabase {
    static func validatedMigrations(_ migrations: [SQLiteMigration]) throws -> [SQLiteMigration] {
        let migrations = migrations.sorted { $0.version < $1.version }
        var previousVersion: Int?

        for migration in migrations {
            guard migration.version > 0, migration.version <= Int(Int32.max) else {
                throw SQLiteMigrationError.invalidVersion(migration.version)
            }
            guard migration.version != previousVersion else {
                throw SQLiteMigrationError.duplicateVersion(migration.version)
            }
            previousVersion = migration.version
        }

        return migrations
    }
}
