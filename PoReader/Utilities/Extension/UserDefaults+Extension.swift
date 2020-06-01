//
//  UserDefaults+Extension.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/22.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

extension UserDefaults {
    /// 存储自定义对象
    ///
    /// - Parameters:
    ///   - object: 对象
    ///   - key: key
    func saveCustomObject(customObject object: NSSecureCoding, forKey key: String) {
        if #available(iOS 13, *) {
            let encodedObject = try! NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true)
            set(encodedObject, forKey: key)
        } else {
            let encodedObject = NSKeyedArchiver.archivedData(withRootObject: object)
            set(encodedObject, forKey: key)
        }
    }
    
    
    /// 读取自定义对象
    ///
    /// - Parameter key: key
    /// - Returns: 对象
    func getCustomObject<T>(forKey key: String, classType: T.Type) -> AnyObject? where T : NSObject, T : NSSecureCoding {
        let decodedObject = object(forKey: key) as? Data
        
        if let decoded = decodedObject {
            if #available(iOS 13, *) {
                let object = try? NSKeyedUnarchiver.unarchivedObject(ofClass: classType, from: decoded)
                return object as AnyObject
            } else {
                let object = NSKeyedUnarchiver.unarchiveObject(with: decoded)
                return object as AnyObject
            }
        }
        return nil
    }
}

