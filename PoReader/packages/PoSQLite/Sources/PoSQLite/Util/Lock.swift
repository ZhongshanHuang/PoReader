import Foundation

final class ConditionLock: @unchecked Sendable {
    @unsafe private var mutex = pthread_mutex_t()
    @unsafe private var cond = pthread_cond_t()

    init() {
        unsafe pthread_mutex_init(&mutex, nil)
        unsafe pthread_cond_init(&cond, nil)
    }

    deinit {
        unsafe pthread_cond_destroy(&cond)
        unsafe pthread_mutex_destroy(&mutex)
    }

    func lock() {
        unsafe pthread_mutex_lock(&mutex)
    }

    func unlock() {
        unsafe pthread_mutex_unlock(&mutex)
    }

    func wait() {
        unsafe pthread_cond_wait(&cond, &mutex)
    }

    func wait(timeout: TimeInterval) {
        var ts = Self.relativeTimespec(timeout: timeout)

        unsafe pthread_cond_timedwait_relative_np(&cond, &mutex, &ts)
    }

    static func relativeTimespec(timeout: TimeInterval) -> timespec {
        guard timeout.isFinite, timeout > 0 else {
            return timespec(tv_sec: 0, tv_nsec: 0)
        }

        let wholeSeconds = timeout.rounded(.down)
        guard wholeSeconds < Double(Int.max) else {
            return timespec(tv_sec: Int.max, tv_nsec: 999_999_999)
        }

        let seconds = Int(wholeSeconds)
        let nanoseconds = Int(((timeout - wholeSeconds) * 1_000_000_000).rounded(.down))
        return timespec(tv_sec: seconds, tv_nsec: min(max(nanoseconds, 0), 999_999_999))
    }

    func signal() {
        unsafe pthread_cond_signal(&cond)
    }

    func broadcast() {
        unsafe pthread_cond_broadcast(&cond)
    }
}

extension DispatchQueue {
    static private let onceTracker = SQLiteMutex<Set<String>>([])

    static func once(name: String, _ block: () -> Void) {
        let shouldRun = onceTracker.withLock { tracker in
            tracker.insert(name).inserted
        }
        guard shouldRun else { return }
        block()
    }
}
