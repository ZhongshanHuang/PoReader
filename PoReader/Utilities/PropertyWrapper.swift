//
//  PropertyWrapper.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/22.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get { return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

@propertyWrapper
struct UserDefaultCustom<T: NSObject & NSSecureCoding> {
    let key: String
    
    var wrappedValue: T? {
        get {
            return UserDefaults.standard.getCustomObject(forKey: key, classType: T.self) as? T
        }
        set {
            switch newValue {
            case .some(let value):
                UserDefaults.standard.saveCustomObject(customObject: value, forKey: key)
            case .none:
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}


@propertyWrapper
enum Lazy<Value> {
    case uninitialized(() -> Value)
    case initialized(Value)
    
    init(wrappedValue: @autoclosure @escaping () -> Value) {
        self = .uninitialized(wrappedValue)
    }
    
    init(body: @escaping () -> Value) {
        self = .uninitialized(body)
    }
    
    var wrappedValue: Value {
        mutating get {
            switch self {
            case .uninitialized(let initializer):
                let value = initializer()
                self = .initialized(value)
                return value
            case .initialized(let value):
                return value
            }
        }
        set {
            self = .initialized(newValue)
        }
    }
}
