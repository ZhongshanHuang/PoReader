import Testing
import UIKit
@testable import PoText

@MainActor
@Test func numberOfLinesSetterStoresClampedValue() {
    let label = PoLabel()

    label.numberOfLines = 3
    #expect(label.numberOfLines == 3)

    label.numberOfLines = -1
    #expect(label.numberOfLines == 0)
}

@MainActor
@Test func textLayoutReflectsNumberOfLinesConfiguration() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 40))
    label.font = UIFont.systemFont(ofSize: 17)
    label.numberOfLines = 1
    label.text = "PoText should wrap into more than one line when constrained."

    #expect(label.textLayout?.numberOfLines == 1)
}

@MainActor
@Test func emptyTextSettersDoNotInvalidateEmptyLabel() {
    let label = PoLabel()

    label.text = nil
    label.text = ""
    label.attributedText = nil
    label.attributedText = NSAttributedString()

    #expect(label._innerText.length == 0)
    #expect(!label._state.isLayoutNeedUpdate)
}

@MainActor
@Test func clearingAlreadyEmptyAttributedTextDoesNotInvalidateAgain() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 160, height: 40))
    label.attributedText = NSAttributedString(string: "content",
                                              attributes: [.font: UIFont.systemFont(ofSize: 17)])
    _ = label.textLayout

    label.attributedText = nil
    #expect(label._innerText.length == 0)
    #expect(label._state.isLayoutNeedUpdate)

    label._state.isLayoutNeedUpdate = false
    label.attributedText = nil
    label.attributedText = NSAttributedString()

    #expect(!label._state.isLayoutNeedUpdate)
}

