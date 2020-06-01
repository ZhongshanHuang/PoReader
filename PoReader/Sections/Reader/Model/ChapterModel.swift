//
//  ChapterModel.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/18.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

class ChapterModel {
    var title: String?
    var content: String
    var range: NSRange
    private var _subranges: [NSRange]?
    var subranges: [NSRange] {
        if _subranges == nil {
            _subranges = content.pageRanges(attributes: Appearance.attributes, constraintSize: Appearance.displayRect.size)
        }
        return _subranges!
    }
    
    init(title: String? = nil, content: String, range: NSRange) {
        self.title = title
        self.content = content
        self.range = range
    }
    
    func updateSubranges() {
        _subranges = nil
    }
}
