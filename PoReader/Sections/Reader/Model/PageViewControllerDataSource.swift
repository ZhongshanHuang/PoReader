//
//  PageViewControllerDataSource.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/18.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

class PageViewControllerDataSource: NSObject {
    
    // MARK: - Properties
    
    var name: String?
    var sourcePath: URL?
    
    private var text: NSString?
    private(set) var chapters: [ChapterModel]?
    
    /// 是否是背面页
    private var isReversePage = true
    
    func parseChapter() {
        guard let sourcePath = sourcePath else { return }
        text = try? NSString(contentsOf: sourcePath, encoding: String.Encoding.utf8.rawValue)

        if text == nil {
            text = try? NSString(contentsOf: sourcePath, encoding: 0x80000632) // GB18030
        }
        guard let text = text else {
            debugPrint("load file faile")
            return
        }

//        let pattern = #"(?<=\s)[第]{0,1}[0-9零一二三四五六七八九十百千万]+[章节卷集部篇](?: |　|：){0,4}(?:\S)*"#
        let pattern = #"\s{1}第(.{1,7})(章|节|集|卷|部|篇)"#
        let expression = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let matchResults = expression.matches(in: text as String, options: .reportCompletion, range: NSRange(location: 0, length: text.length))
        
        var chapterArr = [ChapterModel]()
        if !matchResults.isEmpty && (text.length / matchResults.count) < 30000 { // 防止章节太大，导致分页计算耗时太长

            var lastRange = NSRange()
            for (idx, value) in matchResults.enumerated() {
                let range = value.range
                if idx == 0 {
                    if range.location - lastRange.upperBound > 100 {
                        let aRange = NSRange(location: 0, length: range.location)
                        let chapter = ChapterModel(title: "序言", content: text.substring(with: aRange), range: aRange)
                        chapterArr.append(chapter)
                        lastRange = range
                    } else {
                        lastRange.length = range.upperBound - lastRange.location
                    }
                } else {
                    if range.location - lastRange.upperBound < 50 { // 有可能是目录页，将其合并
                        lastRange.length = range.upperBound - lastRange.location
                    } else {
                        let aRange = NSRange(location: lastRange.location, length: range.location - lastRange.location)
                        let chapter = ChapterModel(title: text.substring(with: lastRange), content: text.substring(with: aRange), range: aRange)
                        chapterArr.append(chapter)
                        lastRange = range
                    }

                }
            }

            let aRange = NSRange(location: lastRange.location, length: text.length - lastRange.location)
            let chapter = ChapterModel(title: text.substring(with: lastRange), content: text.substring(with: aRange), range: aRange)
            chapterArr.append(chapter)
        } else { // 文本没有章节划分，默认按照1万字/章划分
            let totalCount = text.length
            var currentLocal = 0

            while currentLocal < totalCount {
                let length = min(totalCount - currentLocal, 10000)
                let range = NSRange(location: currentLocal, length: length)
                let chapter = ChapterModel(content: text.substring(with: range), range: range)
                chapterArr.append(chapter)
                currentLocal += range.length
            }
        }

        chapters = chapterArr
    }
    
    // 重新计算章节内部分页(因为采用的懒加载，所以这儿其实只删除了之前的分页结果)
    func updateChapterSubrange() {
        chapters?.forEach({ $0.updateSubranges() })
    }
}

// MARK: - Helper

extension PageViewControllerDataSource {
    
