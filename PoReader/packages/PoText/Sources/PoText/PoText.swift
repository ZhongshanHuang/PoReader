import UIKit

public struct PoTextActionContext {
    public let label: PoLabel
    public let text: NSAttributedString?
    public let range: NSRange

    public var selectedText: NSAttributedString? {
        guard let text,
              range.location != NSNotFound,
              range.location >= 0,
              range.length >= 0,
              range.location <= text.length,
              range.length <= text.length - range.location else {
            return nil
        }
        return text.attributedSubstring(from: range)
    }

    public var selectedString: String? {
        selectedText?.string
    }

    public init(label: PoLabel, text: NSAttributedString?, range: NSRange) {
        self.label = label
        self.text = text
        self.range = range
    }
}

public typealias PoTextAction = (PoTextActionContext) -> Void

public enum PoTextStyleMergePolicy: Sendable {
    case keepLocal
    case overrideLocal
}

public struct PoTextStyle: @unchecked Sendable {
    private var container: PoAttributeContainer

    /// The typed container backing this style.
    public var attributeContainer: PoAttributeContainer {
        container
    }

    public var attributes: [NSAttributedString.Key: Any] {
        container.attributes
    }

    public init() {
        container = PoAttributeContainer()
    }

    public init(font: UIFont, color: UIColor? = nil) {
        container = PoAttributeContainer()
        container.font = font
        if let color {
            container.foregroundColor = color
        }
    }

    public init(_ attributes: [NSAttributedString.Key: Any]) {
        container = PoAttributeContainer(attributes)
    }

    public init(_ container: PoAttributeContainer) {
        self.container = container
    }

    public init(attributeContainer: PoAttributeContainer) {
        self.container = attributeContainer
    }

    /// A dynamic-type body style using the system label color.
    public static var body: Self {
        Self(font: .preferredFont(forTextStyle: .body), color: .label)
    }

    /// A dynamic-type headline style using the system label color.
    public static var headline: Self {
        Self(font: .preferredFont(forTextStyle: .headline), color: .label)
    }

    /// A dynamic-type caption style using the system secondary label color.
    public static var caption: Self {
        Self(font: .preferredFont(forTextStyle: .caption1), color: .secondaryLabel)
    }

    public func addingAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Self {
        var new = self
        new.container.merge(PoAttributeContainer(attributes))
        return new
    }

    /// Returns a copy with attributes from another style taking precedence.
    public func adding(_ style: PoTextStyle) -> Self {
        addingAttributes(style.attributes)
    }

    /// Returns a copy without the supplied attribute key.
    public func removingAttribute(_ key: NSAttributedString.Key) -> Self {
        var new = self
        new.container = new.container.removingAttribute(key)
        return new
    }

    public func font(_ font: UIFont) -> Self {
        setting { $0.font = font }
    }

    public func color(_ color: UIColor) -> Self {
        foregroundColor(color)
    }

    public func foregroundColor(_ color: UIColor) -> Self {
        setting { $0.foregroundColor = color }
    }

    public func kern(_ kern: CGFloat) -> Self {
        setting { $0.kern = kern }
    }

    public func underline(_ style: NSUnderlineStyle = .single, color: UIColor? = nil) -> Self {
        setting {
            $0.underlineStyle = style
            if let color {
                $0.underlineStyleColor = color
            }
        }
    }

    public func strikethrough(_ style: NSUnderlineStyle = .single, color: UIColor? = nil) -> Self {
        setting {
            $0.strikethroughStyle = style
            if let color {
                $0.strikethroughColor = color
            }
        }
    }

    public func baselineOffset(_ offset: CGFloat) -> Self {
        setting { $0.baselineOffset = offset }
    }

    public func shadow(_ shadow: NSShadow) -> Self {
        setting { $0.shadow = shadow }
    }

    public func paragraphStyle(_ paragraphStyle: NSParagraphStyle) -> Self {
        setting { $0.paragraphStyle = paragraphStyle }
    }

    public func lineSpacing(_ spacing: CGFloat) -> Self {
        settingParagraphStyle { $0.lineSpacing = spacing }
    }

    public func alignment(_ alignment: NSTextAlignment) -> Self {
        settingParagraphStyle { $0.alignment = alignment }
    }

    public func lineBreak(_ mode: NSLineBreakMode) -> Self {
        settingParagraphStyle { $0.lineBreakMode = mode }
    }

    public func stroke(width: CGFloat?, color: UIColor? = nil) -> Self {
        setting {
            $0.strokeWidth = width
            if let color {
                $0.strokeColor = color
            }
        }
    }

