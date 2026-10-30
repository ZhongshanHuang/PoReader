import UIKit

@MainActor
public func PoNavigationBarConfigInit() {
    UINavigationController.poNavigationControllerMethodExchange()
    UIViewController.poViewControllerMehtodExchange()
}

public protocol PoNavigationBarConfigurable: UINavigationController {
    var defaultNavigationBarConfig: PoNavigationBarConfiguration { get }
}

@MainActor private var kDefaultNavigationBarConfigKey: UInt8 = 0
public extension PoNavigationBarConfigurable {
    var defaultNavigationBarConfig: PoNavigationBarConfiguration {
        if let configure = objc_getAssociatedObject(self, &kDefaultNavigationBarConfigKey) as? PoNavigationBarConfiguration {
            return configure
        }
        let config = PoNavigationBarConfiguration()
        config.barStyle = .default
        config.isTranslucent = true
        config.isHidden = false
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        config.standardAppearance = appearance
        config.scrollEdgeAppearance = appearance
        objc_setAssociatedObject(self, &kDefaultNavigationBarConfigKey, config, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return config
    }
}
