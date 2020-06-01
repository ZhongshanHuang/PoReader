//
//  UIDevice+Extension.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/21.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

extension UIDevice {
    /// 刘海屏
    static var isNotch: Bool {
        if #available(iOS 11, *) {
            return (UIApplication.shared.delegate?.window??.safeAreaInsets.bottom ?? 0) > 0
        } else {
            return false
        }
    }
}
