import UIKit

extension NSAttributedString: NameSpaceCompatible {}

extension NameSpaceWrapper where Base: NSAttributedString {
    
    /* ======================================================================= */
    
    public var attributes: Dictionary<NSAttributedString.Key, Any>? {
        return attributes(at: 0)
    }
    
    public func attributes(at index: Int) -> Dictionary<NSAttributedString.Key, Any>? {
        if base.length == 0 || index >= base.length { return nil }
        return base.attributes(at: index, effectiveRange: nil)
    }
    
    public func attribute(_ attrName: NSAttributedString.Key, at index: Int) -> Any? {
        if base.length == 0 || index >= base.length { return nil }
        return base.attribute(attrName, at: index, effectiveRange: nil)
    }
    
    /* ======================================================================= */
    
    // MARK: - font
    public var font: UIFont? {
        return font(at: 0)
    }
    
    public func font(at index: Int) -> UIFont? {
        return attribute(.font, at: index) as? UIFont
    }
    
    // MARK: - kern
    public var kern: CGFloat {
        return kern(at: 0)
    }
    
    public func kern(at index: Int) -> CGFloat {
        return (attribute(.kern, at: index) as? CGFloat) ?? 0
    }
    
    // MARK: - foregroundColor
    public var foregroundColor: UIColor? {
        return foregroundColor(at: 0)
    }
    
    public func foregroundColor(at index: Int) -> UIColor? {
        return attribute(.foregroundColor, at: index) as? UIColor
    }
    
    // MARK: - backgroundColor
    public var backgroundColor: UIColor? {
        return backgroundColor(at: 0)
    }
    
    public func backgroundColor(at index: Int) -> UIColor? {
        return attribute(.backgroundColor, at: index) as? UIColor
    }
    
    // MARK: - strokeWidth
    public var strokeWidth: CGFloat {
        return strokeWidth(at: 0)
    }
    
    public func strokeWidth(at index: Int) -> CGFloat {
        return (attribute(.strokeWidth, at: index) as? CGFloat) ?? 0
    }
    
    // MARK: - strokeColor
    public var strokeColor: UIColor? {
        return strokeColor(at: 0)
    }
    
    public func strokeColor(at index: Int) -> UIColor? {
        return attribute(.strokeColor, at: index) as? UIColor
    }
    
    // MARK: - shadow
    public var shadow: NSShadow? {
        return shadow(at: 0)
    }
    
    public func shadow(at index: Int) -> NSShadow? {
        return attribute(.shadow, at: index) as? NSShadow
    }
    
    // MARK: - strikethroughStyle
    public var strikethroughStyle: NSUnderlineStyle? {
        return strikethroughStyle(at: 0)
    }
    
    public func strikethroughStyle(at index: Int) -> NSUnderlineStyle? {
        if let rawValue = attribute(.strikethroughStyle, at: index) as? Int {
            return NSUnderlineStyle(rawValue: rawValue)
        }
        return nil
    }
    
    // MARK: - strikethroughColor
    public var strikethroughColor: UIColor? {
        return strikethroughColor(at: 0)
    }
    
    public func strikethroughColor(at index: Int) -> UIColor? {
        return attribute(.strikethroughColor, at: index) as? UIColor
    }
    
    // MARK: - underlineStyle
    public var underlineStyle: NSUnderlineStyle? {
        return underlineStyle(at: 0)
    }
    
    public func underlineStyle(at index: Int) -> NSUnderlineStyle? {
        if let rawValue =  attribute(.underlineStyle, at: index) as? Int {
            return NSUnderlineStyle(rawValue: rawValue)
        }
        return nil
    }
    
    // MARK: - underlineColor
    public var underlineColor: UIColor? {
        return underlineColor(at: 0)
    }
    
    public func underlineColor(at index: Int) -> UIColor? {
        return attribute(.underlineColor, at: index) as? UIColor
    }
    
    // MARK: - ligature
    public var ligature: Int {
        return ligature(at: 0)
    }
    
    public func ligature(at index: Int) -> Int {
        return (attribute(.ligature, at: index) as? Int) ?? 1
    }
    
