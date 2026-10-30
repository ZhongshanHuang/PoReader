import UIKit

// MARK: - PoAttributeContainer
@dynamicMemberLookup
/// A value type for collecting attributes that can be applied to a rich text
/// fragment or to an entire builder result.
public struct PoAttributeContainer: @unchecked Sendable {
    public private(set) var attributes: [NSAttributedString.Key: Any]

    public subscript<T: PoAttributedStringKey>(_: T.Type) -> T.Value? {
        get {
            guard let value = attributes[T.name] else { return nil }
            if let typedValue = value as? T.Value { return typedValue }
            if (T.name == .underlineStyle || T.name == .strikethroughStyle),
               let rawValue = value as? Int {
                return NSUnderlineStyle(rawValue: rawValue) as? T.Value
            }
            return nil
        }
        set {
            guard let newValue else {
                attributes.removeValue(forKey: T.name)
                return
            }
            if let underline = newValue as? NSUnderlineStyle { // Foundation stores this as an Int.
                attributes[T.name] = underline.rawValue
            } else {
                attributes[T.name] = newValue
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
        var container: PoAttributeContainer

        public func callAsFunction(_ value: T.Value) -> PoAttributeContainer {
            var new = container
            new[T.self] = value
            return new
        }
    }

    public init() {
        attributes = [:]
    }

    public init(_ attributes: [NSAttributedString.Key: Any]) {
        self.attributes = attributes
    }

    public init(attributes: [NSAttributedString.Key: Any] = [:]) {
        self.attributes = attributes
    }

    /// Returns a copy with the supplied attributes taking precedence.
    public func addingAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Self {
        var copy = self
        copy.merge(PoAttributeContainer(attributes))
        return copy
    }

    /// Returns a copy with the supplied container taking precedence.
    public func adding(_ container: Self) -> Self {
        merging(container)
    }

    /// Returns a copy without the supplied attribute key.
    public func removingAttribute(_ key: NSAttributedString.Key) -> Self {
        var copy = self
        copy.attributes.removeValue(forKey: key)
        return copy
    }
}

// MARK: - AttributeContainer + merge
extension PoAttributeContainer {
    public enum AttributeMergePolicy: Sendable {
        case keepNew
        case keepCurrent
    }

    public mutating func merge(_ other: PoAttributeContainer,
                               mergePolicy: PoAttributeContainer.AttributeMergePolicy = .keepNew) {
        self.attributes.merge(other.attributes) { v1, v2 in
            switch mergePolicy {
            case .keepNew:
                v2
            case .keepCurrent:
                v1
            }
        }
    }

    public func merging(_ other: PoAttributeContainer,
                        mergePolicy: PoAttributeContainer.AttributeMergePolicy = .keepNew) -> PoAttributeContainer {
        var copy = self
        copy.merge(other, mergePolicy:  mergePolicy)
        return copy
    }
}
