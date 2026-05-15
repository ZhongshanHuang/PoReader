import UIKit

final class ReaderDataSource {
    
    // MARK: - Properties
    
    var name: String?
    var sourcePath: URL?
    
    private var text: NSString?
    private(set) var chapters: [ChapterModel] = []
    
    func parseChapter() {
        guard let sourcePath = sourcePath, let data = try? Data(contentsOf: sourcePath) else { return }

        guard let text = TextFileDecoder.decode(data) else {
            print("load file faile")
            return
        }
        self.text = text

        let chapterArr = ChineseNovelChapterParser.parse(text: text)
        #if DEBUG
        print("章节数: \(chapterArr.count)")
        chapterArr.forEach { model in
            print(model)
        }
        #endif
        chapters = chapterArr
    }
    
    // 重新计算章节内部分页(因为采用的懒加载，所以这儿其实只删除了之前的分页结果)
    func updateChapterSubrange() {
        chapters.forEach({ $0.updateSubranges() })
    }
}

// MARK: - Helper

extension ReaderDataSource {
    
    /// 获取pageItem O(1)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: pageItem
    func pageItem(atChapter chapterIndex: Int, subrangeIndex: Int) -> PageItem? {
        if chapterIndex >= chapters.count {
            return nil
        }
        let chapter = chapters[chapterIndex]
        if subrangeIndex >= chapter.subranges.count {
            return nil
        }
        let pageItem = PageItem(chapterIndex: chapterIndex,
                                subrangeIndex: subrangeIndex,
                                content: chapter.content.substring(with: chapter.subranges[subrangeIndex]),
                                progress: progress(atChapter: chapterIndex, subrangeIndex: subrangeIndex),
                                header: chapter.title ?? name)
        return pageItem
    }
    
    
    /// 获取章节内部分页索引 O(log n)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - sublocation: 章节内部分页的一个字符位置
    /// - Returns: subrangeIndex
    func chapterSubrangeIndex(atChapter chapterIndex: Int, sublocation: Int) -> Int? {
        if chapterIndex >= chapters.count { return nil }
        let chapter = chapters[chapterIndex]
        if sublocation >= chapter.range.length { return nil }
        
        var start = 0
        var end = chapter.subranges.count - 1
        
        while start <= end {
            let mid = start + (end - start) / 2
            let subrange = chapter.subranges[mid]
            if sublocation < subrange.location {
                end = mid - 1
            } else if sublocation >= subrange.upperBound {
                start = mid + 1
            } else {
                return mid
            }
        }
        return nil
    }
    
    
    /// 根据文本一个字符的位置查找到显示的页 O(log n + log m)
    /// - Parameter location: 文本中某一个字的location
    /// - Returns: pageItem
    func pageItem(at location: Int) -> PageItem? {
        guard let (chapterIndex, subrangeIndex) = searchPageLocation(location: location) else { return nil }
        let chapter = chapters[chapterIndex]
        
        let pageItem = PageItem(chapterIndex: chapterIndex,
                                subrangeIndex: subrangeIndex,
                                content: chapter.content.substring(with: chapter.subranges[subrangeIndex]),
                                progress: progress(atChapter: chapterIndex, subrangeIndex: subrangeIndex),
                                header: chapter.title ?? name)
        return pageItem
    }
    
    
    /// 获取当前章节分页首字符在整个文本中的位置 O(1)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: location
    func location(atChapter chapterIndex: Int, subrangeIndex: Int) -> Int? {
        if chapterIndex >= chapters.count {
            return nil
        }
        let chapter = chapters[chapterIndex]
        if subrangeIndex >= chapter.subranges.count {
            return nil
        }
        let subrange = chapter.subranges[subrangeIndex]
        return chapter.range.location + subrange.location
    }
    
    
    /// 获取当前章节分页在整个文本中的位置比例
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: progress
    func progress(atChapter chapterIndex: Int, subrangeIndex: Int) -> Float {
        if chapterIndex == chapters.count - 1 && subrangeIndex == chapters[chapterIndex].subranges.count - 1 {
            return 1
        }
        
        if let text, let location = location(atChapter: chapterIndex, subrangeIndex: subrangeIndex) {
            return Float(location) / Float(text.length)
        }
        return 0
    }
    
    
    /// 获取当前分页首字符在当前章节文本中的位置 O(1)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: sublocation
    func chapterSublocation(atChapter chapterIndex: Int, subrangeIndex: Int) -> Int? {
        if chapterIndex >= chapters.count {
            return nil
        }
        let chapter = chapters[chapterIndex]
        if subrangeIndex >= chapter.subranges.count {
            return nil
        }
        return chapter.subranges[subrangeIndex].location
    }
    
    
    /// 查找文本某个字符在哪章节，哪页
    /// - Parameter location: 文本某个字符的位置
    /// - Returns: 字符所在章节和分页的索引
    func searchPageLocation(location: Int) -> (chapterIndex: Int, subrangeIndex: Int)? {
        var low = 0
        var up = chapters.count - 1
        var chapterIndex = -1
        
        while low <= up {
            let mid = low + (up - low) / 2
            let chapter = chapters[mid]
            if location < chapter.range.location {
                up = mid - 1
            } else if location >= chapter.range.upperBound {
                low = mid + 1
            } else {
                chapterIndex = mid
                break
            }
        }
        
        if chapterIndex == -1 { return nil }
        
        let chapter = chapters[chapterIndex]
        
        let newLocation = location - chapter.range.location
        var start = 0
        var end = chapter.subranges.count - 1
        
        while start <= end {
            let mid = start + (end - start) / 2
            let subrange = chapter.subranges[mid]
            if newLocation < subrange.location {
                end = mid - 1
            } else if newLocation >= subrange.upperBound {
                start = mid + 1
            } else {
                return (chapterIndex, mid)
            }
        }
        return nil
    }
}
