//
//  PoNavigationController.swift
//  HZSCustomTransition
//
//  Created by HzS on 16/4/6.
//  Copyright © 2016年 HzS. All rights reserved.
//

import UIKit

open class PoNavigationController: UINavigationController {
    
    // 场景切换时临时使用的假bar
    private lazy var toFakeBar: UIToolbar = UIToolbar()
    private lazy var fromFakeBar: UIToolbar = UIToolbar()
    
    /// 默认配置
    open lazy var defaultNavigationBarConfigure: PoNavigationBarConfigure = {
        let config = PoNavigationBarConfigure()
        config.barStyle = .default
        config.isTranslucent = true
        config.isHidden = false
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            config.standardAppearance = appearance
            config.scrollEdgeAppearance = appearance
        }
        return config
    }()
    
    /// 全屏返回
    open lazy var fullScreenPopGestureRecognizer: UIPanGestureRecognizer = {
        let target = interactivePopGestureRecognizer?.delegate
        let pan = UIPanGestureRecognizer(target: target, action: Selector(("handleNavigationTransition:")))
        pan.delegate = self
        return pan
    }()
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        // 全屏侧滑返回
        view.addGestureRecognizer(fullScreenPopGestureRecognizer)
        interactivePopGestureRecognizer?.isEnabled = false
        
        // 代理
        delegate = self
    }
}

// MARK: - UINavigationControllerDelegate
extension PoNavigationController: UINavigationControllerDelegate {
    
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // 如果有一边是隐藏了bar
        viewController.navigationBarConfigure.fillSelfEmptyValue(with: defaultNavigationBarConfigure)
        if (viewController.navigationBarConfigure.isHidden ?? false) != navigationController.navigationBar.isHidden {
            navigationController.setNavigationBarHidden(viewController.navigationBarConfigure.isHidden ?? false, animated: animated)
        }
        
        // 没有动画的没必要继续执行
        if animated == false { return }
        
        // 将原生bar设置为透明，为过渡做准备
        navigationController.navigationBar.barTintColor = nil
        navigationController.navigationBar.isTranslucent = true
        navigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController.navigationBar.shadowImage = UIImage()
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
        }
        
        (navigationController.navigationBar.value(forKey: "_backgroundView") as? UIView)?.isHidden = true
        
        navigationController.transitionCoordinator?.animate(alongsideTransition: { (ctx) in
            guard let fromVC = ctx.viewController(forKey: .from),
                let toVC = ctx.viewController(forKey: .to) else { fatalError("nil") }
            
            fromVC.navigationBarConfigure.fillSelfEmptyValue(with: self.defaultNavigationBarConfigure)
            if (fromVC.navigationBarConfigure.isHidden ?? false) == false {
                if let fakeBarFrame = fromVC.originNavigationBarFrame {
                    self.fromFakeBar.frame = fakeBarFrame
                    fromVC.navigationBarConfigure.apply(to: self.fromFakeBar)
                    fromVC.view.addSubview(self.fromFakeBar)
                }
            }
            
            toVC.navigationBarConfigure.fillSelfEmptyValue(with: self.defaultNavigationBarConfigure)
            if (toVC.navigationBarConfigure.isHidden ?? false) == false {
                if let fakeBarFrame = toVC.originNavigationBarFrame {
                    self.toFakeBar.frame = fakeBarFrame
                    toVC.navigationBarConfigure.apply(to: self.toFakeBar)
                    toVC.view.addSubview(self.toFakeBar)
                }
                navigationController.navigationBar.barTintColor = toVC.navigationBarConfigure.barTintColor
                navigationController.navigationBar.titleTextAttributes = toVC.navigationBarConfigure.titleTextAttributes
                navigationController.navigationBar.setBackgroundImage(toVC.navigationBarConfigure.backgroundImage, for: .default)
                navigationController.navigationBar.barStyle = toVC.navigationBarConfigure.barStyle ?? .default
                if #available(iOS 13.0, *) {
                    var appearance = toVC.navigationBarConfigure.standardAppearance
                    if appearance == nil {
                        appearance = self.defaultNavigationBarConfigure.standardAppearance ?? UINavigationBarAppearance()
                    }
                    navigationController.navigationBar.standardAppearance = appearance!
                    navigationController.navigationBar.scrollEdgeAppearance = appearance
                }
            }
        }, completion: { (ctx) in
            if ctx.isCancelled { // 失败后恢复原状
                self.fromFakeBar.removeFromSuperview()
                self.toFakeBar.removeFromSuperview()
                guard let fromVC = ctx.viewController(forKey: .from) else { fatalError("nil") }
                fromVC.navigationBarConfigure.apply(to: self.navigationBar)
                if fromVC.navigationBarConfigure.isHidden != self.navigationBar.isHidden {
                    navigationController.setNavigationBarHidden(fromVC.navigationBarConfigure.isHidden ?? false, animated: animated)
                }
            }
        })
    }
    
    // 如果push或者pop成功就调用，失败是不会调用这儿的，比上面的completion先掉用
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        self.fromFakeBar.removeFromSuperview()
        self.toFakeBar.removeFromSuperview()
        viewController.navigationBarConfigure.apply(to: navigationController.navigationBar)
        (navigationController.navigationBar.value(forKey: "_backgroundView") as? UIView)?.isHidden = false
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PoNavigationController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.fullScreenPopGestureRecognizer {
            return viewControllers.count > 1
        }
        return false
    }
}
