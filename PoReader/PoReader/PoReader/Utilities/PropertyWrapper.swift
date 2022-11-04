//
//  PropertyWrapper.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/22.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

@propertyWrapper
struct UserDefaultValue<T: Codable> {

    struct Wrapper<T>: Codable where T: Codable {
        let wrapped: T
    }

    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.object(forKey: key) as? Data
                else { return defaultValue }
            let value = try? JSONDecoder().decode(Wrapper<T>.self, from: data)
            return value?.wrapped ?? defaultValue
        }
        set {
            do {
                let data = try JSONEncoder().encode(Wrapper(wrapped:newValue))
                UserDefaults.standard.set(data, forKey: key)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

@propertyWrapper
struct UserDefaultOptionalValue<T: Codable> {

    struct Wrapper<T>: Codable where T: Codable {
        let wrapped: T
    }

    let key: String
    let defaultValue: T?

    var wrappedValue: T? {
        get {
            guard let data = UserDefaults.standard.object(forKey: key) as? Data
                else { return defaultValue }
            let value = try? JSONDecoder().decode(Wrapper<T>.self, from: data)
            return value?.wrapped ?? defaultValue
        }
        set {
            if let value = newValue {
                do {
                    let data = try JSONEncoder().encode(Wrapper(wrapped:value))
                    UserDefaults.standard.set(data, forKey: key)
                } catch {
                    debugPrint(error.localizedDescription)
                }
            } else {
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
