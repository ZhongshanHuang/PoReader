//
//  UserSettings.swift
//  PoReader
//
//  Created by zhongshan on 2025/4/29.
//

import Foundation

struct UserSettings {
    /// 观看模式
    enum AppearanceMode: Codable, CaseIterable, CustomStringConvertible {
        /// 白天
        case light
        /// 暗黑
        case dark
        /// 跟随系统
        case auto
        
        var description: String {
            switch self {
            case .light:
                "白天"
            case .dark:
                "暗黑"
            case .auto:
                "跟随系统"
            }
        }
    }
    /// 观看模式
    @UserDefaultCustom(key: "appearanceMode", defaultValue: .auto)
    static var appearanceMode: AppearanceMode
    
    enum TransitionStyle: Codable, CaseIterable, CustomStringConvertible {
        // 翻页效果
        case pageCurl
        // 滑动效果
        case scroll
        
        var description: String {
            switch self {
            case .pageCurl:
                "仿真"
            case .scroll:
                "上下滑动"
            }
        }
    }
    /// 翻页效果
    @UserDefaultCustom(key: "transitionStyle", defaultValue: .pageCurl)
    static var transitionStyle: TransitionStyle
    
    /// 是否自动打开最近浏览书籍
    @UserDefaultCustom(key: "autoOpenBook", defaultValue: true)
    static var autoOpenBook: Bool
}
