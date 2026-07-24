# PoSQLite

PoSQLite is a Swift wrapper around SQLite with parameter-safe SQL interpolation, typed row decoding, transactions, migrations, connection pooling, and a lower-level prepared-statement API.

## Requirements

- Swift 6.4 or later
- iOS 15 or later, or macOS 12 or later

## Quick start

`SQLiteDatabase` is the synchronous API. Create one database instance per independently managed database pool, then use SQL literals or `SQL` values for every operation.

```swift
import Foundation
import PoSQLite

struct User: SQLiteRowDecodable, Sendable {
    let id: Int
    let name: String
    let age: Int?
    let avatar: Data?

    init(row: SQLiteRow) throws {
        id = try row.require("id")
        name = try row.require("name")
        age = try row.get("age")
        avatar = try row.get("avatar", as: Data.self)
    }
}

let database = SQLiteDatabase(path: "/tmp/app.sqlite")

try database.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    age INTEGER,
    avatar BLOB
);
""")

let name = "Ada"
let age = 37
let avatar = Data([0, 1, 2])

let insertion = try database.executeResult("""
INSERT INTO users (name, age, avatar)
VALUES (\(name), \(age), \(avatar))
""")
let rowID = insertion.lastInsertRowID

let users = try database.fetch(
    "SELECT id, name, age, avatar FROM users ORDER BY id",
    as: User.self
)
let adultCount = try database.scalar(
    "SELECT COUNT(*) FROM users WHERE age >= \(18)",
    as: Int.self
)
```

## SQL and parameter binding

Every database operation accepts `SQL`, which is expressible by string literal and string interpolation. Ordinary interpolation is always converted to a SQLite bind parameter. It is never concatenated into the SQL text.

```swift
let name = "Ada"
let query: SQL = "SELECT id FROM users WHERE name = \(name)"

print(query.statement)  // SELECT id FROM users WHERE name = ?
print(query.parameters) // [.text("Ada")]
```

### Interpolation forms

| Syntax | Result | Use for |
| --- | --- | --- |
| `\(value)` | Appends `?` and one bound `SQLiteValue`. | All user or runtime data values. |
| `\(optionalValue)` | Appends `?`; `nil` binds SQLite `NULL`. | Nullable data values. |
| `\(unsafeRaw: raw)` | Inserts `raw` directly into the statement. | Trusted SQL syntax only. |
| `\(identifier: name)` | Inserts a double-quoted identifier, escaping embedded double quotes. | A table, column, index, or other one-part identifier. |

The ordinary forms work with these built-in `SQLiteValueConvertible` types:

| Swift value | SQLite storage class |
| --- | --- |
| `Int`, `Int32`, `Int64` | `INTEGER` |
| `Double` | `REAL` |
| `String` | `TEXT` |
| `Bool` | `INTEGER` (`1` or `0`) |
| `Data`, `[UInt8]` | `BLOB` |
| `Optional<T>` where `T` is supported | The value or `NULL` |
| `SQLiteValue` | Its original storage class |

Types such as `Date`, `UUID`, `Float`, and arrays other than `[UInt8]` are not implicitly converted. Define `SQLiteValueConvertible` when a domain type has a deliberate database representation:

```swift
struct UserID: SQLiteValueConvertible {
    let rawValue: Int64

    var sqliteValue: SQLiteValue {
        .integer(rawValue)
    }
}

try database.execute("DELETE FROM users WHERE id = \(UserID(rawValue: 42))")
```

### Values and `NULL`

Use normal interpolation for values, including values containing quotes or SQL-looking text:

```swift
let name = "Ada'); DROP TABLE users; --"
let age: Int? = nil
let payload: [UInt8] = [0, 1, 2, 255]

try database.execute("""
INSERT INTO users (name, age, avatar)
VALUES (\(name), \(age), \(payload))
""")
```

`age` above is bound as `NULL`. SQL still follows SQLite's `NULL` rules: `column = NULL` never matches a row. Write `IS NULL` or `IS NOT NULL` when that is the intended predicate.

