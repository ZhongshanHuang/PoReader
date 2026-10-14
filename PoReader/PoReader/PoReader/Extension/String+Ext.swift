import UIKit
import CryptoKit

extension NSString {

    struct PageLayout {
        let range: NSRange
        let usedSize: CGSize
    }

    func parseToPage(attributes: [NSAttributedString.Key: Any], constraintSize: CGSize) -> [NSRange] {
        parseToPageLayouts(attributes: attributes, constraintSize: constraintSize).map(\.range)
    }

    func parseToPageLayouts(attributes: [NSAttributedString.Key: Any], constraintSize: CGSize) -> [PageLayout] {
        guard length > 0, constraintSize.width > 0, constraintSize.height > 0 else { return [] }

        var pages = [PageLayout]()
        let date = Date()
        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = false

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        textStorage.setAttributedString(NSAttributedString(string: self as String, attributes: attributes))

        var parsedLength = 0
        var parsedGlyphLength = 0
        while parsedLength < textStorage.length {
            let textContainer = NSTextContainer(size: constraintSize)
            textContainer.lineBreakMode = .byCharWrapping
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            layoutManager.ensureLayout(for: textContainer)

            // The previous page gives us this page's first glyph. Querying its
            // container avoids the expensive reverse lookup in glyphRange(for:).
            // Keep glyph and UTF-16 character offsets separate (emoji/ligatures).
            var glyphRange = NSRange(location: NSNotFound, length: 0)
            var resolvedContainer: NSTextContainer?
            if parsedGlyphLength < layoutManager.firstUnlaidGlyphIndex() {
                resolvedContainer = layoutManager.textContainer(forGlyphAt: parsedGlyphLength,
                                                               effectiveRange: &glyphRange,
                                                               withoutAdditionalLayout: true)
            }
            if resolvedContainer !== textContainer || glyphRange.location != parsedGlyphLength || glyphRange.length == 0 {
                glyphRange = layoutManager.glyphRange(for: textContainer)
            }
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            // Very small containers can return the previous range again. Use the
            // existing remainder fallback instead of appending containers forever.
            guard characterRange.length > 0, characterRange.upperBound > parsedLength else {
                pages.append(PageLayout(range: NSRange(location: parsedLength, length: textStorage.length - parsedLength),
                                        usedSize: constraintSize))
                break
            }

            let usedRect = layoutManager.usedRect(for: textContainer)
            pages.append(PageLayout(range: characterRange,
                                    usedSize: CGSize(width: ceil(usedRect.width), height: ceil(usedRect.height))))
            parsedLength = characterRange.upperBound
            parsedGlyphLength = glyphRange.upperBound
        }

        #if DEBUG
        print("page cost seconds: \(Date().timeIntervalSince(date))")
        #endif
        return pages
    }
    
}

// https://github.com/krzyzanowskim/CryptoSwift
// MARK: - String - MD5
extension String {
    public var md5: String {
        if let data = self.data(using: .utf8, allowLossyConversion: true) {
            let digest = Insecure.MD5.hash(data: data)
            return digest.map({ String(format: "%02hhx", $0) }).joined()
        } else {
            return self
        }
    }
}
