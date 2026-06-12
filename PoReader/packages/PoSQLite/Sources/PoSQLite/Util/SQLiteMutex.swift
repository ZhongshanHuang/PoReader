import Foundation

#if canImport(Synchronization)
import Synchronization
#endif

final class SQLiteMutex<State: Sendable>: @unchecked Sendable {
    private enum Storage {
        case system(AnyObject)
        case pthread(PthreadSQLiteMutexBox<State>)
    }

    private let storage: Storage

    init(_ initialState: State) {
#if canImport(Synchronization)
        if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, *) {
            self.storage = .system(SystemSQLiteMutexBox(initialState))
            return
        }
#endif

        self.storage = .pthread(PthreadSQLiteMutexBox(initialState))
    }

    func withLock<Result>(_ body: (inout sending State) throws -> sending Result) rethrows -> sending Result {
        switch storage {
        case .system(let box):
#if canImport(Synchronization)
            if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, *) {
                return try (box as! SystemSQLiteMutexBox<State>).withLock(body)
            }
#endif
            preconditionFailure("System mutex storage is unavailable on this platform.")
        case .pthread(let box):
            return try box.withLock(body)
        }
    }
}

#if canImport(Synchronization)
@available(iOS 18, macOS 15, tvOS 18, watchOS 11, *)
private final class SystemSQLiteMutexBox<State: Sendable>: @unchecked Sendable {
    private let mutex: Synchronization.Mutex<State>

    init(_ initialState: State) {
        self.mutex = Synchronization.Mutex(initialState)
    }

    func withLock<Result>(_ body: (inout sending State) throws -> sending Result) rethrows -> sending Result {
        try mutex.withLock(body)
    }
}
#endif

private final class PthreadSQLiteMutexBox<State: Sendable>: @unchecked Sendable {
    @unsafe private var mutex = pthread_mutex_t()
    @unsafe private var state: State

    init(_ initialState: State) {
        unsafe self.state = initialState
        unsafe pthread_mutex_init(&mutex, nil)
    }

    deinit {
        unsafe pthread_mutex_destroy(&mutex)
    }

    func withLock<Result>(_ body: (inout sending State) throws -> sending Result) rethrows -> sending Result {
        unsafe pthread_mutex_lock(&mutex)
        defer { unsafe pthread_mutex_unlock(&mutex) }
        return try unsafe body(&state)
    }
}
