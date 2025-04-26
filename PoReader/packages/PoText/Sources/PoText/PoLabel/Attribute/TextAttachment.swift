import UIKit

extension TextAttachment {
    public enum Content: Hashable, @unchecked Sendable {
        case image(UIImage)
        case view(UIView)
        case layer(CALayer)
        
        var contentSize: CGSize {
            switch self {
            case .image(let uiImage):
                uiImage.size
            case .view(let uiView):
                MainActor.assumeIsolated {
                    uiView.bounds.size
                }
            case .layer(let caLayer):
                caLayer.bounds.size
            }
        }
        
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .image(let uiImage):
                hasher.combine(uiImage)
            case .view(let uiView):
                hasher.combine(uiView)
            case .layer(let caLayer):
                hasher.combine(caLayer)
            }
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.image(let lImage), .image(let rImage)):
                return lImage === rImage
            case (.view(let lView), .view(let rView)):
                return lView === rView
            case (.layer(let lLayer), .layer(let rLayer)):
                return lLayer === rLayer
            default:
                return false
            }
        }
    }
}

public final class TextAttachment: NSTextAttachment {
    
    // MARK: - Properties
    
    /// Supported type: UIImage, UIView, CALayer.
    public let content: TextAttachment.Content
    /// Content dispaly mode.
    public let contentMode: UIView.ContentMode
    /// The insets when drawing content.
    public let contentInsets: UIEdgeInsets
    public let verticalAlignment: TextVerticalAlignment
    public let alignToFont: UIFont
    
    // MARK: - Initializer
    
    /// size为容器大小，如果不设置则会使用content的size作为容器大小
    public init(content: TextAttachment.Content, size: CGSize? = nil, alignToFont: UIFont, contentInsets: UIEdgeInsets = .zero, verticalAlignment: TextVerticalAlignment = .bottom, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.content = content
        self.alignToFont = alignToFont
        self.contentInsets = contentInsets
        self.verticalAlignment = verticalAlignment
        self.contentMode = contentMode
        super.init(data: nil, ofType: nil)
        if #available(iOS 13.0, *) {
            self.image = UIImage()
        }
        self.bounds = CGRect(origin: .zero, size: size ?? content.contentSize)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override  func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        var y = alignToFont.descender
        let size = bounds.size
        switch verticalAlignment {
        case .top:
            y -= size.height - alignToFont.lineHeight
        case .center:
            y -= (size.height - alignToFont.lineHeight) * 0.5
        case .bottom:
            break
        }
        return CGRect(origin: CGPoint(x: 0, y: y), size: size)
    }
    
}