    // MARK: - textEffect - 文字效果
    public var textEffect: NSAttributedString.TextEffectStyle? {
        return textEffect(at: 0)
    }
    
    public func textEffect(at index: Int) -> NSAttributedString.TextEffectStyle? {
        return attribute(.textEffect, at: index) as? NSAttributedString.TextEffectStyle
    }
    
    // MAKR: - obliqueness - 倾斜度
    public var obliqueness: CGFloat {
        return obliqueness(at: 0)
    }
    
    public func obliqueness(at index: Int) -> CGFloat {
        return (attribute(.obliqueness, at: index) as? CGFloat) ?? 0
    }
    
    // MARK: - expansion - 横向拉伸
    public var expansion: CGFloat {
        return expansion(at: 0)
    }
    
    public func expansion(at index: Int) -> CGFloat {
        return (attribute(.expansion, at: index) as? CGFloat) ?? 0
    }
    
    // MAKR: - baselineOffset
    public var baselineOffset: CGFloat {
        return baselineOffset(at: 0)
    }
    
    public func baselineOffset(at index: Int) -> CGFloat {
        return (attribute(.baselineOffset, at: index) as? CGFloat) ?? 0
    }
    
    // MARK: - verticalGlyphForm - ios 无效
    public var verticalGlyphForm: Int {
        return verticalGlyphForm(at: 0)
    }
    
    public func verticalGlyphForm(at index: Int) -> Int {
        return (attribute(.verticalGlyphForm, at: index) as? Int) ?? 0
    }
    
    // MARK: - writingDirection
    public var writingDirection: [Int]? {
        return writingDirection(at: 0)
    }
    
    public func writingDirection(at index: Int) -> [Int]? {
        return attribute(.writingDirection, at: index) as? [Int]
    }
    
    // MARK: - paragraphStyle
    public var paragraphStyle: NSParagraphStyle? {
        return paragraphStyle(at: 0)
    }
    
    public func paragraphStyle(at index: Int) -> NSParagraphStyle? {
        return attribute(.paragraphStyle, at: index) as? NSParagraphStyle
    }
    
    // MARK: - alignment
    public var alignment: NSTextAlignment {
        if let style = paragraphStyle {
            return style.alignment
        }
        return NSParagraphStyle.default.alignment
    }
    
    public func alignment(at index: Int) -> NSTextAlignment {
        if let style = paragraphStyle(at: index) {
            return style.alignment
        }
        return NSParagraphStyle.default.alignment
    }
    
    // MARK: - lineBreakMode
    public var lineBreakMode: NSLineBreakMode {
        if let style = paragraphStyle {
            return style.lineBreakMode
        }
        return NSParagraphStyle.default.lineBreakMode
    }
    
    public func lineBreakMode(at index: Int) -> NSLineBreakMode {
        if let style = paragraphStyle(at: index) {
            return style.lineBreakMode
        }
        return NSParagraphStyle.default.lineBreakMode
    }
    
    // MARK: - lineSpacing
    public var lineSpacing: CGFloat {
        if let style = paragraphStyle {
            return style.lineSpacing
        }
        return NSParagraphStyle.default.lineSpacing
    }
    
