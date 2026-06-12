import Foundation

final class SQLiteHandlePoolReference {
    let pool: SQLiteHandlePool
    private let onRelease: () -> Void

    init(_ pool: SQLiteHandlePool, onRelease: @escaping () -> Void = {}) {
        self.pool = pool
        self.onRelease = onRelease
    }

    deinit {
        onRelease()
    }
}

final class SQLitePooledHandleLease {
    let handle: SQLiteHandle
    private let onReturn: () -> Void
    var refCount: Int = 0

    init(_ handle: SQLiteHandle, onReturn: @escaping () -> Void) {
        self.handle = handle
        self.onReturn = onReturn
    }

    deinit {
        onReturn()
    }
}
