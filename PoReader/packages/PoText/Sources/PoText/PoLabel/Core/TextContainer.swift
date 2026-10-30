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
        if lineBreakMode.isNeedTruncation { // Truncation modes need custom glyph-range handling.
            container.lineBreakMode = .byWordWrapping
        } else {
            container.lineBreakMode = lineBreakMode
        }
        if let exclusionPaths {
            container.exclusionPaths = exclusionPaths
        }
        return container
    }

    /// The constrained size. Values are clamped to the supported TextKit range.
    private var _size: CGSize = .zero
    public var size: CGSize {
        get { _size }
        set { _size = Self.clampedSize(newValue) }
    }

    /// The insets for constrained size. The inset value should not be negative.
    private var _insets: UIEdgeInsets = .zero
    public var insets: UIEdgeInsets {
        get { _insets }
        set { _insets = Self.clampedInsets(newValue) }
    }

    /// An array of UIBezierPath for path exclusion. Default is nil.
    public var exclusionPaths: [UIBezierPath]?

    /// Maximum number of rows, 0 means no limit.
    private var _maximumNumberOfLines = 0
    public var maximumNumberOfLines: Int {
        get { _maximumNumberOfLines }
        set { _maximumNumberOfLines = max(0, newValue) }
    }

    /// The line truncation type.
    public var lineBreakMode: NSLineBreakMode = .byTruncatingTail

    /// The truncation token. If nil, the layout uses an ellipsis.
    public var tailTruncationToken: NSAttributedString?

    // MARK: - Initializers
    public init(size: CGSize = .zero, insets: UIEdgeInsets = .zero) {
        self.size = size
        self.insets = insets
    }

    /// Returns an independent snapshot suitable for layout work.
    public func snapshot() -> TextContainer {
        if exclusionPaths == nil && tailTruncationToken == nil { return self }

        var container = self
        container.exclusionPaths = exclusionPaths?.map { path in
            (path.copy() as? UIBezierPath) ?? path
        }
        container.tailTruncationToken = tailTruncationToken?.copy() as? NSAttributedString
        return container
    }

    private static func clampedSize(_ size: CGSize) -> CGSize {
        CGSize(width: clampedDimension(size.width, maximum: maxSize.width),
               height: clampedDimension(size.height, maximum: maxSize.height))
    }

    private static func clampedInsets(_ insets: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(top: clampedDimension(insets.top, maximum: .greatestFiniteMagnitude),
                     left: clampedDimension(insets.left, maximum: .greatestFiniteMagnitude),
                     bottom: clampedDimension(insets.bottom, maximum: .greatestFiniteMagnitude),
                     right: clampedDimension(insets.right, maximum: .greatestFiniteMagnitude))
    }

    private static func clampedDimension(_ value: CGFloat, maximum: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(0, value), maximum)
    }

}

extension NSLineBreakMode {
    var isNeedTruncation: Bool {
        self == .byTruncatingTail || self == .byTruncatingMiddle || self == .byTruncatingHead
    }
}
