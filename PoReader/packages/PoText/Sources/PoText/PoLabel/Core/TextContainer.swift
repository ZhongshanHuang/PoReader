import UIKit

public struct TextContainer: @unchecked Sendable {
    /// 系统默认的maxSize，十进制：65536
    public static let maxSize: CGSize = CGSize(width: 0x10000, height: 0x10000)

    // MARK: - Properties - [public]
    
    public var asNSTextContainer: NSTextContainer {
        var newSize = CGSize(width: size.width - insets.horizontalValue, height: size.height - insets.verticalValue)
        if newSize.width < 0 {
            newSize.width = 0
        }
        if newSize.height < 0 {
            newSize.height = 0
        }
        let container = NSTextContainer(size: newSize)
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = maximumNumberOfLines
        if lineBreakMode.isNeedTruncation { // 发生这几种截断的时候NSlayoutManager glyphRange计算不准确
            container.lineBreakMode = .byWordWrapping
        } else {
            container.lineBreakMode = lineBreakMode
        }
        if let exclusionPaths {
            container.exclusionPaths = exclusionPaths
        }
        return container
    }

    /// The constrained size. (if the size is larger than maxSize, it will be clipped.)
    private var _size: CGSize = .zero
    public var size : CGSize {
        get { _size }
        set {
            _size = newValue
            if newValue.width > TextContainer.maxSize.width {
                _size.width = TextContainer.maxSize.width
            }
            if newValue.height > TextContainer.maxSize.height {
                _size.height = TextContainer.maxSize.height
            }
        }
    }

    /// The insets for constrained size. The inset value should not be negative.
    private var _insets: UIEdgeInsets = .zero
    public var insets: UIEdgeInsets {
        get { _insets }
        set {
            var value = newValue
            if value.top < 0 { value.top = 0 }
            if value.left < 0 { value.left = 0 }
            if value.bottom < 0 { value.bottom = 0 }
            if value.right < 0 { value.right = 0 }
            _insets = value
        }
    }

    /// An array of UIBezierPath for path exclusion. Default is nil.
    var exclusionPaths: [UIBezierPath]?

    /// Maximum number of rows, 0 means no limit.
    public var maximumNumberOfLines: Int = 0

    /// The line truncation type.
    public var lineBreakMode: NSLineBreakMode = .byTruncatingTail

    /// The truncation token. If nil, the layout will use '...'instead.
    public var tailTruncationToken: NSAttributedString?

    // MARK: - Initializers
    public init(size: CGSize = .zero, insets: UIEdgeInsets = .zero) {
        self.size = size
        self.insets = insets
    }

}

extension NSLineBreakMode {
    var isNeedTruncation: Bool {
        self == .byTruncatingTail || self == .byTruncatingMiddle || self == .byTruncatingHead
    }
}
