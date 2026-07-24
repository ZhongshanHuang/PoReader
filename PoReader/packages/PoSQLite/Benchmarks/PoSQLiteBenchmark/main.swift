import Dispatch
import Darwin
import Foundation
import PoSQLite

@main
struct PoSQLiteBenchmark {
    static func main() throws {
        let options = try BenchmarkOptions(arguments: CommandLine.arguments)
        try BenchmarkRunner(options: options).run()
    }
}

private struct BenchmarkOptions {
    var preset = "baseline"
    var outputJSON = false
    var rows = 5_000
    var scalarIterations = 20_000
    var fetchIterations = 20
    var cacheIterations = 20_000
    var cacheMissUniqueStatements = 512
    var pressureWorkers = min(max(ProcessInfo.processInfo.processorCount, 2), 8)
    var pressureIterationsPerWorker = 1_000

    init(arguments: [String]) throws {
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("--") else {
                throw BenchmarkError("Unexpected argument: \(argument)")
            }

            if argument == "--help" {
                Self.printUsage()
                exit(0)
            }

            if argument == "--json" {
                outputJSON = true
                index += 1
                continue
            }

            guard index + 1 < arguments.count else {
                throw BenchmarkError("Missing value for \(argument)")
            }
            let value = arguments[index + 1]

            switch argument {
            case "--preset":
                try applyPreset(value)
            case "--rows":
                rows = try Self.positiveInt(value, argument: argument)
            case "--scalar-iterations":
                scalarIterations = try Self.positiveInt(value, argument: argument)
            case "--fetch-iterations":
                fetchIterations = try Self.positiveInt(value, argument: argument)
            case "--cache-iterations":
                cacheIterations = try Self.positiveInt(value, argument: argument)
            case "--cache-miss-unique-statements":
                cacheMissUniqueStatements = try Self.positiveInt(value, argument: argument)
            case "--pressure-workers":
                pressureWorkers = try Self.positiveInt(value, argument: argument)
            case "--pressure-iterations":
                pressureIterationsPerWorker = try Self.positiveInt(value, argument: argument)
            default:
                throw BenchmarkError("Unknown option: \(argument)")
            }

            index += 2
        }
    }

    mutating private func applyPreset(_ value: String) throws {
        switch value {
        case "quick":
            preset = value
            rows = 500
            scalarIterations = 2_000
            fetchIterations = 5
            cacheIterations = 2_000
            cacheMissUniqueStatements = 128
            pressureWorkers = 2
            pressureIterationsPerWorker = 200
        case "baseline":
            preset = value
            rows = 5_000
            scalarIterations = 20_000
            fetchIterations = 20
            cacheIterations = 20_000
            cacheMissUniqueStatements = 512
            pressureWorkers = min(max(ProcessInfo.processInfo.processorCount, 2), 8)
            pressureIterationsPerWorker = 1_000
        case "stress":
            preset = value
            rows = 20_000
            scalarIterations = 50_000
            fetchIterations = 30
            cacheIterations = 50_000
            cacheMissUniqueStatements = 2_048
            pressureWorkers = min(max(ProcessInfo.processInfo.processorCount, 4), 16)
            pressureIterationsPerWorker = 5_000
        default:
            throw BenchmarkError("Unknown preset: \(value)")
        }
    }

    private static func positiveInt(_ value: String, argument: String) throws -> Int {
        guard let parsed = Int(value), parsed > 0 else {
            throw BenchmarkError("\(argument) must be a positive integer.")
        }
        return parsed
    }

    private static func printUsage() {
        print("""
        Usage: swift run -c release PoSQLiteBenchmark [options]

        Options:
          --preset quick|baseline|stress    Fixed benchmark sizing preset. Default: baseline
          --json                            Emit machine-readable JSON instead of a text table
          --rows N                         Rows inserted into the benchmark table. Default: 5000
          --scalar-iterations N            Scalar query iterations. Default: 20000
          --fetch-iterations N             Full-table fetch iterations. Default: 20
          --cache-iterations N             Statement-cache iterations. Default: 20000
          --cache-miss-unique-statements N Unique raw SELECT statements for miss path. Default: 512
          --pressure-workers N             Concurrent pressure workers. Default: CPU-clamped 2...8
          --pressure-iterations N          Iterations per pressure worker. Default: 1000
        """)
    }
}

private final class BenchmarkRunner {
    let options: BenchmarkOptions
    private var results: [BenchmarkResult] = []

    init(options: BenchmarkOptions) {
        self.options = options
    }