```swift
let archivedAt: Int? = nil
let rows = try database.fetch(
    "SELECT id FROM users WHERE archived_at IS \(archivedAt)"
)
```

### Identifiers

SQLite parameters cannot represent SQL identifiers. Use `identifier:` for one identifier whose name is dynamic:

```swift
let table = "user records"
let column = "display\"name"

let query: SQL = "SELECT \(identifier: column) FROM \(identifier: table)"
// SELECT "display""name" FROM "user records"
```

`identifier:` quotes one name; it does not parse a dotted path. Quote each part separately when needed:

```swift
let schema = "main"
let table = "users"
let query: SQL = "SELECT * FROM \(identifier: schema).\(identifier: table)"
```

`SQL.quoteIdentifier(_:)` exposes the same quoting behavior when a quoted identifier string is needed outside interpolation.

### Trusted raw SQL

`unsafeRaw:` is intentionally explicit because it bypasses binding. Use it only with SQL text fully controlled by the application, never with user input.

```swift
let orderBy = "created_at DESC"
let query: SQL = "SELECT id, name FROM users ORDER BY \(unsafeRaw: orderBy)"

let count = try database.scalar(
    "SELECT \(unsafeRaw: "COUNT(*)") FROM users",
    as: Int.self
)
```

Both string literals and dynamic strings can be used at an `unsafeRaw:` interpolation site. The label makes the trust boundary visible in code; pass only SQL text controlled by the application.

### Explicit `SQL` and parameter arrays

Use `SQL(_:parameters:)` when the statement and bind values are built separately. The high-level execution and query APIs require the array to match the statement's SQLite parameter count exactly.

```swift
let query = SQL(
    "SELECT id, name FROM users WHERE id IN (?, ?, ?)",
    parameters: [.integer(3), .integer(8), .integer(13)]
)
let rows = try database.fetch(query)
```

There is no automatic collection expansion in interpolation. Build the required placeholders yourself and supply one `SQLiteValue` for each parameter. A SQL literal with unbound placeholders also fails in the high-level APIs:

```swift
try database.scalar("SELECT ?") // throws: parameter count does not match
```

`SQL` exposes `statement`, positional `parameters`, optional `namedParameters`, and `description`. `description` is the statement text only and does not include bound values.

### Named placeholders

String interpolation always produces positional `?` placeholders. For SQLite named placeholders such as `:name`, `@name`, and `$name`, build `SQL` with `namedParameters:` and use it with any high-level execution or query API.

```swift
let query = SQL(
    "SELECT id, name FROM users WHERE name = :name AND age >= :minimumAge",
    namedParameters: [
        ":name": "Ada",
        ":minimumAge": 18,
    ]
)
let users = try database.fetch(query, as: User.self)
```

Pass the complete SQLite placeholder name, including its prefix. The dictionary must match the statement's unique names exactly. If `:name` appears more than once in a statement, provide it once in the dictionary. `SQL(_:parameters:)` remains the positional `[SQLiteValue]` form; `SQL(_:namedParameters:)` is the name-to-value form.

Use `SQLiteStmt` directly only when values need to be bound after the statement is prepared or the statement is being manually reused:

```swift
try database.withPreparedStatement(
    "INSERT INTO users (name, age) VALUES (:name, :age)"
) { statement in
    try statement.bind(name: ":name", "Ada")
    try statement.bind(name: ":age", 37)
    try statement.step()
}
```

For manual batch binding, pass a dictionary whose keys are the complete placeholder names:

```swift
try database.withPreparedStatement(
    "INSERT INTO users (name, age) VALUES (:name, :age)"
) { statement in
    try statement.bind([
        ":name": .text("Linus"),
        ":age": .integer(37),
    ])
    try statement.step()
}
```

Every parameter must be named and the dictionary must match the statement's unique names exactly.

### Single statements and raw scripts

All prepared APIs accept exactly one non-empty SQL statement. Use `executeRawScript(_:)` only for a trusted, raw multi-statement script; it does not support binding or interpolation.

```swift
try database.executeRawScript("""
CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
INSERT INTO tags (name) VALUES ('swift');
INSERT INTO tags (name) VALUES ('sqlite');
""")
```

