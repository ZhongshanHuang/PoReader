import Foundation
import UIKit.UIView
    
// MARK: - PoAttributedString
@dynamicMemberLookup
public struct PoAttributedString: @unchecked Sendable {
    var content: NSAttributedString { storage }
    private let storage: NSMutableAttributedString

    public subscript<T: PoAttributedStringKey>(_: T.Type) -> T.Value? {
        get { storage.po.attribute(T.name, at: 0) as? T.Value }
        set {
            if newValue is NSUnderlineStyle { // fix attributes
                storage.po.addAttribute(T.name, value: (newValue as? NSUnderlineStyle)?.rawValue )
            } else {
                storage.po.addAttribute(T.name, value: newValue)
            }
        }
    }

    public subscript<K: PoAttributedStringKey>(dynamicMember keyPath: KeyPath<PoAttributeDynamicLookup, K>) -> K.Value? {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }

    public subscript<K: PoAttributedStringKey>(dynamicMember keyPath: KeyPath<PoAttributeDynamicLookup, K>) -> Builder<K> {
        return Builder(container: self)
    }

    public struct Builder<T: PoAttributedStringKey>: Sendable {
        var container : PoAttributedString

        public func callAsFunction(_ value: T.Value) -> PoAttributedString {
            var new = container
            new[T.self] = value
            return new
        }
    }

    public init(_ string: String) {
        storage = NSMutableAttributedString(string: string)
    }
    
    public init(_ attributedString: NSAttributedString) {
        storage = NSMutableAttributedString(attributedString: attributedString)
    }
    
    /// add attributeContainer
    public func attributeContainer(_ container: PoAttributeContainer) -> Self {
        storage.po.addAttributes(container.attributes)
        return self
    }
    
}

// MARK: - Attachment
public struct PoAttachmentString: @unchecked Sendable {
    var content: NSAttributedString { storage }
    private let storage: NSAttributedString
    
    public init(_ content: TextAttachment.Content, size: CGSize? = nil, alignToFont: UIFont, verticalAlignment: TextVerticalAlignment) {
        let contentMode: UIView.ContentMode
        switch verticalAlignment {
        case .top:
            contentMode = .top
        case .center:
            contentMode = .center
        case .bottom:
            contentMode = .bottom
        }
        self.init(content, size: size, alignToFont: alignToFont, contentInsets: .zero, verticalAlignment: verticalAlignment, contentMode: contentMode)
    }
    
    public init(_ content: TextAttachment.Content, size: CGSize?, alignToFont: UIFont, contentInsets: UIEdgeInsets, verticalAlignment: TextVerticalAlignment, contentMode: UIView.ContentMode) {
        storage = NSAttributedString.po.attachmentString(with: content, size: size, alignToFont: alignToFont, contentInsets: contentInsets, verticalAlignment: verticalAlignment, contentMode: contentMode)
    }
}

// MARK: - String + PoAttributedString
extension String: NameSpaceCompatible {}

extension NameSpaceWrapper where Base == String {
    public func asAttributedString() -> PoAttributedString {
        PoAttributedString(base)
    }
}
