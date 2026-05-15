import Foundation

extension ChapterModel: CustomStringConvertible {
    var description: String {
        "idx: \(idx), range: \(range), title: \(title, default: "nil")"
    }
}

final class ChapterModel {
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
    private var _subranges: [NSRange]?
    var subranges: [NSRange] {
        if _subranges == nil {
            _subranges = content.parseToPage(attributes: Appearance.attributes, constraintSize: Appearance.displayRect.size)
        }
        return _subranges!
    }
    private var _subsizes: [CGSize]?
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
        if _subsizes == nil {
            _subsizes = Array(repeating: CGSize.zero, count: subranges.count)
        }
        if _subsizes![idx].height == 0 {
            let subStr = content.substring(with: subranges[idx]) as NSString
            let rect = subStr.boundingRect(with: Appearance.displayRect.size, options: [.usesLineFragmentOrigin], attributes: Appearance.attributes, context: nil)
            _subsizes?[idx] = CGSize(width: rect.width, height: ceil(rect.height))
            _subrangePrefixHeights = nil
        }
        return _subsizes![idx]
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
        _subranges = nil
        _subsizes = nil
        _subrangePrefixHeights = nil
    }

    private func prefixHeights() -> [CGFloat] {
        if let _subrangePrefixHeights { return _subrangePrefixHeights }

        var heights: [CGFloat] = []
        heights.reserveCapacity(subranges.count)
        var height: CGFloat = 0
        for idx in subranges.indices {
            height += subSize(at: idx).height
            heights.append(height)
        }
        _subrangePrefixHeights = heights
        return heights
    }
}
