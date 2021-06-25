//
//  Appearance.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/28.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

struct Appearance {
    
    // MARK: - 全局
    
    /// 背景色
    static let backgroundColor: UIColor = .dynamicColor(light: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1),
                                                      dark: UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1))
    
    
    // MARK: - 阅读页
    
    /// 背景
    static let readerBackgroundColor: UIColor = .dynamicColor(light: UIColor(patternImage: UIImage(named: "reader_bg")!),
                                                              dark: UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1))
    
    /// 其他的颜色，包括header，progress，power
    static let readerOtherColor: UIColor = .dynamicColor(light: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.3),
                                                         dark: UIColor(white: 0.5, alpha: 0.8))
    
    /// 文字颜色
    static let readerTextColor: UIColor = .dynamicColor(light: .black, dark: UIColor(white: 0.7, alpha: 0.8))
    
    /// 字体
    @UserDefault(key: "fontSize", defaultValue: 18)
    static var fontSize: CGFloat {
        didSet { attributes[.font] = UIFont.systemFont(ofSize: fontSize) }
    }
    
    /// 文字整体属性
    private static var _attributes: [NSAttributedString.Key: Any]?
    static var attributes: [NSAttributedString.Key: Any] {
        get {
            if _attributes == nil {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 7
                paragraphStyle.paragraphSpacing = 10
                paragraphStyle.alignment = .justified
                _attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize),
                               NSAttributedString.Key.paragraphStyle: paragraphStyle]
            }
            _attributes![.foregroundColor] = Appearance.readerTextColor
            return _attributes!
        }
        set { _attributes = newValue }
    }
    
    /// 文本显示范围
    static let displayRect: CGRect = {
        if UIDevice.isNotch {
            return CGRect(x: 20, y: 50, width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.height - 55 - 64)
        }
        return CGRect(x: 20, y: 30, width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.height - 30 - 40)
    }()
    
    // MARK: - 阅读页 bottom bar
    static let readerBottomBarBackgroundColor: UIColor = .dynamicColor(light: .white,
                                                                       dark: UIColor(red: 0.21, green: 0.21, blue: 0.21, alpha: 1))
}
