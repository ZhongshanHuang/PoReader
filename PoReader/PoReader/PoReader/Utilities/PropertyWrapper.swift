//
//  UserDefault.swift
//  KitDemo
//
//  Created by HzS on 2023/7/26.
//  Copyright © 2023 黄中山. All rights reserved.
//

import Foundation

/*
class MyUUUU {
    @UserDefault(key: "") var iii = 3
    @UserDefault(key: "", defaultValue: 3) var iiii
}
 */

/// 普通属性用这个，不可空
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    init(wrappedValue: T, key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
}

/// 普通属性用这个，可空
@propertyWrapper
struct UserDefaultOptional<T> {
    let key: String
    let defaultValue: T?
    
    var wrappedValue: T? {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            switch newValue {
            case .some(let value):
                UserDefaults.standard.set(value, forKey: key)
            case .none:
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    init(key: String, defaultValue: T?) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    init(wrappedValue: T?, key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
}

/// 自定义属性用这个，必须遵循Codable
@propertyWrapper
struct UserDefaultCustom<T: Codable> {

    struct Wrapper<Value>: Codable where Value: Codable {
        let wrapped: Value
    }

    let key: String
    let defaultValue: T
    private var memoryValue: T?

    var wrappedValue: T {
        mutating get {
            if memoryValue != nil { return memoryValue! }
            
            guard let data = UserDefaults.standard.object(forKey: key) as? Data
                else { return defaultValue }
            
            do {
                let value = try JSONDecoder().decode(Wrapper<T>.self, from: data)
                memoryValue = value.wrapped
                return value.wrapped
            } catch {
                debugPrint(error.localizedDescription)
            }
            return defaultValue
        }
        set {
            memoryValue = newValue
            do {
                let data = try JSONEncoder().encode(Wrapper(wrapped:newValue))
                UserDefaults.standard.set(data, forKey: key)
            } catch {
                memoryValue = nil
                UserDefaults.standard.removeObject(forKey: key)
                debugPrint(error.localizedDescription)
            }
        }
    }
    
    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    init(wrappedValue: T, key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
}

/// 自定义属性用这个，必须遵循Codable
@propertyWrapper
struct UserDefaultCustomOptional<T: Codable> {

    struct Wrapper<Value>: Codable where Value: Codable {
        let wrapped: Value
    }

    let key: String
    let defaultValue: T?
    private var memoryValue: T?

    var wrappedValue: T? {
        mutating get {
            if memoryValue != nil { return memoryValue }
            
            guard let data = UserDefaults.standard.object(forKey: key) as? Data
                else { return defaultValue }
            
            do {
                let value = try JSONDecoder().decode(Wrapper<T>.self, from: data)
                memoryValue = value.wrapped
                return value.wrapped
            } catch {
                debugPrint(error.localizedDescription)
            }
            return nil
        }
        set {
            memoryValue = newValue
            if let value = newValue {
                do {
                    let data = try JSONEncoder().encode(Wrapper(wrapped:value))
                    UserDefaults.standard.set(data, forKey: key)
                } catch {
                    memoryValue = nil
                    debugPrint(error.localizedDescription)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    init(key: String, defaultValue: T?) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    init(wrappedValue: T?, key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
}
