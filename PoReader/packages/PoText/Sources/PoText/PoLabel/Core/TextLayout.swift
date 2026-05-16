import CoreText
import UIKit

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

    struct AttributeRun {
        let range: NSRange
        let border: TextBorder?
        let blockBorder: TextBorder?
        let attachment: TextAttachment?

        func canMerge(with next: AttributeRun) -> Bool {
            range.upperBound == next.range.location &&
            border == next.border &&
            blockBorder == next.blockBorder &&
            attachment == next.attachment
        }

        func merging(_ next: AttributeRun) -> AttributeRun {
            AttributeRun(range: NSRange(location: range.location, length: range.length + next.range.length),
                         border: border,
                         blockBorder: blockBorder,
                         attachment: attachment)
        }
    }

    struct AttachmentDrawingInfo {
        let attachment: TextAttachment
        let proposedRect: CGRect
    }

    private struct TruncationLineContext {
        let lineRect: CGRect
        let usedRect: CGRect
        let characterRange: NSRange
        let lastVisibleCharacterIndex: Int
    }

    private final class LineWidthMeasurer {
        private let line: CTLine

        init(attributedString: NSAttributedString) {
            line = CTLineCreateWithAttributedString(attributedString)
        }

        func width(in range: NSRange) -> CGFloat {
            guard range.length > 0 else { return 0 }
            let startOffset = CTLineGetOffsetForStringIndex(line, range.location, nil)
            let endOffset = CTLineGetOffsetForStringIndex(line, range.upperBound, nil)
            return max(0, abs(endOffset - startOffset))
        }
    }
}

public final class TextLayout: @unchecked Sendable {
    private(set) var state: State = State()

    private var attributedStringSnapshot: NSAttributedString?
    private let attributedStringSnapshotLock = NSLock()
    public var attributedString: NSAttributedString {
        attributedStringSnapshotLock.lock()
        defer { attributedStringSnapshotLock.unlock() }
        if let attributedStringSnapshot { return attributedStringSnapshot }
        let snapshot = textStorage.copy() as? NSAttributedString ?? NSAttributedString(attributedString: textStorage)
        attributedStringSnapshot = snapshot
        return snapshot
    }

    let textStorage: NSTextStorage
    let container: TextContainer
    let textContainer: NSTextContainer
    let layoutManager: NSLayoutManager
    private(set) var visibleGlyphRange: NSRange = NSRange(location: NSNotFound, length: 0)
    private(set) var visibleCharacterRange: NSRange = NSRange(location: NSNotFound, length: 0)
    public private(set) var truncationInfo: TruncationInfo?
    /// 实际使用的大小
    public private(set) var textBoundingSize: CGSize = .zero
    
    /// 展示出来多少行
    public var numberOfLines: Int { lineInfos.count }
    private(set) var lineInfos: [LineInfo] = []
    private(set) var imageAttachmentInfos: [AttachmentDrawingInfo] = []
    private(set) var hostedAttachmentInfos: [AttachmentDrawingInfo] = []
    var borderInfos: [TextBorder: [CGRect]] = [:]
    var blockBorderInfos: [TextBorder: [CGRect]] = [:]
    
    public init(attributedString: NSAttributedString, container: TextContainer) {
        let container = container.snapshot()
        self.textStorage = NSTextStorage()
        self.container = container
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
        
        let attributeRuns = collectAttributeRuns(in: visibleCharacterRange)
        
        // line
        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { lineRect, lineUsedRect, _, glyphRange, stop in
            let characterRange = self.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineInfo = LineInfo(rect: lineRect, usedRect: lineUsedRect, glyphRange: glyphRange, characterRange: characterRange)
            self.lineInfos.append(lineInfo)
        }
        prepareDrawingMetadata(from: attributeRuns)
        
        // attachment
        prepareAttachmentInfos(from: attributeRuns)
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
        CGSize(width: textBoundingSize.width + container.insets.horizontalValue, height: textBoundingSize.height + container.insets.verticalValue).pixelCeil
    }