@MainActor
@Test func lineInfoLookupHandlesVisibleCharacters() {
    let text = NSAttributedString(
        string: "PoText line lookup",
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    let layout = TextLayout(attributedString: text, container: TextContainer(size: CGSize(width: 90, height: 100)))

    #expect(layout.attributedString.string == text.string)
    #expect(layout.lineInfoIndex(for: 0) != nil)
    #expect(layout.lineInfoIndex(for: text.length - 1) != nil)
}

@MainActor
@Test func textLayoutAttributedStringSnapshotIsCachedAndIndependent() {
    let text = NSMutableAttributedString(
        string: "snapshot",
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    let layout = TextLayout(attributedString: text, container: TextContainer(size: CGSize(width: 120, height: 40)))

    text.mutableString.setString("mutated")
    let firstSnapshot = layout.attributedString
    let secondSnapshot = layout.attributedString

    #expect(firstSnapshot.string == "snapshot")
    #expect(firstSnapshot === secondSnapshot)
}

@MainActor
@Test func highlightTouchBuildsLayoutBeforeLookupAndResetsState() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
    let highlightRange = NSRange(location: 0, length: 3)
    var tappedRange = NSRange(location: NSNotFound, length: 0)
    var tappedText: String?

    let text = NSMutableAttributedString(
        string: "tap target",
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    let highlight = TextHighlight(foregroundColor: .red) { _, text, range in
        tappedRange = range
        tappedText = text?.string
    }
    text.addAttribute(.poHighlight, value: highlight, range: highlightRange)
    label.attributedText = text

    #expect(label._innerLayout == nil)

    let touchPoint = labelPoint(forCharacterAt: 1, attributedText: text, label: label)
    #expect(label._handleTouchBegan(at: touchPoint) == false)
    #expect(label._innerLayout != nil)
    #expect(label._state.showHighlight)
    #expect(label._highlightRange == highlightRange)

    #expect(label._handleTouchEnded() == false)
    #expect(tappedRange == highlightRange)
    #expect(tappedText == "tap target")
    #expect(label._highlight == nil)
    #expect(!label._state.trackingTouch)
    #expect(!label._state.swallowTouch)
    #expect(!label._state.touchMoved)
}

@MainActor
@Test func highlightWithoutVisualAttributesSkipsHighlightRenderingState() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
    let highlightRange = NSRange(location: 0, length: 3)
    var tapCount = 0

    let text = NSMutableAttributedString(
        string: "tap target",
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    var highlight = TextHighlight()
    highlight.tapAction = { _, _, _ in tapCount += 1 }
    text.addAttribute(.poHighlight, value: highlight, range: highlightRange)
    label.attributedText = text

    let touchPoint = labelPoint(forCharacterAt: 1, attributedText: text, label: label)
    #expect(label._handleTouchBegan(at: touchPoint) == false)
    #expect(label._highlight != nil)
    #expect(!label._state.showHighlight)
    #expect(!label._state.contentsNeedFade)

    #expect(label._handleTouchEnded() == false)
    #expect(tapCount == 1)
}

@MainActor
@Test func longPressHighlightDoesNotAlsoFireTapOnTouchEnd() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
    let highlightRange = NSRange(location: 0, length: 4)
    var tapCount = 0
    var longPressCount = 0

    let text = NSMutableAttributedString(
        string: "hold target",
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    var highlight = TextHighlight()
    highlight.foregroundColor = .red
    highlight.tapAction = { _, _, _ in tapCount += 1 }
    highlight.longPressAction = { _, _, _ in longPressCount += 1 }
    text.addAttribute(.poHighlight, value: highlight, range: highlightRange)
    label.attributedText = text

    let touchPoint = labelPoint(forCharacterAt: 1, attributedText: text, label: label)
    #expect(label._handleTouchBegan(at: touchPoint) == false)

    label._trackDidLongPress()
    #expect(longPressCount == 1)

    #expect(label._handleTouchEnded() == false)
    #expect(tapCount == 0)
    #expect(!label._state.longPressTriggered)
    #expect(!label._state.trackingTouch)
    #expect(!label._state.swallowTouch)
}

@MainActor
@Test func middleTruncationPreservesVisibleStartAndEnd() {
    let text = NSAttributedString(
        string: "abcdefghijklmnopqrstuvwxyz",
        attributes: [.font: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)]
    )
    var container = TextContainer(size: CGSize(width: 120, height: 24))
    container.maximumNumberOfLines = 1
    container.lineBreakMode = .byTruncatingMiddle

    let layout = TextLayout(attributedString: text, container: container)
    let displayedText = layout.attributedString.string
    let isMiddleTruncated: Bool
    if case .middle? = layout.truncationInfo?.type {
        isMiddleTruncated = true
    } else {
        isMiddleTruncated = false
    }

    #expect(isMiddleTruncated)
    #expect(displayedText.contains(TextToken.truncation.rawValue))
    #expect(displayedText.hasPrefix("abc"))
    #expect(displayedText.hasSuffix("xyz"))
}

@MainActor
@Test func middleTruncationPreservesComposedCharacterBoundaries() {
    let leadingEmoji = "👨‍👩‍👧‍👦"
    let trailingEmoji = "👩🏽‍💻"
    let visiblePrefix = "start "
    let visibleSuffix = trailingEmoji + " end"
    let text = NSAttributedString(
        string: visiblePrefix + "abcdefghijklmnopqrstuvwxyz" + leadingEmoji + visibleSuffix,
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    var container = TextContainer(size: CGSize(width: 320, height: 34))
    container.maximumNumberOfLines = 1
    container.lineBreakMode = .byTruncatingMiddle

    let layout = TextLayout(attributedString: text, container: container)
    let displayedText = layout.attributedString.string
    let isMiddleTruncated: Bool
    if case .middle? = layout.truncationInfo?.type {
        isMiddleTruncated = true
    } else {
        isMiddleTruncated = false
    }

    #expect(isMiddleTruncated)
    #expect(displayedText.contains(TextToken.truncation.rawValue))
    #expect(!displayedText.contains("\u{FFFD}"))
    #expect(displayedText.hasPrefix(visiblePrefix))
    #expect(displayedText.hasSuffix(visibleSuffix))
}

@MainActor
@Test func headTruncationPreservesComposedCharacterBoundaries() {
    let trailingEmoji = "👩🏽‍💻"
    let text = NSAttributedString(
        string: "👨‍👩‍👧‍👦abcdefghijklmnopqrstuvwxyz" + trailingEmoji,
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    var container = TextContainer(size: CGSize(width: 150, height: 34))
    container.maximumNumberOfLines = 1
    container.lineBreakMode = .byTruncatingHead

    let layout = TextLayout(attributedString: text, container: container)
    let displayedText = layout.attributedString.string
    let isHeadTruncated: Bool
    if case .head? = layout.truncationInfo?.type {
        isHeadTruncated = true
    } else {
        isHeadTruncated = false
    }

    #expect(isHeadTruncated)
    #expect(displayedText.contains(TextToken.truncation.rawValue))
    #expect(!displayedText.contains("\u{FFFD}"))
    #expect(displayedText.hasSuffix(trailingEmoji))
}

@MainActor
@Test func headTruncationPreservesVisibleTailForContinuousText() {
    let text = NSAttributedString(
        string: "START0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZEND",
        attributes: [.font: UIFont.systemFont(ofSize: 20)]
    )
    var container = TextContainer(size: CGSize(width: 393, height: 46))
    container.maximumNumberOfLines = 1
    container.lineBreakMode = .byTruncatingHead

    let layout = TextLayout(attributedString: text, container: container)
    let displayedText = layout.attributedString.string
    let isHeadTruncated: Bool
    if case .head? = layout.truncationInfo?.type {
        isHeadTruncated = true
    } else {
        isHeadTruncated = false
    }

    #expect(isHeadTruncated)
    #expect(displayedText.contains(TextToken.truncation.rawValue))
    #expect(displayedText != TextToken.truncation.rawValue)
    #expect(displayedText.hasSuffix("END"))
    #expect(layout.textBoundingSize.width <= container.size.width)
}

@MainActor
@Test func headTruncationRelayoutsAfterAutoLayoutWidthChange() {
    let label = PoLabel()
    label.numberOfLines = 1
    label.lineBreakMode = .byTruncatingHead
    label.font = UIFont.systemFont(ofSize: 20)
    label.text = "START0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZEND"

    label.frame = CGRect(x: 0, y: 0, width: 393, height: 46)

    let displayedText = label.textLayout?.attributedString.string ?? ""
    #expect(displayedText.contains(TextToken.truncation.rawValue))
    #expect(displayedText != TextToken.truncation.rawValue)
    #expect(displayedText.hasSuffix("END"))
}

@MainActor
@Test func renderContextSynchronizesContainerSizeBeforeHeadTruncation() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 393, height: 46))
    label.numberOfLines = 1
    label.lineBreakMode = .byTruncatingHead
    label.font = UIFont.systemFont(ofSize: 20)
    label.text = "START0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZEND"

    label._innerContainer.size = .zero
    label._state.isLayoutNeedUpdate = true

    let context = label.asyncLayerPrepareForRenderContext()
    let displayedText = context.resolveLayout()?.attributedString.string ?? ""

    #expect(context.container.size == label.bounds.size)
    #expect(displayedText.contains(TextToken.truncation.rawValue))
    #expect(displayedText != TextToken.truncation.rawValue)
    #expect(displayedText.hasSuffix("END"))
}

