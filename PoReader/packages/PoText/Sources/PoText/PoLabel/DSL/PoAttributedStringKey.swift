import UIKit

// MARK: - PoAttributedStringKey

public protocol PoAttributedStringKey {
    associatedtype Value : Hashable
    static var name : NSAttributedString.Key { get }
}

public extension PoAttributedStringKey {
    var description: String { Self.name.rawValue }
}

// MARK: - PoAttributeDynamicLookup

@dynamicMemberLookup
public enum PoAttributeDynamicLookup: Sendable {
    
    public subscript<T: PoAttributedStringKey>(_: T.Type) -> T {
        get { fatalError("Called outside of a dynamicMemberLookup subscript overload") }
    }
    
    public subscript<T: PoAttributedStringKey>(dynamicMember keyPath: KeyPath<PoTextAttributesScopes, T>) -> T {
        self[T.self]
    }
}

// MARK: - PoTextAttributesScopes

public struct PoTextAttributesScopes: Sendable {
    /// 字体
    public let font: PoTextAttributesScopes.FontAttribute = FontAttribute()
    /// 文字间隔(负数缩紧，正数散开)
    public let kern: PoTextAttributesScopes.KernAttribute = KernAttribute()
    /// 文字颜色
    public let foregroundColor: PoTextAttributesScopes.ForegroundColorAttribute = ForegroundColorAttribute()
    /// 背景颜色 /* PoLabel不支持, 请使用textBorder替代 */
    public let backgroundColor: PoTextAttributesScopes.BackgroundColorAttribute = BackgroundColorAttribute()
    /// 文字的外面的线宽 (正数会变成空心字，负数会加宽文字的线条)
    public let strokeWidth: PoTextAttributesScopes.StrokeWidthAttribute = StrokeWidthAttribute()
    /// 文字颜色，与strokeWidth一同设置才生效
    public let strokeColor: PoTextAttributesScopes.StrokeColorAttribute = StrokeColorAttribute()
    /// 文字阴影
    public let shadow: PoTextAttributesScopes.ShadowAttribute = ShadowAttribute()
    /// 文字删除线  /* PoLabel不支持, 请使用textStrikethroughStyle */
    public let strikethroughStyle: PoTextAttributesScopes.StrikethroughStyleAttribute = StrikethroughStyleAttribute()
    /// 文字删除线颜色 /* PoLabel不支持, 请使用textStrikethroughColor */
    public let strikethroughColor: PoTextAttributesScopes.StrikethroughColorAttribute = StrikethroughColorAttribute()
    /// 下划线
    public let underlineStyle: PoTextAttributesScopes.UnderlineStyleAttribute = UnderlineStyleAttribute()
    /// 下划线颜色
    public let underlineStyleColor: PoTextAttributesScopes.UnderlineColorAttribute = UnderlineColorAttribute()
    /// 连体字符，0:不生效，1:使用默认的连体字符。(只有某些字体才支持)
    public let ligature: PoTextAttributesScopes.LigatureAttribute = LigatureAttribute()
    /// 凸版印刷效果, NSAttributedString.TextEffectStyle.letterpressStyle /* PoLabel不支持 */
    public let textEffect: PoTextAttributesScopes.TextEffectAttribute = TextEffectAttribute()
    /// 基线偏移量(正数:向上偏移，负数:向下偏移)
    public let baselineOffset: PoTextAttributesScopes.BaselineOffsetAttribute = BaselineOffsetAttribute()
    /// 文字布局方向
    public let writingDirection: PoTextAttributesScopes.WritingDirectionAttribute = WritingDirectionAttribute()
    /// 文字倾斜(正数：右倾斜，负数：左倾斜) /* PoLabel不支持 */
    public let obliqueness: PoTextAttributesScopes.ObliquenessAttribute = ObliquenessAttribute()
    /// 字体的横向拉伸(正数：拉伸，负数：压缩) /* PoLabel不支持 */
    public let expansion: PoTextAttributesScopes.ExpansionAttribute = ExpansionAttribute()
    /// 设置文字排版方向，0表示横排文本，1表示竖排文本 在iOS中只支持0 /* PoLabel不支持 */
    public let verticalGlyphForm: PoTextAttributesScopes.VerticalGlyphFormAttribute = VerticalGlyphFormAttribute()
    /// 段落样式
    public let paragraphStyle: PoTextAttributesScopes.ParagraphStyleAttribute = ParagraphStyleAttribute()
    
