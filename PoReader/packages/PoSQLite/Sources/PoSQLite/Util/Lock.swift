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
        let integerPart = Int(timeout.nextDown)
        let fractionalPart = timeout - Double(integerPart)
        var ts = timespec(tv_sec: integerPart, tv_nsec: Int(fractionalPart * 1000000000))

        unsafe pthread_cond_timedwait_relative_np(&cond, &mutex, &ts)
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

final class RWLock: @unchecked Sendable {
    @unsafe var mutex = pthread_mutex_t()
    @unsafe var cond = pthread_cond_t()
    var reader = 0
    var writer = 0
    var pending = 0

    init() {
        unsafe pthread_mutex_init(&mutex, nil)
        unsafe pthread_cond_init(&cond, nil)
    }

    deinit {
        unsafe pthread_cond_destroy(&cond)
        unsafe pthread_mutex_destroy(&mutex)
    }

    func lockRead() {
        unsafe pthread_mutex_lock(&mutex); defer { unsafe pthread_mutex_unlock(&mutex) }
        while writer > 0 || pending > 0 {
            unsafe pthread_cond_wait(&cond, &mutex)
        }
        reader += 1
    }

    func unlockRead() {
        unsafe pthread_mutex_lock(&mutex); defer { unsafe pthread_mutex_unlock(&mutex) }
        reader -= 1
        if reader == 0 {
            unsafe pthread_cond_broadcast(&cond)
        }
    }

    func lockWrite() {
        unsafe pthread_mutex_lock(&mutex); defer { unsafe pthread_mutex_unlock(&mutex) }
        pending += 1
        while writer > 0 || reader > 0 {
            unsafe pthread_cond_wait(&cond, &mutex)
        }
        pending -= 1
        writer += 1
    }

    func unlockWrite() {
        unsafe pthread_mutex_lock(&mutex); defer { unsafe pthread_mutex_unlock(&mutex) }
        writer -= 1
        unsafe pthread_cond_broadcast(&cond)
    }

    var isWriting: Bool {
        unsafe pthread_mutex_lock(&mutex); defer { unsafe pthread_mutex_unlock(&mutex) }
        return writer > 0
    }
}
