import UIKit
import CryptoKit

extension NSString {
    
//    func parseToPage(attributes: [NSAttributedString.Key: Any], constraintSize: CGSize) -> [NSRange] {
//        var ranges = [NSRange]()
//
//        let attributedStr = NSAttributedString(string: self as String, attributes: attributes)
//        
//        let date = Date()
//        var local = 0
//        repeat {
//            let length = min(999, attributedStr.length - local)
//            let subStr = attributedStr.attributedSubstring(from: NSRange(location: local, length: length))
//            let frameSetter = CTFramesetterCreateWithAttributedString(subStr)
//            let path = UIBezierPath(rect: CGRect(origin: .zero, size: constraintSize))
//            let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path.cgPath, nil)
//            let realRange = CTFrameGetVisibleStringRange(frame)
//            let range = NSRange(location: local, length: realRange.length)
//            ranges.append(range)
//            print(range)
//            local += range.length
//        } while local < attributedStr.length
//            print("page cost seconds: \(Date().timeIntervalSince(date))")
//        return ranges
//    }
    
    func parseToPage(attributes: [NSAttributedString.Key: Any], constraintSize: CGSize) -> [NSRange] {
        var ranges = [NSRange]()
//        print(self)
        let date = Date()
        var local = 0
        let storage = NSTextStorage(string: self as String, attributes: attributes)
        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = false
        storage.addLayoutManager(layoutManager)
        repeat {
            let textContainer = NSTextContainer(size: constraintSize)
            textContainer.lineBreakMode = .byCharWrapping
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            layoutManager.ensureLayout(for: textContainer)
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let range = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            ranges.append(range)
            local += range.length
//            #if DEBUG
//            print(range)
//            print(substring(with: range))
//            #endif
        } while local < storage.length
            #if DEBUG
            print("page cost seconds: \(Date().timeIntervalSince(date))")
            #endif
        return ranges
    }
    
}

// https://github.com/krzyzanowskim/CryptoSwift
// MARK: - String - MD5
extension String {
    public var md5: String {
        if let data = self.data(using: .utf8, allowLossyConversion: true) {
            let digest = Insecure.MD5.hash(data: data)
            return digest.map({ String(format: "%02hhx", $0) }).joined()
        } else {
            return self
        }
    }
}
