import Foundation

// MARK: - String isEmpty
extension Optional where Wrapped == String {
    
    var isEmpty: Bool {
        switch self {
        case .some(let value):
            return value.isEmpty
        case .none:
            return true
        }
    }
}

extension NSAttributedString {
    
    var isEmpty: Bool {
        return self.length == 0
    }
    
    public var allRange: NSRange {
        return NSRange(location: 0, length: self.length)
    }
}

extension Optional where Wrapped == NSAttributedString {
    
    var isEmpty: Bool {
        switch self {
        case .some(let value):
            return value.string.isEmpty
        case .none:
            return true
        }
    }
}
