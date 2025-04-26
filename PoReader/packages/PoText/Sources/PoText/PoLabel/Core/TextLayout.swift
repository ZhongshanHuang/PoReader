import UIKit

typealias TextAttributesDictionary = Dictionary<NSAttributedString.Key, Any>

extension TextLayout {
    public struct State: OptionSet, Sendable {
        public var rawValue: UInt8
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        public var isContainsHighlight: Bool {
            get { contains(.isContainsHighlight) }
            set { if newValue { insert(.isContainsHighlight) } else { remove(.isContainsHighlight) } }
        }
        public var isNeedDrawBlockBorder: Bool {
            get { contains(.isNeedDrawBlockBorder) }
            set { if newValue { insert(.isNeedDrawBlockBorder) } else { remove(.isNeedDrawBlockBorder) } }
        }
        public var isNeedDrawBorder: Bool {
            get { contains(.isNeedDrawBorder) }
            set { if newValue { insert(.isNeedDrawBorder) } else { remove(.isNeedDrawBorder) } }
        }
        public var isNeedDrawAttachment: Bool {
            get { contains(.isNeedDrawAttachment) }
            set { if newValue { insert(.isNeedDrawAttachment) } else { remove(.isNeedDrawAttachment) } }
        }
        
        /// Has highlight attibute
        public static let isContainsHighlight = State(rawValue: 1 << 0)
        /// Has block border attribute
        public static let isNeedDrawBlockBorder = State(rawValue: 1 << 1)
        /// Has Border attribute
        public static let isNeedDrawBorder = State(rawValue: 1 << 2)
        /// Has attachment attribute
        public static let isNeedDrawAttachment = State(rawValue: 1 << 3)
    }
    
    public struct TruncationInfo {
        public enum TruncationType {
            case head
            case middle
            case tail
        }
        
        public let type: TruncationType
        /// 如果Truncation大于当前布局行的宽度，则characterRange不准确
        public let characterRange: NSRange
        public let token: NSAttributedString
    }

    struct LineInfo {
        let rect: CGRect
        let usedRect: CGRect
        let glyphRange: NSRange
        let characterRange: NSRange
    }
}

public final class TextLayout: @unchecked Sendable {
    private(set) var state: State = State()
    
    public let textStorage: NSTextStorage
    let containter: TextContainer
    public let textContainer: NSTextContainer
    public let layoutManager: NSLayoutManager
    private(set) var visibleGlyphRange: NSRange = NSRange(location: NSNotFound, length: 0)
    private(set) var visibleCharacterRange: NSRange = NSRange(location: NSNotFound, length: 0)
    public private(set) var truncationInfo: TruncationInfo?
    /// 实际使用的大小
    public private(set) var textBoundingSize: CGSize = .zero
    
    /// 展示出来多少行
    public var numberOfLines: Int { lineInfos.count }
    private(set) var lineInfos: [LineInfo] = []
    private(set) var attachmentInfos: [TextAttachment: CGRect] = [:]
    var borderInfos: [TextBorder: [CGRect]] = [:]
    var blockBorderInfos: [TextBorder: [CGRect]] = [:]
    
