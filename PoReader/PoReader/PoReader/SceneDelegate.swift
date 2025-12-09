//
//  SceneDelegate.swift
//  PoReader
//
//  Created by zhongshan on 2025/12/9.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
                
        window = UIWindow(windowScene: windowScene)
        window?.frame = windowScene.coordinateSpace.bounds
        window?.backgroundColor = Appearance.backgroundColor
        window?.overrideUserInterfaceStyle = UserSettings.appearanceMode.toUIUserInterfaceStyle
        window?.rootViewController = NavigationController(rootViewController: MainViewController())
        window?.makeKeyAndVisible()
        
        // makeKeyAndVisible后才准确
        Appearance.configDeviceSafeAreaInsets(insets: window?.safeAreaInsets)
    }
}