    public func lineSpacing(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.lineSpacing
        }
        return NSParagraphStyle.default.lineSpacing
    }
    
    // MARK: - paragraphSpacing
    public var paragraphSpacing: CGFloat {
        if let style = paragraphStyle {
            return style.paragraphSpacing
        }
        return NSParagraphStyle.default.paragraphSpacing
    }
    
    public func paragraphSpacing(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.paragraphSpacing
        }
        return NSParagraphStyle.default.paragraphSpacing
    }
    
    // MARK: - paragraphSpacingBefore
    public var paragraphSpacingBefore: CGFloat {
        if let style = paragraphStyle {
            return style.paragraphSpacingBefore
        }
        return NSParagraphStyle.default.paragraphSpacingBefore
    }
    
    public func paragraphSpacingBefore(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.paragraphSpacingBefore
        }
        return NSParagraphStyle.default.paragraphSpacingBefore
    }
    
    // MARK: - firstLineHeadIndent
    public var firstLineHeadIndent: CGFloat {
        if let style = paragraphStyle {
            return style.firstLineHeadIndent
        }
        return NSParagraphStyle.default.firstLineHeadIndent
    }
    
    public func firstLineHeadIndent(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.firstLineHeadIndent
        }
        return NSParagraphStyle.default.firstLineHeadIndent
    }
    
    // MARK: - headIndent
    public var headIndent: CGFloat {
        if let style = paragraphStyle {
            return style.headIndent
        }
        return NSParagraphStyle.default.headIndent
    }
    
    public func headIndent(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.headIndent
        }
        return NSParagraphStyle.default.headIndent
    }
    
    // MARK: - tailIndent
    public var tailIndent: CGFloat {
        if let style = paragraphStyle {
            return style.tailIndent
        }
        return NSParagraphStyle.default.tailIndent
    }
    
    public func tailIndent(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.tailIndent
        }
        return NSParagraphStyle.default.tailIndent
    }
    
    // MARK: - minimumLineHeight
    public var minimumLineHeight: CGFloat {
        if let style = paragraphStyle {
            return style.minimumLineHeight
        }
        return NSParagraphStyle.default.minimumLineHeight
    }
    
    public func minimumLineHeight(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.minimumLineHeight
        }
        return NSParagraphStyle.default.minimumLineHeight
    }
    
    // MARK: - maximumLineHeight
    public var maximumLineHeight: CGFloat {
        if let style = paragraphStyle {
            return style.maximumLineHeight
        }
        return NSParagraphStyle.default.maximumLineHeight
    }
    
    public func maximumLineHeight(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.maximumLineHeight
        }
        return NSParagraphStyle.default.maximumLineHeight
    }
    
    // MARK: - lineHeightMultiple
    public var lineHeightMultiple: CGFloat {
        if let style = paragraphStyle {
            return style.lineHeightMultiple
        }
        return NSParagraphStyle.default.lineHeightMultiple
    }
    
    public func lineHeightMultiple(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.lineHeightMultiple
        }
        return NSParagraphStyle.default.lineHeightMultiple
    }
    
    // MARK: - baseWritingDirection
    public var baseWritingDirection: NSWritingDirection {
        if let style = paragraphStyle {
            return style.baseWritingDirection
        }
        return NSParagraphStyle.default.baseWritingDirection
    }
    
    public func baseWritingDirection(at index: Int) -> NSWritingDirection {
        if let style = paragraphStyle(at: index) {
            return style.baseWritingDirection
        }
        return NSParagraphStyle.default.baseWritingDirection
    }
    
    // MARK: - hyphenationFactor
    public var hyphenationFactor: Float { // 断字 - ct没有
        if let style = paragraphStyle {
            return style.hyphenationFactor
        }
        return NSParagraphStyle.default.hyphenationFactor
    }
    
    public func hyphenationFactor(at index: Int) -> Float {
        if let style = paragraphStyle(at: index) {
            return style.hyphenationFactor
        }
        return NSParagraphStyle.default.hyphenationFactor
    }
    
    // MARK: - defaultTabInterval
    public var defaultTabInterval: CGFloat {
        if let style = paragraphStyle {
            return style.defaultTabInterval
        }
        return NSParagraphStyle.default.defaultTabInterval
    }
    
    public func defaultTabInterval(at index: Int) -> CGFloat {
        if let style = paragraphStyle(at: index) {
            return style.defaultTabInterval
        }
        return NSParagraphStyle.default.defaultTabInterval
    }
    
    // MARK: - tabStops
    public var tabStops: [NSTextTab] {
        if let style = paragraphStyle {
            return style.tabStops
        }
        return NSParagraphStyle.default.tabStops
    }
    
    public func tabStops(at index: Int) -> [NSTextTab] {
        if let style = paragraphStyle(at: index) {
            return style.tabStops
        }
        return NSParagraphStyle.default.tabStops
    }
    
    // MARK: - textHighlight
    public var textHighlight: TextHighlight? {
        return textHighlight(at: 0)
    }
    
    public func textHighlight(at index: Int) -> TextHighlight? {
        return attribute(.poHighlight, at: index) as? TextHighlight
    }
    
    // MARK: - textBorder
    public var textBorder: TextBorder? {
        return textBorder(at: 0)
    }
    
    public func textBorder(at index: Int) -> TextBorder? {
        return attribute(.poBorder, at: index) as? TextBorder
    }
    
    // MARK: - textBlockBorder
    public var textBlockBorder: TextBorder? {
        return textBlockBorder(at: 0)
    }
    
    public func textBlockBorder(at index: Int) -> TextBorder? {
        return attribute(.poBlockBorder, at: index) as? TextBorder
    }
    
    // MARK: - Help methods
    
    public func plainText(for range: NSRange) -> String? {
        if range.location == NSNotFound || range.length == NSNotFound { return nil }
        var result = ""
        if range.length == 0 { return result }
        
        let string = (base.string as NSString)
        base.enumerateAttribute(.poBackedString, in: range, options: []) { (value, range, _) in
            if let backed = value as? TextBackedString {
                result.append(backed.rawValue)
            } else {
                result.append(string.substring(with: range))
            }
        }
        return result
    }
    
    public static func attachmentString(with content: TextAttachment.Content, size: CGSize? = nil, alignToFont: UIFont, verticalAlignment: TextVerticalAlignment) -> NSAttributedString {
        let contentMode: UIView.ContentMode
        switch verticalAlignment {
        case .top:
            contentMode = .top
        case .center:
            contentMode = .center
        case .bottom:
            contentMode = .bottom
        }
        return attachmentString(with: content, size: size, alignToFont: alignToFont, contentInsets: .zero, verticalAlignment: verticalAlignment, contentMode: contentMode)
    }
    
    public static func attachmentString(with content: TextAttachment.Content, size: CGSize? = nil, alignToFont: UIFont, contentInsets: UIEdgeInsets, verticalAlignment: TextVerticalAlignment, contentMode: UIView.ContentMode) -> NSAttributedString {
        let attachment = TextAttachment(content: content, size: size, alignToFont: alignToFont, contentInsets: contentInsets, verticalAlignment: verticalAlignment, contentMode: contentMode)
        return NSAttributedString(attachment: attachment)
    }
    
}

