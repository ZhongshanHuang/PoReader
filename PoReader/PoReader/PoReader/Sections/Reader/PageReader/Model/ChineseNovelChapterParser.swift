import Foundation

enum ChineseNovelChapterParser {
    private struct Marker {
        let title: String
        let titleRange: NSRange
    }

    private static let targetChapterLength = 10000
    private static let maxChapterLength = 18000
    private static let splitSearchWindow = 2000
    private static let catalogDistance = 120
    private static let maxTitleLength = 48

    private static let chapterNumberToken = #"0-9０-９零〇一二两三四五六七八九十百千万亿壹贰叁肆伍陆柒捌玖拾佰仟萬億"#
    private static let titleTailToken = #"[\p{Han}A-Za-z0-9０-９\s《》“”"'\(\)（）【】\[\]·,:：，。！？!?、.．\-—－]{0,36}"#

    private static let numberedTitleExpression = try! NSRegularExpression(
        pattern: #"^(?:正文\s*)?(?:(?:第\s*[\#(chapterNumberToken)]+\s*[卷部集]\s*)?(?:第\s*)?[\#(chapterNumberToken)]+\s*[章节回篇]|第\s*[\#(chapterNumberToken)]+\s*[卷部集])(?:\s*[:：、.．·\-—－]\s*|\s+)?\#(titleTailToken)$"#
    )
    private static let specialTitleExpression = try! NSRegularExpression(
        pattern: #"^(?:正文\s*)?(?:序章|序言|前言|楔子|引子|尾声|后记|终章|大结局|作品相关|上架感言|番外(?:篇|卷)?(?:\s*[\#(chapterNumberToken)]+)?)(?:\s*[:：、.．·\-—－]\s*|\s+)?\#(titleTailToken)$"#
    )

    static func parse(text: NSString) -> [ChapterModel] {
        let markers = removeCatalogMarkers(from: collectMarkers(in: text), textLength: text.length)
        if !markers.isEmpty {
            return buildChapters(from: markers, text: text)
        }
        return buildFallbackChapters(in: text)
    }

