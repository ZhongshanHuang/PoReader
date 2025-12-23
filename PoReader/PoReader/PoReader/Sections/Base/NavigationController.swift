import UIKit
import PoNavigationBar

class NavigationController: UINavigationController, PoNavigationBarConfigurable {
    
    @objc
    private func backBtnClick() {
        popViewController(animated: true)
    }
    
    /// Push
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if !children.isEmpty {
            viewController.hidesBottomBarWhenPushed = true
            
            let backBarButtonItem = UIBarButtonItem(image: UIImage(named: "navigation_back")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(backBtnClick))
            viewController.navigationItem.leftBarButtonItem = backBarButtonItem
        }
        super.pushViewController(viewController, animated: true)
    }
}