    /* 自定义属性 */
    
    /// 文字边框
    public let textBorder: PoTextAttributesScopes.TextBorderAttribute = TextBorderAttribute()
    /// 文字块边框
    public let textBlockBorder: PoTextAttributesScopes.TextBlockBorderAttribute = TextBlockBorderAttribute()
    /// 高亮
    public let textHighlight: PoTextAttributesScopes.TextHighlightAttribute = TextHighlightAttribute()
        
    public struct FontAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = UIFont
        public static let name: NSAttributedString.Key = NSAttributedString.Key.font
    }
    
    public struct KernAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = CGFloat
        public static let name: NSAttributedString.Key = NSAttributedString.Key.kern
    }
    
    public struct ForegroundColorAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = UIColor
        public static let name: NSAttributedString.Key = NSAttributedString.Key.foregroundColor
    }
    
    public struct BackgroundColorAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = UIColor
        public static let name: NSAttributedString.Key = NSAttributedString.Key.backgroundColor
    }
    
    public struct StrokeWidthAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = CGFloat
        public static let name: NSAttributedString.Key = NSAttributedString.Key.strokeWidth
    }
    
    public struct StrokeColorAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = UIColor
        public static let name: NSAttributedString.Key = NSAttributedString.Key.strokeColor
    }
    
    public struct ShadowAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = NSShadow
        public static let name: NSAttributedString.Key = NSAttributedString.Key.shadow
    }
    
    public struct StrikethroughStyleAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = NSUnderlineStyle
        public static let name: NSAttributedString.Key = NSAttributedString.Key.strikethroughStyle
    }
    
    public struct StrikethroughColorAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = UIColor
        public static let name: NSAttributedString.Key = NSAttributedString.Key.strikethroughColor
    }
    
    public struct UnderlineStyleAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = NSUnderlineStyle
        public static let name: NSAttributedString.Key = NSAttributedString.Key.underlineStyle
    }
    
    public struct UnderlineColorAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = UIColor
        public static let name: NSAttributedString.Key = NSAttributedString.Key.underlineColor
    }
    
    public struct LigatureAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = Int
        public static let name: NSAttributedString.Key = NSAttributedString.Key.ligature
    }
    
    public struct TextEffectAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = NSAttributedString.TextEffectStyle
        public static let name: NSAttributedString.Key = NSAttributedString.Key.textEffect
    }
    
    public struct BaselineOffsetAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = CGFloat
        public static let name: NSAttributedString.Key = NSAttributedString.Key.baselineOffset
    }
    
    public struct WritingDirectionAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = [Int]
        public static let name: NSAttributedString.Key = NSAttributedString.Key.writingDirection
    }
        
    public struct ObliquenessAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = CGFloat
        public static let name: NSAttributedString.Key = NSAttributedString.Key.obliqueness
    }
    
    public struct ExpansionAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = CGFloat
        public static let name: NSAttributedString.Key = NSAttributedString.Key.expansion
    }
    
    public struct VerticalGlyphFormAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = Int
        public static let name: NSAttributedString.Key = NSAttributedString.Key.verticalGlyphForm
    }
    
    public struct ParagraphStyleAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = NSParagraphStyle
        public static let name: NSAttributedString.Key = NSAttributedString.Key.paragraphStyle
    }
    
    public struct TextBorderAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = TextBorder
        public static let name: NSAttributedString.Key = NSAttributedString.Key.poBorder
    }
    
    public struct TextBlockBorderAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = TextBorder
        public static let name: NSAttributedString.Key = NSAttributedString.Key.poBlockBorder
    }
    
    public struct TextHighlightAttribute: PoAttributedStringKey, Sendable {
        public typealias Value = TextHighlight
        public static let name: NSAttributedString.Key = NSAttributedString.Key.poHighlight
    }
    
}

extension NSUnderlineStyle: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

extension CGAffineTransform:  @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(a)
        hasher.combine(b)
        hasher.combine(c)
        hasher.combine(d)
        hasher.combine(tx)
        hasher.combine(ty)
    }
}
