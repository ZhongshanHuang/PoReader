//
//  PoNavigationBarConfiguration.swift
//  PoNavigationBar
//
//  Created by 黄中山 on 2020/4/2.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

public class PoNavigationBarConfiguration {
    
    /* 自定义便利属性 */
    /// 是否隐藏navigationBar下面的线条
    public var isBottomLineHidden: Bool?
    /// 是否将navigationBar设置为透明
    public var isTransparent: Bool?
    
    /* 对应原生属性 */
    public var isHidden: Bool?
    public var barStyle: UIBarStyle?
    public var isTranslucent: Bool?
    public var tintColor: UIColor?
    public var barTintColor: UIColor?
    public var backgroundColor: UIColor?
    public var backgroundImage: UIImage?
    public var shadowImage: UIImage?
    public var titleTextAttributes: [NSAttributedString.Key: Any]?
    public var largeTitleTextAttributes: [NSAttributedString.Key: Any]?
    public var prefersLargeTitles: Bool?
    
    public var standardAppearance: UINavigationBarAppearance?
    public var compactAppearance: UINavigationBarAppearance?
    public var scrollEdgeAppearance: UINavigationBarAppearance?
    
    private var _compactScrollEdgeAppearance: AnyObject?
    @available(iOS 15.0, *)
    public var compactScrollEdgeAppearance: UINavigationBarAppearance? {
        get { _compactScrollEdgeAppearance as? UINavigationBarAppearance }
        set { _compactScrollEdgeAppearance = newValue }
    }
    
    private var _preferredBehavioralStyle: UInt?
    @available(iOS 16.0, *)
    public var preferredBehavioralStyle: UIBehavioralStyle? {
        get { if let _preferredBehavioralStyle { UIBehavioralStyle(rawValue: _preferredBehavioralStyle) } else { nil } }
        set { _preferredBehavioralStyle = newValue?.rawValue }
    }
    
    public init() {}
    
    internal func apply(to navigationBar: UINavigationBar) {
        navigationBar.isHidden = isHidden ?? false // 在别处设置的此属性
        navigationBar.barStyle = barStyle ?? .default
        navigationBar.tintColor = tintColor
        navigationBar.isTranslucent = isTranslucent ?? true
        navigationBar.barTintColor = barTintColor
        navigationBar.backgroundColor = backgroundColor
        navigationBar.setBackgroundImage(backgroundImage, for: .default)
        navigationBar.shadowImage = shadowImage
        navigationBar.titleTextAttributes = titleTextAttributes
        navigationBar.largeTitleTextAttributes = largeTitleTextAttributes
        navigationBar.prefersLargeTitles = prefersLargeTitles ?? false
        
        navigationBar.standardAppearance = standardAppearance ?? UINavigationBarAppearance()
        navigationBar.compactAppearance = compactAppearance
        navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = compactScrollEdgeAppearance
        }
        if #available(iOS 16.0, *) {
            navigationBar.preferredBehavioralStyle = preferredBehavioralStyle ?? .automatic
        }
        
        if isBottomLineHidden == true {
            navigationBar.standardAppearance.shadowColor = .clear
            navigationBar.scrollEdgeAppearance?.shadowColor = .clear
            navigationBar.shadowImage = UIImage()
        }
        
        if isTransparent == true {
            navigationBar.isTranslucent = true
            navigationBar.setBackgroundImage(UIImage(), for: .default)
            navigationBar.shadowImage = UIImage()
            navigationBar.prefersLargeTitles = false
            
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }
    
    /// 如果自身的属性是nil， 就用另外的配置对应属性来填充（主要是用来区分是否对应的UIViewController特别设置的，
    /// 不是的话就用defaultNavigationBarConfigure）
    internal func fillSelfEmptyValue(with anotherConfiguration: PoNavigationBarConfiguration) {
        if isBottomLineHidden == nil {
            isBottomLineHidden = anotherConfiguration.isBottomLineHidden
        }
        if isTransparent == nil {
            isTransparent = anotherConfiguration.isTransparent
        }
        if isHidden == nil {
            isHidden = anotherConfiguration.isHidden
        }
        if barStyle == nil {
            barStyle = anotherConfiguration.barStyle
        }
        if isTranslucent == nil {
            isTranslucent = anotherConfiguration.isTranslucent
        }
        if tintColor == nil {
            tintColor = anotherConfiguration.tintColor
        }
        if barTintColor == nil {
            barTintColor = anotherConfiguration.barTintColor
        }
        if backgroundColor == nil {
            backgroundColor = anotherConfiguration.backgroundColor
        }
        if backgroundImage == nil {
            backgroundImage = anotherConfiguration.backgroundImage
        }
        if shadowImage == nil {
            shadowImage = anotherConfiguration.shadowImage
        }
        if titleTextAttributes == nil {
            titleTextAttributes = anotherConfiguration.titleTextAttributes
        }
        if largeTitleTextAttributes == nil {
            largeTitleTextAttributes = anotherConfiguration.largeTitleTextAttributes
        }
        if prefersLargeTitles == nil {
            prefersLargeTitles = anotherConfiguration.prefersLargeTitles
        }
        if standardAppearance == nil {
            standardAppearance = anotherConfiguration.standardAppearance
        }
        if compactAppearance == nil {
            compactAppearance = anotherConfiguration.compactAppearance
        }
        if scrollEdgeAppearance == nil {
            scrollEdgeAppearance = anotherConfiguration.scrollEdgeAppearance
        }
        if #available(iOS 15.0, *) {
            if compactScrollEdgeAppearance == nil {
                compactScrollEdgeAppearance = anotherConfiguration.compactScrollEdgeAppearance
            }
        }
        if #available(iOS 16.0, *) {
            if preferredBehavioralStyle == nil {
                preferredBehavioralStyle = anotherConfiguration.preferredBehavioralStyle
            }
        }
    }
}

