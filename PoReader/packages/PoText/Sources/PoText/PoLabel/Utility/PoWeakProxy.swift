import Foundation

// MARK: - PoWeakProxy

// swift don't support NSProxy
final class PoWeakProxy: NSObject {
    weak var target: AnyObject?
    
    init(target: AnyObject) {
        self.target = target
    }
    
    override func responds(to aSelector: Selector!) -> Bool {
        return target?.responds(to: aSelector) ?? false
    }
    
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        return target
    }
}
