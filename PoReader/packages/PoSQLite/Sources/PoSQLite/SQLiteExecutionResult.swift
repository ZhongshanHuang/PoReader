/// The connection-local result of executing one SQL statement.
public struct SQLiteExecutionResult: Equatable, Sendable {
    /// The number of rows changed by the statement.
    public let changes: Int

    /// SQLite's last inserted row ID immediately after the statement completed.
    ///
    /// This value is meaningful after a successful `INSERT` into a rowid table.
    public let lastInsertRowID: Int64

    init(changes: Int, lastInsertRowID: Int64) {
        self.changes = changes
        self.lastInsertRowID = lastInsertRowID
    }
}
