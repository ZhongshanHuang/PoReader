import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        addChild(TextListViewController(), title: "文本", image: .init(systemName: "book"), selectedImage: nil)
        addChild(AudioListViewController(), title: "音频", image: .init(systemName: "headphones"), selectedImage: nil)
    }
    
    private func addChild(_ viewController: UIViewController, title: String, image: UIImage?, selectedImage: UIImage?) {
        viewController.tabBarItem = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
        let nav = NavigationController(rootViewController: viewController)
        addChild(nav)
    }

}
