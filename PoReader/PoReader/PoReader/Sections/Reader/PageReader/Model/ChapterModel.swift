import UIKit

extension ChapterModel: CustomStringConvertible {
    var description: String {
        "idx: \(idx), range: \(range), title: \(title, default: "nil")"
    }
}

final class ChapterModel {
    private struct LayoutSignature: Equatable {
        let constraintSize: CGSize
        let fontName: String?
        let fontSize: CGFloat
        let lineBreakMode: NSLineBreakMode
        let lineSpacing: CGFloat
        let paragraphSpacing: CGFloat
        let alignment: NSTextAlignment

        init(attributes: [NSAttributedString.Key: Any], constraintSize: CGSize) {
            let font = attributes[.font] as? UIFont
            let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle

            self.constraintSize = constraintSize
            self.fontName = font?.fontName
            self.fontSize = font?.pointSize ?? 0
            self.lineBreakMode = paragraphStyle?.lineBreakMode ?? .byCharWrapping
            self.lineSpacing = paragraphStyle?.lineSpacing ?? 0
            self.paragraphSpacing = paragraphStyle?.paragraphSpacing ?? 0
            self.alignment = paragraphStyle?.alignment ?? .natural
        }
    }

    private struct PageCache {
        let signature: LayoutSignature
        let layouts: [NSString.PageLayout]
        let ranges: [NSRange]
    }

    let idx: Int
    let title: String?
    let range: NSRange
    private let sourceText: NSString
    private let contentRange: NSRange
    private var _content: NSString?
    var content: NSString {
        if let _content { return _content }
        let value = sourceText.substring(with: contentRange) as NSString
        _content = value
        return value
    }
    private var pageCache: PageCache?
    private var currentPageCache: PageCache {
        let attributes = Appearance.attributes
        let constraintSize = Appearance.displayRect.size
        let signature = LayoutSignature(attributes: attributes, constraintSize: constraintSize)

        if let pageCache, pageCache.signature == signature {
            return pageCache
        }

        let layouts = content.parseToPageLayouts(attributes: attributes, constraintSize: constraintSize)
        let cache = PageCache(signature: signature,
                              layouts: layouts,
                              ranges: layouts.map(\.range))
        pageCache = cache
        _subrangePrefixHeights = nil
        return cache
    }
    var subranges: [NSRange] {
        currentPageCache.ranges
    }
    private var _subrangePrefixHeights: [CGFloat]?
    
    init(idx: Int, title: String? = nil, sourceText: NSString, range: NSRange) {
        self.idx = idx
        self.title = title
        self.sourceText = sourceText
        self.contentRange = range
        self.range = range
    }

    init(idx: Int, title: String? = nil, content: NSString, range: NSRange) {
        self.idx = idx
        self.title = title
        self.sourceText = content
        self.contentRange = NSRange(location: 0, length: content.length)
        self.range = range
    }
    
    func subSize(at idx: Int) -> CGSize {
        currentPageCache.layouts[idx].usedSize
    }
    
    func totalSubrangeHeight() -> CGFloat {
        return prefixHeights().last ?? 0
    }
    
    func subrangeHeight(before idx: Int) -> CGFloat {
        guard idx > 0 else { return 0 }
        let heights = prefixHeights()
        return heights[min(idx, heights.count) - 1]
    }
    
    /// 只需要删除之前的即可，访问时再解析
    func updateSubranges() {
        pageCache = nil
        _subrangePrefixHeights = nil
    }

    private func prefixHeights() -> [CGFloat] {
        let layouts = currentPageCache.layouts
        if let _subrangePrefixHeights { return _subrangePrefixHeights }

        var heights: [CGFloat] = []
        heights.reserveCapacity(layouts.count)
        var height: CGFloat = 0
        for layout in layouts {
            height += layout.usedSize.height
            heights.append(height)
        }
        _subrangePrefixHeights = heights
        return heights
    }
}