## Database lifecycle and execution

Create a database with a file-system path or URL. The default configuration is `SQLiteConfiguration.mobile`.

```swift
let byPath = SQLiteDatabase(path: "/tmp/app.sqlite")
let byURL = SQLiteDatabase(fileURL: URL(fileURLWithPath: "/tmp/app.sqlite"))
let memory = SQLiteDatabase(path: ":memory:")
```

Connections are opened lazily. Call `open()` to surface an opening or configuration error at a controlled time, and inspect `isOpen` to see whether the pool currently has an opened connection.

```swift
try database.open()
print(database.isOpen)
print(database.path)
print(database.configuration)
```

`close()` permanently closes that `SQLiteDatabase` instance. Create a new instance to reopen the same path. It throws when the calling thread currently holds an active statement or transaction; it waits for work on other threads to return its connection. Each database instance owns an independent pool, including `:memory:` databases.

```swift
try database.close()
```

Use `execute(_:)` for statements that do not return rows. Use `executeResult(_:)` only when you need SQLite's connection-local execution metadata:

| API | Result | Use |
| --- | --- | --- |
| `execute(_:)` | `Void` | One statement that returns no rows. |
| `executeResult(_:)` | `SQLiteExecutionResult` | One statement plus changed-row count or inserted row ID. |
| `executeRawScript(_:)` | `Void` | Trusted raw script containing one or more statements. |

`SQLiteExecutionResult.changes` is the changed-row count. Its `lastInsertRowID` is read from the same connection immediately after execution, and is meaningful after a successful `INSERT` into a rowid table. `execute` and `executeResult` reject statements that return rows, including `RETURNING` statements; use a query API for those statements.

## Query APIs

`SQLiteDatabase` and `SQLiteTransactionContext` conform to `SQLiteExecutor`. The following query APIs are available on both through public extensions:

| API | Result |
| --- | --- |
| `fetch(_:)` | `[SQLiteRow]` |
| `fetch(_:map:)` | `[T]` from a row-mapping closure |
| `fetch(_:as:)` | `[T]` where `T: SQLiteRowDecodable` |
| `forEachRow(_:_:)` | Streams copied `SQLiteRow` values to a closure |
| `fetchOne(_:)` | `SQLiteRow?` |
| `fetchOne(_:as:)` | `T?` where `T: SQLiteRowDecodable` |
| `scalar(_:)` | First column of the first row as `SQLiteValue?` |
| `scalar(_:as:)` | First column of the first row as `T?` where `T: SQLiteValueDecodable` |
| `forEachBorrowedRow(_:_:)` | Streams temporary `SQLiteBorrowedRow` values |
| `fetchBorrowed(_:map:)` | `[T]` mapped from borrowed rows |
| `fetchOneBorrowed(_:map:)` | Optional mapped value from the first borrowed row |

Examples:

```swift
let names = try database.fetch("SELECT name FROM users ORDER BY id") { row in
    try row.require("name", as: String.self)
}

let first = try database.fetchOne(
    "SELECT id, name, age, avatar FROM users WHERE id = \(1)",
    as: User.self
)

let count = try database.scalar("SELECT COUNT(*) FROM users", as: Int.self)

try database.forEachRow("SELECT id, name FROM users") { row in
    print(try row.require("id", as: Int.self), try row.require("name", as: String.self))
}
```

`scalar` reads only the first column of the first row. It returns `nil` when the query returns no rows; a returned SQLite `NULL` also decodes as `nil` for the built-in typed decoders.

`SQLiteExecutor.path` is available on both the database and transaction context. The transaction context does not expose lifecycle or pool-management APIs, but it does expose `execute`, `withPreparedStatement`, nested `withTransaction`, and every query API in this section.

## Rows and decoding

`SQLiteRow` is a copied, `Sendable` row. It remains valid after a query closure returns.

You can also construct one directly for a test fixture or an adapter boundary:

```swift
let row = SQLiteRow(
    columnNames: ["id", "name"],
    values: [.integer(1), .text("Ada")]
)
```

