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
    private var defaultValue: Value
    
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
        get {
            guard let pointer = unsafe pthread_getspecific(key) else { return defaultValue }
            return unsafe Unmanaged<Wrapper>.fromOpaque(pointer).takeUnretainedValue().rawValue
        }
        set {
            if let pointer = unsafe pthread_getspecific(key)  {
                unsafe Unmanaged<AnyObject>.fromOpaque(pointer).release()
            }
            unsafe pthread_setspecific(key, unsafe Unmanaged.passRetained(Wrapper(rawValue: newValue)).toOpaque())
        }
    }
}