    public init(attributedString: NSAttributedString, container: TextContainer) {
        self.textStorage = NSTextStorage()
        self.containter = container
        self.textContainer = container.asNSTextContainer
        self.layoutManager = NSLayoutManager()
        
        layoutManager.usesFontLeading = false
        textStorage.addLayoutManager(layoutManager)
        
        // Instead of calling [NSTextStorage initWithAttributedString:], setting attributedString just after calling addlayoutManager can fix CJK language layout issues.
        // See https://github.com/facebook/AsyncDisplayKit/issues/2894
        textStorage.setAttributedString(attributedString)
        textStorage.po.lineBreakMode = textContainer.lineBreakMode
        layoutManager.addTextContainer(textContainer)
        
        guard attributedString.length > 0 else { return }
        
        layoutManager.ensureLayout(for: textContainer)
        
        visibleGlyphRange = layoutManager.glyphRange(for: textContainer)
        if visibleGlyphRange.length == 0 { return }
        visibleCharacterRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        if let truncationInfo = processTruncation(visibleGlyphRange: visibleGlyphRange, container: container) {
            self.truncationInfo = truncationInfo
            layoutManager.ensureLayout(for: textContainer) /// 内容替换了，重新布局
            visibleGlyphRange = layoutManager.glyphRange(for: textContainer)
            visibleCharacterRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        }
        
        textBoundingSize = layoutManager.usedRect(for: textContainer).size
        
        let block: (TextAttributesDictionary, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void = { (attrs, range, stop) in
            if attrs[.poHighlight] != nil { self.state.isContainsHighlight = true }
            if attrs[.attachment] != nil { self.state.isNeedDrawAttachment = true }
            if attrs[.poBorder] != nil { self.state.isNeedDrawBorder = true }
            if attrs[.poBlockBorder] != nil { self.state.isNeedDrawBlockBorder = true }
        }

        textStorage.enumerateAttributes(in: visibleCharacterRange,
                                        options: .longestEffectiveRangeNotRequired,
                                        using: block)
        
        // line
        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { lineRect, lineUsedRect, _, glyphRange, stop in
            let characterRange = self.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineInfo = LineInfo(rect: lineRect, usedRect: lineUsedRect, glyphRange: glyphRange, characterRange: characterRange)
            self.lineInfos.append(lineInfo)
        }
        
        // attachment
        textStorage.enumerateAttribute(.attachment, in: visibleCharacterRange, options: .longestEffectiveRangeNotRequired) { attachment, range, stop in
            guard let attachment = attachment as? TextAttachment else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let location = layoutManager.location(forGlyphAt: glyphRange.location)
            if !isInLastLine(for: range.location),
                let paragraphStyle = textStorage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle,
               paragraphStyle.lineSpacing > .leastNonzeroMagnitude {
                rect.size.height -= paragraphStyle.lineSpacing
            }
            rect.origin.y += location.y
            rect.origin.y -= attachment.bounds.height
            rect.size.height = attachment.bounds.height
            attachmentInfos[attachment] = rect
        }
    }
    
    /// 点击位置的字符index
    public func textPositionForPoint(_ point: CGPoint) -> Int? {
        var fractionOfDistance: CGFloat = 0
        let index = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: &fractionOfDistance)
        if fractionOfDistance > 0 && fractionOfDistance < 1 {
            return index
        }
        return nil
    }
    
    func suggestedFitsSize() -> CGSize {
        CGSize(width: textBoundingSize.width + containter.insets.horizontalValue, height: textBoundingSize.height + containter.insets.verticalValue).pixelCeil
    }
    
    /// 自定义截断处理
    private func processTruncation(visibleGlyphRange: NSRange, container: TextContainer) -> TruncationInfo? {
        let lastVisibleGlyphIndex = visibleGlyphRange.upperBound - 1
        let lastVisibleCharacterIndex = layoutManager.characterIndexForGlyph(at: lastVisibleGlyphIndex)
        // 需要截断
        guard lastVisibleCharacterIndex < textStorage.length - 1, container.lineBreakMode.isNeedTruncation else { return nil }
        
        if container.lineBreakMode == .byTruncatingTail {
            let tailTruncationToken: NSMutableAttributedString
            let truncationByCustom = (container.tailTruncationToken?.length ?? 0) > 0
            if truncationByCustom {
                tailTruncationToken = NSMutableAttributedString(attributedString: container.tailTruncationToken!)
            } else {
                let attributes = textStorage.attributes(at: lastVisibleCharacterIndex, effectiveRange: nil)
                var replaceAttributes = [NSAttributedString.Key : Any]()
                replaceAttributes[.font] = attributes[.font]
                replaceAttributes[.paragraphStyle] = attributes[.paragraphStyle]
                replaceAttributes[.foregroundColor] = attributes[.foregroundColor] ?? UIColor.black
                tailTruncationToken = NSMutableAttributedString(string: TextToken.truncation.rawValue, attributes: replaceAttributes)
            }
            var lastLineRange: NSRange = NSRange(location: NSNotFound, length: 0)
            let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: visibleGlyphRange.upperBound - 1, effectiveRange: &lastLineRange)
            if lastLineRange.location == NSNotFound { return nil }
            
            let lastLineUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: visibleGlyphRange.upperBound - 1, effectiveRange: nil)
            
            let paragraphStyle = textStorage.attributes(at: lastVisibleCharacterIndex, effectiveRange: nil)[.paragraphStyle] as? NSParagraphStyle
            let writingDirection = paragraphStyle?.baseWritingDirection
            // 是否从左到右布局
            let isLTR = (lastLineRect.minX - lastLineUsedRect.minX) < 0.001 || (writingDirection != .rightToLeft)
            
