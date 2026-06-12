import Foundation

struct SQLiteStatementLease: ~Copyable {
    private let onRelease: () -> Void

    init(onRelease: @escaping () -> Void) {
        self.onRelease = onRelease
    }

    deinit {
        onRelease()
    }
}
