//
//  Constants.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/28.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

struct Constants {
    
    /// 本地书本存储文件夹
    static let localBookDirectory: String = {
        var path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        path = (path as NSString).appendingPathComponent("localBooks")
        if FileManager.default.fileExists(atPath: path) == false {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }()
    
    /// 数据库所在文件夹
    static let databaseDirectory: String = {
        var path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        path = (path as NSString).appendingPathComponent("PoReaderDatabase")
        if FileManager.default.fileExists(atPath: path) == false {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }()
}
