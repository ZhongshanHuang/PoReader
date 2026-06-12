import Foundation

final class ConcurrentList<Value: Sendable> {
    let capacity: Int
    private let values = SQLiteMutex<[Value]>([])
    
    init(capacity: Int) {
        self.capacity = capacity
    }
    
    func pushBack(_ value: Value) -> Bool {
        values.withLock { values in
            if values.count < capacity {
                values.append(value)
                return true
            }
            return false
        }
    }
    
    func popBack() -> Value? {
        values.withLock { values in
            if values.isEmpty {
                return nil
            }
            return values.removeLast()
        }
    }

    var isEmpty: Bool {
        values.withLock { $0.isEmpty }
    }
    
    func clear() -> Int {
        values.withLock { values in
            let count = values.count
            values.removeAll()
            return count
        }
    }
}
