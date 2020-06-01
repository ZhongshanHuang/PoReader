//
//  PoNavigationBarConfigure.swift
//  PoNavigationBar
//
//  Created by 黄中山 on 2020/4/2.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

open class PoNavigationBarConfigure {
    
    var isHidden: Bool?
    var barStyle: UIBarStyle?
    var isTranslucent: Bool?
    var tintColor: UIColor?
    var barTintColor: UIColor?
    var backgroundColor: UIColor?
    var backgroundImage: UIImage?
    var shadowImage: UIImage?
    var titleTextAttributes: [NSAttributedString.Key: Any]?
    
    func apply(to navigationBar: UINavigationBar) {
//        navigationBar.isHidden = isHidden ?? false
        navigationBar.barStyle = barStyle ?? .default
        navigationBar.tintColor = tintColor
        navigationBar.isTranslucent = isTranslucent ?? true
        navigationBar.barTintColor = barTintColor
        navigationBar.backgroundColor = backgroundColor
        navigationBar.setBackgroundImage(backgroundImage, for: .default)
        navigationBar.shadowImage = shadowImage
        navigationBar.titleTextAttributes = titleTextAttributes
    }
    
    func apply(to toolBar: UIToolbar) {
        toolBar.isHidden = isHidden ?? false
        toolBar.barStyle = barStyle ?? .default
        toolBar.isTranslucent = isTranslucent ?? true
        toolBar.barTintColor = barTintColor
        toolBar.backgroundColor = backgroundColor
        toolBar.setBackgroundImage(backgroundImage, forToolbarPosition: .bottom, barMetrics: .default)
        toolBar.setShadowImage(shadowImage, forToolbarPosition: .bottom)
    }
    
    /// 如果自身的属性是nil， 就用另外的配置对应属性来填充（主要是用来区分是否对应的UIViewController特别设置的，
    /// 不是的话就用defaultNavigationBarConfigure）
    func fillSelfEmptyValue(with anotherConfigure: PoNavigationBarConfigure) {
        if isHidden == nil {
            isHidden = anotherConfigure.isHidden
        }
        if barStyle == nil {
            barStyle = anotherConfigure.barStyle
        }
        if isTranslucent == nil {
            isTranslucent = anotherConfigure.isTranslucent
        }
        if tintColor == nil {
            tintColor = anotherConfigure.tintColor
        }
        if barTintColor == nil {
            barTintColor = anotherConfigure.barTintColor
        }
        if backgroundColor == nil {
            backgroundColor = anotherConfigure.backgroundColor
        }
        if backgroundImage == nil {
            backgroundImage = anotherConfigure.backgroundImage
        }
        if shadowImage == nil {
            shadowImage = anotherConfigure.shadowImage
        }
        if titleTextAttributes == nil {
            titleTextAttributes = anotherConfigure.titleTextAttributes
        }
    }
}
