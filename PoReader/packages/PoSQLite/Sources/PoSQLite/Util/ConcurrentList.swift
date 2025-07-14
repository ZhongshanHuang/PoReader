import Foundation

final class ConcurrentList<Value> {
    let capacity: Int
    private(set) var values: [Value] = []
    private let spin = Spin()
    
    init(capacity: Int) {
        self.capacity = capacity
    }
    
    func pushBack(_ value: Value) -> Bool {
        spin.lock()
        defer { spin.unlock() }
        if values.count < capacity {
            values.append(value)
            return true
        }
        return false
    }
    
    func popBack() -> Value? {
        spin.lock()
        defer { spin.unlock() }
        
        if values.isEmpty {
            return nil
        }
        return values.removeLast()
    }
    
    func clear() -> Int {
        spin.lock()
        defer { spin.unlock() }
        let count = values.count
        values.removeAll()
        return count
    }
}