| API group | Usage |
| --- | --- |
| Metadata | `columnNames`, `values`, `count` |
| Optional lookup | `row[position]`, `row[name]` return `SQLiteValue?` |
| Required raw lookup | `value(at:)`, `value(named:)` throw for an invalid position or name |
| Typed nullable lookup | `string`, `int64`, `int`, `double`, `bool`, `blob`, `data`, or `get` with `at:` / `named:` |
| Typed required lookup | `require` with a position or name |

```swift
let rows = try database.fetch("SELECT id, name, age, avatar FROM users")
for row in rows {
    let id = try row.require("id", as: Int.self)
    let name: String? = try row.get("name")
    let age = try row.int(named: "age")
    let avatar = try row.data(named: "avatar")
    print(id, name as Any, age as Any, avatar as Any)
}
```

`get` returns `nil` for a SQLite `NULL`; `require` throws for `NULL`. A type mismatch also throws. The built-in decoders are `SQLiteValue`, `String`, `Int64`, `Int`, `Double`, `Bool`, `[UInt8]`, and `Data`. `Double` also accepts an SQLite integer; `Bool` accepts an SQLite integer and treats zero as `false`.

Name lookup uses the first matching column when a result contains duplicate column names. Use a positional accessor for later duplicates.

Define `SQLiteRowDecodable` for model types:

```swift
struct Tag: SQLiteRowDecodable, Sendable {
    let id: Int
    let name: String

    init(row: SQLiteRow) throws {
        id = try row.require("id")
        name = try row.require("name")
    }
}

let tags = try database.fetch("SELECT id, name FROM tags", as: Tag.self)
```

For a custom scalar decoder, conform to `SQLiteValueDecodable` and implement `decodeSQLiteValue(_:column:)`. That conformance is used by `get`, `require`, and typed `scalar` calls.

`SQLiteValue` represents the five SQLite storage classes directly:

```swift
let values: [SQLiteValue] = [
    .null,
    .integer(42),
    .double(3.14),
    .text("Ada"),
    .blob(Data([0, 1, 2])),
]
```

It also has initializers for the built-in bound value types and supports nil, integer, float, string, and boolean literals.

## Borrowed rows and large blobs

Use `SQLiteBorrowedRow` when copying every row or blob is unnecessary. A borrowed row is noncopyable and only exists during the callback. Return the data you need from the callback; do not attempt to store the row or its `Span<UInt8>`.

```swift
try database.forEachBorrowedRow("SELECT id, payload FROM files") { row in
    let id = try row.require("id", as: Int.self)
    let byteCount = try row.withBlob(named: "payload") { bytes in
        bytes.count
    } ?? 0
    print(id, byteCount)
}

let fileSizes = try database.fetchBorrowed("SELECT id, payload FROM files") { row in
    (
        id: try row.require("id", as: Int.self),
        size: try row.withBlob(named: "payload") { $0.count } ?? 0
    )
}
```

`SQLiteBorrowedRow` provides `count`, `columnName(at:)`, `columnIndex(named:)`, `value`, `string`, `int64`, `int`, `double`, `bool`, `data`, `get`, and `require`, each with positional or named access where applicable. It also provides:

- `withBlob(at:_:)` and `withBlob(named:_:)`, which pass a temporary `Span<UInt8>` and return `nil` for SQL `NULL`.
- `SQLiteBorrowedValueDecodable`, which lets custom types decode directly from a borrowed row when copying is avoidable.

Use `SQLiteRow` rather than a borrowed row whenever the result needs to outlive the callback or cross a concurrency boundary.

## Prepared statements

`withPreparedStatement(_:_:)` is the preferred low-level API. It binds any values already present in an interpolated `SQL`, manages statement finalization, uses the statement cache when enabled, and serializes statements that can write.

```swift
try database.withPreparedStatement(
    "INSERT INTO users (name, age) VALUES (?, ?)"
) { statement in
    try statement.bind(position: 1, "Grace")
    try statement.bind(position: 2, 40)
    try statement.step()
}
```

