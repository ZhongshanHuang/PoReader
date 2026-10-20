import XCTest
@testable import PoReader

final class ChineseNovelChapterParserTests: XCTestCase {
    private func assertMatchesLegacy(_ value: String, file: StaticString = #filePath, line: UInt = #line) {
        let text = value as NSString
        let expected = LegacyChapterParser.parse(text: text)
        let actual = ChineseNovelChapterParser.parse(text: text)
        XCTAssertEqual(actual.map(\.title), expected.map(\.title), file: file, line: line)
        XCTAssertEqual(actual.map(\.range), expected.map(\.range), file: file, line: line)
        XCTAssertEqual(actual.map(\.idx), expected.map(\.idx), file: file, line: line)
    }

    func testTitleFormsAndWhitespaceMatchLegacy() {
        let numbers = Array("0123456789０１２３４５６７８９零〇一二两三四五六七八九十百千万亿壹贰叁肆伍陆柒捌玖拾佰仟萬億").map(String.init)
        let special = ["序章", "序言", "前言", "楔子", "引子", "尾声", "后记", "终章", "大结局", "作品相关", "上架感言", "番外", "番外篇 一", "番外卷９"]
        let titles = numbers.flatMap { ["第\($0)章 风起", "\($0)回 归来", "第\($0)卷", "正文 第\($0)部 第十二篇 启程"] } + special
        let whitespace = ["", " ", "\t", "　", "\u{FEFF}", "\u{00A0}", "\u{2003}", "\u{200B}", "\u{202F}", "\u{000B}", "\u{000C}"]
        for title in titles {
            for padding in whitespace {
                let input = padding + title + padding + "\n" + String(repeating: "正文风雪。", count: 30)
                assertMatchesLegacy(input)
            }
        }
        for title in ["他推门入城", "一阵风吹来", "正文如此", "第一章 😀", "\u{D7FF}未知", "\u{10000}未知", "第1章 " + String(repeating: "字", count: 50)] {
            assertMatchesLegacy(title + "\n正文")
        }
        let actual = ChineseNovelChapterParser.parse(text: "第一章 起风\n正文" as NSString)
        XCTAssertEqual(actual.map(\.title), ["第一章 起风"])
        XCTAssertEqual(actual.map(\.range), [NSRange(location: 0, length: 9)])
    }

    func testUnicodeTitleRegressionsMatchLegacy() {
        for title in [
            "\u{200B}第一章 起风\u{200B}",
            "第\u{000B}一章 起风", "第一章 风\u{000B}起",
            "正文\u{000B}第一章 起风", "番外\u{000B}一",
            // Zero-width spaces are trimmed at the edges, not accepted inside a title.
            "第\u{200B}一章 起风", "第一章 风\u{200B}起",
        ] {
            assertMatchesLegacy(title + "\n正文")
        }
        // Include Han characters outside the CJK extension blocks, block boundaries,
        // unassigned gaps and non-Han supplementary characters. ICU is the oracle.
        for scalar: UInt32 in [
            0x16FE2, 0x16FE3, 0x16FF0, 0x1F600, 0x20000,
            0x2A6DF, 0x2A6E0, 0x2EE60, 0x2F800, 0x2FA1D, 0x2FA1E, 0x2FA1F,
            0x30000, 0x323AF, 0x323B0,
        ] {
            let character = String(UnicodeScalar(scalar)!)
            assertMatchesLegacy("第一章 " + character + "\n正文")
            assertMatchesLegacy("番外 " + character + "\n正文")
        }
    }

    // URL-related words are now allowed in valid titles, intentionally differing
    // from the frozen legacy parser used by the equivalence tests.
    func testTitlesContainingURLWordsAreAccepted() {
        for title in ["第一章 HTTP协议", "第九章 http", "序章 WWW.", "第一章 hTtP故事", "后记 www.附录"] {
            let text = (title + "\n正文") as NSString
            let chapters = ChineseNovelChapterParser.parse(text: text)
            XCTAssertEqual(chapters.map(\.title), [title])
            XCTAssertEqual(chapters.map(\.range), [NSRange(location: 0, length: text.length)])
        }
        for line in ["http", "www.example.com"] {
            XCTAssertEqual(ChineseNovelChapterParser.parse(text: line as NSString).map(\.title), [nil])
        }
    }

    func testLineSeparatorsCatalogAndOffsetsMatchLegacy() {
        for separator in ["\n", "\r", "\r\n", "\u{0085}", "\u{2028}", "\u{2029}", "\u{000B}", "\u{000C}"] {
            let body = String(repeating: "风雪压城时，他终于回到了长安。", count: 20)
            let titles = ["第一章 起风", "第二章 入城", "番外 旧梦"]
            for prefix in ["", "序言说明" + body, "目录" + separator + titles.joined(separator: separator) + separator] {
                let book = prefix + separator + titles.map { "　\($0)　" + separator + body }.joined(separator: separator) + separator
                assertMatchesLegacy(book)
            }
        }
        for text in ["", "\n", "\r\n\n", "   \t　", "第一章 起风", "\u{FEFF}第一章 起风\n正文", "前言\r第一章\n\u{2028}第二章\u{2029}尾声"] {
            assertMatchesLegacy(text)
        }
    }

