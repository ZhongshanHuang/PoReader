import Foundation

final class ThreadLocal<Value>: @unchecked Sendable {
    private final class Wrapper: RawRepresentable {
        typealias RawValue = Value
        var rawValue: RawValue
        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
    
    @unsafe private var key = pthread_key_t()
    private let defaultValue: Value
    
    init(defaultValue: Value) {
        self.defaultValue = defaultValue
        unsafe pthread_key_create(&key) {
            unsafe Unmanaged<AnyObject>.fromOpaque($0).release()
        }
    }
    
    deinit {
        unsafe pthread_key_delete(key)
    }
    
    var value: Value {
        @inline(__always)
        _read {
            guard let pointer = unsafe pthread_getspecific(key) else {
                yield defaultValue
                return
            }
            let wrapper = unsafe Unmanaged<Wrapper>.fromOpaque(pointer).takeUnretainedValue()
            yield wrapper.rawValue
        }

        @inline(__always)
        _modify {
            let wrapper: Wrapper
            if let pointer = unsafe pthread_getspecific(key) {
                wrapper = unsafe Unmanaged<Wrapper>.fromOpaque(pointer).takeUnretainedValue()
            } else {
                wrapper = Wrapper(rawValue: defaultValue)
                unsafe pthread_setspecific(key, unsafe Unmanaged.passRetained(wrapper).toOpaque())
            }
            yield &wrapper.rawValue
        }
    }

    @discardableResult
    @inline(__always)
    func withValue<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        let wrapper: Wrapper
        if let pointer = unsafe pthread_getspecific(key) {
            wrapper = unsafe Unmanaged<Wrapper>.fromOpaque(pointer).takeUnretainedValue()
        } else {
            wrapper = Wrapper(rawValue: defaultValue)
            unsafe pthread_setspecific(key, unsafe Unmanaged.passRetained(wrapper).toOpaque())
        }
        return try body(&wrapper.rawValue)
    }
}