@MainActor
@Test func headTruncationDrawsVisibleTailPixels() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 393, height: 46))
    label.isDisplayedAsynchronously = false
    label.numberOfLines = 1
    label.textVerticalAlignment = .center
    label.lineBreakMode = .byTruncatingHead
    label.attributedText = NSAttributedString(
        string: "START0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZEND",
        attributes: [.font: UIFont.systemFont(ofSize: 20),
                     .foregroundColor: UIColor.black]
    )

    label.layer.display()

    guard let contents = label.layer.contents else {
        #expect(Bool(false))
        return
    }
    let image = UIImage(cgImage: contents as! CGImage)

    let imageSize = CGSize(width: image.cgImage!.width, height: image.cgImage!.height)
    #expect(imageHasNonTransparentPixel(image, in: CGRect(x: 0, y: 0, width: imageSize.width * 0.2, height: imageSize.height)))
    #expect(imageHasNonTransparentPixel(image, in: CGRect(x: imageSize.width * 0.75, y: 0, width: imageSize.width * 0.25, height: imageSize.height)))
}

@MainActor
@Test func tailTruncationHandlesRightToLeftParagraph() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.baseWritingDirection = .rightToLeft
    paragraphStyle.alignment = .right
    let text = NSAttributedString(
        string: "אבגדהוזחטיכלמנסעפצקרשת",
        attributes: [.font: UIFont.systemFont(ofSize: 17),
                     .paragraphStyle: paragraphStyle]
    )
    var container = TextContainer(size: CGSize(width: 110, height: 30))
    container.maximumNumberOfLines = 1
    container.lineBreakMode = .byTruncatingTail

    let layout = TextLayout(attributedString: text, container: container)
    let displayedText = layout.attributedString.string
    let isTailTruncated: Bool
    if case .tail? = layout.truncationInfo?.type {
        isTailTruncated = true
    } else {
        isTailTruncated = false
    }

    #expect(isTailTruncated)
    #expect(displayedText.contains(TextToken.truncation.rawValue))
    #expect(!displayedText.contains("\u{FFFD}"))
}

