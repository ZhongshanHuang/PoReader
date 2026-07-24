import Foundation

/// A mobile-friendly asynchronous facade over `SQLiteDatabase`.
///
/// Work runs on a bounded operation queue rather than the main actor or Swift's
/// cooperative executor. Cancellation prevents queued work from starting;
/// SQLite calls that have already started always return their actual outcome.
public final class AsyncSQLiteDatabase: @unchecked Sendable {
    private let database: SQLiteDatabase
    private let operationQueue: OperationQueue

    public var path: String {
        database.path
    }

    public var configuration: SQLiteConfiguration {
        database.configuration
    }

    public var isOpen: Bool {
        database.isOpen
    }

    public convenience init(
        path: String,
        configuration: SQLiteConfiguration = .mobile,
        maximumConcurrentOperations: Int? = nil,
        qualityOfService: QualityOfService = .userInitiated
    ) {
        self.init(
            database: SQLiteDatabase(path: path, configuration: configuration),
            maximumConcurrentOperations: maximumConcurrentOperations,
            qualityOfService: qualityOfService
        )
    }

    public convenience init(
        fileURL: URL,
        configuration: SQLiteConfiguration = .mobile,
        maximumConcurrentOperations: Int? = nil,
        qualityOfService: QualityOfService = .userInitiated
    ) {
        self.init(
            database: SQLiteDatabase(fileURL: fileURL, configuration: configuration),
            maximumConcurrentOperations: maximumConcurrentOperations,
            qualityOfService: qualityOfService
        )
    }

    public init(
        database: SQLiteDatabase,
        maximumConcurrentOperations: Int? = nil,
        qualityOfService: QualityOfService = .userInitiated
    ) {
        self.database = database

        let operationQueue = OperationQueue()
        operationQueue.name = "com.potato.sqlite.async.\(UUID().uuidString)"
        operationQueue.qualityOfService = qualityOfService
        let configuredMaximum = database.path == ":memory:" ? 1 : database.configuration.maximumConnectionCount
        operationQueue.maxConcurrentOperationCount = min(
            max(1, maximumConcurrentOperations ?? configuredMaximum),
            configuredMaximum
        )
        self.operationQueue = operationQueue
    }

    public func open() async throws {
        try await performBarrier {
            try self.database.open()
        }
    }

    public func close() async throws {
        try await performBarrier {
            try self.database.close()
        }
    }

    public func migrate(_ migrations: [SQLiteMigration]) async throws {
        try await performBarrier {
            try self.database.migrate(migrations)
        }
    }

    public func execute(_ sql: SQL) async throws {
        try await perform {
            try self.database.execute(sql)
        }
    }

    public func executeResult(_ sql: SQL) async throws -> SQLiteExecutionResult {
        try await perform {
            try self.database.executeResult(sql)
        }
    }

    public func executeRawScript(_ sql: String) async throws {
        try await perform {
            try self.database.executeRawScript(sql)
        }
    }

    public func withPreparedStatement<T: Sendable>(
        _ sql: SQL,
        _ body: @escaping @Sendable (_ statement: borrowing SQLiteStmt) throws -> T
    ) async throws -> T {
        try await perform {
            try self.database.withPreparedStatement(sql, body)
        }
    }

    public func fetch(_ sql: SQL) async throws -> [SQLiteRow] {
        try await perform {
            try self.database.fetch(sql)
        }
    }

    public func fetch<T: Sendable>(
        _ sql: SQL,
        map: @escaping @Sendable (SQLiteRow) throws -> T
    ) async throws -> [T] {
        try await perform {
            try self.database.fetch(sql, map: map)
        }
    }

    public func fetch<T: SQLiteRowDecodable & Sendable>(
        _ sql: SQL,
        as type: T.Type = T.self
    ) async throws -> [T] {
        try await perform {
            try self.database.fetch(sql, as: type)
        }
    }

    public func forEachRow(
        _ sql: SQL,
        _ body: @escaping @Sendable (SQLiteRow) throws -> Void
    ) async throws {
        try await perform {
            try self.database.forEachRow(sql, body)
        }
    }

    public func fetchOne(_ sql: SQL) async throws -> SQLiteRow? {
        try await perform {
            try self.database.fetchOne(sql)
        }
    }

    public func fetchOne<T: SQLiteRowDecodable & Sendable>(
        _ sql: SQL,
        as type: T.Type = T.self
    ) async throws -> T? {
        try await perform {
            try self.database.fetchOne(sql, as: type)
        }
    }

    public func scalar(_ sql: SQL) async throws -> SQLiteValue? {
        try await perform {
            try self.database.scalar(sql)
        }
    }

    public func scalar<T: SQLiteValueDecodable & Sendable>(
        _ sql: SQL,
        as type: T.Type = T.self
    ) async throws -> T? {
        try await perform {
            try self.database.scalar(sql, as: type)
        }
    }

    public func fetchBorrowed<T: Sendable>(
        _ sql: SQL,
        map: @escaping @Sendable (_ row: borrowing SQLiteBorrowedRow) throws -> T
    ) async throws -> [T] {
        try await perform {
            try self.database.fetchBorrowed(sql, map: map)
        }
    }

    public func forEachBorrowedRow(
        _ sql: SQL,
        _ body: @escaping @Sendable (_ row: borrowing SQLiteBorrowedRow) throws -> Void
    ) async throws {
        try await perform {
            try self.database.forEachBorrowedRow(sql, body)
        }
    }

    public func fetchOneBorrowed<T: Sendable>(
        _ sql: SQL,
        map: @escaping @Sendable (_ row: borrowing SQLiteBorrowedRow) throws -> T
    ) async throws -> T? {
        try await perform {
            try self.database.fetchOneBorrowed(sql, map: map)
        }
    }

    @discardableResult
    public func withTransaction<T: Sendable>(
        _ mode: SQLiteTransactionMode = .immediate,
        _ body: @escaping @Sendable (_ transaction: borrowing SQLiteTransactionContext) throws -> T
    ) async throws -> T {
        try await perform {
            try self.database.withTransaction(mode, body)
        }
    }

    public func purgeIdleConnections() {
        database.purgeIdleConnections()
    }

    public func purgeStatementCache() {
        database.purgeStatementCache()
    }
}

private extension AsyncSQLiteDatabase {
    func perform<Result: Sendable>(
        _ body: @escaping @Sendable () throws -> Result
    ) async throws -> Result {
        try await schedule(barrier: false, body)
    }

    func performBarrier<Result: Sendable>(
        _ body: @escaping @Sendable () throws -> Result
    ) async throws -> Result {
        try await schedule(barrier: true, body)
    }

    func schedule<Result: Sendable>(
        barrier: Bool,
        _ body: @escaping @Sendable () throws -> Result
    ) async throws -> Result {
        try Task.checkCancellation()
        let state = SQLiteMutex(AsyncSQLiteWorkState.queued)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let operation: @Sendable () -> Void = {
                    do {
                        let shouldRun = state.withLock { state in
                            guard state == .queued else { return false }
                            state = .running
                            return true
                        }
                        if !shouldRun {
                            throw CancellationError()
                        }
                        let result = try body()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

                if barrier {
                    operationQueue.addBarrierBlock(operation)
                } else {
                    operationQueue.addOperation(operation)
                }
            }
        } onCancel: {
            state.withLock { state in
                if state == .queued {
                    state = .cancelled
                }
            }
        }
    }
}

private enum AsyncSQLiteWorkState: Equatable, Sendable {
    case queued
    case running
    case cancelled
}
