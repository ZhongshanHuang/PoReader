//
//  PageItem.swift
//  PoReader
//
//  Created by HzS on 2022/10/20.
//

import Foundation

struct PageItem {
    /// 章节索引
    let chapterIndex: Int
    /// 章节内部分页索引
    let subrangeIndex: Int
    /// 分页内容
    let content: String
    /// 进度
    let progress: Float
    /// 书名或者章节名
    let header: String?
    
    init(chapterIndex: Int, subrangeIndex: Int, content: String, progress: Float, header: String? = nil) {
        self.chapterIndex = chapterIndex
        self.subrangeIndex = subrangeIndex
        self.content = content
        self.progress = progress
        self.header = header
    }
}
