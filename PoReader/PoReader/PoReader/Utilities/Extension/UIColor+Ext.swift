//
//  UIColor+Ext.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/27.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

extension UIColor {
    
    static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13, *) {
            return UIColor { (traintCollection) -> UIColor in
                if traintCollection.userInterfaceStyle == .dark {
                    return dark
                } else {
                    return light
                }
            }
        }
        return light
    }
    
}

