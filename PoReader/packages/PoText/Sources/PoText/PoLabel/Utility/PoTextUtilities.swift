import UIKit

/*
 
 Unicode 字符集
 用21位表示
 分为17(2^5)个平面，每个平面65536(2^16)
 常用的字符放在基本平面(BMP) U+0000 ~ U+FFFF
 剩下的字符放在辅助平面(SMP) U+010000 ~ U+10FFFF
 
 UTF16
 
 code units(码元)
 code point(码点)
 代理对
 U+D800 ~ U+DFFF 是一个空段
 辅助平面的字符位共有 2^20 个，因此表示这些字符至少需要 20 个二进制位。UTF-16 将这 20 个二进制位分成两半，前 10 位映射在 U+D800 到 U+DBFF，称为高位（H），后 10 位映射在 U+DC00 到 U+DFFF，称为低位（L）。这意味着，一个辅助平面的字符，被拆成两个基本平面的字符表示。
 H = Math.floor((c-0x10000) / 0x400)+0xD800
 L = (c - 0x10000) % 0x400 + 0xDC00
 
 
 UTF8
 
 0000 0000 - 0000 007F    0xxxxxxx
 0000 0080 - 0000 07FF    110xxxxx 10xxxxxx
 0000 0800 - 0000 FFFF    1110xxxx 10xxxxxx 10xxxxxx
 0001 0000 - 0010 FFFF    11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
 
 */

private let poScale = UITraitCollection.current.displayScale

struct PoTextUtilities {
    
    /// 判断字体是否包含emoji
    static func ctFontContainsColorBitmapGlyphs(_ ctFont: CTFont) -> Bool {
        CTFontGetSymbolicTraits(ctFont).contains(.traitColorGlyphs)
    }
    
    /// 判断某个glyph是否emoji
    static func ctGlyphIsEmoji(ctFont: CTFont, glyph: CGGlyph) -> Bool {
        // 判断字体是否包含emoji
        if ctFontContainsColorBitmapGlyphs(ctFont) {
            // glyph是否是emoji
            if CTFontCreatePathForGlyph(ctFont, glyph, nil) == nil {
                return true
            }
        }
        return false
    }
    
    /// Whether the character is 'line break char':
    /// U+000D (\\r or CR)
    /// U+2028 (Unicode line separator)
    /// U+000A (\\n or LF)
    /// U+2029 (Unicode paragraph separator)
    /// U+0085 (Unicode next line)
    static func isLinebreakChar(unichar: unichar) -> Bool {
        switch unichar {
        case 0x000A, 0x000D, 0x2028, 0x2029, 0x0085:
            return true
        default:
            return false
        }
    }
    
    /// Whether the string contains line break char
    static func isLineBreakString(_ str: NSString) -> Bool {
        if str.length == 1 {
            let c = str.character(at: 0)
            return isLinebreakChar(unichar: c)
        } else if str.length == 2 {
            let c0 = str.character(at: 0)
            let c1 = str.character(at: 1)
            return c0 == 0x000D && c1 == 0x000A
        }
        return false
    }
    
    /// If the string has a 'line break' suffix, return the 'line break' length.
    static func lineBreakTailLength(_ str: NSString) -> Int {
        if str.length >= 2 {
            let c2 = str.character(at: str.length - 1)
            if isLinebreakChar(unichar: c2) {
                let c1 = str.character(at: str.length - 2)
                if c1 == 13 && c2 == 10 {
                    return 2
                } else {
                    return 1
                }
            } else {
                return 0
            }
        } else if str.length == 1 {
            return isLinebreakChar(unichar: str.character(at: 0)) ? 1 : 0
        } else {
            return 0
        }
    }
    
}

// MARK: - Pixel alignment

extension CGFloat {
    
    var toPiexl: CGFloat {
        return self * poScale
    }
    
    var fromPixel: CGFloat {
        return self / poScale
    }
    
    var pixelFloor: CGFloat {
        return floor(self * poScale) / poScale
    }
    
    var pixelRound: CGFloat {
        return Darwin.round(self * poScale) / poScale
    }
    
    var pixelCeil: CGFloat {
        return ceil(self * poScale) / poScale
    }
    
    var pixelHalf: CGFloat {
        return (floor(self * poScale) + 0.5) / poScale
    }
    
    /// convert degrees to radians
    var toRadians: CGFloat {
        self * .pi / 180
    }
    
    /// convert radians to degrees
    var toDegrees: CGFloat {
        self * 180 / .pi
    }
}

extension CGPoint {
    
    var pixelFloor: CGPoint {
        CGPoint(x: floor(self.x * poScale) / poScale, y: floor(self.y * poScale) / poScale)
    }
    
    var pixelRound: CGPoint {
        CGPoint(x: round(self.x * poScale) / poScale, y: round(self.y * poScale) / poScale)
    }
    
    var pixelCeil: CGPoint {
        CGPoint(x: ceil(self.x * poScale) / poScale, y: ceil(self.y * poScale) / poScale)
    }

    
    var pixelHalf: CGPoint {
        CGPoint(x: (floor(self.x * poScale) + 0.5) / poScale, y: (floor(self.y * poScale) + 0.5) / poScale)
    }

}

extension CGSize {
    
    var pixelFloor: CGSize {
        CGSize(width: floor(self.width * poScale) / poScale, height: floor(self.height * poScale) / poScale)
    }
    
    var pixelRound: CGSize {
        CGSize(width: round(self.width * poScale) / poScale, height: round(self.height * poScale) / poScale)
    }
    
