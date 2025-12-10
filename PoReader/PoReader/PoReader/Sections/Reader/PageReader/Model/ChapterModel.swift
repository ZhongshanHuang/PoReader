//
//  ChapterModel.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/18.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

extension ChapterModel: CustomStringConvertible {
    var description: String {
        "idx: \(idx), range: \(range), title: \(title, default: "nil")"
    }
}

final class ChapterModel {
    let idx: Int
    let title: String?
    let content: NSString
    let range: NSRange
    private var _subranges: [NSRange]?
    var subranges: [NSRange] {
        if _subranges == nil {
            _subranges = content.parseToPage(attributes: Appearance.attributes, constraintSize: Appearance.displayRect.size)
        }
        return _subranges!
    }
    private var _subsizes: [CGSize]?
    
    init(idx: Int, title: String? = nil, content: NSString, range: NSRange) {
        self.idx = idx
        self.title = title
        self.content = content
        self.range = range
    }
    
    func subSize(at idx: Int) -> CGSize {
        if _subsizes == nil {
            _subsizes = Array(repeating: CGSize.zero, count: subranges.count)
        }
        if _subsizes![idx].height == 0 {
            let subStr = content.substring(with: subranges[idx]) as NSString
            let rect = subStr.boundingRect(with: Appearance.displayRect.size, options: [.usesLineFragmentOrigin], attributes: Appearance.attributes, context: nil)
            _subsizes?[idx] = CGSize(width: rect.width, height: ceil(rect.height))
        }
        return _subsizes![idx]
    }
    
    func totalSubrangeHeight() -> CGFloat {
        var height: CGFloat = 0
        for idx in 0..<subranges.count {
            height += subSize(at: idx).height
        }
        return height
    }
    
    func subrangeHeight(before idx: Int) -> CGFloat {
        var height: CGFloat = 0
        for i in 0..<idx {
            height += subSize(at: i).height
        }
        return height
    }
    
    /// 只需要删除之前的即可，访问时再解析
    func updateSubranges() {
        _subranges = nil
        _subsizes = nil
    }
}
