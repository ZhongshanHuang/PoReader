//
//  PoNavigationBarConfigure.swift
//  PoNavigationBar
//
//  Created by 黄中山 on 2020/4/2.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

open class PoNavigationBarConfigure {
    
    open var isHidden: Bool?
    open var barStyle: UIBarStyle?
    open var isTranslucent: Bool?
    open var tintColor: UIColor?
    open var barTintColor: UIColor?
    open var backgroundColor: UIColor?
    open var backgroundImage: UIImage?
    open var shadowImage: UIImage?
    open var titleTextAttributes: [NSAttributedString.Key: Any]?
    
    private var _standardAppearance: AnyObject?
    @available(iOS 13.0, *)
    open var standardAppearance: UINavigationBarAppearance? {
        get { _standardAppearance as? UINavigationBarAppearance }
        set { _standardAppearance = newValue }
    }
    
    private var _compactAppearance: AnyObject?
    @available(iOS 13.0, *)
    open var compactAppearance: UINavigationBarAppearance? {
        get { _compactAppearance as? UINavigationBarAppearance }
        set { _compactAppearance = newValue }
    }
    
    private var _scrollEdgeAppearance: AnyObject?
    @available(iOS 13.0, *)
    open var scrollEdgeAppearance: UINavigationBarAppearance? {
        get { _scrollEdgeAppearance as? UINavigationBarAppearance }
        set { _scrollEdgeAppearance = newValue }
    }
    
    private var _compactScrollEdgeAppearance: AnyObject?
    @available(iOS 15.0, *)
    open var compactScrollEdgeAppearance: UINavigationBarAppearance? {
        get { _compactScrollEdgeAppearance as? UINavigationBarAppearance }
        set { _compactScrollEdgeAppearance = newValue }
    }
    
    internal func apply(to navigationBar: UINavigationBar) {
//        navigationBar.isHidden = isHidden ?? false // 在别处设置的此属性
        navigationBar.barStyle = barStyle ?? .default
        navigationBar.tintColor = tintColor
        navigationBar.isTranslucent = isTranslucent ?? true
        navigationBar.barTintColor = barTintColor
        navigationBar.backgroundColor = backgroundColor
        navigationBar.setBackgroundImage(backgroundImage, for: .default)
        navigationBar.shadowImage = shadowImage
        navigationBar.titleTextAttributes = titleTextAttributes
        if #available(iOS 13.0, *) {
            navigationBar.standardAppearance = standardAppearance ?? UINavigationBarAppearance()
            navigationBar.compactAppearance = compactAppearance
            navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        }
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = compactScrollEdgeAppearance
        }
    }
    
    internal func apply(to toolBar: UIToolbar) {
        toolBar.isHidden = isHidden ?? false
        toolBar.barStyle = barStyle ?? .default
        toolBar.isTranslucent = isTranslucent ?? true
        toolBar.barTintColor = barTintColor
        toolBar.backgroundColor = backgroundColor
        toolBar.setBackgroundImage(backgroundImage, forToolbarPosition: .bottom, barMetrics: .default)
        toolBar.setShadowImage(shadowImage, forToolbarPosition: .bottom)
        if #available(iOS 13.0, *) {
            toolBar.standardAppearance = standardAppearance?.toToolbarAppearance ?? UIToolbarAppearance()
            toolBar.compactAppearance = compactAppearance?.toToolbarAppearance
        }
    }
    
    /// 如果自身的属性是nil， 就用另外的配置对应属性来填充（主要是用来区分是否对应的UIViewController特别设置的，
    /// 不是的话就用defaultNavigationBarConfigure）
    internal func fillSelfEmptyValue(with anotherConfigure: PoNavigationBarConfigure) {
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
        if #available(iOS 13.0, *) {
            if standardAppearance == nil {
                standardAppearance = anotherConfigure.standardAppearance
            }
            if compactAppearance == nil {
                compactAppearance = anotherConfigure.compactAppearance
            }
            if scrollEdgeAppearance == nil {
                scrollEdgeAppearance = anotherConfigure.scrollEdgeAppearance
            }
        }
        if #available(iOS 15.0, *) {
            if compactScrollEdgeAppearance == nil {
                compactScrollEdgeAppearance = anotherConfigure.compactScrollEdgeAppearance
            }
        }
    }
}

@available(iOS 13.0, *)
private extension UINavigationBarAppearance {
    
    var toToolbarAppearance: UIToolbarAppearance {
        return UIToolbarAppearance(barAppearance: self)
    }
}