    var pixelCeil: CGSize {
        CGSize(width: ceil(self.width * poScale) / poScale, height: ceil(self.height * poScale) / poScale)
    }
    
    var pixelHalf: CGSize {
        CGSize(width: (floor(self.width * poScale) + 0.5) / poScale, height: (floor(self.height * poScale) + 0.5) / poScale)
    }
}

extension CGRect {
    
    var pixelFloor: CGRect {
        let origin = self.origin.pixelCeil
        let corner = CGPoint(x: self.maxX, y: self.maxY).pixelFloor
        var rect = CGRect(origin: origin, size: CGSize(width: corner.x - origin.x, height: corner.y - origin.y))
        if rect.width < 0 { rect.size.width = 0 }
        if rect.height < 0 { rect.size.height = 0 }
        return rect
    }
    
    var pixelRound: CGRect {
        let origin = self.origin.pixelRound
        let corner = CGPoint(x: self.maxX, y: self.maxY).pixelRound
        return CGRect(origin: origin, size: CGSize(width: corner.x - origin.x, height: corner.y - origin.y))
    }
    
    var pixelCeil: CGRect {
        let origin = self.origin.pixelFloor
        let corner = CGPoint(x: self.maxX, y: self.maxY).pixelCeil
        return CGRect(origin: origin, size: CGSize(width: corner.x - origin.x, height: corner.y - origin.y))
    }
    
    var pixelHalf: CGRect {
        let origin = self.origin.pixelHalf
        let corner = CGPoint(x: self.maxX, y: self.maxY).pixelHalf
        return CGRect(origin: origin, size: CGSize(width: corner.x - origin.x, height: corner.y - origin.y))
    }
    
    func fitWithContentMode(_ mode: UIView.ContentMode, in size: CGSize) -> CGRect {
        var stdSize = CGSize(width: (size.width < 0 ? -size.width : size.width),
                             height: (size.height < 0 ? -size.height : size.height))
        var stdRect = self.standardized
        let center = CGPoint(x: stdRect.midX, y: stdRect.midY)
        
        switch mode {
        case .scaleAspectFit, .scaleAspectFill:
            if stdRect.width < 0.01 || stdRect.height < 0.01 || stdSize.width < 0.01 || stdSize.height < 0.01 {
                stdRect.origin = center
                stdRect.size = .zero
            } else {
                var scale: CGFloat = 0
                if mode == .scaleAspectFit {
                    if stdSize.width / stdSize.height < stdRect.width / stdRect.height {
                        scale = stdRect.height / stdSize.height
                    } else {
                        scale = stdRect.size.width / stdSize.width
                    }
                } else {
                    if stdSize.width / stdSize.height < stdRect.width / stdRect.height {
                        scale = stdRect.size.width / stdSize.width
                    } else {
                        scale = stdRect.height / stdSize.height
                    }
                }
                stdSize.width *= scale
                stdSize.height *= scale
                stdRect.size = stdSize
                stdRect.origin = CGPoint(x: center.x - stdSize.width * 0.5, y: center.y - stdSize.height * 0.5)
            }
        case .center:
            stdRect.size = stdSize
            stdRect.origin = CGPoint(x: center.x - stdSize.width * 0.5, y: center.y - stdSize.height * 0.5)
        case .top:
            stdRect.origin.x = center.x - stdSize.width * 0.5
            stdRect.size = stdSize
        case .bottom:
            stdRect.origin.x = center.x - stdSize.width * 0.5
            stdRect.origin.y += stdRect.height - stdSize.height
            stdRect.size = stdSize
        case .left:
            stdRect.origin.y = center.y - stdSize.height * 0.5
            stdRect.size = stdSize
        case .right:
            stdRect.origin.y = center.y - stdSize.height * 0.5
            stdRect.origin.x += stdRect.width - stdSize.width
            stdRect.size = stdSize
        case .topLeft:
            stdRect.size = stdSize
        case .topRight:
            stdRect.origin.x += stdRect.width - stdSize.width
            stdRect.size = stdSize
        case .bottomLeft:
            stdRect.origin.y += stdRect.height - stdSize.height
            stdRect.size = stdSize
        case .bottomRight:
            stdRect.origin.x += stdRect.width - stdSize.width
            stdRect.origin.y += stdRect.height - stdSize.height
            stdRect.size = stdSize
        case .scaleToFill, .redraw:
            break
        @unknown default:
            fatalError("UIView.ContentMode: \(mode) has not implement!")
        }
        return stdRect
    }
    
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    
    var area: CGFloat {
        if self.isNull { return 0 }
        let rect = standardized
        return rect.width * rect.height
    }
}

extension UIEdgeInsets {
    
    var pixelFloor: UIEdgeInsets {
        return UIEdgeInsets(top: top.pixelFloor, left: left.pixelFloor, bottom: bottom.pixelFloor, right: right.pixelFloor)
    }
    
    var pixelCeil: UIEdgeInsets {
        return UIEdgeInsets(top: top.pixelCeil, left: left.pixelCeil, bottom: bottom.pixelCeil, right: right.pixelCeil)
    }
    
    func invert() -> UIEdgeInsets {
        return UIEdgeInsets(top: -top, left: -left, bottom: -bottom, right: -right)
    }
    
    var horizontalValue: CGFloat {
        left + right
    }
    
    var verticalValue: CGFloat {
        top + bottom
    }
    
}
