//
//  ToastConfig.swift
//  MGOA-iOS
//
//  Created by HzS on 2022/3/11.
//

import Foundation
import UIKit

public struct ToastConfig {
    
    static let `default` = ToastConfig()
    
    // 动画持续时长
    public var duration: TimeInterval = 2
    
    // default
    public var backgroundColor: UIColor = UIColor(white: 0, alpha: 0.8)
    
    // default 13
    public var font: UIFont = UIFont.systemFont(ofSize: 14, weight: .medium)
    // default white
    public var textColor: UIColor = .white
    // default center
    public var textAlignment: NSTextAlignment = .center
    
    // 圆角
    public var cornerRadius: CGFloat = 17
    // 内间隔
    public var paddings: UIEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    // 最小外间隔
    public var margins: UIEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 15, right: 20)
    // 位置
    public var position: Toast.Position = .bottom
}

