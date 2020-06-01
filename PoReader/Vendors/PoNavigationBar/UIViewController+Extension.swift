//
//  UIViewController+Extension.swift
//  NavigationBar
//
//  Created by 黄中山 on 2020/4/1.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

// MARK: - UIViewController + Extension
extension UIViewController {
    
    private struct AssociatedObjectKey {
        static var navigationBarConfigureKey: UInt8?
    }
    
    // 用来存储属性的model
    private var _navigationBarConfigure: PoNavigationBarConfigure? {
        get {
            return objc_getAssociatedObject(self, &AssociatedObjectKey.navigationBarConfigureKey) as? PoNavigationBarConfigure
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObjectKey.navigationBarConfigureKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // lazy load
    open var navigationBarConfigure: PoNavigationBarConfigure {
        get {
            if let configure = _navigationBarConfigure { return configure }
            let configure = PoNavigationBarConfigure()
            _navigationBarConfigure = configure
            return configure
        }
        set {
            _navigationBarConfigure = newValue
        }
    }
    
    /// 将navigationBarConfigure设置到navigationBar
    /// 除非在viewWillAppear之后设置了navigationBarConfigure，否则不需要手动调用
    open func flushBarConfigure(_ animated: Bool = false) {
        guard let navigationBar = navigationController?.navigationBar else { return }
        navigationBarConfigure.apply(to: navigationBar)
        navigationController?.setNavigationBarHidden(navigationBarConfigure.isHidden ?? false, animated: animated)
    }
    
    internal var originNavigationBarFrame: CGRect? {
        guard let bar = navigationController?.navigationBar else { return nil }
        guard let background = bar.value(forKey: "_backgroundView") as? UIView else { return nil }
        var frame = background.frame
        frame.origin = .zero
        return frame
    }
}
