//
//  AppDelegate.swift
//  PoReader
//
//  Created by HzS on 2022/10/17.
//

import UIKit
import PoNavigationBar

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        PoNavigationBarConfigInit()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = Appearance.backgroundColor
        window?.overrideUserInterfaceStyle = UserSettings.appearanceMode.toUIUserInterfaceStyle
        window?.rootViewController = NavigationController(rootViewController: MainViewController())
        window?.makeKeyAndVisible()
        // makeKeyAndVisible后才准确
        Appearance.configDeviceSafeAreaInsets(insets: window?.safeAreaInsets)
        return true
    }
    
    

}

