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
        didSet { attributes[.font] = UIFont.pingfang(ofSize: fontSize) }
    }
    
    /// 文字整体属性
    private static var _attributes: [NSAttributedString.Key: Any]?
    static var attributes: [NSAttributedString.Key: Any] {
        get {
            if _attributes == nil {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byCharWrapping
                paragraphStyle.lineSpacing = Appearance.lineSpacing
                paragraphStyle.paragraphSpacing = Appearance.paragraphSpacing
                paragraphStyle.alignment = .justified
                _attributes = [NSAttributedString.Key.font: UIFont.pingfang(ofSize: fontSize),
                               NSAttributedString.Key.paragraphStyle: paragraphStyle]
            }
            _attributes![.foregroundColor] = Appearance.readerTextColor
            return _attributes!
        }
        set { _attributes = newValue }
    }
    
    static let lineSpacing: CGFloat = 7
    static let paragraphSpacing: CGFloat = 10
    
    //注意:以下方法均不考虑iOS11以下情况
    static func configDeviceSafeAreaInsets(insets: UIEdgeInsets?) {
        _deviceSafeAreaInsets = insets
    }
    private static var _deviceSafeAreaInsets: UIEdgeInsets?
    static var deviceSafeAreaInsets: UIEdgeInsets {
        if let insets = _deviceSafeAreaInsets {
            return insets
        }
        if let window = UIApplication.shared.currentKeyWindow {
            _deviceSafeAreaInsets = window.safeAreaInsets
            return window.safeAreaInsets
        }
        return .zero
    }
    
    static let displayInsets: UIEdgeInsets = UIEdgeInsets(top: deviceSafeAreaInsets.top, left: 20, bottom: max(deviceSafeAreaInsets.bottom, 30), right: 20)
    
    /// 文本显示范围(左下原点)
    static let displayRect: CGRect = {
        return CGRect(x: displayInsets.left, y: displayInsets.top, width: UIScreen.main.bounds.width - displayInsets.left - displayInsets.right, height: UIScreen.main.bounds.height - displayInsets.bottom - displayInsets.top)
    }()
    
    // MARK: - 阅读页 bottom bar
    static let readerBottomBarBackgroundColor: UIColor = .dynamicColor(light: .white,
                                                                       dark: UIColor(red: 0.21, green: 0.21, blue: 0.21, alpha: 1))
}
