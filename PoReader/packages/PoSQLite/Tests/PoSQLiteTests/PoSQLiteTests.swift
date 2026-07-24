import XCTest
import Foundation
import SQLite3
@testable import PoSQLite

final class PoSQLiteTests: XCTestCase {
    private struct Person: Equatable {
        let id: Int
        let name: String
        let age: Int?
        let score: Double?
        let isActive: Bool?
        let payload: [UInt8]?
        let note: String?
    }

    private struct UserRecord: Equatable, Sendable, SQLiteRowDecodable {
        let id: Int
        let name: String
        let age: Int?
        let payload: Data?

        init(id: Int, name: String, age: Int?, payload: Data?) {
            self.id = id
            self.name = name
            self.age = age
            self.payload = payload
        }

        init(row: SQLiteRow) throws {
            self.id = try row.require("id")
            self.name = try row.require("name")
            self.age = try row.get("age")
            self.payload = try row.get("payload", as: Data.self)
        }
    }

    func testExecuteFetchAndScalarAPIs() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("""
        CREATE TABLE people (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER,
            score REAL,
            is_active INTEGER,
            payload BLOB,
            note TEXT
        );
        """)

        let name = "Blob"
        let age = 37
        let score = 9.5
        let isActive = true
        let payload: [UInt8] = [0, 1, 2, 255]
        let note: String? = nil
        let execution = try database.executeResult("""
        INSERT INTO people (name, age, score, is_active, payload, note)
        VALUES (\(name), \(age), \(score), \(isActive), \(payload), \(note))
        """)
        XCTAssertEqual(execution.changes, 1)
        XCTAssertEqual(execution.lastInsertRowID, 1)

        let people = try database.fetch("""
        SELECT id, name, age, score, is_active, payload, note
        FROM people
        WHERE name = \(name)
        """) { row in
            Person(
                id: try XCTUnwrap(row.int(named: "id")),
                name: try XCTUnwrap(row.string(named: "name")),
                age: try row.int(named: "age"),
                score: try row.double(named: "score"),
                isActive: try row.bool(named: "is_active"),
                payload: try row.blob(named: "payload"),
                note: try row.string(named: "note")
            )
        }

        XCTAssertEqual(
            people,
            [
                Person(
                    id: 1,
                    name: "Blob",
                    age: 37,
                    score: 9.5,
                    isActive: true,
                    payload: [0, 1, 2, 255],
                    note: nil
                )
            ]
        )
        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM people"), .integer(1))
        XCTAssertNil(try database.scalar("SELECT 1 WHERE 0"))