            let tailTruncationSize = tailTruncationToken.boundingRect(with: TextContainer.maxSize, options: .usesLineFragmentOrigin, context: nil).size
            if tailTruncationSize.width >= lastLineUsedRect.width {
                let replaceRange = NSRange(location: lastLineRange.location, length: textStorage.length - lastLineRange.location)
                textStorage.replaceCharacters(in: replaceRange, with: tailTruncationToken)
                return TruncationInfo(type: .middle, characterRange: NSRange(location: lastLineRange.location, length: tailTruncationToken.length), token: tailTruncationToken)
            }
            let tailTruncationOriginalX = isLTR ? (textContainer.size.width - tailTruncationSize.width) : (0)
            let tailTruncationUsedRect = CGRect(x: tailTruncationOriginalX,
                                                y: lastLineRect.minY,
                                                width: tailTruncationSize.width,
                                                height: tailTruncationSize.height)
            let replaceStartPointX = isLTR ? tailTruncationUsedRect.minX : tailTruncationUsedRect.maxX
            let replaceStartGlyphIndex = layoutManager.glyphIndex(for: CGPoint(x: replaceStartPointX, y: tailTruncationUsedRect.midY), in: textContainer, fractionOfDistanceThroughGlyph: nil)
            let replaceStartCharacterIndex = layoutManager.characterIndexForGlyph(at: replaceStartGlyphIndex)
            let replaceRange = NSRange(location: replaceStartCharacterIndex, length: textStorage.length - replaceStartCharacterIndex)
            if !truncationByCustom, let foregroundColor = textStorage.attribute(.foregroundColor, at: replaceRange.location, effectiveRange: nil) {
                tailTruncationToken.addAttribute(.foregroundColor, value: foregroundColor, range: tailTruncationToken.allRange)
            }
            textStorage.replaceCharacters(in: replaceRange, with: tailTruncationToken)
            return TruncationInfo(type: .tail, characterRange: NSRange(location: replaceStartCharacterIndex, length: tailTruncationToken.length), token: tailTruncationToken)
        }
        
        if container.lineBreakMode == .byTruncatingMiddle {
            var lastLineGlyphRange: NSRange = NSRange(location: NSNotFound, length: 0)
            let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: visibleGlyphRange.upperBound - 1, effectiveRange: &lastLineGlyphRange)
            if lastLineGlyphRange.location == NSNotFound { return nil }
            let lastLineRange = layoutManager.characterRange(forGlyphRange: lastLineGlyphRange, actualGlyphRange: nil)
            let lastLineUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: visibleGlyphRange.upperBound - 1, effectiveRange: nil)
            let lastLineMidGlyphIndex = layoutManager.glyphIndex(for: lastLineUsedRect.center, in: textContainer)
            let lastLineMidCharacterIndex = layoutManager.characterIndexForGlyph(at: lastLineMidGlyphIndex)
            
            let paragraphStyle = textStorage.attributes(at: lastLineMidCharacterIndex, effectiveRange: nil)[.paragraphStyle] as? NSParagraphStyle
            let writingDirection = paragraphStyle?.baseWritingDirection
            // 是否从左到右布局
            let isLTR = (lastLineRect.minX - lastLineUsedRect.minX) < 0.001 || (writingDirection != .rightToLeft)
            
            let attributes = textStorage.attributes(at: lastLineMidCharacterIndex, effectiveRange: nil)
            var replaceAttributes = [NSAttributedString.Key : Any]()
            replaceAttributes[.font] = attributes[.font]
            replaceAttributes[.paragraphStyle] = attributes[.paragraphStyle]
            replaceAttributes[.foregroundColor] = attributes[.foregroundColor] ?? UIColor.black
            let midTruncationToken = NSMutableAttributedString(string: TextToken.truncation.rawValue, attributes: replaceAttributes)
            
            let midTruncationSize = midTruncationToken.boundingRect(with: TextContainer.maxSize, options: .usesLineFragmentOrigin, context: nil).size
            if midTruncationSize.width >= lastLineUsedRect.width {
                let replaceRange = NSRange(location: lastLineRange.location, length: textStorage.length - lastLineRange.location)
                textStorage.replaceCharacters(in: replaceRange, with: midTruncationToken)
                return TruncationInfo(type: .middle, characterRange: NSRange(location: lastLineRange.location, length: midTruncationToken.length), token: midTruncationToken)
            }
            let midTruncationOriginalX = lastLineUsedRect.midX - midTruncationSize.width / 2
            let midTruncationUsedRect = CGRect(x: midTruncationOriginalX,
                                                y: lastLineRect.minY,
                                                width: midTruncationSize.width,
                                                height: midTruncationSize.height)
            let replaceStartPointX = isLTR ? midTruncationUsedRect.minX : midTruncationUsedRect.maxX
            let replaceStartGlyphIndex = layoutManager.glyphIndex(for: CGPoint(x: replaceStartPointX, y: midTruncationUsedRect.midY), in: textContainer, fractionOfDistanceThroughGlyph: nil)
            let replaceStartCharacterIndex = layoutManager.characterIndexForGlyph(at: replaceStartGlyphIndex)
            let replaceRange = NSRange(location: replaceStartCharacterIndex, length: textStorage.length - replaceStartCharacterIndex)
            if let foregroundColor = textStorage.attribute(.foregroundColor, at: replaceRange.location, effectiveRange: nil) {
                midTruncationToken.addAttribute(.foregroundColor, value: foregroundColor, range: midTruncationToken.allRange)
            }
            textStorage.replaceCharacters(in: replaceRange, with: midTruncationToken)
            return TruncationInfo(type: .head, characterRange: NSRange(location: replaceStartCharacterIndex, length: midTruncationToken.length), token: midTruncationToken)
        }
        
        if container.lineBreakMode == .byTruncatingHead {
            var lastLineRange: NSRange = NSRange(location: NSNotFound, length: 0)
            let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: visibleGlyphRange.upperBound - 1, effectiveRange: &lastLineRange)
            if lastLineRange.location == NSNotFound { return nil }
            
            let lastLineFirstCharacterIndex = lastLineRange.location
            let lastLineUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: visibleGlyphRange.upperBound - 1, effectiveRange: nil)
            
            let paragraphStyle = textStorage.attributes(at: lastLineFirstCharacterIndex, effectiveRange: nil)[.paragraphStyle] as? NSParagraphStyle
            let writingDirection = paragraphStyle?.baseWritingDirection
            // 是否从左到右布局
            let isLTR = (lastLineRect.minX - lastLineUsedRect.minX) < 0.001 || (writingDirection != .rightToLeft)
            
            let attributes = textStorage.attributes(at: lastLineFirstCharacterIndex, effectiveRange: nil)
            var replaceAttributes = [NSAttributedString.Key : Any]()
            replaceAttributes[.font] = attributes[.font]
            replaceAttributes[.paragraphStyle] = attributes[.paragraphStyle]
            replaceAttributes[.foregroundColor] = attributes[.foregroundColor] ?? UIColor.black
            let headTruncationToken = NSMutableAttributedString(string: TextToken.truncation.rawValue, attributes: replaceAttributes)
            
            let headTruncationSize = headTruncationToken.boundingRect(with: TextContainer.maxSize, options: .usesLineFragmentOrigin, context: nil).size
            if headTruncationSize.width >= lastLineUsedRect.width {
                let replaceRange = NSRange(location: lastLineRange.location, length: textStorage.length - lastLineRange.location)
                textStorage.replaceCharacters(in: replaceRange, with: headTruncationToken)
                return TruncationInfo(type: .head, characterRange: NSRange(location: lastLineRange.location, length: headTruncationToken.length), token: headTruncationToken)
            }
            let headTruncationOriginalX = isLTR ? (0) : (textContainer.size.width - headTruncationSize.width)
            let headTruncationUsedRect = CGRect(x: headTruncationOriginalX,
                                                y: lastLineRect.minY,
                                                width: headTruncationSize.width,
                                                height: headTruncationSize.height)
            let replaceStartPointX = isLTR ? headTruncationUsedRect.minX : headTruncationUsedRect.maxX
            let replaceStartGlyphIndex = layoutManager.glyphIndex(for: CGPoint(x: replaceStartPointX, y: headTruncationUsedRect.midY), in: textContainer, fractionOfDistanceThroughGlyph: nil)
            let replaceStartCharacterIndex = layoutManager.characterIndexForGlyph(at: replaceStartGlyphIndex)
            
            let replaceEndPointX = isLTR ? (replaceStartPointX + headTruncationSize.width) : (replaceStartPointX - headTruncationSize.width)
            let replaceEndGlyphIndex = layoutManager.glyphIndex(for: CGPoint(x: replaceEndPointX, y: headTruncationUsedRect.midY), in: textContainer, fractionOfDistanceThroughGlyph: nil)
            let replaceEndCharacterIndex = layoutManager.characterIndexForGlyph(at: replaceEndGlyphIndex)
            
            let replaceRange = NSRange(location: replaceStartCharacterIndex, length: replaceEndCharacterIndex - replaceStartCharacterIndex)
            if let foregroundColor = textStorage.attribute(.foregroundColor, at: replaceRange.location, effectiveRange: nil) {
                headTruncationToken.addAttribute(.foregroundColor, value: foregroundColor, range: headTruncationToken.allRange)
            }
            textStorage.replaceCharacters(in: replaceRange, with: headTruncationToken)
            return TruncationInfo(type: .head, characterRange: NSRange(location: replaceStartCharacterIndex, length: headTruncationToken.length), token: headTruncationToken)
        }
        return nil
    }
    
}