    private func collectAttributeRuns(in range: NSRange) -> [AttributeRun] {
        var runs = [AttributeRun]()
        textStorage.enumerateAttributes(in: range, options: .longestEffectiveRangeNotRequired) { attrs, range, _ in
            if attrs[.poHighlight] != nil { state.isContainsHighlight = true }

            let attachment = attrs[.attachment] as? TextAttachment
            let border = attrs[.poBorder] as? TextBorder
            let blockBorder = attrs[.poBlockBorder] as? TextBorder

            if attachment != nil { state.isNeedDrawAttachment = true }
            if border != nil { state.isNeedDrawBorder = true }
            if blockBorder != nil { state.isNeedDrawBlockBorder = true }

            if attachment != nil || border != nil || blockBorder != nil {
                let run = AttributeRun(range: range,
                                       border: border,
                                       blockBorder: blockBorder,
                                       attachment: attachment)
                if let last = runs.last, last.canMerge(with: run) {
                    runs[runs.count - 1] = last.merging(run)
                } else {
                    runs.append(run)
                }
            }
        }
        return runs
    }

    private func prepareAttachmentInfos(from attributeRuns: [AttributeRun]) {
        guard state.isNeedDrawAttachment else { return }

        for attributeRun in attributeRuns {
            guard let attachment = attributeRun.attachment else { continue }
            let range = attributeRun.range
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
            let info = AttachmentDrawingInfo(attachment: attachment, proposedRect: rect)
            switch attachment.content {
            case .image:
                imageAttachmentInfos.append(info)
            case .view, .layer:
                hostedAttachmentInfos.append(info)
            }
        }
    }
    
