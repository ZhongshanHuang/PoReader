import UIKit

extension NSParagraphStyle: NameSpaceCompatible {}

extension NameSpaceWrapper where Base: NSParagraphStyle {
    
    static func style(with ctStyle: CTParagraphStyle) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        
        var lineSpacing: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .lineSpacingAdjustment, MemoryLayout<CGFloat>.stride, &lineSpacing) {
            style.lineSpacing = lineSpacing
        }
        
        var paragraphSpacing: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .paragraphSpacing, MemoryLayout<CGFloat>.stride, &paragraphSpacing) {
            style.paragraphSpacing = paragraphSpacing
        }
        
        var alignment: CTTextAlignment = .left
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .paragraphSpacing, MemoryLayout<CTTextAlignment>.stride, &alignment) {
            style.alignment = NSTextAlignment(alignment)
        }
        
        var firstLineHeadIndent: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .firstLineHeadIndent, MemoryLayout<CGFloat>.stride, &firstLineHeadIndent) {
            style.firstLineHeadIndent = firstLineHeadIndent
        }
        
        var headIndent: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .headIndent, MemoryLayout<CGFloat>.stride, &headIndent) {
            style.headIndent = headIndent
        }
        
        var tailIndent: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .tailIndent, MemoryLayout<CGFloat>.stride, &tailIndent) {
            style.tailIndent = tailIndent
        }
        
        var lineBreakMode: CTLineBreakMode = .byTruncatingTail
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .lineBreakMode, MemoryLayout<CTLineBreakMode>.stride, &lineBreakMode) {
            style.lineBreakMode = NSLineBreakMode(rawValue: Int(lineBreakMode.rawValue))!
        }
        
        var minimumLineHeight: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .minimumLineHeight, MemoryLayout<CGFloat>.stride, &minimumLineHeight) {
            style.minimumLineHeight = minimumLineHeight
        }
        
        var maximumLineHeight: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .maximumLineHeight, MemoryLayout<CGFloat>.stride, &maximumLineHeight) {
            style.maximumLineHeight = maximumLineHeight
        }
        
        var baseWritingDirection: CTWritingDirection = .leftToRight
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .maximumLineHeight, MemoryLayout<CTWritingDirection>.stride, &baseWritingDirection) {
            style.baseWritingDirection = NSWritingDirection(rawValue: Int(baseWritingDirection.rawValue))!
        }
        
        var lineHeightMultiple: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .lineHeightMultiple, MemoryLayout<CGFloat>.stride, &lineHeightMultiple) {
            style.lineHeightMultiple = lineHeightMultiple
        }
        
        var paragraphSpacingBefore: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .paragraphSpacingBefore, MemoryLayout<CGFloat>.stride, &paragraphSpacingBefore) {
            style.paragraphSpacingBefore = paragraphSpacingBefore
        }
        
        var tabStops: CFArray?
        var tabStopsPtr: UnsafeMutablePointer<CFArray>? = nil
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .tabStops, MemoryLayout<Array<CTTextTab>>.stride, &tabStopsPtr) {
            var tabs = [NSTextTab]()
            tabStops = tabStopsPtr?.pointee
            if let tabStops {
                let tabStopsArray = tabStops as NSArray
                for obj in tabStopsArray {
                    let ctTab = obj as! CTTextTab
                    let tab = NSTextTab(textAlignment: NSTextAlignment(CTTextTabGetAlignment(ctTab)),
                                                        location: CGFloat(CTTextTabGetLocation(ctTab)),
                                                        options: (CTTextTabGetOptions(ctTab) as? [NSTextTab.OptionKey : Any]) ?? [:])
                    tabs.append(tab)
                }
                
            }
            style.tabStops = tabs
        }
        
        var defaultTabInterval: CGFloat = 0
        if CTParagraphStyleGetValueForSpecifier(ctStyle, .defaultTabInterval, MemoryLayout<CGFloat>.stride, &defaultTabInterval) {
            style.defaultTabInterval = defaultTabInterval
        }
        
        return style
    }
    
    var ctStyle: CTParagraphStyle {
        
        var sets = Array<CTParagraphStyleSetting>()
        
        let ctLineSpacing = withUnsafePointer(to: base.lineSpacing) { UnsafeRawPointer($0) }
        let lineSpacingSet = CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.stride, value: ctLineSpacing)
        sets.append(lineSpacingSet)
        
        let ctAlignment = withUnsafePointer(to: base.alignment.rawValue) { UnsafeRawPointer($0) }
        let alignmentSet = CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.stride, value: ctAlignment)
        sets.append(alignmentSet)
        
        let ctFirstLineheadIndent = withUnsafePointer(to: base.firstLineHeadIndent) { UnsafeRawPointer($0) }
        let firstLineHeadIndentSet = CTParagraphStyleSetting(spec: .firstLineHeadIndent, valueSize: MemoryLayout<CGFloat>.stride, value: ctFirstLineheadIndent)
        sets.append(firstLineHeadIndentSet)
        
        let ctHeadIndent = withUnsafePointer(to: base.headIndent) { UnsafeRawPointer($0) }
        let headIndentSet = CTParagraphStyleSetting(spec: .headIndent, valueSize: MemoryLayout<CGFloat>.stride, value: ctHeadIndent)
        sets.append(headIndentSet)
        
        let ctTailIndent = withUnsafePointer(to: base.tailIndent) { UnsafeRawPointer($0) }
        let tailIndentSet = CTParagraphStyleSetting(spec: .tailIndent, valueSize: MemoryLayout<CGFloat>.stride, value: ctTailIndent)
        sets.append(tailIndentSet)
        
        let ctLineBreakMode = withUnsafePointer(to: base.lineBreakMode.rawValue) { UnsafeRawPointer($0) }
        let lineBreakModeSet = CTParagraphStyleSetting(spec: .lineBreakMode, valueSize: MemoryLayout<CTLineBreakMode>.stride, value: ctLineBreakMode)
        sets.append(lineBreakModeSet)
        
        let ctMinimumLineHeight = withUnsafePointer(to: base.minimumLineHeight) { UnsafeRawPointer($0) }
        let minimumLineHeightSet = CTParagraphStyleSetting(spec: .minimumLineHeight, valueSize: MemoryLayout<CGFloat>.stride, value: ctMinimumLineHeight)
        sets.append(minimumLineHeightSet)
        
        let ctMaximumLineHeight = withUnsafePointer(to: base.maximumLineHeight) { UnsafeRawPointer($0) }
        let maximumLineHeightSet = CTParagraphStyleSetting(spec: .maximumLineHeight, valueSize: MemoryLayout<CGFloat>.stride, value: ctMaximumLineHeight)
        sets.append(maximumLineHeightSet)
        
        let ctBaseWritingDirection = withUnsafePointer(to: base.baseWritingDirection.rawValue) { UnsafeRawPointer($0) }
        let baseWritingDirectionSet = CTParagraphStyleSetting(spec: .baseWritingDirection, valueSize: MemoryLayout<CTWritingDirection>.stride, value: ctBaseWritingDirection)
        sets.append(baseWritingDirectionSet)
        
        let ctLineHeightMultiple = withUnsafePointer(to: base.lineHeightMultiple) { UnsafeRawPointer($0) }
        let lineHeightMultipleSet = CTParagraphStyleSetting(spec: .lineHeightMultiple, valueSize: MemoryLayout<CGFloat>.stride, value: ctLineHeightMultiple)
        sets.append(lineHeightMultipleSet)
        
        let ctParagraphSpacingBefore = withUnsafePointer(to: base.paragraphSpacingBefore) { UnsafeRawPointer($0) }
        let paragraphSpacingBeforeSet = CTParagraphStyleSetting(spec: .paragraphSpacingBefore, valueSize: MemoryLayout<CGFloat>.stride, value: ctParagraphSpacingBefore)
        sets.append(paragraphSpacingBeforeSet)
        
        var ctTabStops = [CTTextTab]()
        for tab in base.tabStops {
            let ctTab = CTTextTabCreate(CTTextAlignment(tab.alignment), Double(tab.location), tab.options as CFDictionary)
            ctTabStops.append(ctTab)
        }
        let ctTabStopsP = ctTabStops.withUnsafeBytes({ $0.baseAddress })
        let tabStopsSet = CTParagraphStyleSetting(spec: .tabStops, valueSize: MemoryLayout<[CTTextTab]>.stride, value: ctTabStopsP!)
        sets.append(tabStopsSet)
        
        let ctDefaultTabInterval = withUnsafePointer(to: base.defaultTabInterval) { UnsafeRawPointer($0) }
        let defaultTabIntervalSet = CTParagraphStyleSetting(spec: .defaultTabInterval, valueSize: MemoryLayout<CGFloat>.stride, value: ctDefaultTabInterval)
        sets.append(defaultTabIntervalSet)
        
        return CTParagraphStyleCreate(&sets, sets.count)
    }
    
}