        let duplicateColumns = try XCTUnwrap(database.fetchOne("SELECT 1 AS value, 2 AS value"))
        XCTAssertEqual(duplicateColumns.columnNames, ["value", "value"])
        XCTAssertEqual(duplicateColumns["value"], .integer(1))
        XCTAssertEqual(duplicateColumns[1], .integer(2))
    }

    func testExecuteResultReturnsStatementResult() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY AUTOINCREMENT, value INTEGER NOT NULL);")
        let firstInsert = try database.executeResult("INSERT INTO items (value) VALUES (\(1))")
        XCTAssertEqual(firstInsert.changes, 1)
        XCTAssertEqual(firstInsert.lastInsertRowID, 1)

        let update = try database.executeResult("UPDATE items SET value = \(2) WHERE id = \(1)")
        XCTAssertEqual(update.changes, 1)
        XCTAssertEqual(update.lastInsertRowID, 1)

        try database.execute("CREATE TABLE metadata (key TEXT PRIMARY KEY);")
        let secondInsert = try database.executeResult("INSERT INTO items (value) VALUES (\(3))")
        XCTAssertEqual(secondInsert.changes, 1)
        XCTAssertEqual(secondInsert.lastInsertRowID, 2)
    }

    func testSQLInterpolationExecuteFetchAndScalarAPIs() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let table = "people"
        try database.execute("""
        CREATE TABLE \(identifier: table) (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER,
            active INTEGER NOT NULL,
            payload BLOB
        );
        """)

        let name = "Ada"
        let age: Int? = nil
        let payload = Data([8, 13, 21])
        let insertion = try database.executeResult("""
        INSERT INTO \(identifier: table) (name, age, active, payload)
        VALUES (\(name), \(age), \(true), \(payload))
        """)

        XCTAssertEqual(insertion.lastInsertRowID, 1)

        let people = try database.fetch("""
        SELECT id, name, age, active, payload
        FROM \(identifier: table)
        WHERE name = \(name)
        """) { row in
            Person(
                id: try XCTUnwrap(row.int(named: "id")),
                name: try XCTUnwrap(row.string(named: "name")),
                age: try row.int(named: "age"),
                score: nil,
                isActive: try row.bool(named: "active"),
                payload: try row.blob(named: "payload"),
                note: nil
            )
        }

        XCTAssertEqual(
            people,
            [
                Person(
                    id: 1,
                    name: "Ada",
                    age: nil,
                    score: nil,
                    isActive: true,
                    payload: [8, 13, 21],
                    note: nil
                )
            ]
        )

        XCTAssertEqual(
            try database.scalar("SELECT \(unsafeRaw: "COUNT(*)") FROM \(identifier: table) WHERE name = \(name)"),
            .integer(1)
        )
    }

    func testNamedSQLParametersWorkAcrossHighLevelAndPreparedAPIs() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL);")

        let insert = SQL(
            "INSERT INTO people (name, age) VALUES (:name, :age)",
            namedParameters: [
                ":name": "Ada",
                ":age": 37,
            ]
        )
        XCTAssertEqual(try database.executeResult(insert).lastInsertRowID, 1)

        let count = try database.scalar(
            SQL(
                "SELECT COUNT(*) FROM people WHERE name = :name OR name = :name",
                namedParameters: [":name": .text("Ada")]
            ),
            as: Int.self
        )
        XCTAssertEqual(count, 1)

        let names = try database.fetch(
            SQL("SELECT name FROM people WHERE age = :age", namedParameters: [":age": .integer(37)])
        ) { row in
            try row.require("name", as: String.self)
        }
        XCTAssertEqual(names, ["Ada"])

        let firstRow = try XCTUnwrap(
            database.fetchOne(
                SQL("SELECT name FROM people WHERE name = :name", namedParameters: [":name": .text("Ada")])
            )
        )
        XCTAssertEqual(try firstRow.string(named: "name"), "Ada")

        let borrowedNames = try database.fetchBorrowed(
            SQL("SELECT name FROM people WHERE age = :age", namedParameters: [":age": .integer(37)])
        ) { row in
            try row.require("name", as: String.self)
        }
        XCTAssertEqual(borrowedNames, ["Ada"])

        let firstBorrowedName = try database.fetchOneBorrowed(
            SQL("SELECT name FROM people WHERE name = :name", namedParameters: [":name": .text("Ada")])
        ) { row in
            try row.require("name", as: String.self)
        }
        XCTAssertEqual(firstBorrowedName, "Ada")

        try database.withPreparedStatement(
            SQL("SELECT age FROM people WHERE name = :name", namedParameters: [":name": .text("Ada")])
        ) { statement in
            XCTAssertEqual(try statement.step(), .row)
            XCTAssertEqual(try statement.columnValue(position: 0), .integer(37))
        }

        var statement = try database.unsafePrepare(
            SQL("SELECT name FROM people WHERE age = :age", namedParameters: [":age": .integer(37)])
        )
        defer { try? statement.finalize() }
        XCTAssertEqual(try statement.step(), .row)
        XCTAssertEqual(try statement.columnValue(position: 0), .text("Ada"))
    }

    func testNamedSQLParametersValidateNamesBeforeStepping() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        XCTAssertThrowsError(
            try database.scalar(
                SQL("SELECT :expected", namedParameters: [":missing": .integer(1)])
            )
        ) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_RANGE)
            XCTAssertEqual(sqliteError?.operation, "bind_parameter_names")
        }
    }

    func testMobileConfigurationAppliesDefaultPragmas() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        XCTAssertEqual(database.configuration, .mobile)
        XCTAssertEqual(try database.scalar("PRAGMA journal_mode"), .text("wal"))
        XCTAssertEqual(try database.scalar("PRAGMA synchronous"), .integer(1))
        XCTAssertEqual(try database.scalar("PRAGMA foreign_keys"), .integer(1))
        XCTAssertEqual(try database.scalar("PRAGMA busy_timeout"), .integer(5_000))
        XCTAssertEqual(try database.scalar("PRAGMA temp_store"), .integer(0))
        XCTAssertEqual(try database.scalar("PRAGMA cache_size"), .integer(-4_096))
        XCTAssertEqual(try database.scalar("PRAGMA wal_autocheckpoint"), .integer(1_000))
        XCTAssertEqual(try database.scalar("PRAGMA journal_size_limit"), .integer(16 * 1024 * 1024))
        XCTAssertLessThanOrEqual(database.configuration.maximumConnectionCount, 4)
        XCTAssertLessThanOrEqual(database.configuration.maximumIdleConnectionCount, 2)
        XCTAssertEqual(database.configuration.statementCacheCapacityPerConnection, 16)

        XCTAssertEqual(SQLiteConfiguration.mobileLowMemory.maximumConnectionCount, 2)
        XCTAssertEqual(SQLiteConfiguration.mobileLowMemory.maximumIdleConnectionCount, 1)
        XCTAssertEqual(SQLiteConfiguration.mobileLowMemory.statementCacheCapacityPerConnection, 8)
        XCTAssertEqual(SQLiteConfiguration(busyTimeoutMilliseconds: .max).busyTimeoutMilliseconds, Int(Int32.max))
    }

    func testStatementCacheCanBeEnabledDisabledAndCapped() throws {
        let disabledConfiguration = SQLiteConfiguration(statementCacheCapacityPerConnection: 0)
        let (disabledDatabase, disabledURL) = makeDatabase(configuration: disabledConfiguration)
        defer { cleanup(database: disabledDatabase, url: disabledURL) }

        XCTAssertEqual(try disabledDatabase.scalar("SELECT 1"), .integer(1))
        XCTAssertEqual(disabledDatabase.cachedStatementCount, 0)

        let enabledConfiguration = SQLiteConfiguration(statementCacheCapacityPerConnection: 2)
        let (enabledDatabase, enabledURL) = makeDatabase(configuration: enabledConfiguration)
        defer { cleanup(database: enabledDatabase, url: enabledURL) }

        XCTAssertEqual(try enabledDatabase.scalar("SELECT 1"), .integer(1))
        XCTAssertEqual(enabledDatabase.cachedStatementCount, 1)

        XCTAssertEqual(try enabledDatabase.scalar("SELECT 1"), .integer(1))
        XCTAssertEqual(enabledDatabase.cachedStatementCount, 1)

        XCTAssertEqual(try enabledDatabase.scalar("SELECT 2"), .integer(2))
        XCTAssertEqual(enabledDatabase.cachedStatementCount, 2)

        XCTAssertEqual(try enabledDatabase.scalar("SELECT 3"), .integer(3))
        XCTAssertEqual(enabledDatabase.cachedStatementCount, 2)

        enabledDatabase.purgeStatementCache()
        XCTAssertEqual(enabledDatabase.cachedStatementCount, 0)

        XCTAssertEqual(try enabledDatabase.scalar("SELECT 4"), .integer(4))
        XCTAssertEqual(enabledDatabase.cachedStatementCount, 1)
    }

    func testPurgeAllStatementCachesClearsIdleCachedStatementsAcrossDatabases() throws {
        let configuration = SQLiteConfiguration(statementCacheCapacityPerConnection: 2)
        let (firstDatabase, firstURL) = makeDatabase(configuration: configuration)
        let (secondDatabase, secondURL) = makeDatabase(configuration: configuration)
        defer {
            cleanup(database: firstDatabase, url: firstURL)
            cleanup(database: secondDatabase, url: secondURL)
        }

        XCTAssertEqual(try firstDatabase.scalar("SELECT 1"), .integer(1))
        XCTAssertEqual(try secondDatabase.scalar("SELECT 2"), .integer(2))
        XCTAssertEqual(firstDatabase.cachedStatementCount, 1)
        XCTAssertEqual(secondDatabase.cachedStatementCount, 1)

        SQLiteDatabase.purgeAllStatementCaches()

        XCTAssertEqual(firstDatabase.cachedStatementCount, 0)
        XCTAssertEqual(secondDatabase.cachedStatementCount, 0)
    }

    func testFastLRUCacheMaintainsLRUOrderWithoutNodeReferences() throws {
        var cache = FastLRUCache<String, Int>(capacity: 2)

        XCTAssertNil(cache.insertValue(1, forKey: "a"))
        XCTAssertNil(cache.insertValue(2, forKey: "b"))
        XCTAssertEqual(cache.count, 2)

        XCTAssertEqual(cache.value(forKey: "a"), 1)
        XCTAssertEqual(cache.insertValue(3, forKey: "c"), 2)
        XCTAssertNil(cache.value(forKey: "b"))
        XCTAssertEqual(cache.value(forKey: "a"), 1)
        XCTAssertEqual(cache.value(forKey: "c"), 3)

        XCTAssertEqual(cache.insertValue(10, forKey: "a"), 1)
        XCTAssertEqual(cache.count, 2)
        XCTAssertEqual(cache.value(forKey: "a"), 10)

        let doubled = try XCTUnwrap(cache.withValue(forKey: "c") { value in
            value *= 2
            return value
        })
        XCTAssertEqual(doubled, 6)

        XCTAssertEqual(cache.insertValue(4, forKey: "d"), 10)
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertEqual(cache.value(forKey: "c"), 6)
        XCTAssertEqual(cache.value(forKey: "d"), 4)

        XCTAssertEqual(cache.removeLeastRecentlyUsedValue(), 6)
        XCTAssertEqual(cache.removeValue(forKey: "d"), 4)
        XCTAssertTrue(cache.isEmpty)
    }

    func testFastLRUCacheCapacityZeroDoesNotRetainValues() {
        var cache = FastLRUCache<String, Int>(capacity: 0)

        XCTAssertEqual(cache.insertValue(1, forKey: "a"), 1)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertNil(cache.removeLeastRecentlyUsedValue())
    }

    func testThreadLocalValueAndWithValueMutateCurrentThreadStorageInPlace() throws {
        let storage = ThreadLocal<[String: Int]>(defaultValue: [:])

        storage.value["direct"] = 3
        XCTAssertEqual(storage.value["direct"], 3)

        storage.withValue { value in
            value["main"] = 1
        }
        storage.withValue { value in
            value["main", default: 0] += 1
        }
        XCTAssertEqual(storage.value["main"], 2)

        storage.value = ["reset": 4]
        XCTAssertEqual(storage.value, ["reset": 4])
        storage.value["main"] = 2

        let finished = DispatchSemaphore(value: 0)
        let workerValue = ValueRecorder<Int>()
        DispatchQueue.global(qos: .userInitiated).async {
            storage.withValue { value in
                value["worker"] = 7
                workerValue.record(value["main"] ?? 0)
            }
            finished.signal()
        }

        XCTAssertEqual(finished.wait(timeout: .now() + .seconds(2)), .success)
        XCTAssertEqual(workerValue.value, 0)
        XCTAssertNil(storage.value["worker"])
        XCTAssertEqual(storage.value["main"], 2)
    }

    func testReadOnlyConfigurationSkipsJournalModePragma() throws {
        let createConfiguration = SQLiteConfiguration(journalMode: nil)
        let (writer, url) = makeDatabase(configuration: createConfiguration)
        defer { cleanup(database: writer, url: url) }

        try writer.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")
        try writer.execute("INSERT INTO items (name) VALUES (\("stored"))")
        try writer.close()

        let readOnlyConfiguration = SQLiteConfiguration(accessMode: .readOnly)
        XCTAssertNil(readOnlyConfiguration.journalMode)
        XCTAssertFalse(readOnlyConfiguration.connectionPreparationStatements.contains { $0.contains("journal_mode") })

        let reader = SQLiteDatabase(fileURL: url, configuration: readOnlyConfiguration)
        defer { cleanup(database: reader, url: url) }

        XCTAssertEqual(try reader.scalar("PRAGMA journal_mode"), .text("delete"))
        XCTAssertEqual(try reader.scalar("SELECT COUNT(*) FROM items"), .integer(1))
        XCTAssertThrowsError(try reader.execute("INSERT INTO items (name) VALUES (\("blocked"))")) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_READONLY)
            XCTAssertEqual(sqliteError?.operation, "step")
        }
    }

    func testClosePreventsFurtherUseAndAllowsFreshDatabaseForSamePath() throws {
        let (database, url) = makeDatabase()
        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")
        try database.close()

        XCTAssertFalse(database.isOpen)
        XCTAssertThrowsError(try database.open()) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_MISUSE)
            XCTAssertEqual(sqliteError?.operation, "open_handle")
        }
        XCTAssertThrowsError(try database.scalar("SELECT COUNT(*) FROM items")) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_MISUSE)
            XCTAssertEqual(sqliteError?.operation, "open_handle")
        }

        let reopened = SQLiteDatabase(fileURL: url)
        defer { cleanup(database: reopened, url: url) }
        XCTAssertEqual(try reopened.scalar("SELECT COUNT(*) FROM items"), .integer(0))
    }

    func testCloseThrowsWhenCurrentThreadHoldsStatement() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")
        var statement = try database.unsafePrepare("SELECT COUNT(*) FROM items")
        defer { try? statement.finalize() }

        XCTAssertThrowsError(try database.close()) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_BUSY)
            XCTAssertEqual(sqliteError?.operation, "close")
        }
    }

    func testMemoryDatabaseUsesSQLiteMemoryPath() throws {
        let database = SQLiteDatabase(path: ":memory:")
        defer { try? database.close() }

        XCTAssertEqual(database.path, ":memory:")
        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")
        try database.execute("INSERT INTO items (name) VALUES (\("memory"))")
        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items"), .integer(1))
    }

    func testDatabaseInstancesOwnIndependentMemoryPoolsAndLifecycles() throws {
        let first = SQLiteDatabase(path: ":memory:")
        let second = SQLiteDatabase(path: ":memory:")
        defer {
            try? first.close()
            try? second.close()
        }

        try first.execute("CREATE TABLE items (value INTEGER NOT NULL);")
        try second.execute("CREATE TABLE items (value INTEGER NOT NULL);")
        try first.execute("INSERT INTO items (value) VALUES (\(1))")

        XCTAssertEqual(try first.scalar("SELECT COUNT(*) FROM items"), .integer(1))
        XCTAssertEqual(try second.scalar("SELECT COUNT(*) FROM items"), .integer(0))

        try first.close()
        try second.execute("INSERT INTO items (value) VALUES (\(2))")
        XCTAssertEqual(try second.scalar("SELECT COUNT(*) FROM items"), .integer(1))
    }

    func testTransactionContextAndRowDecodableAPIs() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let payload = Data([1, 3, 3, 7])
        try database.execute("""
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER,
            payload BLOB
        );
        """)

        try database.withTransaction { transaction in
            let insertion = try transaction.executeResult("""
            INSERT INTO users (name, age, payload)
            VALUES (\("Grace"), \(nil as Int?), \(payload))
            """)
            XCTAssertEqual(insertion.changes, 1)
            XCTAssertEqual(insertion.lastInsertRowID, 1)

            XCTAssertEqual(
                try transaction.scalar("SELECT COUNT(*) FROM users WHERE name = \("Grace")", as: Int.self),
                1
            )

            XCTAssertEqual(
                try transaction.fetchOne(
                    "SELECT id, name, age, payload FROM users WHERE name = \("Grace")",
                    as: UserRecord.self
                ),
                UserRecord(id: 1, name: "Grace", age: nil, payload: payload)
            )
        }

        let user = try XCTUnwrap(
            database.fetchOne(
                "SELECT id, name, age, payload FROM users WHERE name = \("Grace")",
                as: UserRecord.self
            )
        )

        XCTAssertEqual(
            user,
            UserRecord(id: 1, name: "Grace", age: nil, payload: payload)
        )
    }

    func testTransactionRollsBackAndRethrows() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        enum TestFailure: Error {
            case expected
        }

        try database.execute("CREATE TABLE items (name TEXT NOT NULL UNIQUE);")
        try database.execute("INSERT INTO items (name) VALUES (\("existing"))")

        XCTAssertThrowsError(
            try database.withTransaction { transaction in
                try transaction.execute("INSERT INTO items (name) VALUES (\("pending"))")
                throw TestFailure.expected
            }
        )

        let names = try database.fetch("SELECT name FROM items ORDER BY name") { row in
            try XCTUnwrap(row.string(named: "name"))
        }
        XCTAssertEqual(names, ["existing"])
    }

    func testPreparedStatementInTransactionRollsBackAndRethrows() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        enum TestFailure: Error {
            case expected
        }

        try database.execute("CREATE TABLE items (name TEXT NOT NULL);")

        XCTAssertThrowsError(
            try database.withTransaction { transaction in
                try transaction.withPreparedStatement("INSERT INTO items (name) VALUES (?)") { statement in
                    try statement.bind(position: 1, "pending")
                    try statement.step()
                }
                throw TestFailure.expected
            }
        )

        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items"), .integer(0))
    }

    func testNestedTransactionUsesSavepoint() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (name TEXT NOT NULL);")

        try database.withTransaction { transaction in
            try transaction.execute("INSERT INTO items (name) VALUES (\("outer"))")
            try transaction.withTransaction { nestedTransaction in
                try nestedTransaction.execute("INSERT INTO items (name) VALUES (\("inner"))")
            }
            try transaction.execute("INSERT INTO items (name) VALUES (\("after"))")
        }

        let names = try database.fetch("SELECT name FROM items ORDER BY name") { row in
            try row.require("name", as: String.self)
        }
        XCTAssertEqual(names, ["after", "inner", "outer"])
    }

    func testNestedTransactionRollbackDoesNotRollbackOuterTransaction() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        enum TestFailure: Error {
            case expected
        }

        try database.execute("CREATE TABLE items (name TEXT NOT NULL);")

        try database.withTransaction { transaction in
            try transaction.execute("INSERT INTO items (name) VALUES (\("outer"))")
            XCTAssertThrowsError(
                try transaction.withTransaction { nestedTransaction in
                    try nestedTransaction.execute("INSERT INTO items (name) VALUES (\("pending"))")
                    throw TestFailure.expected
                }
            )
            try transaction.execute("INSERT INTO items (name) VALUES (\("after"))")
        }

        let names = try database.fetch("SELECT name FROM items ORDER BY name") { row in
            try row.require("name", as: String.self)
        }
        XCTAssertEqual(names, ["after", "outer"])
    }

    func testMigrationsAreOrderedAtomicAndIdempotent() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let migrations = [
            SQLiteMigration(version: 2) { transaction in
                try transaction.execute("ALTER TABLE items ADD COLUMN name TEXT NOT NULL DEFAULT 'migrated';")
                try transaction.execute("INSERT INTO items (value, name) VALUES (\(2), \("second"))")
            },
            SQLiteMigration(version: 1) { transaction in
                try transaction.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, value INTEGER NOT NULL);")
            },
        ]

        try database.migrate(migrations)
        try database.migrate(migrations)

        XCTAssertEqual(try database.scalar("PRAGMA user_version", as: Int.self), 2)
        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items", as: Int.self), 1)
        XCTAssertEqual(try database.scalar("SELECT name FROM items", as: String.self), "second")
    }

    func testMigrationFailureRollsBackSchemaAndVersion() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        enum MigrationFailure: Error {
            case expected
        }

        XCTAssertThrowsError(
            try database.migrate([
                SQLiteMigration(version: 1) { transaction in
                    try transaction.execute("CREATE TABLE items (id INTEGER PRIMARY KEY);")
                },
                SQLiteMigration(version: 2) { _ in
                    throw MigrationFailure.expected
                },
            ])
        ) { error in
            XCTAssertTrue(error is MigrationFailure)
        }

        XCTAssertEqual(try database.scalar("PRAGMA user_version", as: Int.self), 0)
        XCTAssertThrowsError(try database.scalar("SELECT COUNT(*) FROM items"))
    }

    func testMigrationValidationRejectsInvalidDuplicateAndNewerVersions() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        XCTAssertThrowsError(try database.migrate([SQLiteMigration(version: 0) { _ in }])) { error in
            XCTAssertEqual(error as? SQLiteMigrationError, .invalidVersion(0))
        }
        let outOfRangeVersion = Int(Int32.max) + 1
        XCTAssertThrowsError(
            try database.migrate([SQLiteMigration(version: outOfRangeVersion) { _ in }])
        ) { error in
            XCTAssertEqual(error as? SQLiteMigrationError, .invalidVersion(outOfRangeVersion))
        }
        XCTAssertThrowsError(
            try database.migrate([
                SQLiteMigration(version: 1) { _ in },
                SQLiteMigration(version: 1) { _ in },
            ])
        ) { error in
            XCTAssertEqual(error as? SQLiteMigrationError, .duplicateVersion(1))
        }

        try database.execute("PRAGMA user_version = 3")
        XCTAssertThrowsError(try database.migrate([SQLiteMigration(version: 2) { _ in }])) { error in
            XCTAssertEqual(
                error as? SQLiteMigrationError,
                .databaseVersionIsNewer(current: 3, latestMigration: 2)
            )
        }
    }

    func testEmptyStatementThrowsInsteadOfCrashing() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        do {
            _ = try database.unsafePrepare("-- comment only")
            XCTFail("Expected an empty SQL statement to throw.")
        } catch let error as SQLiteError {
            XCTAssertEqual(error.code, SQLITE_MISUSE)
        }
    }

    func testBlobHelpersReadByteCountsCorrectly() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let payload: [UInt8] = [1, 0, 2, 0]
        try database.execute("CREATE TABLE blobs (payload BLOB NOT NULL);")
        try database.execute("INSERT INTO blobs (payload) VALUES (\(payload))")

        try database.withPreparedStatement("SELECT payload FROM blobs") { statement in
            var result = try statement.step()
            while result == .row {
                XCTAssertEqual(try statement.columnValue(position: 0), .blob(Data([1, 0, 2, 0])))
                result = try statement.step()
            }
        }
    }

    func testEmptyBlobBindingsRemainBlobValues() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let emptyPayload: [UInt8] = []
        try database.execute("CREATE TABLE blobs (id INTEGER PRIMARY KEY AUTOINCREMENT, payload BLOB);")
        try database.execute("INSERT INTO blobs (payload) VALUES (\(emptyPayload))")
        try database.withPreparedStatement("INSERT INTO blobs (payload) VALUES (?)") { statement in
            try statement.bind(position: 1, Data())
            try statement.step()
        }

        let rows = try database.fetch("SELECT typeof(payload) AS storage, length(payload) AS size, payload FROM blobs ORDER BY id") { row in
            (
                storage: try row.require("storage", as: String.self),
                size: try row.require("size", as: Int.self),
                payload: try row.require("payload", as: [UInt8].self)
            )
        }

        XCTAssertEqual(rows.map(\.storage), ["blob", "blob"])
        XCTAssertEqual(rows.map(\.size), [0, 0])
        XCTAssertEqual(rows.map(\.payload), [[], []])
    }

    func testSpanBlobAPIsBorrowBytes() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let payload: [UInt8] = [3, 1, 4, 1, 5, 9]
        try database.execute("CREATE TABLE blobs (payload BLOB NOT NULL);")
        try database.withPreparedStatement("INSERT INTO blobs (payload) VALUES (?)") { statement in
            try payload.withUnsafeBufferPointer { buffer in
                try statement.bindBlob(position: 1, bytes: unsafe Span(_unsafeElements: buffer))
            }
            try statement.step()
        }

        try database.withPreparedStatement("SELECT payload FROM blobs") { statement in
            var result = try statement.step()
            while result == .row {
                let borrowed = try statement.withColumnBlob(position: 0) { span in
                    span.withUnsafeBufferPointer { unsafe Array($0) }
                }
                XCTAssertEqual(borrowed, payload)
                result = try statement.step()
            }
        }
    }

    func testStatementColumnAPIsRejectInvalidPositions() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.withPreparedStatement("SELECT 1 AS value") { statement in
            XCTAssertEqual(try statement.step(), .row)
            XCTAssertEqual(try statement.columnName(position: 0), "value")
            XCTAssertEqual(try statement.columnValue(position: 0), .integer(1))

            for position in [-1, 1] {
                XCTAssertThrowsError(try statement.columnName(position: position)) { error in
                    XCTAssertEqual((error as? SQLiteError)?.code, SQLITE_RANGE)
                    XCTAssertEqual((error as? SQLiteError)?.operation, "column")
                }
                XCTAssertThrowsError(try statement.columnValue(position: position))
                XCTAssertThrowsError(try statement.withColumnBlob(position: position) { _ in })
            }
        }
    }

    func testAsyncDatabaseRunsWorkOffMainThread() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PoSQLiteAsyncTests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        let database = AsyncSQLiteDatabase(fileURL: url)

        do {
            try await database.migrate([
                SQLiteMigration(version: 1) { transaction in
                    try transaction.execute("CREATE TABLE items (id INTEGER PRIMARY KEY AUTOINCREMENT, value INTEGER NOT NULL);")
                },
            ])
            let insertion = try await database.executeResult("INSERT INTO items (value) VALUES (\(1))")
            XCTAssertEqual(insertion.lastInsertRowID, 1)
            try await database.withTransaction { transaction in
                try transaction.execute("INSERT INTO items (value) VALUES (\(2))")
            }

            let mainThreadFlags = try await database.fetch("SELECT value FROM items") { _ in
                Thread.isMainThread
            }
            XCTAssertEqual(mainThreadFlags, [false, false])
            let count = try await database.scalar("SELECT COUNT(*) FROM items", as: Int.self)
            XCTAssertEqual(count, 2)
            try await database.close()
        } catch {
            try? await database.close()
            removeDatabaseFiles(at: url)
            throw error
        }

        removeDatabaseFiles(at: url)
    }

    func testAsyncDatabaseSupportsStreamingBorrowedAndPreparedAPIs() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PoSQLiteAsyncExtendedTests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        let database = AsyncSQLiteDatabase(fileURL: url)

        do {
            try await database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, value INTEGER NOT NULL);")
            try await database.execute("INSERT INTO items (value) VALUES (\(1)), (\(2));")

            let copiedValues = ArrayRecorder<Int>()
            try await database.forEachRow("SELECT value FROM items ORDER BY id") { row in
                copiedValues.append(try row.require("value", as: Int.self))
            }
            XCTAssertEqual(copiedValues.values, [1, 2])

            let borrowedValues = ArrayRecorder<Int>()
            try await database.forEachBorrowedRow("SELECT value FROM items ORDER BY id") { row in
                borrowedValues.append(try row.require("value", as: Int.self))
            }
            XCTAssertEqual(borrowedValues.values, [1, 2])

            let firstBorrowed = try await database.fetchOneBorrowed(
                "SELECT value FROM items ORDER BY id"
            ) { row in
                try row.require("value", as: Int.self)
            }
            XCTAssertEqual(firstBorrowed, 1)

            let preparedValue = try await database.withPreparedStatement(
                "SELECT value FROM items WHERE id = ?"
            ) { statement in
                try statement.bind(position: 1, 2)
                guard try statement.step() == .row else { return SQLiteValue.null }
                return try statement.columnValue(position: 0)
            }
            XCTAssertEqual(preparedValue, .integer(2))

            let namedValue = try await database.scalar(
                SQL("SELECT value FROM items WHERE value = :value", namedParameters: [":value": .integer(1)]),
                as: Int.self
            )
            XCTAssertEqual(namedValue, 1)
            try await database.close()
        } catch {
            try? await database.close()
            removeDatabaseFiles(at: url)
            throw error
        }

        removeDatabaseFiles(at: url)
    }

    func testBorrowedRowAPIsReadValuesAndBlobSpans() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE blobs (id INTEGER PRIMARY KEY, name TEXT NOT NULL, payload BLOB);")
        try database.execute("INSERT INTO blobs (name, payload) VALUES (\("first"), \([1, 2, 3] as [UInt8]))")
        try database.execute("INSERT INTO blobs (name, payload) VALUES (\("empty"), \([] as [UInt8]))")

        let rows = try database.fetchBorrowed("SELECT id, name, payload FROM blobs ORDER BY id") { row in
            XCTAssertEqual(try row.columnName(at: 0), "id")
            let payload = try row.withBlob(named: "payload") { span in
                span.withUnsafeBufferPointer { unsafe Array($0) }
            }
            let payloadData = try row.data(named: "payload")
            return (
                id: try row.require("id", as: Int.self),
                name: try row.require("name", as: String.self),
                payload: try XCTUnwrap(payload),
                payloadData: try XCTUnwrap(payloadData),
                payloadBytes: try row.require("payload", as: [UInt8].self)
            )
        }

        XCTAssertEqual(rows.map(\.id), [1, 2])
        XCTAssertEqual(rows.map(\.name), ["first", "empty"])
        XCTAssertEqual(rows.map(\.payload), [[1, 2, 3], []])
        XCTAssertEqual(rows.map(\.payloadData), [Data([1, 2, 3]), Data()])
        XCTAssertEqual(rows.map(\.payloadBytes), [[1, 2, 3], []])

        let nullPayload = try database.fetchOneBorrowed("SELECT NULL AS payload") { row in
            try row.withBlob(named: "payload") { span in
                span.withUnsafeBufferPointer { unsafe Array($0) }
            }
        }
        let nullPayloadValue = try XCTUnwrap(nullPayload)
        XCTAssertNil(nullPayloadValue)
    }

    func testCloseWaitsForActiveStatementLease() throws {
        let (database, url) = makeDatabase()
        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")
        try database.execute("INSERT INTO items (name) VALUES (\("held"))")

        var statement = try database.unsafePrepare("SELECT name FROM items")
        XCTAssertEqual(try statement.step(), .row)

        let closeStarted = DispatchSemaphore(value: 0)
        let closeFinished = DispatchSemaphore(value: 0)
        let failures = FailureRecorder()
        DispatchQueue.global(qos: .userInitiated).async {
            closeStarted.signal()
            do {
                try database.close()
            } catch {
                failures.record(error)
            }
            closeFinished.signal()
        }

        XCTAssertEqual(closeStarted.wait(timeout: .now() + .seconds(2)), .success)
        XCTAssertEqual(closeFinished.wait(timeout: .now() + .milliseconds(100)), .timedOut)

        try statement.finalize()
        XCTAssertEqual(closeFinished.wait(timeout: .now() + .seconds(2)), .success)
        XCTAssertEqual(failures.messages, [])

        cleanup(database: database, url: url)
    }

    func testConnectionPoolWaitsForReturnedHandle() throws {
        let configuration = SQLiteConfiguration(
            connectionCheckoutTimeoutMilliseconds: 1_000,
            maximumConnectionCount: 1,
            maximumIdleConnectionCount: 1
        )
        let (database, url) = makeDatabase(configuration: configuration)
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")
        try database.execute("INSERT INTO items (name) VALUES (\("held"))")

        var statement = try database.unsafePrepare("SELECT name FROM items")
        XCTAssertEqual(try statement.step(), .row)

        let started = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        let failures = FailureRecorder()
        let scalar = ValueRecorder<SQLiteValue>()
        DispatchQueue.global(qos: .userInitiated).async {
            started.signal()
            do {
                scalar.record(try database.scalar("SELECT COUNT(*) FROM items"))
            } catch {
                failures.record(error)
            }
            finished.signal()
        }

        XCTAssertEqual(started.wait(timeout: .now() + .seconds(2)), .success)
        XCTAssertEqual(finished.wait(timeout: .now() + .milliseconds(100)), .timedOut)

        try statement.finalize()
        XCTAssertEqual(finished.wait(timeout: .now() + .seconds(2)), .success)
        XCTAssertEqual(failures.messages, [])
        XCTAssertEqual(scalar.value, .integer(1))
    }

    func testConnectionPoolCheckoutTimeoutThrowsBusy() throws {
        let configuration = SQLiteConfiguration(
            connectionCheckoutTimeoutMilliseconds: nil,
            maximumConnectionCount: 1,
            maximumIdleConnectionCount: 1
        )
        let (database, url) = makeDatabase(configuration: configuration)
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")
        try database.execute("INSERT INTO items (name) VALUES (\("held"))")

        var statement = try database.unsafePrepare("SELECT name FROM items")
        defer { try? statement.finalize() }
        XCTAssertEqual(try statement.step(), .row)

        let finished = DispatchSemaphore(value: 0)
        let sqliteError = ValueRecorder<SQLiteError>()
        let failures = FailureRecorder()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try database.scalar("SELECT COUNT(*) FROM items")
            } catch let error as SQLiteError {
                sqliteError.record(error)
            } catch {
                failures.record(error)
            }
            finished.signal()
        }

        XCTAssertEqual(finished.wait(timeout: .now() + .seconds(2)), .success)
        XCTAssertEqual(failures.messages, [])
        let error = try XCTUnwrap(sqliteError.value)
        XCTAssertEqual(error.code, SQLITE_BUSY)
        XCTAssertEqual(error.operation, "open_handle")
    }

    func testConditionLockRelativeTimespecKeepsNanosecondsInRange() {
        let oneSecond = ConditionLock.relativeTimespec(timeout: 1)
        XCTAssertEqual(oneSecond.tv_sec, 1)
        XCTAssertEqual(oneSecond.tv_nsec, 0)

        let fractional = ConditionLock.relativeTimespec(timeout: 1.5)
        XCTAssertEqual(fractional.tv_sec, 1)
        XCTAssertEqual(fractional.tv_nsec, 500_000_000)

        let subsecond = ConditionLock.relativeTimespec(timeout: 0.999_999_999_9)
        XCTAssertEqual(subsecond.tv_sec, 0)
        XCTAssertLessThanOrEqual(subsecond.tv_nsec, 999_999_999)
    }

    func testConcurrentReadsAndWritesUsePoolSafely() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, value INTEGER NOT NULL);")

        let failures = FailureRecorder()
        let queue = DispatchQueue(label: "com.potato.sqlite.tests.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        for index in 0..<80 {
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    if index.isMultiple(of: 4) {
                        try database.execute("INSERT INTO items (value) VALUES (\(index))")
                    } else {
                        _ = try database.scalar("SELECT COUNT(*) FROM items")
                    }
                } catch {
                    failures.record(error)
                }
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + .seconds(5)), .success)
        XCTAssertEqual(failures.messages, [])
        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items"), .integer(20))
    }

    func testSQLiteErrorsCarrySQLContext() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let sql = "SELECT * FROM missing_table"
        do {
            _ = try database.execute(SQL(sql))
            XCTFail("Expected invalid SQL to throw.")
        } catch let error as SQLiteError {
            XCTAssertEqual(error.code, SQLITE_ERROR)
            XCTAssertEqual(error.extendedCode, SQLITE_ERROR)
            XCTAssertEqual(error.operation, "prepare")
            XCTAssertEqual(error.sql, sql)
            XCTAssertTrue(error.description.contains("sql=\(sql)"))
        }
    }

    func testSQLiteConstraintErrorsCarryExtendedCodeAndSQL() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let duplicate = "duplicate"
        let sql: SQL = "INSERT INTO items (name) VALUES (\(duplicate))"
        try database.execute("CREATE TABLE items (name TEXT NOT NULL UNIQUE);")
        try database.execute(sql)

        do {
            try database.execute(sql)
            XCTFail("Expected duplicate unique value to throw.")
        } catch let error as SQLiteError {
            let uniqueConstraint = SQLITE_CONSTRAINT | (8 << 8)
            XCTAssertEqual(error.code, SQLITE_CONSTRAINT)
            XCTAssertEqual(error.extendedCode, uniqueConstraint)
            XCTAssertEqual(error.operation, "step")
            XCTAssertEqual(error.sql, sql.statement)
        }
    }

    func testBindNameErrorsCarryBindContext() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        let sql = "SELECT :expected"
        let missingName = ":missing"
        var statement = try database.unsafePrepare(SQL(sql))
        defer { try? statement.finalize() }

        do {
            try statement.bind(name: missingName, 1)
            XCTFail("Expected missing bind parameter to throw.")
        } catch let error as SQLiteError {
            XCTAssertEqual(error.code, SQLITE_MISUSE)
            XCTAssertEqual(error.operation, "bind_parameter_index")
            XCTAssertEqual(error.sql, sql)
            XCTAssertEqual(error.bind?.name, missingName)
        }
    }

    func testPositionalBindCountMismatchThrowsBeforeStep() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (name TEXT NOT NULL, value INTEGER);")

        XCTAssertThrowsError(
            try database.execute(SQL("INSERT INTO items (name, value) VALUES (?, ?)", parameters: ["missing"]))
        ) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_RANGE)
            XCTAssertEqual(sqliteError?.operation, "bind_parameter_count")
        }

        XCTAssertThrowsError(
            try database.scalar("SELECT ?")
        ) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_RANGE)
            XCTAssertEqual(sqliteError?.operation, "bind_parameter_count")
        }

        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items"), .integer(0))
    }

    func testBindPositionAndZeroBlobCountValidateBeforeSQLiteCall() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        var statement = try database.unsafePrepare("SELECT ?")
        defer { try? statement.finalize() }

        let overflowingPosition = Int(Int32.max) + 1
        XCTAssertThrowsError(try statement.bind(position: overflowingPosition, 1)) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_RANGE)
            XCTAssertEqual(sqliteError?.operation, "bind")
            XCTAssertEqual(sqliteError?.bind?.position, overflowingPosition)
        }

        XCTAssertThrowsError(try statement.bindZeroBlob(position: 1, count: -1)) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_RANGE)
            XCTAssertEqual(sqliteError?.operation, "bind")
            XCTAssertEqual(sqliteError?.bind?.position, 1)
        }
    }

    func testNamedBindParametersMustMatchStatement() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        var statement = try database.unsafePrepare("SELECT :expected")
        defer { try? statement.finalize() }

        XCTAssertThrowsError(try statement.bind([":missing": 1])) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_RANGE)
            XCTAssertEqual(sqliteError?.operation, "bind_parameter_names")
        }
    }

    func testPreparedAPIsRejectMultipleStatements() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (name TEXT NOT NULL);")

        XCTAssertThrowsError(
            try database.execute("INSERT INTO items (name) VALUES ('first'); INSERT INTO items (name) VALUES ('second');")
        ) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_MISUSE)
            XCTAssertEqual(sqliteError?.operation, "prepare")
        }

        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items"), .integer(0))
        XCTAssertEqual(try database.scalar("SELECT 1; -- trailing comment"), .integer(1))
    }

    func testExecuteRawScriptAllowsMultipleStatements() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.executeRawScript("""
        CREATE TABLE items (name TEXT NOT NULL);
        INSERT INTO items (name) VALUES ('first');
        INSERT INTO items (name) VALUES ('second');
        """)

        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items"), .integer(2))
    }

    func testExecuteRejectsStatementsThatReturnRows() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        try database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
        XCTAssertThrowsError(
            try database.execute("SELECT 1")
        ) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_MISUSE)
            XCTAssertEqual(sqliteError?.operation, "execute")
        }
        XCTAssertThrowsError(
            try database.execute("INSERT INTO items DEFAULT VALUES RETURNING id")
        ) { error in
            let sqliteError = error as? SQLiteError
            XCTAssertEqual(sqliteError?.code, SQLITE_MISUSE)
            XCTAssertEqual(sqliteError?.operation, "execute")
        }
        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items", as: Int.self), 0)
    }

    func testTransactionReportsRollbackFailureWithoutLosingPrimaryError() throws {
        let (database, url) = makeDatabase()
        defer { cleanup(database: database, url: url) }

        enum TestFailure: Error {
            case expected
        }

        try database.execute("CREATE TABLE items (name TEXT NOT NULL);")

        do {
            try database.withTransaction { transaction in
                try transaction.execute("INSERT INTO items (name) VALUES (\("pending"))")
                try transaction.execute("ROLLBACK TRANSACTION;")
                throw TestFailure.expected
            }
            XCTFail("Expected transaction to throw.")
        } catch let error as SQLiteTransactionError {
            XCTAssertTrue(error.primaryError is TestFailure)
            let rollbackError = try XCTUnwrap(error.rollbackError as? SQLiteError)
            XCTAssertEqual(rollbackError.operation, "execute")
            XCTAssertEqual(rollbackError.sql, "ROLLBACK TRANSACTION;")
        }

        XCTAssertEqual(try database.scalar("SELECT COUNT(*) FROM items"), .integer(0))
    }
}

private extension PoSQLiteTests {
    func makeDatabase(configuration: SQLiteConfiguration = .mobile) -> (SQLiteDatabase, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PoSQLiteTests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        return (SQLiteDatabase(fileURL: url, configuration: configuration), url)
    }

    func cleanup(database: SQLiteDatabase, url: URL) {
        try? database.close()
        removeDatabaseFiles(at: url)
    }

    func removeDatabaseFiles(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }
}

private final class FailureRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var messages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ error: any Error) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(String(describing: error))
    }
}

private final class ValueRecorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value?

    var value: Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ value: Value?) {
        lock.lock()
        defer { lock.unlock() }
        storage = value
    }
}

private final class ArrayRecorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: Value) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }
}
