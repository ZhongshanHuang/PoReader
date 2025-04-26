import Foundation

public protocol NameSpaceCompatible {
    associatedtype ExtensionTargetType
    var po: NameSpaceWrapper<ExtensionTargetType> { get }
    static var po: NameSpaceWrapper<ExtensionTargetType>.Type { get }
}

extension NameSpaceCompatible {
    
    public var po: NameSpaceWrapper<Self> {
        return NameSpaceWrapper<Self>(self)
    }
    
    public static var po: NameSpaceWrapper<Self>.Type {
        return NameSpaceWrapper<Self>.self
    }
}

public struct NameSpaceWrapper<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}