    public func textBorder(_ border: TextBorder) -> Self {
        setting { $0.textBorder = border }
    }

    public func textBlockBorder(_ border: TextBorder) -> Self {
        setting { $0.textBlockBorder = border }
    }

    private func setting(_ update: (inout PoAttributeContainer) -> Void) -> Self {
        var new = self
        update(&new.container)
        return new
    }

    private func settingParagraphStyle(_ update: (NSMutableParagraphStyle) -> Void) -> Self {
        var new = self
        let paragraphStyle = (new.container.paragraphStyle?.mutableCopy() as? NSMutableParagraphStyle)
            ?? (NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        update(paragraphStyle)
        new.container.paragraphStyle = paragraphStyle
        return new
    }
}

public struct PoText: @unchecked Sendable, CustomStringConvertible {
    private let storage: NSMutableAttributedString

    public var attributedString: NSAttributedString {
        storage.copy() as? NSAttributedString ?? NSAttributedString()
    }

    /// Bridges to Swift's native ``AttributedString``.
    public var swiftAttributedString: AttributedString {
        AttributedString(attributedString)
    }

    /// The plain string represented by this value.
    public var string: String { storage.string }

    /// The UTF-16 length used by Foundation ranges.
    public var length: Int { storage.length }

    public var description: String { string }

    public var mutableAttributedString: NSMutableAttributedString {
        NSMutableAttributedString(attributedString: storage)
    }

    public init(_ string: String, attributes: [NSAttributedString.Key: Any]? = nil) {
        storage = NSMutableAttributedString(string: string, attributes: attributes)
    }

    /// Creates an unstyled rich-text value from a string.
    public init(string: String) {
        self.init(string)
    }

    /// Creates a rich-text value from a string and Foundation attributes.
    public init(string: String, attributes: [NSAttributedString.Key: Any]? = nil) {
        storage = NSMutableAttributedString(string: string, attributes: attributes)
    }

    public init(_ attributedString: NSAttributedString) {
        storage = NSMutableAttributedString(attributedString: attributedString)
    }

    /// Creates a rich-text value from an attributed string.
    public init(attributedString: NSAttributedString) {
        self.init(attributedString)
    }

    /// Creates a rich-text value from Swift's native ``AttributedString``.
    public init(_ attributedString: AttributedString) {
        self.init(NSAttributedString(attributedString))
    }

    public init(style: PoTextStyle,
                mergePolicy: PoTextStyleMergePolicy = .keepLocal,
                @PoTextBuilder _ builder: () -> NSAttributedString) {
        storage = NSMutableAttributedString(attributedString: builder())
        storage.po_applyStyle(style, mergePolicy: mergePolicy)
    }

    public init(_ string: String, style: PoTextStyle) {
        storage = NSMutableAttributedString(string: string)
        storage.po.addAttributes(style.attributes)
    }

    /// Creates a rich-text value from a string and reusable style.
    public init(string: String,
                style: PoTextStyle,
                mergePolicy: PoTextStyleMergePolicy = .keepLocal) {
        storage = NSMutableAttributedString(string: string)
        storage.po_applyStyle(style, mergePolicy: mergePolicy)
    }

    private init(storage: NSMutableAttributedString) {
        self.storage = storage
    }

    public func style(_ style: PoTextStyle) -> Self {
        attributes(style.attributes)
    }

    public func attributeContainer(_ container: PoAttributeContainer) -> Self {
        attributes(container.attributes)
    }

    public func attributes(_ attributes: [NSAttributedString.Key: Any]) -> Self {
        applying { $0.po.addAttributes(attributes) }
    }

    public func attributes(_ container: PoAttributeContainer) -> Self {
        attributes(container.attributes)
    }

    /// Returns a copy with the supplied attributes taking precedence.
    public func addingAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Self {
        self.attributes(attributes)
    }

    /// Returns a copy without the supplied attribute key.
    public func removingAttribute(_ key: NSAttributedString.Key) -> Self {
        applying { $0.po.addAttribute(key, value: nil) }
    }

    /// Returns a copy with a string appended without inheriting discontinuous
    /// interaction attributes from the preceding fragment.
    public func appending(_ string: String) -> Self {
        applying { text in
            let insertionRange = NSRange(location: text.length, length: string.utf16.count)
            text.replaceCharacters(in: NSRange(location: text.length, length: 0), with: string)
            if insertionRange.length > 0 {
                text.po.removeDiscontinuousAttributes(in: insertionRange)
            }
        }
    }