    func testLongChaptersAndFallbackBoundariesMatchLegacy() {
        // Recognized chapters and fallback text intentionally use different limits.
        for length in [9999, 10000, 10001, 18000, 18001] {
            let title = "第一章 起风\n"
            assertMatchesLegacy(String(repeating: "字", count: length))
            assertMatchesLegacy(title + String(repeating: "字", count: length - title.utf16.count))
        }
        for unit in ["无标题长文本", "😀e\u{301}👨‍👩‍👧‍👦", "他走进城门。\r\n", "山河故人。\u{2028}"] {
            let text = String(repeating: unit, count: 7000)
            assertMatchesLegacy(text)
            assertMatchesLegacy("第一章 起风\n" + text + "\n第二章 入城\n正文")
        }
    }

    func testGeneratedBooksMatchLegacy() {
        var state: UInt64 = 0x12345678
        func next(_ upperBound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 32) % UInt64(upperBound))
        }
        let lines = ["第一章 起风", "一章 旧梦", "第１２卷 第三章 入城", "正文 第两回 归来", "番外篇 二", "目录", "尾声", "他走进城门，灯火渐次亮起。", "一阵风吹来。", "😀emoji e\u{301}", "", "www.example.com", "第一章 协议", String(repeating: "正文", count: 60)]
        let separators = ["\n", "\r", "\r\n", "\u{0085}", "\u{2028}", "\u{2029}"]
        let padding = ["", "\t", "　", "\u{FEFF}", "\u{00A0}", "\u{200B}"]
        for _ in 0..<300 {
            var book = ""
            for _ in 0..<(20 + next(180)) {
                book += padding[next(padding.count)] + lines[next(lines.count)] + padding[next(padding.count)] + separators[next(separators.count)]
            }
            assertMatchesLegacy(book)
        }
    }

    // Opt in with OTHER_SWIFT_FLAGS='$(inherited) -DPOREADER_PROFILE_CHAPTERS'.
    // Measures chapter parsing only; disk reads, decoding and pagination are excluded.
    func testChapterParsingPerformance() throws {
        #if !POREADER_PROFILE_CHAPTERS
        throw XCTSkip("Build with -DPOREADER_PROFILE_CHAPTERS to benchmark chapter parsing.")
        #else
        let shortBody = String(repeating: "他推门入城，街上灯火渐次亮起。\n", count: 200)
        let longBody = String(repeating: "他推门入城，街上灯火渐次亮起。", count: 200) + "\n"
        var rows = [[String: Any]]()
        for (name, body, count, hasTitles) in [
            ("short_lines_160k", shortBody, 50, true),
            ("short_lines_1_6m", shortBody, 500, true),
            ("short_lines_8m", shortBody, 2500, true),
            ("long_lines_1_5m", longBody, 500, true),
            ("no_titles_1_6m", shortBody, 500, false),
            ("no_line_breaks_1_5m", String(repeating: "风雪压城。", count: 300000), 1, false),
            ("title_like_body_1_6m", shortBody.replacingOccurrences(of: "他推门", with: "一阵风"), 500, true)
        ] {
            let text = (1...count).map { (hasTitles ? "第\($0)章 风起青萍\n" : "") + body }.joined() as NSString
            let expected = LegacyChapterParser.parse(text: text)
            _ = ChineseNovelChapterParser.parse(text: text)
            var samples = [[Double](), [Double]()]
            for repetition in 0..<5 {
                for strategy in (repetition.isMultiple(of: 2) ? [0, 1] : [1, 0]) {
                    let start = CFAbsoluteTimeGetCurrent()
                    let actual = strategy == 0 ? LegacyChapterParser.parse(text: text) : ChineseNovelChapterParser.parse(text: text)
                    samples[strategy].append((CFAbsoluteTimeGetCurrent() - start) * 1000)
                    XCTAssertEqual(actual.map(\.title), expected.map(\.title))
                    XCTAssertEqual(actual.map(\.range), expected.map(\.range))
                }
            }
            let before = samples[0].sorted()[2]
            let after = samples[1].sorted()[2]
            rows.append(["fixture": name, "utf16_length": text.length, "chapters": expected.count,
                         "baseline_ms": samples[0], "optimized_ms": samples[1],
                         "baseline_median_ms": before, "optimized_median_ms": after, "speedup": before / after])
            print("CHAPTER_PROFILE \(name) utf16=\(text.length) chapters=\(expected.count) before=\(before) after=\(after) speedup=\(before / after)")
        }
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "chapter-parsing-profile.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
    }
}

// Frozen pre-optimization implementation: independent oracle for title and UTF-16
// range equivalence, including catalog filtering and fallback chapter splitting.

private enum LegacyChapterParser {
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