Positional bind indices start at `1`. Named bindings use the complete SQLite placeholder name, including its prefix:

```swift
try database.withPreparedStatement(
    "INSERT INTO users (name, age) VALUES (:name, :age)"
) { statement in
    try statement.bind([
        ":name": .text("Linus"),
        ":age": .integer(33),
    ])
    try statement.step()
}
```

The statement API is:

| API group | Methods and behavior |
| --- | --- |
| Step and lifetime | `step()` returns `.row` or `.done`; `reset(clearBindings:)`, `clearBindings()`, and mutating `finalize()` manage reuse and lifetime. |
| Value binding | `bind(position:_:)` and `bind(name:_:)` accept any `SQLiteValueConvertible`. `bind(_ values: [SQLiteValue])` requires the exact positional count. `bind(_ values: [String: SQLiteValue])` requires all parameters to be named and the dictionary to match the unique names exactly. |
| Blob and null binding | `bindBlob`, `bindZeroBlob`, and `bindNull`, each available by `position:` or `name:`. `bindBlob` takes a `Span<UInt8>`. |
| Parameter inspection | `bindParameterCount()`, `bindParameterName(position:)`, and `bindParameterIndex(name:)`. |
| Column inspection | `columnCount()`, `columnName(position:)`, `columnDeclaredType(position:)`, `columnType(position:)`, `columnValue(position:)`, and `withColumnBlob(position:_:)`. Read columns only after `step()` returns `.row`. |

`SQLiteType` has `.integer`, `.float`, `.text`, `.blob`, and `.null`. `SQLiteStepResult` has `.row` and `.done`.

For normal `Data` or `[UInt8]` bindings, the generic `bind` API and SQL interpolation are sufficient. Use the `Span` APIs only when avoiding a blob copy matters:

```swift
let bytes: [UInt8] = [3, 1, 4, 1, 5]

try database.withPreparedStatement("INSERT INTO files (payload) VALUES (?)") { statement in
    try bytes.withUnsafeBufferPointer { buffer in
        try statement.bindBlob(
            position: 1,
            bytes: unsafe Span(_unsafeElements: buffer)
        )
    }
    try statement.step()
}
```

`unsafePrepare(_:)` is an advanced escape hatch. It does not use the cache or the regular write serialization, and the caller must finalize the returned noncopyable statement:

```swift
var statement = try database.unsafePrepare("SELECT name FROM users WHERE id = ?")
defer { try? statement.finalize() }

try statement.bind(position: 1, 1)
if try statement.step() == .row {
    print(try statement.columnValue(position: 0))
}
```

Prefer `withPreparedStatement`, execution APIs, and query APIs unless manual lifetime control is required.

## Transactions

`withTransaction` runs its closure on one SQLite connection. It commits the returned result when the closure succeeds and rolls back when it throws.

```swift
try database.withTransaction(.immediate) { transaction in
    try transaction.execute(
        "INSERT INTO users (name, age) VALUES (\("Grace"), \(40))"
    )
    try transaction.execute(
        "INSERT INTO users (name, age) VALUES (\("Linus"), \(nil as Int?))"
    )

    let count = try transaction.scalar("SELECT COUNT(*) FROM users", as: Int.self)
    print(count as Any)
}
```

The transaction mode defaults to `.immediate`. The available `SQLiteTransactionMode` cases are:

| Mode | SQLite begin statement | Meaning |
| --- | --- | --- |
| `.deferred` | `BEGIN DEFERRED TRANSACTION` | Acquires a write lock only when a write is needed. |
| `.immediate` | `BEGIN IMMEDIATE TRANSACTION` | Acquires a reserved write lock up front. |
| `.exclusive` | `BEGIN EXCLUSIVE TRANSACTION` | Requests an exclusive lock up front. |

Nested `withTransaction` calls use SQLite savepoints. An inner error rolls back only its savepoint when caught by the outer closure. The transaction context is noncopyable and is supplied only to the closure; use its execution, prepared-statement, query-extension, and nested-transaction APIs rather than retaining it.

