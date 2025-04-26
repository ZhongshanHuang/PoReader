import UIKit

extension NSAttributedString.Key {
    
    public static let poBackedString     = NSAttributedString.Key(rawValue: "PoTextBackedString")
    public static let poBorder           = NSAttributedString.Key(rawValue: "PoTextBorder")
    public static let poBlockBorder      = NSAttributedString.Key(rawValue: "PoTextBlockBorder")
    public static let poHighlight        = NSAttributedString.Key(rawValue: "PoTextHighlight")
    
    public static let allDiscontinuousAttributeKeys: [NSAttributedString.Key] = [.poBackedString]
}

// MARK: - TextLineStyle

public struct TextLineStyle : OptionSet, Hashable, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    // basic style (bitmask: 0xFF)
    public static let styleMask: TextLineStyle = TextLineStyle(rawValue: 0xFF)
    public static let single: TextLineStyle = TextLineStyle(rawValue: 0x01) //(──────)
    public static let thick: TextLineStyle = TextLineStyle(rawValue: 0x02)  //(━━━━━━)
    public static let double: TextLineStyle = TextLineStyle(rawValue: 0x09) //(══════)
    
    // style pattern (bitmask: 0xF00) must work with (single|double|thick) together
    public static let patternMask = TextLineStyle(rawValue: 0xF00)
    public static let patternDot = TextLineStyle(rawValue: 0x100)           //(‑ ‑ ‑ ‑ ‑)
    public static let patternDash = TextLineStyle(rawValue: 0x200)          //(— — — — —)
    public static let patternDashDot = TextLineStyle(rawValue: 0x300)       //(— ‑ — ‑ —)
    public static let patternDashDotDot = TextLineStyle(rawValue: 0x400)    //(— ‑ ‑ — ‑)
    public static let patternCircleDot = TextLineStyle(rawValue: 0x900)     //(•••••••••)
}


// MARK: - TextLineDecoration

/// 装饰线条的样式
public struct TextLineDecoration: Hashable, Sendable {
    public let style: TextLineStyle
    public let width: CGFloat
    public let color: UIColor
    public let shadow: TextShadow?
    
    public init(style: TextLineStyle = .single, width: CGFloat = 1, color: UIColor = .black, shadow: TextShadow? = nil) {
        self.style = style
        self.width = width
        self.color = color
        self.shadow = shadow
    }
}

// MARK: - TextBorder

public struct TextBorder: Hashable, Sendable {
    public var lineStyle: TextLineStyle = .single
    public var strokeWidth: CGFloat = 0
    public var strokeColor: UIColor?
    public var lineJoin: CGLineJoin = .miter
    public var fillColor: UIColor?
    public var insets: UIEdgeInsets = .zero
    public var cornerRadius: CGFloat = 0
    public var shadow: TextShadow?
    
    public init(lineStyle: TextLineStyle = .single, 
                lineWidth: CGFloat,
                strokeColor: UIColor,
                lineJoin: CGLineJoin = .miter,
                cornerRadius: CGFloat = 0,
                insets: UIEdgeInsets = .zero,
                shadow: TextShadow? = nil) {
        self.lineStyle = lineStyle
        self.strokeWidth = lineWidth
        self.strokeColor = strokeColor
        self.lineJoin = lineJoin
        self.cornerRadius = cornerRadius
        self.insets = insets
        self.shadow = shadow
    }
    
    public init(fillColor: UIColor,
                cornerRadius: CGFloat = 0,
                insets: UIEdgeInsets = UIEdgeInsets(top: -2, left: 0, bottom: 0, right: -2),
                shadow: TextShadow? = nil) {
        self.fillColor = fillColor
        self.cornerRadius = cornerRadius
        self.insets = insets
        self.shadow = shadow
    }
    
    public init(lineStyle: TextLineStyle = .single, 
                lineWidth: CGFloat,
                strokeColor: UIColor,
                lineJoin: CGLineJoin = .miter,
                fillColor: UIColor,
                cornerRadius: CGFloat = 0, insets: UIEdgeInsets = .zero, shadow: TextShadow? = nil) {
        self.lineStyle = lineStyle
        self.strokeWidth = lineWidth
        self.strokeColor = strokeColor
        self.lineJoin = lineJoin
        self.fillColor = fillColor
        self.cornerRadius = cornerRadius
        self.insets = insets
        self.shadow = shadow
    }
    
}

extension UIEdgeInsets: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(top)
        hasher.combine(left)
        hasher.combine(bottom)
        hasher.combine(right)
    }
}

// MARK: - TextShadow

public struct TextShadow: Hashable, Sendable {
    public let color: UIColor
    public let offset: CGSize
    public let blur: CGFloat
    public let blendMode: CGBlendMode
    