    /// 获取pageItem O(1)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: pageItem
    func pageItem(atChapter chapterIndex: Int, subrangeIndex: Int) -> PageItem? {
        guard let chapters = chapters else { return nil }
        
        if chapterIndex >= chapters.count {
            return nil
        }
        let chapter = chapters[chapterIndex]
        if subrangeIndex >= chapter.subranges.count {
            return nil
        }
        
        let pageItem = PageItem()
        pageItem.header = name
        pageItem.chapterIndex = chapterIndex
        pageItem.subrangeIndex = subrangeIndex
        pageItem.content = (chapter.content as NSString).substring(with: chapter.subranges[subrangeIndex])
        pageItem.progress = progress(atChapter: chapterIndex, subrangeIndex: subrangeIndex)
        return pageItem
    }
    
    
    /// 获取一个页的反面，不添加反面页的话暗黑模式时 反面会显示白色刺眼 O(1)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: reversePageItem
    private func reversePageItem(atChapter chapterIndex: Int, subrangeIndex: Int) -> ReversePageItem {
        let reverseItem = ReversePageItem()
        reverseItem.chapterIndex = chapterIndex
        reverseItem.subrangeIndex = subrangeIndex
        return reverseItem
    }
    
    /// 获取章节内部分页索引 O(log n)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - sublocation: 章节内部分页的一个字符位置
    /// - Returns: subrangeIndex
    func chapterSubrangeIndex(atChapter chapterIndex: Int, sublocation: Int) -> Int? {
        guard let chapters = chapters else { return nil }
        
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
        let chapter = chapters![chapterIndex]
        
        let pageItem = PageItem()
        pageItem.chapterIndex = chapterIndex
        pageItem.subrangeIndex = subrangeIndex
        pageItem.content = (chapter.content as NSString).substring(with: chapter.subranges[subrangeIndex])
        return pageItem
    }
    
    
    /// 获取当前章节分页首字符在整个文本中的位置 O(1)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: location
    func location(atChapter chapterIndex: Int, subrangeIndex: Int) -> Int? {
        guard let chapters = chapters else { return nil }
        
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
        guard let chapters = chapters else { return 0 }
        if chapterIndex == chapters.count - 1 && subrangeIndex == chapters[chapterIndex].subranges.count - 1 {
            return 1
        }
        
        if let location = location(atChapter: chapterIndex, subrangeIndex: subrangeIndex) {
            return Float(location) / Float(text!.length)
        }
        return 0
    }
    
    
    /// 获取当前分页首字符在当前章节文本中的位置 O(1)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: sublocation
    func chapterSublocation(atChapter chapterIndex: Int, subrangeIndex: Int) -> Int? {
        guard let chapters = chapters else { return nil }
        
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
        guard let chapters = chapters else { return nil }

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

// MARK: - UIPageViewControllerDataSource

extension PageViewControllerDataSource: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let chapters = chapters else { return nil }

        if let pageItem = viewController as? PageItem {
            if pageItem.subrangeIndex == 0 {
                if pageItem.chapterIndex == 0 {
                    return nil
                } else {
                    let chapter = chapters[pageItem.chapterIndex - 1]
                    return reversePageItem(atChapter: pageItem.chapterIndex - 1, subrangeIndex: chapter.subranges.count - 1)
                }
            }
            return reversePageItem(atChapter: pageItem.chapterIndex, subrangeIndex: pageItem.subrangeIndex - 1)
        } else if let reverseItem = viewController as? ReversePageItem {
            return pageItem(atChapter: reverseItem.chapterIndex, subrangeIndex: reverseItem.subrangeIndex)
        } else {
            return nil
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let chapters = chapters else { return nil }
        
        if let reverseItem = viewController as? ReversePageItem {
            let chapter = chapters[reverseItem.chapterIndex]
            if reverseItem.subrangeIndex >= chapter.subranges.count - 1 {
                if reverseItem.chapterIndex >= chapters.count - 1 {
                    return nil
                } else {
                    return pageItem(atChapter: reverseItem.chapterIndex + 1, subrangeIndex: 0)
                }
            }
            return pageItem(atChapter: reverseItem.chapterIndex, subrangeIndex: reverseItem.subrangeIndex + 1)
        } else if let pageItem = viewController as? PageItem {
            return reversePageItem(atChapter: pageItem.chapterIndex, subrangeIndex: pageItem.subrangeIndex)
        } else {
            return nil
        }
    }

}