extension NameSpaceWrapper where Base: NSMutableAttributedString {
    
    /* ======================================================================= */
    
    public func configure(_ make: (_ make: NameSpaceWrapper) -> Void) {
        make(self)
    }
        
    public func addAttribute(_ attrName: NSAttributedString.Key, value: Any?, range: NSRange? = nil) {
        let range = range ?? NSRange(location: 0, length: base.length)
        if let value = value {
            base.addAttribute(attrName, value: value, range: range)
        } else {
            base.removeAttribute(attrName, range: range)
        }
    }
    
    public func addAttributes(_ attrs: [NSAttributedString.Key : Any], range: NSRange? = nil) {
        let range = range ?? NSRange(location: 0, length: base.length)
        base.addAttributes(attrs, range: range)
    }
    
    public func setAttributes(_ attrs: Dictionary<NSAttributedString.Key, Any>, range: NSRange? = nil) {
        // 此方法会删除之前所有的attrs，然后add新的
        let range = range ?? NSRange(location: 0, length: base.length)
        base.setAttributes(attrs, range: range)
    }
    
    public func removeAllAttributes(in range: NSRange)  {
        base.setAttributes(nil, range: range)
    }
    
    /* ======================================================================= */
    
    // MARK: - font
    public var font: UIFont? {
        get { return font(at: 0) }
        nonmutating set { setFont(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 字体
    public func setFont(_ font: UIFont?, range: NSRange) {
        addAttribute(.font, value: font, range: range)
    }
    
    // MARK: - kern
    public var kern: CGFloat? {
        get { return kern(at: 0) }
        nonmutating set { setKern(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 文字间隔(负数缩紧，正数散开)
    public func setKern(_ kern: CGFloat?, range: NSRange) {
        addAttribute(.kern, value: kern, range: range)
    }

    //MARK: - foregroundColor
    public var foregroundColor: UIColor? {
        get { return foregroundColor(at: 0) }
        nonmutating set { setForegroundColor(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 文字颜色
    public func setForegroundColor(_ color: UIColor?, range: NSRange) {
        addAttribute(.foregroundColor, value: color, range: range)
    }

    // MARK: - backgroundColor
    @available(*, deprecated, message:"PoLabel不支持, 请使用textBorder替代")
    public var backgroundColor: UIColor? {
        get { return backgroundColor(at: 0) }
        nonmutating set { setBackgroundColor(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 背景颜色
    @available(*, deprecated, message:"PoLabel不支持, 请使用textBorder替代")
    public func setBackgroundColor(_ color: UIColor?, range: NSRange) {
        addAttribute(.backgroundColor, value: color, range: range)
    }

    // MARK: - strokeWidth
    public var strokeWidth: CGFloat? {
        get { return strokeWidth(at: 0) }
        nonmutating set { setStrokeWidth(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 文字的外面的线宽 (正数会变成空心字，负数会加宽文字的线条)
    public func setStrokeWidth(_ width: CGFloat?, range: NSRange) {
        addAttribute(.strokeWidth, value: width, range: range)
    }

    // MARK: - strokeColor
    public var strokeColor: UIColor? {
        get { return strokeColor(at: 0) }
        nonmutating set { setStrokeColor(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    // 文字颜色，与strokeWidth一同设置才生效
    public func setStrokeColor(_ color: UIColor?, range: NSRange) {
        addAttribute(.strokeColor, value: color, range: range)
    }

    // MARK: - shadow
    public var shadow: NSShadow? {
        get { return shadow(at: 0) }
        nonmutating set { setShadow(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 文字阴影
    public func setShadow(_ shadow: NSShadow?, range: NSRange) {
        addAttribute(.shadow, value: shadow, range: range)
    }

    // MARK: - strikethroughStyle
    public var strikethroughStyle: NSUnderlineStyle? {
        get { return strikethroughStyle(at: 0) }
        nonmutating set { setStrikethroughStyle(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 删除线(线条从文字中间水平贯穿)
    public func setStrikethroughStyle(_ style: NSUnderlineStyle?, range: NSRange) {
        addAttribute(.strikethroughStyle, value: style?.rawValue, range: range)
    }

    // MARK: - strikethroughColor
    public var strikethroughColor: UIColor? {
        get { return strikethroughColor(at: 0) }
        nonmutating set { setStrikethroughColor(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 删除线的颜色
    public func setStrikethroughColor(_ color: UIColor?, range: NSRange) {
        addAttribute(.strikethroughColor, value: color, range: range)
    }

    // MARK: - underlineStyle
    public var underlineStyle: NSUnderlineStyle? {
        get { return underlineStyle(at: 0) }
        nonmutating set { setUnderlineStyle(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 下划线
    public func setUnderlineStyle(_ style: NSUnderlineStyle?, range: NSRange) {
        addAttribute(.underlineStyle, value: style?.rawValue, range: range)
    }

    // MARK: - underlineColor
    public var underlineColor: UIColor? {
        get { return underlineColor(at: 0) }
        nonmutating set { setUnderlineColor(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 下划线的颜色
    public func setUnderlineColor(_ color: UIColor?, range: NSRange) {
        addAttribute(.underlineColor, value: color, range: range)
    }
    
    // MARK: - ligature
    public var ligature: Int? {
        get { return ligature(at: 0) }
        nonmutating set { setLigature(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 连体字符，0:不生效，1:使用默认的连体字符。(只有某些字体才支持)
    public func setLigature(_ ligature: Int?, range: NSRange) {
        addAttribute(.ligature, value: ligature, range: range)
    }

    // MARK: - textEffect
    @available(*, deprecated, message:"PoLabel不支持")
    public var textEffect: NSAttributedString.TextEffectStyle? {
        get { return textEffect(at: 0) }
        nonmutating set { setTextEffect(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 凸版印刷效果, NSAttributedString.TextEffectStyle.letterpressStyle
    @available(*, deprecated, message:"PoLabel不支持")
    public func setTextEffect(_ textEffect: NSAttributedString.TextEffectStyle?, range: NSRange) {
        addAttribute(.textEffect, value: textEffect, range: range)
    }

    // MARK: - obliqueness
    @available(*, deprecated, message:"PoLabel不支持")
    public var obliqueness: CGFloat? {
        get { return obliqueness(at: 0) }
        nonmutating set { setObliqueness(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 文字倾斜(正数：右倾斜，负数：左倾斜)
    @available(*, deprecated, message:"PoLabel不支持")
    public func setObliqueness(_ obliqueness: CGFloat?, range: NSRange) {
        addAttribute(.obliqueness, value: obliqueness, range: range)
    }

    // MARK: - expansion
    @available(*, deprecated, message:"PoLabel不支持")
    public var expansion: CGFloat? {
        get { return expansion(at: 0) }
        nonmutating set { setExpansion(expansion: newValue, range: NSRange(location: 0, length: base.length)) }
    }

    /// 字体的横向拉伸(正数：拉伸，负数：压缩)
    @available(*, deprecated, message:"PoLabel不支持")
    public func setExpansion( expansion: CGFloat?, range: NSRange) {
        addAttribute(.expansion, value: expansion, range: range)
    }

    // MARK: - baselineOffset
    public var baselineOffset: CGFloat? {
        get { return baselineOffset(at: 0) }
        nonmutating set { setBaselineOffset(newValue, range: NSRange(location: 0, length: base.length)) }
    }

    /// 基线偏移量(正数:向上偏移，负数:向下偏移)
    public func setBaselineOffset(_ offset: CGFloat?, range: NSRange) {
        addAttribute(.baselineOffset, value: offset, range: range)
    }

    // MARK: - verticalGlyphForm - ios 无效
    @available(*, deprecated, message:"PoLabel不支持")
    public var verticalGlyphForm: Int? {
        get { return verticalGlyphForm(at: 0) }
        nonmutating set { setVerticalGlyphForm(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 设置文字排版方向，0表示横排文本，1表示竖排文本 在iOS中只支持0
    @available(*, deprecated, message:"PoLabel不支持")
    public func setVerticalGlyphForm(_ form: Int?, range: NSRange) {
        addAttribute(.verticalGlyphForm, value: form, range: range)
    }

    // MARK: - writingDirection
    public var writingDirection: [Int]? {
        get { return writingDirection(at: 0) }
        nonmutating set { setWritingDirection(newValue, range: NSRange(location: 0, length: base.length)) }
    }

    /// 文字书写方向
    public func setWritingDirection(_ direction: [Int]?, range: NSRange) {
        addAttribute(.writingDirection, value: direction, range: range)
    }

    // MARK: - paragraphStyle
    public var paragraphStyle: NSParagraphStyle? {
        get { return paragraphStyle(at: 0) }
        nonmutating set { setParagraphStyle(newValue, range: NSRange(location: 0, length: base.length)) }
    }

    /// 段落样式
    public func setParagraphStyle(_ style: NSParagraphStyle?, range: NSRange) {
        addAttribute(.paragraphStyle, value: style, range: range)
    }

    // MARK: - alignment
    public var alignment: NSTextAlignment {
        get { return alignment(at: 0) }
        nonmutating set { setAlignment(newValue, range: NSRange(location: 0, length: base.length)) }
    }

    /// 文字对齐方向
    public func setAlignment(_ alignment: NSTextAlignment, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.alignment == alignment { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.alignment == alignment { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.alignment = alignment
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - baseWritingDirection
    public var baseWritingDirection: NSWritingDirection {
        get { return baseWritingDirection(at: 0) }
        nonmutating set { setBaseWritingDirection(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 文字书写方向(与alignment效果类似)
    public func setBaseWritingDirection(_ direction: NSWritingDirection, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.baseWritingDirection == direction { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.baseWritingDirection == direction { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.baseWritingDirection = direction
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - lineSpacing
    public var lineSpacing: CGFloat {
        get { return lineSpacing(at: 0) }
        nonmutating set { setLineSpacing(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 行间距
    public func setLineSpacing(_ spacing: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.lineSpacing == spacing { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.lineSpacing == spacing { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.lineSpacing = spacing
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - paragraphSpacing
    public var paragraphSpacing: CGFloat {
        get { return paragraphSpacing(at: 0) }
        nonmutating set { setParagraphSpacing(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 本段的尾部与下一段头部的距离(文章以\r or \n or \r\n分割段落)(好像与paragraphSpacingBefore没什么区别)
    public func setParagraphSpacing(_ spacing: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.paragraphSpacing == spacing { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.paragraphSpacing == spacing { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.paragraphSpacing = spacing
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - paragraphSpacingBefore
    public var paragraphSpacingBefore: CGFloat {
        get { return paragraphSpacingBefore(at: 0) }
        nonmutating set { setParagraphSpacingBefore(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 本段的头部与上一段尾部的距离(好像与paragraphSpacing没什么区别)
    public func setParagraphSpacingBefore(_ spacing: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.paragraphSpacingBefore == spacing { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.paragraphSpacingBefore == spacing { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.paragraphSpacingBefore = spacing
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - firstLineHeadIndent
    public var firstLineHeadIndent: CGFloat {
        get { return firstLineHeadIndent(at: 0) }
        nonmutating set { setFirstLineHeadIndent(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 每个段落第一行的缩进
    public func setFirstLineHeadIndent(_ indent: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.firstLineHeadIndent == indent { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.firstLineHeadIndent == indent { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.firstLineHeadIndent = indent
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - headIndent
    public var headIndent: CGFloat {
        get { return headIndent(at: 0) }
        nonmutating set { setHeadIndent(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 首行除外的整体缩进(正数向右边缩进，s负数向左边缩进)
    public func setHeadIndent(_ indent: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.headIndent == indent { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.headIndent == indent { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.headIndent = indent
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - tailIndent
    public var tailIndent: CGFloat {
        get { return tailIndent(at: 0) }
        nonmutating set { setTailIndent(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 尾部缩进(负数向左边缩进，正数表示文字整体的宽度)
    public func setTailIndent(_ indent: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.tailIndent == indent { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.tailIndent == indent { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.tailIndent = indent
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - lineBreakMode
    public var lineBreakMode: NSLineBreakMode {
        get { return lineBreakMode(at: 0) }
        nonmutating set { setLineBreakMode(newValue, range: NSRange(location: 0, length: base.length)) }
    }

    /// 文字截断模式
    public func setLineBreakMode(_ mode: NSLineBreakMode, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.lineBreakMode == mode { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.lineBreakMode == mode { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.lineBreakMode = mode
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - minimumLineHeight
    public var minimumLineHeight: CGFloat {
        get { return minimumLineHeight(at: 0) }
        nonmutating set { setMinimumLineHeight(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 最小行高
    public func setMinimumLineHeight(_ height: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.minimumLineHeight == height { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.minimumLineHeight == height { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.minimumLineHeight = height
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - maximumLineHeight
    public var maximumLineHeight: CGFloat {
        get { return maximumLineHeight(at: 0) }
        nonmutating set { setMaximumLineHeight(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 最大行高
    public func setMaximumLineHeight(_ height: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.maximumLineHeight == height { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.maximumLineHeight == height { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.maximumLineHeight = height
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - lineHeightMultiple
    public var lineHeightMultiple: CGFloat {
        get { return lineHeightMultiple(at: 0) }
        nonmutating set { setLineHeightMultiple(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    /// 行高相乘系数
    public func setLineHeightMultiple(_ multiple: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.lineHeightMultiple == multiple { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.lineHeightMultiple == multiple { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.lineHeightMultiple = multiple
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - hyphenationFactor
    public var hyphenationFactor: Float {
        get { return hyphenationFactor(at: 0) }
        nonmutating set { setHyphenationFactor(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    public func setHyphenationFactor(_ factor: Float, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.hyphenationFactor == factor { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.hyphenationFactor == factor { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.hyphenationFactor = factor
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - defaultTabInterval
    public var defaultTabInterval: CGFloat {
        get { return defaultTabInterval(at: 0) }
        nonmutating set { setDefaultTabInterval(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    public func setDefaultTabInterval(_ interval: CGFloat, range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.defaultTabInterval == interval { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.defaultTabInterval == interval { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.defaultTabInterval = interval
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - tabStops
    public var tabStops: [NSTextTab] {
        get { return tabStops(at: 0) }
        nonmutating set { setTabStops(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    public func setTabStops(_ tabStops: [NSTextTab], range: NSRange) {
        base.enumerateAttribute(.paragraphStyle, in: range, options: []) { (value, subRange, _) in
            var paragraphStyle: NSMutableParagraphStyle?
            if let style = value as? NSParagraphStyle {
                if style.tabStops == tabStops { return }
                if style is NSMutableParagraphStyle {
                    paragraphStyle = style as? NSMutableParagraphStyle
                } else {
                    paragraphStyle = style.mutableCopy() as? NSMutableParagraphStyle
                }
            } else {
                if NSParagraphStyle.default.tabStops == tabStops { return }
                paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
            }
            paragraphStyle?.tabStops = tabStops
            setParagraphStyle(paragraphStyle, range: subRange)
        }
    }

    // MARK: - attachment
    public func setAttachment(_ attachment: NSTextAttachment, range: NSRange) {
        addAttribute(.attachment, value: attachment, range: range)
    }

    // MARK: - link
    public func setLink(_ link: Any?, range: NSRange) {
        addAttribute(.link, value: link, range: range)
    }

    /**************************************** custom ****************************************/

    // MARK: - textBackedString
    public func setTextBackedString(_ backedString: TextBackedString?, range: NSRange) {
        addAttribute(.poBackedString, value: backedString, range: range)
    }

    // MARK: - textBorder
    public var textBorder: TextBorder? {
        get { return textBorder(at: 0) }
        nonmutating set { setTextBorder(newValue, range:  NSRange(location: 0, length: base.length)) }
    }

    public func setTextBorder(_ border: TextBorder?, range: NSRange) {
        addAttribute(.poBorder, value: border, range: range)
    }

    // MARK: - textBlockBorder
    public var textBlockBorder: TextBorder? {
        get { return textBlockBorder(at: 0) }
        nonmutating set { setTextBlockBorder(newValue, range:  NSRange(location: 0, length: base.length)) }
    }

    public func setTextBlockBorder(_ border: TextBorder?, range: NSRange) {
        addAttribute(.poBlockBorder, value: border, range: range)
    }

    // MARK: - textHighlight
    public var textHighlight: TextHighlight? {
        get { return textHighlight(at: 0) }
        nonmutating set { setTextHighlight(newValue, range: NSRange(location: 0, length: base.length)) }
    }
    
    public func setTextHighlight(_ highlight: TextHighlight?, range: NSRange) {
        addAttribute(.poHighlight, value: highlight, range: range)
    }

    // MARK: - Helper Methods
    public func insert(_ string: String, at index: Int) {
        base.replaceCharacters(in: NSRange(location: index, length: 0), with: string)
        removeDiscontinuousAttributes(in: NSRange(location: index, length: string.utf16.count))
    }

    public func append(_ content: String) {
        let length = base.length
        base.replaceCharacters(in: NSRange(location: length, length: 0), with: content)
        removeDiscontinuousAttributes(in: NSRange(location: length, length: content.utf16.count))
    }

    public func removeDiscontinuousAttributes(in range: NSRange) {
        for key in NSAttributedString.Key.allDiscontinuousAttributeKeys {
            base.removeAttribute(key, range: range)
        }
    }
    
    public static func attachmentString(with content: TextAttachment.Content, size: CGSize? = nil, alignToFont: UIFont, verticalAlignment: TextVerticalAlignment) -> NSMutableAttributedString {
        let contentMode: UIView.ContentMode
        switch verticalAlignment {
        case .top:
            contentMode = .top
        case .center:
            contentMode = .center
        case .bottom:
            contentMode = .bottom
        }
        return attachmentString(with: content, size: size, alignToFont: alignToFont, contentInsets: .zero, verticalAlignment: verticalAlignment, contentMode: contentMode)
    }
    
    public static func attachmentString(with content: TextAttachment.Content, size: CGSize? = nil, alignToFont: UIFont, contentInsets: UIEdgeInsets, verticalAlignment: TextVerticalAlignment, contentMode: UIView.ContentMode) -> NSMutableAttributedString {
        let attachment = TextAttachment(content: content, size: size, alignToFont: alignToFont, contentInsets: contentInsets, verticalAlignment: verticalAlignment, contentMode: contentMode)
        return NSMutableAttributedString(attachment: attachment)
    }
    
}

