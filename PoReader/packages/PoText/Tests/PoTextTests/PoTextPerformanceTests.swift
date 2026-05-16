import UIKit
import XCTest
@testable import PoText

final class PoTextPerformanceTests: XCTestCase {

    private static let runPerformanceTestsKey = "POTEXT_RUN_PERFORMANCE_TESTS"

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard Self.shouldRunPerformanceTests else {
            throw XCTSkip("Set OTHER_SWIFT_FLAGS=-D\(Self.runPerformanceTestsKey) to run PoText performance baselines.")
        }
    }

    private static var shouldRunPerformanceTests: Bool {
        #if POTEXT_RUN_PERFORMANCE_TESTS
        true
        #else
        ProcessInfo.processInfo.environment[runPerformanceTestsKey] == "1"
        #endif
    }

    func testLongTextLayoutPerformance() {
        let text = Self.longAttributedText(repetitions: 260)
        let container = TextContainer(size: CGSize(width: 220, height: 2_000))

        measure(options: Self.measureOptions()) {
            autoreleasepool {
                let layout = TextLayout(attributedString: text, container: container)
                XCTAssertGreaterThan(layout.numberOfLines, 0)
            }
        }
    }

    func testBorderHeavyLayoutPerformance() {
        let text = Self.borderHeavyText(repetitions: 180)
        let container = TextContainer(size: CGSize(width: 240, height: 2_000))

        measure(options: Self.measureOptions()) {
            autoreleasepool {
                let layout = TextLayout(attributedString: text, container: container)
                XCTAssertFalse(layout.borderInfos.isEmpty)
                XCTAssertFalse(layout.blockBorderInfos.isEmpty)
            }
        }
    }

    func testImageAttachmentLayoutPerformance() {
        let text = Self.imageAttachmentText(count: 80)
        let container = TextContainer(size: CGSize(width: 260, height: 2_000))

        measure(options: Self.measureOptions()) {
            autoreleasepool {
                let layout = TextLayout(attributedString: text, container: container)
                XCTAssertEqual(layout.imageAttachmentInfos.count, 80)
            }
        }
    }

    func testMiddleTruncationLayoutPerformance() {
        let text = Self.longAttributedText(repetitions: 80)
        var container = TextContainer(size: CGSize(width: 180, height: 28))
        container.maximumNumberOfLines = 1
        container.lineBreakMode = .byTruncatingMiddle

        measure(options: Self.measureOptions()) {
            autoreleasepool {
                let layout = TextLayout(attributedString: text, container: container)
                XCTAssertNotNil(layout.truncationInfo)
            }
        }
    }

    @MainActor
    func testHighlightTouchLookupPerformance() {
        let label = PoLabel(frame: CGRect(x: 0, y: 0, width: 260, height: 60))
        label.isDisplayedAsynchronously = false
        label.attributedText = Self.highlightText()
        guard let layout = label.textLayout else {
            XCTFail("Expected layout")
            return
        }
        let point = Self.labelPoint(forCharacterAt: 12, layout: layout, label: label)

        measure(options: Self.measureOptions()) {
            autoreleasepool {
                XCTAssertFalse(label._handleTouchBegan(at: point))
                XCTAssertFalse(label._handleTouchEnded())
            }
        }
    }

    private static func measureOptions() -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 8
        return options
    }

    private static func longAttributedText(repetitions: Int) -> NSAttributedString {
        let paragraph = "PoText lays out attributed text with UIKit, truncation, borders, highlights, and attachments. "
        let text = String(repeating: paragraph, count: repetitions)
        let value = NSMutableAttributedString(string: text,
                                              attributes: [.font: UIFont.systemFont(ofSize: 17),
                                                           .foregroundColor: UIColor.label])
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        paragraphStyle.lineBreakMode = .byWordWrapping
        value.addAttribute(.paragraphStyle, value: paragraphStyle, range: value.allRange)
        return value
    }

    private static func borderHeavyText(repetitions: Int) -> NSAttributedString {
        let text = NSMutableAttributedString(string: String(repeating: "border block ", count: repetitions),
                                             attributes: [.font: UIFont.systemFont(ofSize: 16)])
        let border = TextBorder(fillColor: UIColor.yellow.withAlphaComponent(0.35),
                                cornerRadius: 3,
                                insets: UIEdgeInsets(top: -2, left: -1, bottom: -2, right: -1))
        let blockBorder = TextBorder(fillColor: UIColor.cyan.withAlphaComponent(0.2),
                                     cornerRadius: 2,
                                     insets: UIEdgeInsets(top: -1, left: -2, bottom: -1, right: -2))
        var location = 0
        while location < text.length {
            let borderLength = min(6, text.length - location)
            text.po.setTextBorder(border, range: NSRange(location: location, length: borderLength))
            if location.isMultiple(of: 24) {
                let blockLength = min(12, text.length - location)
                text.po.setTextBlockBorder(blockBorder, range: NSRange(location: location, length: blockLength))
            }
            location += 13
        }
        return text
    }

    private static func imageAttachmentText(count: Int) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 17)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in
            UIColor.systemBlue.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 10, height: 10), cornerRadius: 2).fill()
        }
        let text = NSMutableAttributedString(string: "", attributes: [.font: font])
        for index in 0..<count {
            text.append(NSAttributedString(string: "item\(index) ", attributes: [.font: font]))
            text.append(NSAttributedString.po.attachmentString(with: .image(image),
                                                               size: CGSize(width: 10, height: 10),
                                                               alignToFont: font,
                                                               verticalAlignment: .center))
        }
        return text
    }

    private static func highlightText() -> NSAttributedString {
        let text = NSMutableAttributedString(string: "highlight target " + String(repeating: "content ", count: 80),
                                             attributes: [.font: UIFont.systemFont(ofSize: 17)])
        var highlight = TextHighlight()
        highlight.foregroundColor = .systemRed
        highlight.tapAction = { _, _, _ in }
        text.addAttribute(.poHighlight, value: highlight, range: NSRange(location: 10, length: 6))
        return text
    }

    @MainActor
    private static func labelPoint(forCharacterAt characterIndex: Int, layout: TextLayout, label: PoLabel) -> CGPoint {
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
}
