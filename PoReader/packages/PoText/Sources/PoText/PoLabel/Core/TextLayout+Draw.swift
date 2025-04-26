import UIKit

extension TextLayout {
    
    /// 对外绘制接口（可以异步）
    public func draw(in ctx: CGContext, at point: CGPoint, size: CGSize) {
        if state.isNeedDrawBlockBorder {
            drawBlockBorder(in: ctx, at: point, size: size)
        }
        
        if state.isNeedDrawBorder {
            drawBorder(in: ctx, at: point, size: size)
        }
        
        drawImageAttachments(in: ctx, at: point, size: size)
        layoutManager.drawGlyphs(forGlyphRange: visibleGlyphRange, at: point)
    }
    
    /// 将uiView，caLayer类型的attachment添加到container（必须在主线程）
    @MainActor
    public func drawAttachments(in container: UIView, at point: CGPoint, size: CGSize) {
        if !state.isNeedDrawAttachment { return }
        
        attachmentInfos.forEach { (attachment, proposedRect) in
            var rect = proposedRect
            let contentSize = attachment.content.contentSize
            rect = rect.inset(by: attachment.contentInsets)
            rect = rect.fitWithContentMode(attachment.contentMode, in: contentSize)
            rect = rect.pixelRound
            rect = rect.standardized
            rect.origin.x += point.x
            rect.origin.y += point.y
            
            switch attachment.content {
            case .image:
                break
            case .layer(let layer):
                layer.frame = rect
                container.layer.addSublayer(layer)
            case .view(let view):
                view.frame = rect
                container.addSubview(view)
            }
        }
    }
    
    private func drawImageAttachments(in ctx: CGContext, at point: CGPoint, size: CGSize) {
        if !state.isNeedDrawAttachment { return }
    
        attachmentInfos.forEach { (attachment, proposedRect) in
            switch attachment.content {
            case .image(let image):
                var rect = proposedRect
                let contentSize = attachment.content.contentSize
                rect = rect.inset(by: attachment.contentInsets)
                rect = rect.fitWithContentMode(attachment.contentMode, in: contentSize)
                rect = rect.pixelRound
                rect = rect.standardized
                rect.origin.x += point.x
                rect.origin.y += point.y
                
                if let cgImage = image.cgImage {
                    ctx.saveGState()
                    ctx.translateBy(x: 0, y: rect.maxY + rect.minY)
                    ctx.scaleBy(x: 1, y: -1)
                    ctx.draw(cgImage, in: rect)
                    ctx.restoreGState()
                }
            case .layer, .view:
                break
            }
        }
    }
    
    /// border
    private func drawBorder(in ctx: CGContext, at point: CGPoint, size: CGSize) {
        if borderInfos.isEmpty {
            textStorage.enumerateAttribute(.poBorder, in: visibleCharacterRange) { value, range, stop in
                guard let border = value as? TextBorder else { return }
                borderInfos[border] = rects(forCharacterRange: range)
            }
        }
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.translateBy(x: point.x, y: point.y)
        borderInfos.forEach { (border, rects) in
            TextDrawIMP.drawBorderRects(in: ctx, border: border, size: size, rects: rects)
        }
    }
    
    /// blockBoder
    private func drawBlockBorder(in ctx: CGContext, at point: CGPoint, size: CGSize) {
        if blockBorderInfos.isEmpty {
            textStorage.enumerateAttribute(.poBlockBorder, in: visibleCharacterRange) { value, range, stop in
                guard let border = value as? TextBorder else { return }
                
                var borderRect: CGRect?
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if glyphRange.location == NSNotFound { return }
                layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer) { rect, stop in
                    if borderRect == nil {
                        borderRect = rect
                        borderRect?.size.width = size.width
                    } else {
                        borderRect = borderRect!.union(rect)
                    }
                }
                if let borderRect {
                    blockBorderInfos[border] = [borderRect]
                }
            }
        }
        
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.translateBy(x: point.x, y: point.y)
        
