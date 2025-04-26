//
//  UIColor+extension.swift
//  KitDemo
//
//  Created by 黄山哥 on 2019/6/30.
//  Copyright © 2019 黄中山. All rights reserved.
//

import UIKit

extension UIColor {
        
    /// 支持 #FFFFFF或者FFFFFF格式，错误格式会得到黑色
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        guard hex.count >= 6 else {
            self.init(red: 0, green: 0, blue: 0, alpha: 1.0)
            return
        }
        
        let value: UInt?
        if hex.hasPrefix("#") {
            value = UInt(hex.dropFirst())
        } else {
            value = UInt(hex)
        }
        if value == nil {
            self.init(red: 0, green: 0, blue: 0, alpha: 1.0)
        } else {
            self.init(value!, alpha: alpha)
        }
    }
    
    convenience init(_ hex: UInt, alpha: CGFloat = 1.0) {
        let red = (hex >> 16) & 0xFF
        let green = (hex >> 8) & 0xFF
        let blue = hex & 0xFF
        self.init(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
    }
    
}
