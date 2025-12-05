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
    
    private struct AssociatedObjectKeys {
        static var navigationBarConfigKey: UInt8 = 0
        static var interactivePopDisabledKey: UInt8 = 0
        static var willAppearInjectClosureKey: UInt8 = 0
    }
    
    typealias WillAppearInjectClosure = (_ viewController: UIViewController, _ animated: Bool) -> Void
    
    /// 是否禁用返回手势
    public var poInteractivePopDisabled: Bool {
        get {
            (objc_getAssociatedObject(self, &AssociatedObjectKeys.interactivePopDisabledKey) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObjectKeys.interactivePopDisabledKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var willAppearInjectClosure: WillAppearInjectClosure? {
        get {
            objc_getAssociatedObject(self, &AssociatedObjectKeys.willAppearInjectClosureKey) as? WillAppearInjectClosure
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObjectKeys.willAppearInjectClosureKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
        
    /// lazy navigationBarConfigure
    public var poNavigationBarConfig: PoNavigationBarConfiguration {
        get {
            if let configure = objc_getAssociatedObject(self, &AssociatedObjectKeys.navigationBarConfigKey) as? PoNavigationBarConfiguration {
                return configure
            }
            let configure = PoNavigationBarConfiguration()
            objc_setAssociatedObject(self, &AssociatedObjectKeys.navigationBarConfigKey, configure, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return configure
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObjectKeys.navigationBarConfigKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// copy default standard appearance
    public var poCopyNavigationBarStandardAppearance: UINavigationBarAppearance {
        if let appearance = (navigationController as? PoNavigationBarConfigurable)?.defaultNavigationBarConfig.standardAppearance {
            return UINavigationBarAppearance(barAppearance: appearance)
        }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        return appearance
    }
    
    /// copy default standard appearance
    public var poCopyNavigationBarScrollEdgeAppearance: UINavigationBarAppearance {
        if let appearance = (navigationController as? PoNavigationBarConfigurable)?.defaultNavigationBarConfig.scrollEdgeAppearance {
            return UINavigationBarAppearance(barAppearance: appearance)
        }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        return appearance
    }
    
    /// 将navigationBarConfig设置到navigationBar, animated 影响setNavigationBarHidden
    /// 除非在viewWillAppear之后设置了navigationBarConfig，否则不需要手动调用
    public func flushBarConfigure(_ animated: Bool = false) {
        guard let navigationBar = navigationController?.navigationBar else { return }
        poNavigationBarConfig.apply(to: navigationBar)
        navigationController?.setNavigationBarHidden(poNavigationBarConfig.isHidden ?? false, animated: animated)
    }
    
    static func poViewControllerMehtodExchange() {
        do {
            let originalSelector = #selector(UIViewController.viewWillAppear(_:))
            let swizzledSelector = #selector(UIViewController.navigationBar_viewWillAppear(_:))
            guard let originalMethod = class_getInstanceMethod(self, originalSelector),
                    let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else { return }
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    @objc
    private func navigationBar_viewWillAppear(_ animated: Bool) {
        navigationBar_viewWillAppear(animated)
        willAppearInjectClosure?(self, animated)
    }
    
}