        blockBorderInfos.forEach { (border, rects) in
            TextDrawIMP.drawBorderRects(in: ctx, border: border, size: size, rects: rects)
        }
    }
    
    // MARK: - help
    
    private func rects(forCharacterRange targetCharacterRange: NSRange) -> [CGRect] {
        var rects = [CGRect]()
        if let firstLineIndex = lineInfoIndex(for: targetCharacterRange.location) {
            if let lastLineIndex = lineInfoIndex(for: targetCharacterRange.upperBound - 1), lastLineIndex != firstLineIndex { // 多行
                for lineIndex in firstLineIndex...lastLineIndex {
                    let lineInfo = lineInfos[lineIndex]
                    let characterRange: NSRange
                    if lineIndex == firstLineIndex {
                        characterRange = NSRange(location: targetCharacterRange.location, length: lineInfo.characterRange.length - (targetCharacterRange.location - lineInfo.characterRange.location))
                    } else if lineIndex == lastLineIndex {
                        characterRange = NSRange(location: lineInfo.characterRange.location, length: targetCharacterRange.upperBound - lineInfo.characterRange.location)
                    } else {
                        characterRange = lineInfo.characterRange
                    }
                    if let rect = rectInLine(forCharacterRange: characterRange, lineIndex: lineIndex) {
                        rects.append(rect)
                    }
                }
            } else { // 只有一行
                if let rect = rectInLine(forCharacterRange: targetCharacterRange, lineIndex: firstLineIndex) {
                    rects.append(rect)
                }
            }
        }
        return rects
    }
    
    /// 在一行中characterRange的rect
    private func rectInLine(forCharacterRange characterRange: NSRange, lineIndex: Int) -> CGRect? {
        if characterRange.length <= 0 { return nil }
        // line后面有换行符时boundingRect会返回整行的宽度，不符合预期故剔除
        var characterRange = characterRange
        let lastChar = (textStorage.string as NSString).substring(with: NSRange(location: characterRange.upperBound - 1, length: 1))
        if lastChar == "\r" {
            characterRange = NSRange(location: characterRange.location, length: characterRange.length - 1)
        } else if lastChar == "\n" {
            if characterRange.length >= 2, (textStorage.string as NSString).substring(with: NSRange(location: characterRange.upperBound - 2, length: 1)) == "\r" {
                characterRange = NSRange(location: characterRange.location, length: characterRange.length - 2)
            } else {
                characterRange = NSRange(location: characterRange.location, length: characterRange.length - 1)
            }
        }
        if characterRange.length <= 0 { return nil }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        if glyphRange.location == NSNotFound { return nil }
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        // lineSpacing会影响boundingRect的高度，不符合预期故剔除
        if lineIndex != lineInfos.count - 1,
            let paragraphStyle = textStorage.attribute(.paragraphStyle, at: characterRange.location, effectiveRange: nil) as? NSParagraphStyle,
           paragraphStyle.lineSpacing > .leastNonzeroMagnitude {
            rect.size.height -= paragraphStyle.lineSpacing
        }
        return rect
    }
    
    /// 根据characterIndex查找所在line的索引
    func lineInfoIndex(for characterIndex: Int) -> Int? {
        if lineInfos.isEmpty { return nil }
        if characterIndex < 0 || characterIndex >= textStorage.length { return nil }
        var low = 0
        var high = lineInfos.count
        while low <= high {
            let mid = (low + high) / 2
            if lineInfos[mid].characterRange.upperBound <= characterIndex {
                low = mid + 1
            } else if lineInfos[mid].characterRange.location > characterIndex {
                high = mid - 1
            } else {
                return mid
            }
        }
        return nil
    }
    
    func isInLastLine(for characterIndex: Int) -> Bool {
        if let lastLine = lineInfos.last,
            characterIndex >= lastLine.characterRange.location && characterIndex < lastLine.characterRange.upperBound {
            return true
        }
        return false
    }
    
}