    /// Returns a copy with another rich-text fragment appended.
    public func appending(_ text: PoText) -> Self {
        appending(text.attributedString)
    }

    /// Returns a copy with an attributed string appended.
    public func appending(_ attributedString: NSAttributedString) -> Self {
        applying { text in
            text.append(attributedString)
        }
    }

    public func font(_ font: UIFont?) -> Self {
        applying { $0.po.font = font }
    }

    public func color(_ color: UIColor?) -> Self {
        foregroundColor(color)
    }

    public func foregroundColor(_ color: UIColor?) -> Self {
        applying { $0.po.foregroundColor = color }
    }

    public func kern(_ kern: CGFloat?) -> Self {
        applying { $0.po.kern = kern }
    }

    public func underline(_ style: NSUnderlineStyle = .single, color: UIColor? = nil) -> Self {
        applying {
            $0.po.underlineStyle = style
            if let color {
                $0.po.underlineColor = color
            }
        }
    }

    public func strikethrough(_ style: NSUnderlineStyle = .single, color: UIColor? = nil) -> Self {
        applying {
            $0.po.strikethroughStyle = style
            if let color {
                $0.po.strikethroughColor = color
            }
        }
    }

    public func stroke(width: CGFloat?, color: UIColor? = nil) -> Self {
        applying {
            $0.po.strokeWidth = width
            if let color {
                $0.po.strokeColor = color
            }
        }
    }

    public func shadow(_ shadow: NSShadow?) -> Self {
        applying { $0.po.shadow = shadow }
    }

    public func shadow(color: UIColor, offset: CGSize = .zero, blur: CGFloat = 0) -> Self {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowOffset = offset
        shadow.shadowBlurRadius = blur
        return self.shadow(shadow)
    }

    public func baselineOffset(_ offset: CGFloat?) -> Self {
        applying { $0.po.baselineOffset = offset }
    }

    public func paragraphStyle(_ paragraphStyle: NSParagraphStyle?) -> Self {
        applying { $0.po.paragraphStyle = paragraphStyle }
    }

    public func lineSpacing(_ spacing: CGFloat) -> Self {
        applying { $0.po.lineSpacing = spacing }
    }

    public func alignment(_ alignment: NSTextAlignment) -> Self {
        applying { $0.po.alignment = alignment }
    }

    public func lineBreak(_ mode: NSLineBreakMode) -> Self {
        applying { $0.po.lineBreakMode = mode }
    }

    public func textBorder(_ border: TextBorder?) -> Self {
        applying { $0.po.textBorder = border }
    }

    public func textBlockBorder(_ border: TextBorder?) -> Self {
        applying { $0.po.textBlockBorder = border }
    }

    public func fill(_ color: UIColor,
                     cornerRadius: CGFloat = 3,
                     insets: UIEdgeInsets = UIEdgeInsets(top: -2, left: -2, bottom: -2, right: -2),
                     shadow: TextShadow? = nil) -> Self {
        textBorder(TextBorder(fillColor: color,
                              cornerRadius: cornerRadius,
                              insets: insets,
                              shadow: shadow))
    }

    public func highlight(_ highlight: TextHighlight?) -> Self {
        applying { text in
            text.po.setTextHighlight(nil, range: text.allRange)
            text.po.setTextHighlight(highlight, range: text.allRange)
        }
    }

    public func onTap(highlightForegroundColor: UIColor? = nil,
                      highlightBackgroundColor: UIColor? = nil,
                      action: @escaping PoTextAction) -> Self {
        updatingHighlight(foregroundColor: highlightForegroundColor,
                          backgroundColor: highlightBackgroundColor) { highlight in
            highlight.tapAction = { label, text, range in
                action(PoTextActionContext(label: label, text: text, range: range))
            }
        }
    }

    public func onLongPress(highlightForegroundColor: UIColor? = nil,
                            highlightBackgroundColor: UIColor? = nil,
                            action: @escaping PoTextAction) -> Self {
        updatingHighlight(foregroundColor: highlightForegroundColor,
                          backgroundColor: highlightBackgroundColor) { highlight in
            highlight.longPressAction = { label, text, range in
                action(PoTextActionContext(label: label, text: text, range: range))
            }
        }
    }

    public static func link(_ string: String,
                            color: UIColor = .systemBlue,
                            isUnderlined: Bool = false,
                            highlightColor: UIColor? = nil,
                            action: @escaping PoTextAction) -> PoText {
        var text = PoText(string)
            .foregroundColor(color)
            .onTap(highlightBackgroundColor: highlightColor ?? color.withAlphaComponent(0.12),
                   action: action)
        if isUnderlined {
            text = text.underline(color: color)
        }
        return text
    }