If the operation fails and the rollback also fails, PoSQLite throws `SQLiteTransactionError` with both `primaryError` and `rollbackError`.

## Migrations

`SQLiteMigration` groups schema changes under a positive version number. `migrate(_:)` sorts migrations, applies only pending versions, and updates `PRAGMA user_version` in the same transaction.

```swift
let migrations = [
    SQLiteMigration(version: 1) { transaction in
        try transaction.execute("""
        CREATE TABLE users (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL
        )
        """)
    },
    SQLiteMigration(version: 2) { transaction in
        try transaction.execute("ALTER TABLE users ADD COLUMN age INTEGER")
    },
]

try database.migrate(migrations)
```

Migrations are idempotent after their version is recorded. They throw `SQLiteMigrationError` when a version is not in `1...Int32.max`, occurs more than once, or the database version is newer than the newest supplied migration.

## Async database API

`AsyncSQLiteDatabase` is the mobile-friendly facade for application code that should not block the main thread. It runs work on a bounded operation queue, permits concurrent reads up to the connection limit, and retains SQLiteDatabase's serialized write behavior.

```swift
let database = AsyncSQLiteDatabase(
    fileURL: databaseURL,
    maximumConcurrentOperations: 4,
    qualityOfService: .userInitiated
)

try await database.execute(
    "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)"
)
let insertion = try await database.executeResult(
    "INSERT INTO users (name) VALUES (\("Ada"))"
)
let id = insertion.lastInsertRowID
let count = try await database.scalar("SELECT COUNT(*) FROM users", as: Int.self)
```

Initializers accept `path:`, `fileURL:`, or an existing `SQLiteDatabase`, plus optional `maximumConcurrentOperations` and `qualityOfService`. The requested concurrency is clamped to the database configuration's connection limit; `:memory:` always uses one worker.

Like `SQLiteDatabase`, the async facade exposes read-only `path`, `configuration`, and `isOpen` properties.

| Async API | Result |
| --- | --- |
| `open()`, `close()`, `migrate(_:)` | Lifecycle and migration operations |
| `execute(_:)`, `executeResult(_:)`, `executeRawScript(_:)` | Async counterparts of the synchronous execution APIs |
| `withPreparedStatement(_:_:)` | Managed prepared statement on a database worker |
| `fetch(_:)`, `fetch(_:map:)`, `fetch(_:as:)` | Copied rows, mapped rows, or `SQLiteRowDecodable` rows |
| `forEachRow(_:_:)` | Streams copied rows on a database worker |
| `fetchOne(_:)`, `fetchOne(_:as:)` | Optional copied row or decoded row |
| `scalar(_:)`, `scalar(_:as:)` | Optional scalar value |
| `forEachBorrowedRow(_:_:)`, `fetchBorrowed(_:map:)`, `fetchOneBorrowed(_:map:)` | Streaming, mapped, or single values from borrowed rows |
| `withTransaction(_:_:)` | One-worker synchronous transaction closure |
| `purgeIdleConnections()`, `purgeStatementCache()` | Resource management for the underlying pool |

Async row-mapping, borrowed-row, prepared-statement, and transaction closures are `@Sendable`, and their returned values must be `Sendable`. The prepared-statement and transaction closures themselves are synchronous: they cannot suspend with `await`, ensuring each keeps one worker and one SQLite connection for its whole lifetime.

Cancelling a task prevents queued work from starting. A SQLite call that has already started is not interrupted and returns its real result or error.

## Configuration, pooling, and caches

`SQLiteConfiguration.mobile` is the default. Its values are tuned for a mobile app:

| Setting | Default |
| --- | --- |
| `accessMode` | `.readWriteCreate` |
| `mutexMode` | `.noMutex` |
| `cacheMode` | `.private` |
| `usesURI` | `false` |
| `busyTimeoutMilliseconds` | `5_000` |
| `connectionCheckoutTimeoutMilliseconds` | `5_000` |
| `maximumConnectionCount` | CPU-based, clamped to `2...4` |
| `maximumIdleConnectionCount` | CPU-based, clamped to `1...2` |
| `journalMode` | `.wal` |
| `synchronous` | `.normal` |
| `foreignKeys` | `true` |
| `walAutoCheckpointPages` | `1_000` |
| `mmapSizeBytes` | `32 MiB` |
| `pageCacheSizeKiBPerConnection` | `4 MiB` |
| `tempStore` | `nil` (SQLite default) |
| `journalSizeLimitBytes` | `16 MiB` |
| `statementCacheCapacityPerConnection` | `16` |
| `additionalPragmas` | `[]` |

