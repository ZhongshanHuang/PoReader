import UIKit
import CryptoKit

extension NSString {

    struct PageLayout {
        let range: NSRange
        let usedSize: CGSize
    }

    /// Ranges only: skips `usedRect(for:)` and the intermediate `[PageLayout]` array.
    func parseToPage(attributes: [NSAttributedString.Key: Any], constraintSize: CGSize) -> [NSRange] {
        var ranges = [NSRange]()
        enumeratePageLayouts(attributes: attributes, constraintSize: constraintSize, computesUsedSize: false) { page in
            ranges.append(page.range)
            return true
        }
        return ranges
    }

    func parseToPageLayouts(attributes: [NSAttributedString.Key: Any], constraintSize: CGSize) -> [PageLayout] {
        var pages = [PageLayout]()
        enumeratePageLayouts(attributes: attributes, constraintSize: constraintSize) { page in
            pages.append(page)
            return true
        }
        return pages
    }

    // MARK: - Streaming core

    /// Lays out one page at a time and hands each finished page to `body` right away.
    ///
    /// - Return `false` from `body` to stop early (e.g. the user changed the font size and this job is stale).
    /// - `body` runs synchronously on the calling thread.
    /// - Pass `computesUsedSize: false` if only ranges are needed; `usedSize` is then `.zero`.
    /// - Returns: `true` if every page was produced, `false` if `body` stopped the enumeration.
    @discardableResult
    func enumeratePageLayouts(attributes: [NSAttributedString.Key: Any],
                              constraintSize: CGSize,
                              computesUsedSize: Bool = true,
                              _ body: (PageLayout) -> Bool) -> Bool {
        guard length > 0, constraintSize.width > 0, constraintSize.height > 0 else { return true }

        #if DEBUG
        let startDate = Date()
        defer { print("page cost seconds: \(Date().timeIntervalSince(startDate))") }
        #endif

        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = false

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        textStorage.setAttributedString(NSAttributedString(string: self as String, attributes: attributes))

        let totalLength = textStorage.length
        var parsedLength = 0
        var parsedGlyphLength = 0
        while parsedLength < totalLength {
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
                let rest = PageLayout(range: NSRange(location: parsedLength, length: totalLength - parsedLength),
                                      usedSize: computesUsedSize ? constraintSize : .zero)
                return body(rest)
            }

            var usedSize = CGSize.zero
            if computesUsedSize {
                let usedRect = layoutManager.usedRect(for: textContainer)
                usedSize = CGSize(width: ceil(usedRect.width), height: ceil(usedRect.height))
            }
            guard body(PageLayout(range: characterRange, usedSize: usedSize)) else { return false }

            parsedLength = characterRange.upperBound
            parsedGlyphLength = glyphRange.upperBound
        }
        return true
    }
}

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
