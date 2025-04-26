import UIKit

// MARK: - PoAttributeContainer
@dynamicMemberLookup
public struct PoAttributeContainer: @unchecked Sendable {
    private(set) var attributes : [NSAttributedString.Key : Any]

    public subscript<T: PoAttributedStringKey>(_: T.Type) -> T.Value? {
        get { attributes[T.name] as? T.Value }
        set {
            if newValue is NSUnderlineStyle { // fix attributes
                attributes[T.name] = (newValue as? NSUnderlineStyle)?.rawValue
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
        var container : PoAttributeContainer

        public func callAsFunction(_ value: T.Value) -> PoAttributeContainer {
            var new = container
            new[T.self] = value
            return new
        }
    }

    public init() {
        attributes = [:]
    }
    
    public init(_ attributes: [NSAttributedString.Key : Any]) {
        self.attributes = attributes
    }
    
    public init(attributes: [NSAttributedString.Key : Any] = [:]) {
        self.attributes = attributes
    }
    
}

// MARK: - AttributeContainer + merge
extension PoAttributeContainer {
    public enum AttributeMergePolicy : Sendable {
        case keepNew
        case keepCurrent
    }
    
    public mutating func merge(_ other: PoAttributeContainer, mergePolicy: PoAttributeContainer.AttributeMergePolicy = .keepNew) {
        self.attributes.merge(other.attributes) { v1, v2 in
            switch mergePolicy {
            case .keepNew:
                v2
            case .keepCurrent:
                v1
            }
        }
    }

    public func merging(_ other: PoAttributeContainer, mergePolicy:  PoAttributeContainer.AttributeMergePolicy = .keepNew) -> PoAttributeContainer {
        var copy = self
        copy.merge(other, mergePolicy:  mergePolicy)
        return copy
    }
}