    /// 自定义截断处理
    private func processTruncation(visibleGlyphRange: NSRange, container: TextContainer) -> TruncationInfo? {
        // 需要截断
        guard container.lineBreakMode.isNeedTruncation,
              let lineContext = truncationLineContext(for: visibleGlyphRange),
              lineContext.lastVisibleCharacterIndex < textStorage.length - 1 else { return nil }

        let sourceString = textStorage.string as NSString
        
        if container.lineBreakMode == .byTruncatingTail {
            let tailTruncationToken: NSMutableAttributedString
            let truncationByCustom = (container.tailTruncationToken?.length ?? 0) > 0
            if truncationByCustom, let token = container.tailTruncationToken {
                tailTruncationToken = NSMutableAttributedString(attributedString: token)
            } else {
                tailTruncationToken = defaultTruncationToken(at: lineContext.lastVisibleCharacterIndex)
            }
            let isLTR = isLeftToRightLine(lineRect: lineContext.lineRect,
                                          usedRect: lineContext.usedRect,
                                          characterIndex: lineContext.lastVisibleCharacterIndex)
            
            let tailTruncationSize = tailTruncationToken.boundingRect(with: TextContainer.maxSize, options: .usesLineFragmentOrigin, context: nil).size
            if tailTruncationSize.width >= lineContext.usedRect.width {
                let replaceRange = NSRange(location: lineContext.characterRange.location, length: textStorage.length - lineContext.characterRange.location)
                textStorage.replaceCharacters(in: replaceRange, with: tailTruncationToken)
                return TruncationInfo(type: .tail, characterRange: NSRange(location: lineContext.characterRange.location, length: tailTruncationToken.length), token: tailTruncationToken)
            }
            let tailTruncationOriginalX = isLTR ? (textContainer.size.width - tailTruncationSize.width) : 0
            let tailTruncationUsedRect = CGRect(x: tailTruncationOriginalX,
                                                y: lineContext.lineRect.minY,
                                                width: tailTruncationSize.width,
                                                height: tailTruncationSize.height)
            let replaceStartPointX = isLTR ? tailTruncationUsedRect.minX : tailTruncationUsedRect.maxX
            let replaceStartGlyphIndex = layoutManager.glyphIndex(for: CGPoint(x: replaceStartPointX, y: tailTruncationUsedRect.midY), in: textContainer, fractionOfDistanceThroughGlyph: nil)
            let rawReplaceStartCharacterIndex = layoutManager.characterIndexForGlyph(at: replaceStartGlyphIndex)
            let replaceStartCharacterIndex = composedCharacterPrefixEnd(rawReplaceStartCharacterIndex,
                                                                        lowerBound: lineContext.characterRange.location,
                                                                        in: sourceString)
            let replaceRange = NSRange(location: replaceStartCharacterIndex, length: textStorage.length - replaceStartCharacterIndex)
            if !truncationByCustom {
                applyTruncationTokenForegroundColor(tailTruncationToken, at: replaceRange.location)
            }
            textStorage.replaceCharacters(in: replaceRange, with: tailTruncationToken)
            return TruncationInfo(type: .tail, characterRange: NSRange(location: replaceStartCharacterIndex, length: tailTruncationToken.length), token: tailTruncationToken)
        }
        
        if container.lineBreakMode == .byTruncatingMiddle {
            let lastLineMidGlyphIndex = layoutManager.glyphIndex(for: lineContext.usedRect.center, in: textContainer)
            let lastLineMidCharacterIndex = layoutManager.characterIndexForGlyph(at: lastLineMidGlyphIndex)
            let midTruncationToken = defaultTruncationToken(at: lastLineMidCharacterIndex)
            
            let midTruncationSize = midTruncationToken.boundingRect(with: TextContainer.maxSize, options: .usesLineFragmentOrigin, context: nil).size
            if midTruncationSize.width >= lineContext.usedRect.width {
                let replaceRange = NSRange(location: lineContext.characterRange.location, length: textStorage.length - lineContext.characterRange.location)
                textStorage.replaceCharacters(in: replaceRange, with: midTruncationToken)
                return TruncationInfo(type: .middle, characterRange: NSRange(location: lineContext.characterRange.location, length: midTruncationToken.length), token: midTruncationToken)
            }

            let availableTextWidth = max(0, lineContext.usedRect.width - midTruncationSize.width)
            let lastLineStart = lineContext.characterRange.location
            let lastLineEnd = min(lineContext.characterRange.upperBound, lineContext.lastVisibleCharacterIndex + 1, textStorage.length)
            let widthMeasurer = LineWidthMeasurer(attributedString: textStorage)
            let prefix = middleTruncationPrefix(from: lastLineStart,
                                                to: lastLineEnd,
                                                fitting: availableTextWidth * 0.5,
                                                widthMeasurer: widthMeasurer,
                                                sourceString: sourceString)
            let prefixEnd = composedCharacterPrefixEnd(prefix.end, lowerBound: lastLineStart, in: sourceString)
            let prefixWidth = prefixEnd == prefix.end ? prefix.width : widthMeasurer.width(in: NSRange(location: lastLineStart, length: prefixEnd - lastLineStart))
            var suffixStart = middleTruncationSuffixStart(from: prefixEnd,
                                                          to: textStorage.length,
                                                          fitting: max(0, availableTextWidth - prefixWidth),
                                                          widthMeasurer: widthMeasurer,
                                                          sourceString: sourceString)
            suffixStart = composedCharacterSuffixStart(suffixStart, upperBound: textStorage.length, in: sourceString)
            if suffixStart <= prefixEnd {
                suffixStart = composedCharacterSuffixStart(min(textStorage.length, prefixEnd + 1), upperBound: textStorage.length, in: sourceString)
            }
            guard suffixStart > prefixEnd else { return nil }

            let replaceRange = NSRange(location: prefixEnd, length: suffixStart - prefixEnd)
            applyTruncationTokenForegroundColor(midTruncationToken, at: replaceRange.location)
            textStorage.replaceCharacters(in: replaceRange, with: midTruncationToken)
            return TruncationInfo(type: .middle, characterRange: NSRange(location: prefixEnd, length: midTruncationToken.length), token: midTruncationToken)
        }
        
        if container.lineBreakMode == .byTruncatingHead {
            let lastLineFirstCharacterIndex = lineContext.characterRange.location
            let isLTR = isLeftToRightLine(lineRect: lineContext.lineRect,
                                          usedRect: lineContext.usedRect,
                                          characterIndex: lastLineFirstCharacterIndex)
            let headTruncationToken = defaultTruncationToken(at: lastLineFirstCharacterIndex)
            
            let headTruncationSize = headTruncationToken.boundingRect(with: TextContainer.maxSize, options: .usesLineFragmentOrigin, context: nil).size
            let availableLineWidth = max(0, textContainer.size.width)
            if headTruncationSize.width >= availableLineWidth {
                let replaceRange = NSRange(location: lineContext.characterRange.location, length: textStorage.length - lineContext.characterRange.location)
                textStorage.replaceCharacters(in: replaceRange, with: headTruncationToken)
                return TruncationInfo(type: .head, characterRange: NSRange(location: lineContext.characterRange.location, length: headTruncationToken.length), token: headTruncationToken)
            }
            if isLTR {
                let suffixTargetWidth = max(0, availableLineWidth - headTruncationSize.width)
                let widthMeasurer = LineWidthMeasurer(attributedString: textStorage)
                var suffixStart = middleTruncationSuffixStart(from: lineContext.characterRange.location,
                                                              to: textStorage.length,
                                                              fitting: suffixTargetWidth,
                                                              widthMeasurer: widthMeasurer,
                                                              sourceString: sourceString)
                suffixStart = composedCharacterSuffixStart(suffixStart, upperBound: textStorage.length, in: sourceString)
                guard suffixStart > lineContext.characterRange.location else { return nil }

                let replaceRange = NSRange(location: lineContext.characterRange.location,
                                           length: suffixStart - lineContext.characterRange.location)
                applyTruncationTokenForegroundColor(headTruncationToken, at: replaceRange.location)
                textStorage.replaceCharacters(in: replaceRange, with: headTruncationToken)
                return TruncationInfo(type: .head, characterRange: NSRange(location: replaceRange.location, length: headTruncationToken.length), token: headTruncationToken)
            }
            let headTruncationOriginalX = textContainer.size.width - headTruncationSize.width
            let headTruncationUsedRect = CGRect(x: headTruncationOriginalX,
                                                y: lineContext.lineRect.minY,
                                                width: headTruncationSize.width,
                                                height: headTruncationSize.height)
            let replaceStartPointX = headTruncationUsedRect.maxX
            let replaceStartGlyphIndex = layoutManager.glyphIndex(for: CGPoint(x: replaceStartPointX, y: headTruncationUsedRect.midY), in: textContainer, fractionOfDistanceThroughGlyph: nil)
            var replaceStartCharacterIndex = layoutManager.characterIndexForGlyph(at: replaceStartGlyphIndex)
            
            let replaceEndPointX = replaceStartPointX - headTruncationSize.width
            let replaceEndGlyphIndex = layoutManager.glyphIndex(for: CGPoint(x: replaceEndPointX, y: headTruncationUsedRect.midY), in: textContainer, fractionOfDistanceThroughGlyph: nil)
            var replaceEndCharacterIndex = layoutManager.characterIndexForGlyph(at: replaceEndGlyphIndex)
            
            if replaceEndCharacterIndex < replaceStartCharacterIndex {
                swap(&replaceStartCharacterIndex, &replaceEndCharacterIndex)
            }
            replaceStartCharacterIndex = composedCharacterPrefixEnd(replaceStartCharacterIndex,
                                                                    lowerBound: lineContext.characterRange.location,
                                                                    in: sourceString)
            replaceEndCharacterIndex = composedCharacterSuffixStart(replaceEndCharacterIndex,
                                                                    upperBound: textStorage.length,
                                                                    in: sourceString)
            guard replaceEndCharacterIndex >= replaceStartCharacterIndex else { return nil }
            let replaceRange = NSRange(location: replaceStartCharacterIndex, length: replaceEndCharacterIndex - replaceStartCharacterIndex)
            applyTruncationTokenForegroundColor(headTruncationToken, at: replaceRange.location)
            textStorage.replaceCharacters(in: replaceRange, with: headTruncationToken)
            return TruncationInfo(type: .head, characterRange: NSRange(location: replaceStartCharacterIndex, length: headTruncationToken.length), token: headTruncationToken)
        }
        return nil
    }