    func run() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PoSQLiteBenchmark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let databaseURL = temporaryDirectory.appendingPathComponent("benchmark.sqlite")
        let configuration = SQLiteConfiguration(
            maximumConnectionCount: max(options.pressureWorkers, 2),
            maximumIdleConnectionCount: max(min(options.pressureWorkers, 4), 1),
            statementCacheCapacityPerConnection: 128
        )
        let database = SQLiteDatabase(fileURL: databaseURL, configuration: configuration)
        defer { try? database.close() }

        try prepare(database: database)

        if !options.outputJSON {
            print("PoSQLite benchmark")
            print("preset: \(options.preset), rows: \(options.rows), workers: \(options.pressureWorkers), statement cache: \(configuration.statementCacheCapacityPerConnection)")
            print("")
            print(formatRow(name: "case", operations: "operations", time: "time", rate: "ops/s"))
        }

        try measureScalarCount(database)
        try measureScalarLookup(database)
        try measureFetch(database)
        try measureBorrowedFetch(database)
        try measureStatementCacheHit(database)
        try measureStatementCacheMiss(database)
        try measureConcurrentPressure(database)

        if options.outputJSON {
            try printJSON(statementCacheCapacity: configuration.statementCacheCapacityPerConnection)
        }
    }

    private func prepare(database: SQLiteDatabase) throws {
        try database.execute("""
        CREATE TABLE items (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            value INTEGER NOT NULL,
            payload BLOB NOT NULL
        );
        """)

        try database.withTransaction { transaction in
            try transaction.withPreparedStatement("INSERT INTO items (id, name, value, payload) VALUES (?, ?, ?, ?)") { statement in
                for id in 1...options.rows {
                    try statement.bind(position: 1, id)
                    try statement.bind(position: 2, "item-\(id)")
                    try statement.bind(position: 3, id &* 3)
                    try statement.bind(position: 4, Data(repeating: UInt8(truncatingIfNeeded: id), count: 64))
                    try statement.step()
                    try statement.reset(clearBindings: true)
                }
            }
        }
    }

    private func measureScalarCount(_ database: SQLiteDatabase) throws {
        let sql: SQL = "SELECT COUNT(*) FROM items WHERE value >= \(options.rows)"
        let expected = options.rows - ((options.rows + 2) / 3) + 1
        var checksum = 0
        try measure(name: "scalar count", operations: options.scalarIterations) {
            for _ in 0..<options.scalarIterations {
                checksum &+= try database.scalar(sql, as: Int.self) ?? 0
            }
        }
        precondition(checksum == expected * options.scalarIterations)
    }

    private func measureScalarLookup(_ database: SQLiteDatabase) throws {
        let id = max(options.rows / 2, 1)
        let sql: SQL = "SELECT value FROM items WHERE id = \(id)"
        let expected = id &* 3
        var checksum = 0
        try measure(name: "scalar lookup", operations: options.scalarIterations) {
            for _ in 0..<options.scalarIterations {
                checksum &+= try database.scalar(sql, as: Int.self) ?? 0
            }
        }
        precondition(checksum == expected * options.scalarIterations)
    }

    private func measureFetch(_ database: SQLiteDatabase) throws {
        let sql: SQL = "SELECT id, name, value, payload FROM items ORDER BY id"
        var checksum = 0
        try measure(name: "fetch SQLiteRow", operations: options.fetchIterations * options.rows) {
            for _ in 0..<options.fetchIterations {
                let values = try database.fetch(sql) { row in
                    let id = try row.require("id", as: Int.self)
                    let value = try row.require("value", as: Int.self)
                    return id &+ value
                }
                checksum &+= values.reduce(0, &+)
            }
        }
        precondition(checksum > 0)
    }

    private func measureBorrowedFetch(_ database: SQLiteDatabase) throws {
        let sql: SQL = "SELECT id, name, value, payload FROM items ORDER BY id"
        var checksum = 0
        try measure(name: "fetch borrowed", operations: options.fetchIterations * options.rows) {
            for _ in 0..<options.fetchIterations {
                try database.forEachBorrowedRow(sql) { row in
                    checksum &+= try row.require("id", as: Int.self)
                    checksum &+= try row.require("value", as: Int.self)
                    checksum &+= try row.require("name", as: String.self).utf8.count
                }
            }
        }
        precondition(checksum > 0)
    }

    private func measureStatementCacheHit(_ database: SQLiteDatabase) throws {
        let sql: SQL = "SELECT 42"
        var checksum = 0
        try measure(name: "statement cache hit", operations: options.cacheIterations) {
            for _ in 0..<options.cacheIterations {
                checksum &+= try database.scalar(sql, as: Int.self) ?? 0
            }
        }
        precondition(checksum > 0)
    }

    private func measureStatementCacheMiss(_ database: SQLiteDatabase) throws {
        let statements = (0..<options.cacheMissUniqueStatements).map { index -> SQL in
            let raw = String(index)
            return "SELECT \(unsafeRaw: raw)"
        }

        var checksum = 0
        try measure(name: "statement cache miss", operations: options.cacheIterations) {
            for index in 0..<options.cacheIterations {
                checksum &+= try database.scalar(statements[index % statements.count], as: Int.self) ?? 0
            }
        }
        precondition(checksum >= 0)
    }

    private func measureConcurrentPressure(_ database: SQLiteDatabase) throws {
        let rows = options.rows
        let workers = options.pressureWorkers
        let iterationsPerWorker = options.pressureIterationsPerWorker
        let failures = FailureBox()
        try measure(
            name: "concurrent checkout",
            operations: workers * iterationsPerWorker
        ) {
            DispatchQueue.concurrentPerform(iterations: workers) { worker in
                for iteration in 0..<iterationsPerWorker {
                    do {
                        if iteration % 16 == 0 {
                            try database.execute("""
                            UPDATE items
                            SET value = value + 1
                            WHERE id = \(((worker + iteration) % rows) + 1)
                            """)
                        } else {
                            _ = try database.scalar("""
                            SELECT COUNT(*)
                            FROM items
                            WHERE id >= \(((worker + iteration) % rows) + 1)
                            """)
                        }
                    } catch {
                        failures.record(String(describing: error))
                    }
                }
            }
        }

        if let message = failures.first {
            throw BenchmarkError("Concurrent pressure failed: \(message)")
        }
    }

    private func measure(name: String, operations: Int, _ body: () throws -> Void) throws {
        let start = DispatchTime.now().uptimeNanoseconds
        try body()
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let seconds = Double(elapsed) / 1_000_000_000
        let rate = Double(operations) / seconds
        let result = BenchmarkResult(
            name: name,
            operations: operations,
            seconds: seconds,
            operationsPerSecond: rate
        )
        results.append(result)

        if !options.outputJSON {
            print(formatRow(
                name: name,
                operations: String(operations),
                time: "\(fixed3(seconds))s",
                rate: String(Int(rate.rounded()))
            ))
        }
    }

    private func printJSON(statementCacheCapacity: Int) throws {
        let report = BenchmarkReport(
            preset: options.preset,
            rows: options.rows,
            scalarIterations: options.scalarIterations,
            fetchIterations: options.fetchIterations,
            cacheIterations: options.cacheIterations,
            cacheMissUniqueStatements: options.cacheMissUniqueStatements,
            pressureWorkers: options.pressureWorkers,
            pressureIterationsPerWorker: options.pressureIterationsPerWorker,
            statementCacheCapacity: statementCacheCapacity,
            results: results
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        guard let string = String(data: data, encoding: .utf8) else {
            throw BenchmarkError("Failed to encode benchmark JSON as UTF-8.")
        }
        print(string)
    }

    private func formatRow(name: String, operations: String, time: String, rate: String) -> String {
        [
            name.padding(toLength: 30, withPad: " ", startingAt: 0),
            operations.leftPadded(toLength: 12),
            time.leftPadded(toLength: 12),
            rate.leftPadded(toLength: 14)
        ].joined(separator: " ")
    }

    private func fixed3(_ value: Double) -> String {
        let scaled = Int((value * 1_000).rounded())
        let whole = scaled / 1_000
        let fraction = abs(scaled % 1_000)
        let fractionText = String(fraction)
        return "\(whole).\(String(repeating: "0", count: 3 - fractionText.count))\(fractionText)"
    }
}

private struct BenchmarkReport: Encodable {
    let preset: String
    let rows: Int
    let scalarIterations: Int
    let fetchIterations: Int
    let cacheIterations: Int
    let cacheMissUniqueStatements: Int
    let pressureWorkers: Int
    let pressureIterationsPerWorker: Int
    let statementCacheCapacity: Int
    let results: [BenchmarkResult]
}

private struct BenchmarkResult: Encodable {
    let name: String
    let operations: Int
    let seconds: Double
    let operationsPerSecond: Double
}

private extension String {
    func leftPadded(toLength length: Int) -> String {
        guard count < length else { return self }
        return String(repeating: " ", count: length - count) + self
    }
}

private final class FailureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []

    var first: String? {
        lock.lock()
        defer { lock.unlock() }
        return messages.first
    }

    func record(_ message: String) {
        lock.lock()
        messages.append(message)
        lock.unlock()
    }
}

private struct BenchmarkError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