    public var nsShadow: NSShadow {
        let shadow = NSShadow()
        shadow.shadowOffset = offset
        shadow.shadowBlurRadius = blur
        shadow.shadowColor = color
        return shadow
    }
    
    public init(color: UIColor = UIColor(white: 0, alpha: 0.333333), offset: CGSize = .zero, blur: CGFloat = 0, blendMode: CGBlendMode = .normal) {
        self.color = color
        self.offset = offset
        self.blur = blur
        self.blendMode = blendMode
    }
    
    public init(nsShadow: NSShadow) {
        self.offset = nsShadow.shadowOffset
        self.blur = nsShadow.shadowBlurRadius
        if let shadowColor = nsShadow.shadowColor {
            if shadowColor is UIColor {
                self.color = (shadowColor as! UIColor)
            } else if CFGetTypeID(shadowColor as CFTypeRef) == CGColor.typeID {
                self.color = UIColor(cgColor: shadowColor as! CGColor)
            } else {
                self.color = UIColor(white: 0, alpha: 0.333333)
            }
        } else {
            self.color = UIColor(white: 0, alpha: 0.333333)
        }
        self.blendMode = .normal
    }
    
}

// MARK: - TextHighlight

public struct TextHighlight: Hashable, @unchecked Sendable {
    private let uuid: String = UUID().uuidString
    public private(set) var attributes: [NSAttributedString.Key: Any] = [:]
    public var tapAction: TextAction?
    public var longPressAction: TextAction?
    
    public var font: UIFont? {
        get { attributes[.font] as? UIFont }
        set { setAttribute(.font, value: newValue) }
    }
    
    public var foregroundColor: UIColor? {
        get { attributes[.foregroundColor] as? UIColor }
        set { setAttribute(.foregroundColor, value: newValue) }
    }
    
    public var strokeWidth: CGFloat? {
        get { attributes[.strokeWidth] as? CGFloat }
        set { setAttribute(.strokeWidth, value: newValue) }
    }
    
    public var strokeColor: UIColor? {
        get { attributes[.strokeColor] as? UIColor }
        set { setAttribute(.strokeColor, value: newValue) }
    }
    
    public var shadow: NSShadow? {
        get { attributes[.shadow] as? NSShadow }
        set { setAttribute(.shadow, value: newValue) }
    }
    
    public var border: TextBorder? {
        get { attributes[.poBorder] as? TextBorder }
        set { setAttribute(.poBorder, value: newValue) }
    }
    
    private mutating func setAttribute(_ name: NSAttributedString.Key, value: Any?) {
        attributes[name] = value
    }
    
    public init() {}
    
    public init(foregroundColor: UIColor, tapAction: @escaping TextAction) {
        self.foregroundColor = foregroundColor
        self.tapAction = tapAction
    }
    
    public init(backgroundColor: UIColor, tapAction: @escaping TextAction) {
        let highlightBorder = TextBorder(fillColor: backgroundColor,
                                         cornerRadius: 3,
                                         insets: UIEdgeInsets(top: -2, left: -1, bottom: -2, right: -1))
        self.border = highlightBorder
        self.tapAction = tapAction
    }
    
    public init(attributes: [NSAttributedString.Key: Any], tapAction: @escaping TextAction) {
        self.attributes = attributes
        self.tapAction = tapAction
    }
    
    public init(attributes: [NSAttributedString.Key: Any], longPressAction: @escaping TextAction) {
        self.attributes = attributes
        self.longPressAction = longPressAction
    }
    
    public static func == (lhs: TextHighlight, rhs: TextHighlight) -> Bool {
        lhs.uuid == rhs.uuid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

}


// MARK: - TextBackedString

public struct TextBackedString: RawRepresentable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/**
 The tap/long press action callback
 
 @param containerView The text container view).
 @param text          The whole text.
 @param range         The text range in `text` (if no range, the range.location is NSNotFound).
 @param rect          The text frame in `containerView` (if no data, the rect is CGRectNull).
 */
public typealias TextAction = (_ containerView: PoLabel, _ text: NSAttributedString?, _ range: NSRange) -> Void


// MARK: - TextVerticalAlignment

public enum TextVerticalAlignment: Sendable {
    case top
    case center
    case bottom
}

public struct TextToken: RawRepresentable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

//    public static let attachment: TextToken = TextToken(rawValue: String(UnicodeScalar(0xFFFC)!)) // 空白占位符,16进制
    public static let truncation: TextToken = TextToken(rawValue: String(unicodeScalarLiteral: "\u{2026}")) // 省略号… ，16进制
}