    private func truncationLineContext(for visibleGlyphRange: NSRange) -> TruncationLineContext? {
        guard visibleGlyphRange.location != NSNotFound, visibleGlyphRange.length > 0 else { return nil }

        let lastVisibleGlyphIndex = visibleGlyphRange.upperBound - 1
        let lastVisibleCharacterIndex = layoutManager.characterIndexForGlyph(at: lastVisibleGlyphIndex)
        var lastLineGlyphRange = NSRange(location: NSNotFound, length: 0)
        let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastVisibleGlyphIndex, effectiveRange: &lastLineGlyphRange)
        guard lastLineGlyphRange.location != NSNotFound else { return nil }

        let lastLineCharacterRange = layoutManager.characterRange(forGlyphRange: lastLineGlyphRange, actualGlyphRange: nil)
        let lastLineUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: lastVisibleGlyphIndex, effectiveRange: nil)
        return TruncationLineContext(lineRect: lastLineRect,
                                     usedRect: lastLineUsedRect,
                                     characterRange: lastLineCharacterRange,
                                     lastVisibleCharacterIndex: lastVisibleCharacterIndex)
    }

    private func isLeftToRightLine(lineRect: CGRect, usedRect: CGRect, characterIndex: Int) -> Bool {
        let paragraphStyle = textStorage.attributes(at: clampedCharacterIndex(characterIndex), effectiveRange: nil)[.paragraphStyle] as? NSParagraphStyle
        let writingDirection = paragraphStyle?.baseWritingDirection
        return (lineRect.minX - usedRect.minX) < 0.001 || writingDirection != .rightToLeft
    }

    private func defaultTruncationToken(at characterIndex: Int) -> NSMutableAttributedString {
        let attributes = textStorage.attributes(at: clampedCharacterIndex(characterIndex), effectiveRange: nil)
        var replaceAttributes = [NSAttributedString.Key : Any]()
        replaceAttributes[.font] = attributes[.font]
        replaceAttributes[.paragraphStyle] = attributes[.paragraphStyle]
        replaceAttributes[.foregroundColor] = attributes[.foregroundColor] ?? UIColor.black
        return NSMutableAttributedString(string: TextToken.truncation.rawValue, attributes: replaceAttributes)
    }

    private func applyTruncationTokenForegroundColor(_ token: NSMutableAttributedString, at characterIndex: Int) {
        guard token.length > 0, textStorage.length > 0 else { return }
        if let foregroundColor = textStorage.attribute(.foregroundColor, at: clampedCharacterIndex(characterIndex), effectiveRange: nil) {
            token.addAttribute(.foregroundColor, value: foregroundColor, range: token.allRange)
        }
    }

    private func clampedCharacterIndex(_ index: Int) -> Int {
        guard textStorage.length > 0 else { return 0 }
        return min(max(index, 0), textStorage.length - 1)
    }

    private func composedCharacterPrefixEnd(_ index: Int, lowerBound: Int, in sourceString: NSString) -> Int {
        let clampedIndex = min(max(index, lowerBound), sourceString.length)
        guard clampedIndex > lowerBound, clampedIndex < sourceString.length else { return clampedIndex }

        let sequenceRange = sourceString.rangeOfComposedCharacterSequence(at: clampedIndex)
        guard sequenceRange.location < clampedIndex else { return clampedIndex }
        return max(lowerBound, sequenceRange.location)
    }

    private func composedCharacterSuffixStart(_ index: Int, upperBound: Int, in sourceString: NSString) -> Int {
        let clampedUpperBound = min(max(upperBound, 0), sourceString.length)
        let clampedIndex = min(max(index, 0), clampedUpperBound)
        guard clampedIndex < clampedUpperBound, clampedIndex < sourceString.length else { return clampedIndex }

        let sequenceRange = sourceString.rangeOfComposedCharacterSequence(at: clampedIndex)
        guard sequenceRange.location < clampedIndex else { return clampedIndex }
        return min(clampedUpperBound, sequenceRange.upperBound)
    }

    private func middleTruncationPrefix(from start: Int, to end: Int, fitting targetWidth: CGFloat, widthMeasurer: LineWidthMeasurer, sourceString: NSString) -> (end: Int, width: CGFloat) {
        guard start < end, targetWidth > 0 else { return (start, 0) }

        var low = start
        var high = end
        var result = start
        var resultWidth: CGFloat = 0
        while low <= high {
            let mid = (low + high) / 2
            let rangeEnd = composedCharacterPrefixEnd(mid, lowerBound: start, in: sourceString)
            let range = NSRange(location: start, length: rangeEnd - start)
            let width = widthMeasurer.width(in: range)
            if width <= targetWidth {
                result = rangeEnd
                resultWidth = width
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return (result, resultWidth)
    }

    private func middleTruncationSuffixStart(from lowerBound: Int, to end: Int, fitting targetWidth: CGFloat, widthMeasurer: LineWidthMeasurer, sourceString: NSString) -> Int {
        guard lowerBound < end, targetWidth > 0 else { return end }

        var low = 0
        var high = end - lowerBound
        var resultLength = 0
        while low <= high {
            let length = (low + high) / 2
            let start = composedCharacterSuffixStart(end - length, upperBound: end, in: sourceString)
            let range = NSRange(location: start, length: end - start)
            if widthMeasurer.width(in: range) <= targetWidth {
                resultLength = end - start
                low = length + 1
            } else {
                high = length - 1
            }
        }
        return end - resultLength
    }

}
