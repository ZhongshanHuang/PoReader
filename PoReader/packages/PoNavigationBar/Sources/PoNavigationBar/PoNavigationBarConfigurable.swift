//
//  PoNavigationBarConfigurable.swift
//  HZSCustomTransition
//
//  Created by HzS on 16/4/6.
//  Copyright © 2016年 HzS. All rights reserved.
//

import UIKit

public func PoNavigationBarConfigInit() {
    UINavigationController.poNavigationControllerMethodExchange()
    UIViewController.poViewControllerMehtodExchange()
}

public protocol PoNavigationBarConfigurable: UINavigationController {
    var defaultNavigationBarConfig: PoNavigationBarConfiguration { get }
}

private var kDefaultNavigationBarConfigKey: UInt8 = 0
public extension PoNavigationBarConfigurable {
    var defaultNavigationBarConfig: PoNavigationBarConfiguration {
        if let configure = objc_getAssociatedObject(self, &kDefaultNavigationBarConfigKey) as? PoNavigationBarConfiguration {
            return configure
        }
        let config = PoNavigationBarConfiguration()
        config.barStyle = .default
        config.isTranslucent = true
        config.isHidden = false
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            config.standardAppearance = appearance
            config.scrollEdgeAppearance = appearance
        }
        objc_setAssociatedObject(self, &kDefaultNavigationBarConfigKey, config, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return config
    }
}