@MainActor
@Test func customTailTruncationTokenHighlightUsesDisplayedText() {
    let font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 120, height: 32))
    label.numberOfLines = 1

    let source = NSAttributedString(
        string: "abcdefghijklmnopqrstuvwxyz",
        attributes: [.font: font]
    )
    let tokenHighlightRange = NSRange(location: 3, length: 4)
    var tappedRange = NSRange(location: NSNotFound, length: 0)
    var tappedText: String?
    var highlight = TextHighlight()
    highlight.foregroundColor = .red
    highlight.tapAction = { _, text, range in
        tappedText = text?.string
        tappedRange = range
    }

    let token = NSMutableAttributedString(
        string: "...more",
        attributes: [.font: font]
    )
    token.addAttribute(.poHighlight, value: highlight, range: tokenHighlightRange)
    label.tailTruncationToken = token
    label.attributedText = source

    guard let layout = label.textLayout, let truncationInfo = layout.truncationInfo else {
        #expect(Bool(false))
        return
    }

    let expectedRange = NSRange(location: truncationInfo.characterRange.location + tokenHighlightRange.location,
                                length: tokenHighlightRange.length)
    let touchPoint = labelPoint(forCharacterAt: expectedRange.location + 1, layout: layout, label: label)
    #expect(label._handleTouchBegan(at: touchPoint) == false)
    #expect(label._highlightText?.string == layout.attributedString.string)
    #expect(label._highlightRange == expectedRange)

    #expect(label._handleTouchEnded() == false)
    #expect(tappedText == layout.attributedString.string)
    #expect(tappedRange == expectedRange)
}

@MainActor
@Test func repeatedEqualBordersAccumulateDrawingRects() {
    let text = NSMutableAttributedString(
        string: "one two three four",
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    let border = TextBorder(fillColor: .yellow)
    let blockBorder = TextBorder(fillColor: .cyan)
    text.po.setTextBorder(border, range: NSRange(location: 0, length: 3))
    text.po.setTextBorder(border, range: NSRange(location: 8, length: 5))
    text.po.setTextBlockBorder(blockBorder, range: NSRange(location: 0, length: 3))
    text.po.setTextBlockBorder(blockBorder, range: NSRange(location: 14, length: 4))

    let layout = TextLayout(attributedString: text,
                            container: TextContainer(size: CGSize(width: 240, height: 80)))

    #expect(layout.borderInfos[border]?.count == 2)
    #expect(layout.blockBorderInfos[blockBorder]?.count == 2)
}

@MainActor
@Test func sameBorderAcrossUnrelatedAttributesUsesSingleDrawingRect() {
    let text = NSMutableAttributedString(
        string: "single border",
        attributes: [.font: UIFont.systemFont(ofSize: 17)]
    )
    let border = TextBorder(fillColor: .yellow)
    text.po.setTextBorder(border, range: text.allRange)
    text.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: 6))
    text.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 7, length: 6))

    let layout = TextLayout(attributedString: text,
                            container: TextContainer(size: CGSize(width: 240, height: 80)))

    #expect(layout.borderInfos[border]?.count == 1)
}

@MainActor
@Test func drawingSeparatedStrokeBorderRectsRendersEachRect() {
    let size = CGSize(width: 120, height: 44)
    let rects = [
        CGRect(x: 8, y: 10, width: 32, height: 18),
        CGRect(x: 76, y: 10, width: 32, height: 18)
    ]
    let border = TextBorder(lineStyle: .single,
                            lineWidth: 2,
                            strokeColor: .red,
                            insets: .zero)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
        TextDrawIMP.drawBorderRects(in: context.cgContext, border: border, size: size, rects: rects)
    }

    #expect(imageHasDominantRedPixel(image, in: rects[0].insetBy(dx: -2, dy: -2)))
    #expect(imageHasDominantRedPixel(image, in: rects[1].insetBy(dx: -2, dy: -2)))
}