enum TextDrawIMP {
    static func drawBorderRects(in context: CGContext, border: TextBorder, size: CGSize, rects: [CGRect]) {
        if rects.isEmpty { return }
        
        var isShadowWork = false
        if let shadow = border.shadow {
            isShadowWork = true
            context.saveGState()
            let shadowColor: CGColor = shadow.color.cgColor
            context.setShadow(offset: shadow.offset, blur: shadow.blur, color: shadowColor)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        
        var paths = [CGPath]()
        for var rect in rects {
            rect = rect.inset(by: border.insets)
            rect = rect.pixelRound
            let path = CGPath(roundedRect: rect, cornerWidth: border.cornerRadius, cornerHeight: border.cornerRadius, transform: nil)
            paths.append(path)
        }
        
        if let fillColor = border.fillColor {
            context.saveGState()
            context.setFillColor(fillColor.cgColor)
            for path in paths {
                context.addPath(path)
            }
            context.fillPath()
            context.restoreGState()
        }
        
        // 只有style的时候才画线，单独设置pattern不进行绘画
        if border.strokeColor != nil && (border.lineStyle.rawValue & TextLineStyle.styleMask.rawValue) > 0 && border.strokeWidth > 0 {
            
            //------------------------- single line -------------------------//
            context.saveGState()
            for path in paths {
                var bounds = path.boundingBoxOfPath.union(CGRect(origin: .zero, size: size))
                bounds = bounds.insetBy(dx: -2 * border.strokeWidth, dy: -2 * border.strokeWidth)
                context.addRect(bounds)
                context.addPath(path)
                context.clip(using: .evenOdd)
            }
            context.setStrokeColor(border.strokeColor!.cgColor)
            context.setLineWidth(border.strokeWidth)
            context.setLineCap(.butt)
            context.setLineJoin(.miter)
            
            if (border.lineStyle.rawValue & TextLineStyle.patternMask.rawValue) > 0 {
                setLinePattern(in: context, style: border.lineStyle, width: border.strokeWidth, phase: 0)
            }
            
            var inset = -border.strokeWidth * 0.5
            if (border.lineStyle.rawValue & TextLineStyle.styleMask.rawValue) == TextLineStyle.thick.rawValue {
                inset *= 2
                context.setLineWidth(border.strokeWidth * 2)
            }
            var radiusDelta = -inset
            if border.cornerRadius <= 0 {
                radiusDelta = 0
            }
            context.setLineJoin(border.lineJoin)
            for var rect in rects {
                rect = rect.inset(by: border.insets)
                rect = rect.insetBy(dx: inset, dy: inset)
                let corner = border.cornerRadius + radiusDelta
                let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
                context.addPath(path)
            }
            context.strokePath()
            context.restoreGState()
            
            //------------------------- second line -------------------------//
            if (border.lineStyle.rawValue & TextLineStyle.styleMask.rawValue) == TextLineStyle.double.rawValue {
                context.saveGState()
                var inset = -border.strokeWidth * 2
                for var rect in rects {
                    rect = rect.inset(by: border.insets)
                    rect = rect.insetBy(dx: inset, dy: inset)
                    let corner = border.cornerRadius + 2 * border.strokeWidth
                    let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
                    var bounds = path.boundingBoxOfPath.union(CGRect(origin: .zero, size: size))
                    bounds = bounds.insetBy(dx: -2 * border.strokeWidth, dy: -2 * border.strokeWidth)
                    context.addRect(bounds)
                    context.addPath(path)
                    context.clip(using: .evenOdd)
                }
                context.setStrokeColor(border.strokeColor!.cgColor)
                context.setLineWidth(border.strokeWidth)
                setLinePattern(in: context, style: border.lineStyle, width: border.strokeWidth, phase: 0)
                context.setLineJoin(border.lineJoin)
                inset = -border.strokeWidth * 2.5
                radiusDelta = border.strokeWidth * 2
                if border.cornerRadius <= 0 {
                    radiusDelta = 0
                }
                for var rect in rects {
                    rect = rect.inset(by: border.insets)
                    rect = rect.insetBy(dx: inset, dy: inset)
                    let corner = border.cornerRadius + radiusDelta
                    let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
                    context.addPath(path)
                }
                context.strokePath()
                context.restoreGState()
            }
        }
        
        if isShadowWork {
            context.endTransparencyLayer()
            context.restoreGState()
        }
    }


    private static func setLinePattern(in context: CGContext, style: TextLineStyle, width: CGFloat, phase: CGFloat) {
        let dash: CGFloat = 12
        let dot: CGFloat = 5
        let space: CGFloat = 3
        var lengths = [CGFloat]()
        let pattern = style.rawValue & TextLineStyle.patternMask.rawValue
        
        if pattern == TextLineStyle.patternDot.rawValue {
            lengths = [width * dot, width * space]
        } else if pattern == TextLineStyle.patternDash.rawValue {
            lengths = [width * dash, width * space]
        } else if pattern == TextLineStyle.patternDashDot.rawValue {
            lengths = [width * dash, width * space, width * dot, width * space]
        } else if pattern == TextLineStyle.patternDashDotDot.rawValue {
            lengths = [width * dash, width * space,width * dot, width * space, width * dot, width * space]
        } else if pattern == TextLineStyle.patternCircleDot.rawValue {
            lengths = [width * 0, width * space]
            context.setLineCap(.round)
            context.setLineJoin(.round)
        }
        
        context.setLineDash(phase: phase, lengths: lengths)
    }
}
