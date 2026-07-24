import Foundation

@safe struct FastLRUCache<Key: Hashable, Value>: ~Copyable {
    private struct Slot {
        var key: Key?
        var value: Value?
        var previous = -1
        var next = -1
        var nextFree = -1
    }

    let capacity: Int
    private var indices: [Key: Int]
    private var slots: ContiguousArray<Slot>
    private var leastRecentlyUsed = -1
    private var mostRecentlyUsed = -1
    private var freeList = -1
    private var storageCount = 0

    init(capacity: Int) {
        let capacity = max(0, capacity)
        self.capacity = capacity
        self.indices = [:]
        self.slots = []
        self.indices.reserveCapacity(capacity)
        self.slots.reserveCapacity(capacity)
    }

    var count: Int {
        storageCount
    }

    var isEmpty: Bool {
        storageCount == 0
    }

    @inline(__always)
    func containsValue(forKey key: Key) -> Bool {
        indices[key] != nil
    }

    @inline(__always)
    mutating func value(forKey key: Key) -> Value? {
        guard let index = indices[key] else { return nil }
        moveToMostRecentlyUsed(index)
        return slots[index].value
    }

    @inline(__always)
    mutating func withValue<Result>(
        forKey key: Key,
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result? {
        guard let index = indices[key] else { return nil }
        moveToMostRecentlyUsed(index)
        return try body(&slots[index].value!)
    }

    @discardableResult
    @inline(__always)
    mutating func insertValue(_ value: consuming Value, forKey key: Key) -> Value? {
        if let index = indices[key] {
            moveToMostRecentlyUsed(index)
            let oldValue = slots[index].value
            slots[index].value = value
            return oldValue
        }

        if capacity == 0 {
            return value
        }

        let discarded = storageCount == capacity ? removeLeastRecentlyUsedValue() : nil
        let index = allocateSlot()
        slots[index].key = key
        slots[index].value = value
        linkMostRecentlyUsed(index)
        indices[key] = index
        storageCount += 1
        return discarded
    }

    @discardableResult
    @inline(__always)
    mutating func removeValue(forKey key: Key) -> Value? {
        guard let index = indices.removeValue(forKey: key) else { return nil }
        return removeSlot(at: index)
    }

    @discardableResult
    @inline(__always)
    mutating func removeLeastRecentlyUsedValue() -> Value? {
        guard leastRecentlyUsed >= 0 else { return nil }
        let index = leastRecentlyUsed
        if let key = slots[index].key {
            indices.removeValue(forKey: key)
        }
        return removeSlot(at: index)
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        indices.removeAll(keepingCapacity: keepingCapacity)
        slots.removeAll(keepingCapacity: keepingCapacity)
        leastRecentlyUsed = -1
        mostRecentlyUsed = -1
        freeList = -1
        storageCount = 0

        if keepingCapacity {
            indices.reserveCapacity(capacity)
            slots.reserveCapacity(capacity)
        }
    }
}

private extension FastLRUCache {
    @inline(__always)
    mutating func allocateSlot() -> Int {
        if freeList >= 0 {
            let index = freeList
            freeList = slots[index].nextFree
            slots[index].nextFree = -1
            return index
        }

        let index = slots.count
        slots.append(Slot())
        return index
    }

    @inline(__always)
    mutating func removeSlot(at index: Int) -> Value? {
        unlink(index)
        let value = slots[index].value
        slots[index].key = nil
        slots[index].value = nil
        slots[index].previous = -1
        slots[index].next = -1
        slots[index].nextFree = freeList
        freeList = index
        storageCount -= 1
        return value
    }

    @inline(__always)
    mutating func moveToMostRecentlyUsed(_ index: Int) {
        guard index != mostRecentlyUsed else { return }
        unlink(index)
        linkMostRecentlyUsed(index)
    }

    @inline(__always)
    mutating func linkMostRecentlyUsed(_ index: Int) {
        slots[index].previous = mostRecentlyUsed
        slots[index].next = -1

        if mostRecentlyUsed >= 0 {
            slots[mostRecentlyUsed].next = index
        } else {
            leastRecentlyUsed = index
        }

        mostRecentlyUsed = index
    }

    @inline(__always)
    mutating func unlink(_ index: Int) {
        let previous = slots[index].previous
        let next = slots[index].next

        if previous >= 0 {
            slots[previous].next = next
        } else {
            leastRecentlyUsed = next
        }

        if next >= 0 {
            slots[next].previous = previous
        } else {
            mostRecentlyUsed = previous
        }

        slots[index].previous = -1
        slots[index].next = -1
    }
}