@MainActor
@Test func renderContextSnapshotsMutableTextAndContainerReferences() {
    let text = NSMutableAttributedString(string: "before")
    let token = NSMutableAttributedString(string: "more")
    let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 4, height: 4))
    var container = TextContainer(size: CGSize(width: 100, height: 40))
    container.tailTruncationToken = token
    container.exclusionPaths = [path]

    let context = PoAsyncLayerRenderContext(text: text,
                                            container: container,
                                            verticalAlignment: .center,
                                            contentsNeedFade: false,
                                            fadeForAsync: false,
                                            textContainerInsets: .zero)

    text.mutableString.setString("after")
    token.mutableString.setString("changed")
    path.append(UIBezierPath(rect: CGRect(x: 10, y: 10, width: 10, height: 10)))

    let copiedPath = context.container.exclusionPaths!.first!
    #expect(context.text.string == "before")
    #expect(context.container.tailTruncationToken?.string == "more")
    #expect(copiedPath !== path)
    #expect(copiedPath.bounds == CGRect(x: 0, y: 0, width: 4, height: 4))
}

@MainActor
@Test func synchronousRenderContextReusesCommittedLayoutWithoutCopyingText() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 160, height: 40))
    label.isDisplayedAsynchronously = false
    label.text = "reuse committed layout"

    let layout = label.textLayout
    let context = label.asyncLayerPrepareForRenderContext()

    #expect(context.layout === layout)
    #expect(context.text.length == 0)
    #expect(context.hasRenderableContent)
}

@MainActor
@Test func synchronousRenderContextBuildsPendingLayoutWithoutCopyingText() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 160, height: 40))
    label.isDisplayedAsynchronously = false
    label.text = "pending synchronous layout"

    #expect(label._state.isLayoutNeedUpdate)

    let context = label.asyncLayerPrepareForRenderContext()

    #expect(context.layout != nil)
    #expect(context.text.length == 0)
    #expect(context.shouldCommitLayout)
    #expect(context.hasRenderableContent)
}

@MainActor
@Test func asynchronousRenderContextReusesCommittedLayoutWithoutCopyingText() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 160, height: 40))
    label.isDisplayedAsynchronously = true
    label.text = "reuse committed layout"

    let layout = label.textLayout
    let context = label.asyncLayerPrepareForRenderContext()

    #expect(context.layout === layout)
    #expect(context.text.length == 0)
    #expect(context.hasRenderableContent)
}

@MainActor
@Test func synchronousDisplayWithReusedLayoutStillDrawsContents() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 180, height: 40))
    label.isDisplayedAsynchronously = false
    label.text = "draw reused layout"
    _ = label.textLayout
    label.layer.contents = nil

    label.layer.display()

    #expect(label.layer.contents != nil)
}

@MainActor
@Test func viewAndLayerAttachmentsAreTrackedAfterDisplay() {
    let font = UIFont.systemFont(ofSize: 17)
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 220, height: 50))
    label.isDisplayedAsynchronously = false

    let view = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    let layer = CALayer()
    layer.bounds = CGRect(x: 0, y: 0, width: 12, height: 12)

    let text = NSMutableAttributedString(string: "attachments ", attributes: [.font: font])
    text.append(NSAttributedString.po.attachmentString(with: .view(view),
                                                       size: CGSize(width: 10, height: 10),
                                                       alignToFont: font,
                                                       verticalAlignment: .center))
    text.append(NSAttributedString.po.attachmentString(with: .layer(layer),
                                                       size: CGSize(width: 12, height: 12),
                                                       alignToFont: font,
                                                       verticalAlignment: .center))
    label.attributedText = text

    label.layer.display()

    #expect(label._attachmentViews.count == 1)
    #expect(label._attachmentLayers.count == 1)
    #expect(label._attachmentViews.first === view)
    #expect(label._attachmentLayers.first === layer)
    #expect(view.superview === label)
    #expect(layer.superlayer === label.layer)
}

