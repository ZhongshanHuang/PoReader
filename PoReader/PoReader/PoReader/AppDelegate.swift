//
//  AppDelegate.swift
//  PoReader
//
//  Created by HzS on 2022/10/17.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = Appearance.backgroundColor
        window?.rootViewController = BaseNavigationController(rootViewController: MainViewController())
        window?.makeKeyAndVisible()
        
        // 发起一个网络请求，弹出权限申请弹窗
        let task = URLSession.shared.dataTask(with: URLRequest(url: URL(string: "https://www.baidu.com/")!))
        task.resume()
        
        return true
    }

}

