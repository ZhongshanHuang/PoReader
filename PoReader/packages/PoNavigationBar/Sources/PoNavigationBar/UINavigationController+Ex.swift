//
//  File.swift
//  
//
//  Created by HzS on 2024/3/8.
//

import UIKit

extension UINavigationController {
    
    private struct AssociatedObjectKeys {
        static var fullScreenPopGestureRecognizer: UInt8 = 0
        static var fullScreenPopGestureRecognizerDelegate: UInt8 = 0
    }
    
    public var fullScreenPopGestureRecognizer: UIPanGestureRecognizer {
        if let panGestureRecognizer = objc_getAssociatedObject(self, &AssociatedObjectKeys.fullScreenPopGestureRecognizer) as? UIPanGestureRecognizer {
            return panGestureRecognizer
        }
        let panGestureRecognizer = UIPanGestureRecognizer()
        panGestureRecognizer.maximumNumberOfTouches = 1
        objc_setAssociatedObject(self, &AssociatedObjectKeys.fullScreenPopGestureRecognizer, panGestureRecognizer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return panGestureRecognizer
    }
    
    private var fullScreenPopGestureRecognizerDelegate: FullScreenPopGestureRecognizerDelegate {
        if let delegate = objc_getAssociatedObject(self, &AssociatedObjectKeys.fullScreenPopGestureRecognizerDelegate) as? FullScreenPopGestureRecognizerDelegate {
            return delegate
        }
        let delegate = FullScreenPopGestureRecognizerDelegate(navigationController: self)
        objc_setAssociatedObject(self, &AssociatedObjectKeys.fullScreenPopGestureRecognizerDelegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return delegate
    }
    
    static func poNavigationControllerMethodExchange() {
        do {
            let originalSelector = #selector(UINavigationController.pushViewController(_:animated:))
            let swizzledSelector = #selector(UINavigationController.navigationBar_pushViewController(_:animated:))
            guard let originalMethod = class_getInstanceMethod(self, originalSelector),
                    let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else { return }
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    @objc
    private func navigationBar_pushViewController(_ viewController: UIViewController, animated: Bool) {
        defer { navigationBar_pushViewController(viewController, animated: animated) }
        guard self is PoNavigationBarConfigurable else { return }
        
        let contain =  interactivePopGestureRecognizer?.view?.gestureRecognizers?.contains(where: { $0 == fullScreenPopGestureRecognizer }) == true
        if !contain {
            interactivePopGestureRecognizer?.view?.addGestureRecognizer(fullScreenPopGestureRecognizer)
            fullScreenPopGestureRecognizer.delegate = fullScreenPopGestureRecognizerDelegate
            let internalTargets = interactivePopGestureRecognizer?.value(forKey: "targets") as? NSArray
            if let internalTarget = (internalTargets?.firstObject as? NSObject)?.value(forKey: "target") {
                fullScreenPopGestureRecognizer.addTarget(internalTarget, action: Selector(("handleNavigationTransition:")))
                interactivePopGestureRecognizer?.isEnabled = false
            }
        }
        
        let closure: WillAppearInjectClosure = { [weak self] viewController, animated in
            guard let self else { return }
            
            viewController.poNavigationBarConfig.fillSelfEmptyValue(with: (self as! PoNavigationBarConfigurable).defaultNavigationBarConfig)
            let isHidden = viewController.poNavigationBarConfig.isHidden ?? false
            setNavigationBarHidden(isHidden, animated: animated)
            if !isHidden {
                viewController.poNavigationBarConfig.apply(to: navigationBar)
            }
        }
        
        viewController.willAppearInjectClosure = closure

        let disappearingViewController = viewControllers.last
        if disappearingViewController != nil && disappearingViewController?.willAppearInjectClosure == nil {
            disappearingViewController?.willAppearInjectClosure = closure
        }
        
    }
    
}

private final class FullScreenPopGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    unowned(unsafe) let navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if navigationController.viewControllers.count <= 1 {
            return false
        }
        if navigationController.viewControllers.last?.poInteractivePopDisabled == true {
            return false
        }
        if (navigationController.value(forKey: "_isTransitioning") as? Bool) == true {
            return false
        }
        
        let translation = navigationController.fullScreenPopGestureRecognizer.translation(in: navigationController.fullScreenPopGestureRecognizer.view)
        if translation.x <= 0 {
            return false
        }
        return true
    }
}