@MainActor
@Test func imageAttachmentsSkipHostedAttachmentPass() {
    let font = UIFont.systemFont(ofSize: 17)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in
        UIColor.systemBlue.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10)).fill()
    }
    let text = NSMutableAttributedString(string: "image ", attributes: [.font: font])
    text.append(NSAttributedString.po.attachmentString(with: .image(image),
                                                       size: CGSize(width: 10, height: 10),
                                                       alignToFont: font,
                                                       verticalAlignment: .center))

    let layout = TextLayout(attributedString: text,
                            container: TextContainer(size: CGSize(width: 120, height: 40)))

    #expect(layout.imageAttachmentInfos.count == 1)
    #expect(layout.hostedAttachmentInfos.isEmpty)

    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 120, height: 40))
    label.isDisplayedAsynchronously = false
    label.attributedText = text
    label.layer.display()

    #expect(label._attachmentViews.isEmpty)
    #expect(label._attachmentLayers.isEmpty)
}

@MainActor
@Test func emptyTextDisplayClearsContentsWithoutRenderingImage() {
    let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
    let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in
        UIColor.red.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1, height: 1)).fill()
    }
    label.layer.contents = image.cgImage
    #expect(label.layer.contents != nil)

    label.layer.display()

    #expect(label.layer.contents == nil)
}

@MainActor
private func labelPoint(forCharacterAt characterIndex: Int, attributedText: NSAttributedString, label: PoLabel) -> CGPoint {
    let layout = TextLayout(attributedString: attributedText, container: label._innerContainer)
    return labelPoint(forCharacterAt: characterIndex, layout: layout, label: label)
}

@MainActor
private func labelPoint(forCharacterAt characterIndex: Int, layout: TextLayout, label: PoLabel) -> CGPoint {
    let glyphRange = layout.layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
    var glyphRect = layout.layoutManager.boundingRect(forGlyphRange: glyphRange, in: layout.textContainer)
    if glyphRect.isEmpty {
        glyphRect = layout.lineInfos.first?.usedRect ?? .zero
    }

    var point = CGPoint(x: glyphRect.midX + label.textContainerInsets.left, y: glyphRect.midY)
    switch label.textVerticalAlignment {
    case .center:
        point.y += (label.bounds.height - layout.textBoundingSize.height) * 0.5 + (label.textContainerInsets.top - label.textContainerInsets.bottom) / 2
    case .bottom:
        point.y += (label.bounds.height - layout.textBoundingSize.height) - label.textContainerInsets.bottom
    case .top:
        point.y += label.textContainerInsets.top
    }
    return point
}

private func imageHasDominantRedPixel(_ image: UIImage, in rect: CGRect) -> Bool {
    guard let cgImage = image.cgImage else { return false }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let context = CGContext(data: &pixels,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return false
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let minX = max(0, Int(rect.minX.rounded(.down)))
    let maxX = min(width, Int(rect.maxX.rounded(.up)))
    let minY = max(0, Int(rect.minY.rounded(.down)))
    let maxY = min(height, Int(rect.maxY.rounded(.up)))
    guard minX < maxX, minY < maxY else { return false }

    for y in minY..<maxY {
        for x in minX..<maxX {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let red = pixels[offset]
            let green = pixels[offset + 1]
            let blue = pixels[offset + 2]
            let alpha = pixels[offset + 3]
            if red > 120, green < 80, blue < 80, alpha > 80 {
                return true
            }
        }
    }
    return false
}

private func imageHasNonTransparentPixel(_ image: UIImage, in rect: CGRect) -> Bool {
    guard let cgImage = image.cgImage else { return false }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let context = CGContext(data: &pixels,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return false
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let minX = max(0, Int(rect.minX.rounded(.down)))
    let maxX = min(width, Int(rect.maxX.rounded(.up)))
    let minY = max(0, Int(rect.minY.rounded(.down)))
    let maxY = min(height, Int(rect.maxY.rounded(.up)))
    guard minX < maxX, minY < maxY else { return false }

    for y in minY..<maxY {
        for x in minX..<maxX {
            let offset = y * bytesPerRow + x * bytesPerPixel
            if pixels[offset + 3] > 40 {
                return true
            }
        }
    }
    return false
}