    public static func attachment(_ content: TextAttachment.Content,
                                  size: CGSize? = nil,
                                  alignToFont font: UIFont = .systemFont(ofSize: 17),
                                  contentInsets: UIEdgeInsets = .zero,
                                  verticalAlignment: TextVerticalAlignment = .center,
                                  contentMode: UIView.ContentMode = .scaleAspectFit) -> PoText {
        PoText(NSAttributedString.po.attachmentString(with: content,
                                                      size: size,
                                                      alignToFont: font,
                                                      contentInsets: contentInsets,
                                                      verticalAlignment: verticalAlignment,
                                                      contentMode: contentMode))
    }

    public static func attachment(_ image: UIImage,
                                  size: CGSize? = nil,
                                  alignToFont font: UIFont = .systemFont(ofSize: 17),
                                  contentInsets: UIEdgeInsets = .zero,
                                  verticalAlignment: TextVerticalAlignment = .center,
                                  contentMode: UIView.ContentMode = .scaleAspectFit) -> PoText {
        attachment(.image(image),
                   size: size,
                   alignToFont: font,
                   contentInsets: contentInsets,
                   verticalAlignment: verticalAlignment,
                   contentMode: contentMode)
    }

    public static func attachment(_ view: UIView,
                                  size: CGSize? = nil,
                                  alignToFont font: UIFont = .systemFont(ofSize: 17),
                                  contentInsets: UIEdgeInsets = .zero,
                                  verticalAlignment: TextVerticalAlignment = .center,
                                  contentMode: UIView.ContentMode = .scaleAspectFit) -> PoText {
        attachment(.view(view),
                   size: size,
                   alignToFont: font,
                   contentInsets: contentInsets,
                   verticalAlignment: verticalAlignment,
                   contentMode: contentMode)
    }

    public static func attachment(_ layer: CALayer,
                                  size: CGSize? = nil,
                                  alignToFont font: UIFont = .systemFont(ofSize: 17),
                                  contentInsets: UIEdgeInsets = .zero,
                                  verticalAlignment: TextVerticalAlignment = .center,
                                  contentMode: UIView.ContentMode = .scaleAspectFit) -> PoText {
        attachment(.layer(layer),
                   size: size,
                   alignToFont: font,
                   contentInsets: contentInsets,
                   verticalAlignment: verticalAlignment,
                   contentMode: contentMode)
    }

    public static func tag(_ string: String,
                           font: UIFont = .systemFont(ofSize: 12),
                           color: UIColor = .label,
                           fillColor: UIColor = .systemYellow,
                           cornerRadius: CGFloat = 3,
                           insets: UIEdgeInsets = UIEdgeInsets(top: -2, left: -4, bottom: -2, right: -4)) -> PoText {
        PoText(string)
            .font(font)
            .foregroundColor(color)
            .fill(fillColor, cornerRadius: cornerRadius, insets: insets)
    }

    private func applying(_ update: (NSMutableAttributedString) -> Void) -> Self {
        let newStorage = NSMutableAttributedString(attributedString: storage)
        update(newStorage)
        return Self(storage: newStorage)
    }

    private func updatingHighlight(foregroundColor: UIColor?,
                                   backgroundColor: UIColor?,
                                   update: (inout TextHighlight) -> Void) -> Self {
        applying { text in
            let current = text.po.textHighlight
            var highlight = TextHighlight(attributes: current?.attributes ?? [:])
            highlight.tapAction = current?.tapAction
            highlight.longPressAction = current?.longPressAction
            if let foregroundColor {
                highlight.foregroundColor = foregroundColor
            }
            if let backgroundColor {
                highlight.border = Self.highlightBorder(fillColor: backgroundColor)
            }
            update(&highlight)
            text.po.setTextHighlight(nil, range: text.allRange)
            text.po.setTextHighlight(highlight, range: text.allRange)
        }
    }

    private static func highlightBorder(fillColor: UIColor) -> TextBorder {
        TextBorder(fillColor: fillColor,
                   cornerRadius: 3,
                   insets: UIEdgeInsets(top: -2, left: -1, bottom: -2, right: -1))
    }
}

extension PoText: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension PoAttributedString: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension NameSpaceWrapper where Base == String {
    public var text: PoText {
        PoText(base)
    }
}
