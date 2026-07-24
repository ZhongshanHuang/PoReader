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
        while parsedLength < textStorage.length {
            let textContainer = NSTextContainer(size: constraintSize)
            textContainer.lineBreakMode = .byCharWrapping
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            layoutManager.ensureLayout(for: textContainer)

            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            guard characterRange.length > 0 else {
                pages.append(PageLayout(range: NSRange(location: parsedLength, length: textStorage.length - parsedLength),
                                        usedSize: constraintSize))
                break
            }

            let usedRect = layoutManager.usedRect(for: textContainer)
            pages.append(PageLayout(range: characterRange,
                                    usedSize: CGSize(width: ceil(usedRect.width), height: ceil(usedRect.height))))
            parsedLength = characterRange.upperBound
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
