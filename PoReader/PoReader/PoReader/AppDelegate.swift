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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        PoNavigationBarConfigInit()
        return true
    }
    
}