    private static func collectMarkers(in text: NSString) -> [Marker] {
        let fullRange = NSRange(location: 0, length: text.length)
        var markers: [Marker] = []

        text.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let titleRange = trimmedRange(in: text, range: lineRange)
            guard titleRange.length > 0, titleRange.length <= maxTitleLength else { return }

            let title = text.substring(with: titleRange)
            guard isChapterTitle(title) else { return }
            markers.append(Marker(title: title, titleRange: titleRange))
        }
        return markers
    }

    private static func isChapterTitle(_ title: String) -> Bool {
        let value = title.replacingOccurrences(of: "　", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let nsValue = value as NSString
        let range = NSRange(location: 0, length: nsValue.length)
        guard range.length > 0, range.length <= maxTitleLength else { return false }

        if value.localizedCaseInsensitiveContains("http") ||
            value.localizedCaseInsensitiveContains("www.") {
            return false
        }

        return numberedTitleExpression.firstMatch(in: value, range: range) != nil ||
            specialTitleExpression.firstMatch(in: value, range: range) != nil
    }

    private static func removeCatalogMarkers(from markers: [Marker], textLength: Int) -> [Marker] {
        guard markers.count >= 3 else { return markers }

        var ignored = Set<Int>()
        var clusterStart = 0
        var clusterTitles: Set<String> = [markers[0].title]

        func closeCluster(at end: Int) {
            guard end - clusterStart + 1 >= 3 else { return }
            let clusterLocation = markers[clusterStart].titleRange.location
            let isFrontCatalog = clusterLocation < min(80000, max(textLength / 4, 1))
            if isFrontCatalog || end - clusterStart + 1 >= 8 {
                for idx in clusterStart...end {
                    ignored.insert(idx)
                }
            }
        }

        for idx in 1..<markers.count {
            let distance = markers[idx].titleRange.location - markers[idx - 1].titleRange.upperBound
            if distance <= catalogDistance, clusterTitles.contains(markers[idx].title) {
                closeCluster(at: idx - 1)
                clusterStart = idx
                clusterTitles = [markers[idx].title]
                continue
            }

            if distance > catalogDistance {
                closeCluster(at: idx - 1)
                clusterStart = idx
                clusterTitles = [markers[idx].title]
            } else {
                clusterTitles.insert(markers[idx].title)
            }
        }
        closeCluster(at: markers.count - 1)

        return markers.enumerated().compactMap { ignored.contains($0.offset) ? nil : $0.element }
    }

    private static func buildChapters(from markers: [Marker], text: NSString) -> [ChapterModel] {
        var chapters: [ChapterModel] = []
        var firstStart = markers[0].titleRange.location
        let prefixContainsCatalog = firstStart > 0 && text.substring(with: NSRange(location: 0, length: firstStart)).contains("目录")

        if firstStart > 100, !prefixContainsCatalog {
            appendChapter(title: "序言", sourceText: text, range: NSRange(location: 0, length: firstStart), to: &chapters)
        } else if !prefixContainsCatalog {
            firstStart = 0
        }

        for idx in markers.indices {
            let marker = markers[idx]
            let start = idx == markers.startIndex ? firstStart : marker.titleRange.location
            let end = idx == markers.index(before: markers.endIndex) ? text.length : markers[markers.index(after: idx)].titleRange.location
            appendChapter(title: marker.title, sourceText: text, range: NSRange(location: start, length: end - start), to: &chapters)
        }
        return chapters
    }

    private static func buildFallbackChapters(in text: NSString) -> [ChapterModel] {
        var chapters: [ChapterModel] = []
        var location = 0

        while location < text.length {
            let split = splitLocation(in: text, from: location, upperBound: text.length)
            appendChapter(title: nil,
                          sourceText: text,
                          range: NSRange(location: location, length: split - location),
                          to: &chapters)
            location = split
        }
        return chapters
    }

    private static func appendChapter(title: String?, sourceText: NSString, range: NSRange, to chapters: inout [ChapterModel]) {
        guard range.length > 0 else { return }

        if range.length <= maxChapterLength {
            chapters.append(ChapterModel(idx: chapters.count, title: title, sourceText: sourceText, range: range))
            return
        }

        var location = range.location
        let upperBound = range.upperBound
        while location < upperBound {
            let split = splitLocation(in: sourceText, from: location, upperBound: upperBound)
            chapters.append(ChapterModel(idx: chapters.count,
                                         title: title,
                                         sourceText: sourceText,
                                         range: NSRange(location: location, length: split - location)))
            location = split
        }
    }

    private static func splitLocation(in text: NSString, from start: Int, upperBound: Int) -> Int {
        let desired = min(start + targetChapterLength, upperBound)
        if desired >= upperBound { return upperBound }

        let lowerBound = max(start + 1, desired - splitSearchWindow)
        if let backward = lineBreakLocation(in: text, from: min(desired, upperBound - 1), through: lowerBound, upperBound: upperBound, reversed: true),
           backward > start {
            return backward
        }

        let forwardBound = min(upperBound - 1, desired + splitSearchWindow)
        if let forward = lineBreakLocation(in: text, from: desired, through: forwardBound, upperBound: upperBound, reversed: false),
           forward > start {
            return forward
        }

        return composedCharacterBoundary(in: text, proposed: desired, from: start, upperBound: upperBound)
    }

    private static func lineBreakLocation(in text: NSString, from start: Int, through end: Int, upperBound: Int, reversed: Bool) -> Int? {
        if reversed {
            var idx = start
            while idx >= end {
                if let location = locationAfterLineBreak(in: text, at: idx, upperBound: upperBound) {
                    return location
                }
                idx -= 1
            }
        } else {
            var idx = start
            while idx <= end {
                if let location = locationAfterLineBreak(in: text, at: idx, upperBound: upperBound) {
                    return location
                }
                idx += 1
            }
        }
        return nil
    }

    private static func locationAfterLineBreak(in text: NSString, at index: Int, upperBound: Int) -> Int? {
        let character = text.character(at: index)
        if character == 10 { return index + 1 }
        if character == 13 {
            if index + 1 < upperBound, text.character(at: index + 1) == 10 {
                return index + 2
            }
            return index + 1
        }
        return nil
    }

    private static func composedCharacterBoundary(in text: NSString, proposed: Int, from start: Int, upperBound: Int) -> Int {
        let location = min(max(proposed, start + 1), upperBound)
        if location >= upperBound { return upperBound }

        let range = text.rangeOfComposedCharacterSequence(at: location)
        if range.location <= start {
            return min(location + 1, upperBound)
        }
        return range.location
    }

    private static func trimmedRange(in text: NSString, range: NSRange) -> NSRange {
        var start = range.location
        var end = range.upperBound

        while start < end, isTrimCharacter(text.character(at: start)) {
            start += 1
        }
        while end > start, isTrimCharacter(text.character(at: end - 1)) {
            end -= 1
        }
        return NSRange(location: start, length: end - start)
    }

    private static func isTrimCharacter(_ character: unichar) -> Bool {
        switch character {
        case 9, 32, 0x3000, 0xFEFF:
            return true
        default:
            return false
        }
    }
}
