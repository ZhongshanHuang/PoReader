import Foundation

final class ThreadLocal<Value>: @unchecked Sendable {
    private final class Wrapper: RawRepresentable {
        typealias RawValue = Value
        var rawValue: RawValue
        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
    
    private var key = pthread_key_t()
    private var defaultValue: Value
    
    init(defaultValue: Value) {
        self.defaultValue = defaultValue
        pthread_key_create(&key) {
            Unmanaged<AnyObject>.fromOpaque($0).release()
        }
    }
    
    deinit {
        pthread_key_delete(key)
    }
    
    var value: Value {
        get {
            guard let pointer = pthread_getspecific(key) else { return defaultValue }
            return Unmanaged<Wrapper>.fromOpaque(pointer).takeUnretainedValue().rawValue
        }
        set {
            if let pointer = pthread_getspecific(key)  {
                Unmanaged<AnyObject>.fromOpaque(pointer).release()
            }
            pthread_setspecific(key, Unmanaged.passRetained(Wrapper(rawValue: newValue)).toOpaque())
        }
    }
}