`SQLiteConfiguration.mobileLowMemory` reduces the connection count to `2`, idle connections to `1`, mmap to `16 MiB`, page cache to `2 MiB` per connection, and the statement cache to `8` per connection.

Configure only the behavior your application needs:

```swift
let configuration = SQLiteConfiguration(
    accessMode: .readWriteCreate,
    busyTimeoutMilliseconds: 10_000,
    connectionCheckoutTimeoutMilliseconds: 10_000,
    maximumConnectionCount: 4,
    maximumIdleConnectionCount: 2,
    journalMode: .wal,
    foreignKeys: true,
    statementCacheCapacityPerConnection: 32,
    additionalPragmas: [
        "PRAGMA secure_delete=ON;",
    ]
)

let database = SQLiteDatabase(path: "/tmp/app.sqlite", configuration: configuration)
```

All configuration options are public properties on `SQLiteConfiguration`, and the initializer exposes the same set. The available enum cases are:

| Type | Cases |
| --- | --- |
| `AccessMode` | `.readOnly`, `.readWrite`, `.readWriteCreate` |
| `MutexMode` | `.noMutex`, `.fullMutex` |
| `CacheMode` | `.default`, `.private`, `.shared` |
| `JournalMode` | `.delete`, `.truncate`, `.persist`, `.memory`, `.wal`, `.off` |
| `Synchronous` | `.off`, `.normal`, `.full`, `.extra` |
| `TempStore` | `.default`, `.file`, `.memory` |

Set `usesURI: true` when `path` is a SQLite URI. A read-only configuration does not attempt to set `journalMode`. `additionalPragmas` are raw SQL statements run for every newly opened connection, so they must be application-controlled.

`maximumConnectionCount` is normalized to at least `1`; the idle count is clamped to that limit. For `:memory:`, PoSQLite always uses one connection so one database instance observes one in-memory database.

`busyTimeoutMilliseconds` controls SQLite's lock wait. `connectionCheckoutTimeoutMilliseconds` separately controls how long an operation waits for a pooled connection; set it to `nil` to fail immediately with `SQLITE_BUSY` when the pool is exhausted.

The static `SQLiteConfiguration.defaultMaximumConnectionCount`, `defaultMaximumIdleConnectionCount`, and `defaultConnectionCheckoutTimeoutMilliseconds` expose the values used by the defaults.

Prepared statements are cached per connection when `statementCacheCapacityPerConnection` is greater than zero. To release resources:

```swift
database.purgeIdleConnections()
database.purgeStatementCache()

SQLiteDatabase.purgeAllIdleConnections()
SQLiteDatabase.purgeAllStatementCaches()
```

The purge APIs affect idle connections. A statement in active use is not invalidated.

## Errors

SQLite failures are reported as `SQLiteError`. It contains the SQLite `code`, optional `extendedCode`, original `message`, optional `operation`, optional `sql`, and optional bind context (`bind.position` or `bind.name`). Its `description` and `localizedDescription` combine those details for logs.

```swift
do {
    try database.execute("INSERT INTO missing_table VALUES (\(1))")
} catch let error as SQLiteError {
    print(error.code)
    print(error.operation as Any)
    print(error.sql as Any)
    print(error.description)
}
```

You can construct `SQLiteError` with either an `Int32` or `Int` code, a description, and optional extended-code, operation, SQL, and bind-context details. `SQLiteError.BindContext.position(_:)` and `.name(_:)` construct those bind-context values.

Transaction rollback failures use `SQLiteTransactionError`; migration validation failures use `SQLiteMigrationError`.
