# PoSQLite

PoSQLite is a small Swift wrapper around SQLite. It provides safe SQL interpolation, row mapping, transactions, and a lower-level statement API when you need direct control.

## Usage

```swift
import Foundation
import PoSQLite

struct User: SQLiteRowDecodable {
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
let result = try database.execute("""
INSERT INTO users (name, age, avatar)
VALUES (\(name), \(age), \(avatar))
""")

print(result.lastInsertRowID)

let users = try database.fetch("SELECT id, name, age, avatar FROM users ORDER BY id", as: User.self)
let adultCount = try database.scalar("SELECT COUNT(*) FROM users WHERE age >= \(18)", as: Int.self)
```

Interpolated values are always bound as parameters. They are not concatenated into the SQL string.

```swift
try database.execute("UPDATE users SET age = \(38) WHERE name = \("Ada")")

let rows = try database.fetch("SELECT id, name FROM users WHERE name = \(name)") { row in
    (id: try row.require("id", as: Int.self), name: try row.require("name", as: String.self))
}
```

Use explicit raw SQL or quoted identifiers only for SQL syntax, not user values:

```swift
let table = "users"
let rows = try database.fetch("SELECT \(raw: "COUNT(*)") FROM \(identifier: table)")
```

Transactions keep all writes on the same SQLite handle and roll back on any thrown error:

```swift
try database.transaction { transaction in
    try transaction.execute("INSERT INTO users (name, age) VALUES (\("Grace"), \(40))")
    try transaction.execute("INSERT INTO users (name, age) VALUES (\("Linus"), \(nil as Int?))")

    let count = try transaction.scalar("SELECT COUNT(*) FROM users", as: Int.self)
    print(count as Any)
}
```

Nested transactions use SQLite savepoints, so an inner rollback does not automatically roll back the outer transaction.

Use `withPreparedStatement(_:access:_:)` when you need direct statement control with automatic finalization. Use `prepare(_:)` only when you need to manage the statement lifetime manually:

```swift
try database.withPreparedStatement("INSERT INTO users (name) VALUES (?)", access: .write) { statement in
    try statement.bind(position: 1, "Manual")
    try statement.step()
}
```

`execute`, `fetch`, `fetchOne`, and `scalar` require every SQL placeholder to be bound by `SQL` interpolation or explicit `SQL("...", parameters:)`. Use `executeScript(_:)` only for raw multi-statement scripts; it does not bind values.

## Configuration

`SQLiteDatabase` uses `SQLiteConfiguration.mobile` by default. The default is tuned for mobile apps:

- WAL journal mode
- `synchronous=NORMAL`
- `foreign_keys=ON`
- `busy_timeout=5000`
- 5000 ms connection checkout timeout when the pool is full
- `temp_store=MEMORY`
- 64 MiB mmap size
- 8 MiB page cache target
- 1000-page WAL autocheckpoint
- 16 MiB journal size limit
- capped connection pooling with a small idle handle cache

Override only the parts your app needs:

```swift
let configuration = SQLiteConfiguration(
    busyTimeoutMilliseconds: 10_000,
    connectionCheckoutTimeoutMilliseconds: 10_000,
    maximumConnectionCount: 4,
    maximumIdleConnectionCount: 2,
    additionalPragmas: [
        "PRAGMA user_version=1;"
    ]
)

let database = SQLiteDatabase(path: "/tmp/app.sqlite", configuration: configuration)
```

Connections are opened lazily. Call `open()` when you want to fail early instead of waiting for the first query:

```swift
try database.open()
print(database.isOpen)
```

`close()` permanently closes the database pool for the same path and configuration, and throws if the current thread still holds an active statement or transaction:

```swift
try database.close()
```

Create a new `SQLiteDatabase` for the same path when you need to reopen it.
