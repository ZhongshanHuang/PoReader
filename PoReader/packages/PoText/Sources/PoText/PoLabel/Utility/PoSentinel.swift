import Foundation

struct PoSentinel {
    
    // MARK: - Properties
    private var _value: Int = 0
    
    private mutating func _valuePtr() -> UnsafeMutablePointer<Int> {
        withUnsafeMutablePointer(to: &_value) { (ptr) -> UnsafeMutablePointer<Int> in
            return ptr
        }
    }
    
    // MARK: - Initializers
    init(value: Int = 0) {
        self._value = value
    }
    
    // MARK: - Methods
    @discardableResult
    mutating func value() -> Int {
        _swift_stdlib_atomicLoadInt(object: _valuePtr())
    }
    
    @discardableResult
    mutating func increase() -> Int {
        _swift_stdlib_atomicFetchAddInt(object: _valuePtr(), operand: 1)
    }
}
