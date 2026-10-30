import Foundation
import UIKit.UIView

// MARK: - PoAttributedString

/// A small, value-semantic attributed string used by ``PoTextBuilder``.
///
/// Every transforming operation returns an independent value, so reusing a
/// base fragment cannot accidentally mutate another fragment.
@dynamicMemberLookup
public struct PoAttributedString: @unchecked Sendable {
    private var storage: NSMutableAttributedString

    /// The Foundation representation of this fragment.
    public var content: NSAttributedString {
        storage.copy() as? NSAttributedString ?? NSAttributedString()
    }

    /// Alias matching Foundation's terminology.
    public var attributedString: NSAttributedString { content }

    /// The plain string represented by this fragment.
    public var string: String { storage.string }

    /// The UTF-16 length used by Foundation ranges.
    public var length: Int { storage.length }

    public subscript<T: PoAttributedStringKey>(_: T.Type) -> T.Value? {
        get {
            guard let value = storage.po.attribute(T.name, at: 0) else { return nil }
            if let typedValue = value as? T.Value { return typedValue }
            if (T.name == .underlineStyle || T.name == .strikethroughStyle),
               let rawValue = value as? Int {
                return NSUnderlineStyle(rawValue: rawValue) as? T.Value
            }
            return nil
        }
        set {
            let copy = NSMutableAttributedString(attributedString: storage)
            guard copy.length > 0 else {
                storage = copy
                return
            }
            if let newValue {
                if let underline = newValue as? NSUnderlineStyle {
                    copy.po.addAttribute(T.name, value: underline.rawValue)
                } else {
                    copy.po.addAttribute(T.name, value: newValue)
                }
            } else {
                copy.po.addAttribute(T.name, value: nil)
            }
            storage = copy
        }
    }

    public subscript<K: PoAttributedStringKey>(dynamicMember keyPath: KeyPath<PoAttributeDynamicLookup, K>) -> K.Value? {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }

    public subscript<K: PoAttributedStringKey>(dynamicMember keyPath: KeyPath<PoAttributeDynamicLookup, K>) -> Builder<K> {
        Builder(container: self)
    }

    public struct Builder<T: PoAttributedStringKey>: Sendable {
        var container: PoAttributedString

        public func callAsFunction(_ value: T.Value) -> PoAttributedString {
            var new = container
            new[T.self] = value
            return new
        }
    }

    public init(_ string: String) {
        storage = NSMutableAttributedString(string: string)
    }

    public init(string: String) {
        self.init(string)
    }

    public init(_ attributedString: NSAttributedString) {
        storage = NSMutableAttributedString(attributedString: attributedString)
    }

    public init(attributedString: NSAttributedString) {
        self.init(attributedString)
    }

    /// Creates a fragment from Swift's native ``AttributedString``.
    public init(_ attributedString: AttributedString) {
        self.init(NSAttributedString(attributedString))
    }

    /// Returns a copy with all attributes from the supplied container applied.
    public func attributeContainer(_ container: PoAttributeContainer) -> Self {
        applying { $0.po.addAttributes(container.attributes) }
    }

    public func addingAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Self {
        applying { $0.po.addAttributes(attributes) }
    }

    public func removingAttribute(_ key: NSAttributedString.Key) -> Self {
        applying { $0.po.addAttribute(key, value: nil) }
    }

    private func applying(_ update: (NSMutableAttributedString) -> Void) -> Self {
        let copy = NSMutableAttributedString(attributedString: storage)
        update(copy)
        var result = self
        result.storage = copy
        return result
    }
}

// MARK: - Attachment

/// A builder-compatible attachment fragment.
public struct PoAttachmentString: @unchecked Sendable {
    private let storage: NSAttributedString

    public var content: NSAttributedString {
        storage.copy() as? NSAttributedString ?? NSAttributedString()
    }

    public var attributedString: NSAttributedString { content }

    public init(_ content: TextAttachment.Content,
                size: CGSize? = nil,
                alignToFont: UIFont = .systemFont(ofSize: 17),
                verticalAlignment: TextVerticalAlignment = .center) {
        let contentMode: UIView.ContentMode
        switch verticalAlignment {
        case .top: contentMode = .top
        case .center: contentMode = .center
        case .bottom: contentMode = .bottom
        }
        self.init(content,
                  size: size,
                  alignToFont: alignToFont,
                  contentInsets: .zero,
                  verticalAlignment: verticalAlignment,
                  contentMode: contentMode)
    }

    public init(_ content: TextAttachment.Content,
                size: CGSize? = nil,
                alignToFont: UIFont = .systemFont(ofSize: 17),
                contentInsets: UIEdgeInsets,
                verticalAlignment: TextVerticalAlignment = .center,
                contentMode: UIView.ContentMode = .scaleAspectFit) {
        storage = NSAttributedString.po.attachmentString(with: content,
                                                          size: size,
                                                          alignToFont: alignToFont,
                                                          contentInsets: contentInsets,
                                                          verticalAlignment: verticalAlignment,
                                                          contentMode: contentMode)
    }
}

// MARK: - String + PoAttributedString

extension String: NameSpaceCompatible {}

public extension String {
    /// Converts a string into a typed builder fragment.
    func asAttributedString() -> PoAttributedString {
        PoAttributedString(self)
    }

    /// Short alias for ``asAttributedString()``.
    var attributed: PoAttributedString {
        PoAttributedString(self)
    }
}

public extension NameSpaceWrapper where Base == String {
    /// Converts a string into a typed builder fragment.
    func asAttributedString() -> PoAttributedString {
        PoAttributedString(base)
    }

    /// Short alias for ``asAttributedString()``.
    var attributed: PoAttributedString {
        PoAttributedString(base)
    }
}
