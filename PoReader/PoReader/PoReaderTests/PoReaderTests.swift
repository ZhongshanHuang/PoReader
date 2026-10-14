//
//  PoReaderTests.swift
//  PoReaderTests
//
//  Created by HzS on 2022/10/17.
//

import XCTest
import UIKit
@testable import PoReader

final class PoReaderTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testChineseNovelChapterParsingSkipsFrontCatalog() throws {
        let firstBody = String(repeating: "他推门入城，街上灯火渐次亮起。\n", count: 24)
        let secondBody = String(repeating: "风从江面吹来，卷起远处的潮声。\n", count: 24)
        let extraBody = String(repeating: "旧梦在雨里醒来，故人仍在桥边等候。\n", count: 18)
        let text = """
        目录
        第一章 初入江湖
        第二章 风起青萍
        番外 一 江湖旧梦

        第一章 初入江湖
        \(firstBody)
        第二章 风起青萍
        \(secondBody)
        番外 一 江湖旧梦
        \(extraBody)
        """

        let dataSource = try makeDataSource(text: text, encoding: .utf8)

        XCTAssertEqual(dataSource.chapters.map { $0.title }, [
            "第一章 初入江湖",
            "第二章 风起青萍",
            "番外 一 江湖旧梦"
        ])
        XCTAssertFalse(dataSource.chapters[0].content.contains("目录"))
    }

    func testChineseNovelParserDecodesGB18030() throws {
        let text = """
        第一章 起风
        风雪压城时，他终于回到了长安。
        """
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))

        let dataSource = try makeDataSource(text: text, encoding: encoding)

        XCTAssertEqual(dataSource.chapters.first?.title, "第一章 起风")
        XCTAssertTrue(dataSource.chapters.first?.content.contains("长安") == true)
    }

    func testChineseNovelParserDecodesWindowsSimplifiedChinese() throws {
        let text = """
        第一章 雨夜
        雨打芭蕉，旧城里的灯一盏盏亮起。
        """
        let encoding = String.Encoding(rawValue: 0x80000421)

        let dataSource = try makeDataSource(text: text, encoding: encoding)

        XCTAssertEqual(dataSource.chapters.first?.title, "第一章 雨夜")
        XCTAssertTrue(dataSource.chapters.first?.content.contains("芭蕉") == true)
    }

    func testTextFileDecoderPrefersBig5OverGB18030Gibberish() throws {
        let text = """
        第一章 萬柳山莊
        這是繁體中文小說內容。
        """
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
        let data = try XCTUnwrap(text.data(using: encoding))

        let decoded = try XCTUnwrap(TextFileDecoder.decode(data))

        XCTAssertEqual(decoded as String, text)
    }

    func testTextFileDecoderDecodesUTF16LittleEndianWithoutBOM() throws {
        let text = """
        第一章 万柳山庄
        这是中文小说内容。
        """
        let data = try XCTUnwrap(text.data(using: .utf16LittleEndian))

        let decoded = try XCTUnwrap(TextFileDecoder.decode(data))

        XCTAssertEqual(decoded as String, text)
    }

    func testTextFileDecoderKeepsASCIIUTF8Readable() throws {
        let text = """
        Chapter 1
        ASCII only text.
        """
        let data = try XCTUnwrap(text.data(using: .utf8))

        let decoded = try XCTUnwrap(TextFileDecoder.decode(data))

        XCTAssertEqual(decoded as String, text)
    }

    func testPaginationRangesAreContiguous() {
        let text = NSString(string: String(repeating: "这一页需要连续分页，不能反复回到开头。\n", count: 120))
        let ranges = text.parseToPage(attributes: [.font: UIFont.systemFont(ofSize: 18)],
                                      constraintSize: CGSize(width: 240, height: 140))

        XCTAssertGreaterThan(ranges.count, 1)
        XCTAssertEqual(ranges.first?.location, 0)
        XCTAssertEqual(ranges.last?.upperBound, text.length)
        for idx in 1..<ranges.count {
            XCTAssertEqual(ranges[idx].location, ranges[idx - 1].upperBound)
        }
    }

    func testPaginationStopsWhenTinyContainerRepeatsRange() {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        style.lineSpacing = 7
        style.paragraphSpacing = 10
        style.alignment = .justified
        let text = "\t空格  末尾\t\n\n" as NSString
        let layouts = text.parseToPageLayouts(attributes: [.font: UIFont.pingfang(ofSize: 18), .paragraphStyle: style],
                                             constraintSize: CGSize(width: 25, height: 27))
        XCTAssertEqual(layouts.first?.range.location, 0)
        XCTAssertEqual(layouts.last?.range.upperBound, text.length)
        XCTAssertLessThanOrEqual(layouts.count, text.length)
        for index in layouts.indices {
            XCTAssertGreaterThan(layouts[index].range.length, 0)
            if index > 0 {
                XCTAssertEqual(layouts[index].range.location, layouts[index - 1].range.upperBound)
            }
        }
    }

    private func makeDataSource(text: String, encoding: String.Encoding) throws -> ReaderDataSource {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        try text.data(using: encoding)!.write(to: url)

        let dataSource = ReaderDataSource()
        dataSource.sourcePath = url
        dataSource.parseChapter()
        return dataSource
    }

}

// Opt-in diagnostic: run in Release with OTHER_SWIFT_FLAGS=-DPOREADER_PROFILE_PAGINATION.
// From the repository root (set destination to a simulator/device available in Xcode):
// xcodebuild test -project PoReader/PoReader.xcodeproj -scheme PoReader -configuration Release \
//   -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -parallel-testing-enabled NO \
//   -only-testing:PoReaderTests/PoReaderTests/testPaginationDirectLookupMatchesLegacy \
//   -only-testing:PoReaderTests/PoReaderTests/testPaginationDirectLookupPerformance \
//   ENABLE_TESTABILITY=YES OTHER_SWIFT_FLAGS='$(inherited) -DPOREADER_PROFILE_PAGINATION'
// Attachments contain all per-page timings and aggregate statistics. Timings are
// diagnostic observations, not pass/fail performance thresholds.
// Profiling is confined to this test target. The helper retains both lookup paths
// for comparison; the legacy control also guards non-advancing ranges so malformed
// tiny-container cases can be compared without hanging the test runner.
extension PoReaderTests {
    func testPaginationDirectLookupMatchesLegacy() throws {
        #if !POREADER_PROFILE_PAGINATION
        throw XCTSkip("Build with -DPOREADER_PROFILE_PAGINATION to compare lookup strategies.")
        #else
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        style.lineSpacing = 7
        style.paragraphSpacing = 10
        style.alignment = .justified
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.pingfang(ofSize: 18), .paragraphStyle: style]
        let units = ["", "字", "\n", "\n\n\n", "正文\n", "\t空格  末尾\t\n\n",
                     "中英文 mixed office ffi 12345，。！？\n",
                     "👨‍👩‍👧‍👦🇨🇳👍🏽 e\u{301} o\u{308} क्‍ष العربية עברית\n",
                     "第一行\r\n第二行\r第三行\u{2028}行分隔\u{2029}段分隔\n",
                     String(repeating: "无换行长段落。", count: 10)]
        var cases = 0
        for unit in units {
            for repetitions in [1, 23] {
                for size in [CGSize(width: 350, height: 700), CGSize(width: 110, height: 95), CGSize(width: 25, height: 27), .zero, CGSize(width: 100, height: 1)] {
                    // Tiny pages exercise boundaries without turning this into a thousands-of-pages stress test.
                    let boundedUnit = size.height < 10 ? String(unit.prefix(12)) : unit
                    let text = String(repeating: boundedUnit, count: size.width < 50 || size.height < 10 ? 1 : repetitions) as NSString
                    let legacy = PaginationProfile.run(text, attributes: attributes, size: size)
                    let baseline = legacy.layouts
                    let candidate = PaginationProfile.run(text, attributes: attributes, size: size, directLookup: true)
                    let production = text.parseToPageLayouts(attributes: attributes, constraintSize: size)
                    XCTAssertEqual(candidate.layouts.map(\.range), baseline.map(\.range), "text=\(unit), size=\(size)")
                    XCTAssertEqual(candidate.layouts.map(\.usedSize), baseline.map(\.usedSize), "text=\(unit), size=\(size)")
                    XCTAssertEqual(production.map(\.range), baseline.map(\.range))
                    XCTAssertEqual(production.map(\.usedSize), baseline.map(\.usedSize))
                    XCTAssertEqual(candidate.usedFallback, legacy.usedFallback)
                    if candidate.lookupFallbacks > 0 {
                        print("PAGINATION_LOOKUP fallback text=\(unit.debugDescription) repeats=\(repetitions) size=\(size) pages=\(candidate.layouts.count) count=\(candidate.lookupFallbacks)")
                    }
                    cases += 1
                }
            }
        }
        print("PAGINATION_LOOKUP correctness cases=\(cases)")
        #endif
    }

    func testPaginationDirectLookupPerformance() throws {
        #if !POREADER_PROFILE_PAGINATION
        throw XCTSkip("Build with -DPOREADER_PROFILE_PAGINATION to compare lookup strategies.")
        #else
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        style.lineSpacing = 7
        style.paragraphSpacing = 10
        style.alignment = .justified
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.pingfang(ofSize: 18), .paragraphStyle: style]
        let size = CGSize(width: 350, height: 700)
        let sentence = "他推开城门，看见长街尽头的灯火。风从江面吹来，带着远处的潮声，旧日的故事又一次浮现在眼前。"
        let paragraph = String(repeating: sentence, count: 3) + "\n"
        var summaries = [[String: Any]]()
        var csv = "fixture,utf16_length,repeat,strategy,page,location,length,create_ms,add_ms,ensure_ms,lookup_ms,character_ms,used_rect_ms\n"
        _ = PaginationProfile.run(paragraph as NSString, attributes: attributes, size: size, directLookup: true)
        for (fixture, unit, lengths) in [
            ("paragraphs", paragraph, [5_000, 10_000, 20_000, 40_000, 80_000, 160_000]),
            ("single_paragraph", paragraph.replacingOccurrences(of: "\n", with: "，"), [20_000, 80_000])
        ] {
            for length in lengths {
                let source = String(repeating: unit, count: length / (unit as NSString).length + 1) as NSString
                let text = source.substring(to: length) as NSString
                var variants = [[PaginationProfile](), [PaginationProfile]()]
                for repetition in 0..<5 {
                    for strategy in (repetition.isMultiple(of: 2) ? [0, 1] : [1, 0]) {
                        let profile = PaginationProfile.run(text, attributes: attributes, size: size, directLookup: strategy == 1)
                        XCTAssertFalse(profile.usedFallback)
                        XCTAssertEqual(profile.lookupFallbacks, 0)
                        variants[strategy].append(profile)
                        for (index, page) in profile.pages.enumerated() {
                            let range = profile.layouts[index].range
                            csv += "\(fixture),\(length),\(repetition),\(strategy),\(index + 1),\(range.location),\(range.length),"
                            csv += page.map { String(format: "%.6f", $0) }.joined(separator: ",") + "\n"
                        }
                    }
                    XCTAssertEqual(variants[0].last!.layouts.map(\.range), variants[1].last!.layouts.map(\.range))
                    XCTAssertEqual(variants[0].last!.layouts.map(\.usedSize), variants[1].last!.layouts.map(\.usedSize))
                }
                let production = text.parseToPageLayouts(attributes: attributes, constraintSize: size)
                XCTAssertEqual(production.map(\.range), variants[0][0].layouts.map(\.range))
                XCTAssertEqual(production.map(\.usedSize), variants[0][0].layouts.map(\.usedSize))
                var summary: [String: Any] = ["fixture": fixture, "utf16_length": length, "pages": variants[0][0].pages.count]
                for strategy in 0..<2 {
                    let runs = variants[strategy]
                    let prefix = strategy == 0 ? "legacy" : "direct"
                    summary[prefix + "_total_ms"] = runs.map(\.totalMS)
                    summary[prefix + "_median_ms"] = median(runs.map(\.totalMS))
                    summary[prefix + "_lookup_median_ms"] = median(runs.map { $0.pages.reduce(0) { $0 + $1[3] } })
                    summary[prefix + "_ensure_median_ms"] = median(runs.map { $0.pages.reduce(0) { $0 + $1[2] } })
                    let count = runs[0].pages.count
                    let indices = Array(1..<(count - 1))
                    summary[prefix + "_page_quartiles_ms"] = (0..<4).map { quarter in
                        let subset = indices[(indices.count * quarter / 4)..<(indices.count * (quarter + 1) / 4)]
                        return median(runs.flatMap { run in subset.map { run.pages[$0].reduce(0, +) } })
                    }
                }
                summaries.append(summary)
                print("PAGINATION_LOOKUP " + String(decoding: try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]), as: UTF8.self))
            }
        }
        let json = try JSONSerialization.data(withJSONObject: summaries, options: [.prettyPrinted, .sortedKeys])
        for (name, data, type) in [("pagination-lookup-summary.json", json, "public.json"),
                                  ("pagination-lookup-pages.csv", Data(csv.utf8), "public.comma-separated-values-text")] {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: type)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        #endif
    }

    func testPaginationContainerScaling() throws {
        #if !POREADER_PROFILE_PAGINATION
        throw XCTSkip("Build with -DPOREADER_PROFILE_PAGINATION to run pagination diagnostics.")
        #else
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        style.lineSpacing = 7
        style.paragraphSpacing = 10
        style.alignment = .justified
        let font = try XCTUnwrap(UIFont(name: "PingFangSC-Regular", size: 18))
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
        let size = CGSize(width: 350, height: 700)
        let sentence = "他推开城门，看见长街尽头的灯火。风从江面吹来，带着远处的潮声，旧日的故事又一次浮现在眼前。"
        let paragraph = String(repeating: sentence, count: 3) + "\n"
        let fixtures = [("paragraphs", paragraph), ("single_paragraph", paragraph.replacingOccurrences(of: "\n", with: "，"))]
        var csv = "fixture,utf16_length,repeat,page,location,length,create_ms,add_ms,ensure_ms,glyph_ms,character_ms,used_rect_ms\n"
        var summaries = [[String: Any]]()

        // Warm font/system caches; every measured invocation uses fresh layout objects.
        _ = NSString(string: paragraph).parseToPageLayouts(attributes: attributes, constraintSize: size)
        for (fixture, unit) in fixtures {
            for length in [5_000, 10_000, 20_000, 40_000, 80_000, 160_000] {
                let source = String(repeating: unit, count: length / (unit as NSString).length + 1) as NSString
                let text = source.substring(to: length) as NSString
                var baselineTimes = [Double]()
                var profileTimes = [Double]()
                var profiles = [PaginationProfile]()
                for repetition in 0..<5 {
                    // Alternate order to reduce cache/order bias.
                    var baseline = [NSString.PageLayout]()
                    func runBaseline() {
                        let start = CACurrentMediaTime()
                        autoreleasepool {
                            baseline = text.parseToPageLayouts(attributes: attributes, constraintSize: size)
                        }
                        baselineTimes.append((CACurrentMediaTime() - start) * 1_000)
                    }
                    if repetition.isMultiple(of: 2) { runBaseline() }
                    let profile = autoreleasepool {
                        PaginationProfile.run(text, attributes: attributes, size: size, directLookup: true)
                    }
                    if !repetition.isMultiple(of: 2) { runBaseline() }
                    XCTAssertEqual(profile.layouts.map(\.range), baseline.map(\.range))
                    XCTAssertEqual(profile.layouts.map(\.usedSize), baseline.map(\.usedSize))
                    XCTAssertEqual(profile.layouts.first?.range.location, 0)
                    XCTAssertEqual(profile.layouts.last?.range.upperBound, text.length)
                    XCTAssertFalse(profile.usedFallback, "Zero-length layout must not be counted as successful pagination")
                    for index in 1..<profile.layouts.count {
                        XCTAssertEqual(profile.layouts[index - 1].range.upperBound, profile.layouts[index].range.location)
                    }
                    profileTimes.append(profile.totalMS)
                    profiles.append(profile)
                    for (index, page) in profile.pages.enumerated() {
                        let range = profile.layouts[index].range
                        csv += "\(fixture),\(length),\(repetition),\(index + 1),\(range.location),\(range.length),"
                        csv += page.map { String(format: "%.6f", $0) }.joined(separator: ",") + "\n"
                    }
                }
                let count = profiles[0].pages.count
                let stageNames = ["create", "add", "ensure", "glyph", "character", "used_rect"]
                var stages = [String: Double]()
                for stage in 0..<stageNames.count {
                    stages[stageNames[stage]] = median(profiles.map { $0.pages.reduce(0) { $0 + $1[stage] } })
                }
                // Exclude page 1 (lazy shaping/startup) and the partial final page.
                let interior = Array(1..<(count - 1))
                var quarters = [Double]()
                var addQuarters = [Double]()
                var ensureQuarters = [Double]()
                var glyphQuarters = [Double]()
                for quarter in 0..<4 {
                    let indices = interior[(interior.count * quarter / 4)..<(interior.count * (quarter + 1) / 4)]
                    quarters.append(median(profiles.flatMap { profile in indices.map { profile.pages[$0].reduce(0, +) } }))
                    addQuarters.append(median(profiles.flatMap { profile in indices.map { profile.pages[$0][1] } }))
                    ensureQuarters.append(median(profiles.flatMap { profile in indices.map { profile.pages[$0][2] } }))
                    glyphQuarters.append(median(profiles.flatMap { profile in indices.map { profile.pages[$0][3] } }))
                }
                let summary: [String: Any] = [
                    "fixture": fixture, "utf16_length": length, "pages": count,
                    "baseline_ms": baselineTimes, "baseline_median_ms": median(baselineTimes),
                    "instrumented_ms": profileTimes, "instrumented_median_ms": median(profileTimes),
                    "setup_median_ms": median(profiles.map(\.setupMS)), "stage_total_median_ms": stages,
                    "first_page_median_ms": median(profiles.map { $0.pages[0].reduce(0, +) }),
                    "interior_quartile_page_median_ms": quarters,
                    "interior_quartile_add_median_ms": addQuarters,
                    "interior_quartile_ensure_median_ms": ensureQuarters,
                    "interior_quartile_glyph_median_ms": glyphQuarters
                ]
                summaries.append(summary)
                let json = try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys])
                print("PAGINATION_PROFILE " + String(decoding: json, as: UTF8.self))
            }
        }
        let metadata: [String: Any] = [
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "device": UIDevice.current.model, "processor_count": ProcessInfo.processInfo.processorCount,
            "font": font.fontName, "font_size": 18, "width": 350, "height": 700,
            "line_spacing": 7, "paragraph_spacing": 10, "repetitions": 5,
            "notes": "Release; warm font cache; fresh layout objects; alternating baseline/profile order; wall-clock milliseconds; page timers exclude result recording; total includes setup, recording and object teardown.",
            "results": summaries
        ]
        let json = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        for (name, data, type) in [("pagination-summary.json", json, "public.json"),
                                   ("pagination-pages.csv", Data(csv.utf8), "public.comma-separated-values-text")] {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: type)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        #endif
    }
}

#if POREADER_PROFILE_PAGINATION
private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

private struct PaginationProfile {
    var layouts = [NSString.PageLayout]()
    var pages = [[Double]]()
    var setupMS: Double = 0
    var totalMS: Double = 0
    var usedFallback = false
    var lookupFallbacks = 0

    static func run(_ text: NSString, attributes: [NSAttributedString.Key: Any], size: CGSize, directLookup: Bool = false) -> Self {
        var result = Self()
        guard text.length > 0, size.width > 0, size.height > 0 else { return result }
        let start = CACurrentMediaTime()
        autoreleasepool {
            let manager = NSLayoutManager()
            manager.usesFontLeading = false
            let storage = NSTextStorage()
            storage.addLayoutManager(manager)
            storage.setAttributedString(NSAttributedString(string: text as String, attributes: attributes))
            result.setupMS = (CACurrentMediaTime() - start) * 1_000
            var parsedLength = 0
            var nextGlyphIndex = 0
            while parsedLength < storage.length {
                guard result.pages.count <= text.length + 1 else {
                    XCTFail("Pagination failed to advance")
                    break
                }
                let t0 = CACurrentMediaTime()
                let container = NSTextContainer(size: size)
                container.lineBreakMode = .byCharWrapping
                container.lineFragmentPadding = 0
                let t1 = CACurrentMediaTime()
                manager.addTextContainer(container)
                let t2 = CACurrentMediaTime()
                manager.ensureLayout(for: container)
                let t3 = CACurrentMediaTime()
                var glyphs = NSRange(location: NSNotFound, length: 0)
                if directLookup {
                    if nextGlyphIndex < manager.firstUnlaidGlyphIndex(),
                       manager.textContainer(forGlyphAt: nextGlyphIndex, effectiveRange: &glyphs, withoutAdditionalLayout: true) === container,
                       glyphs.location == nextGlyphIndex, glyphs.length > 0 {
                        // Reuse the complete container range returned by the direct lookup.
                    } else {
                        result.lookupFallbacks += 1
                        glyphs = manager.glyphRange(for: container)
                    }
                } else {
                    glyphs = manager.glyphRange(for: container)
                }
                let t4 = CACurrentMediaTime()
                let range = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
                let t5 = CACurrentMediaTime()
                // Match the existing zero-length fallback, also stopping repeated ranges
                // observed for a 25x27pt container with trailing tabs/blank lines.
                guard range.length > 0, range.upperBound > parsedLength else {
                    result.usedFallback = true
                    result.layouts.append(.init(range: NSRange(location: parsedLength, length: storage.length - parsedLength), usedSize: size))
                    break
                }
                let rect = manager.usedRect(for: container)
                let t6 = CACurrentMediaTime()
                result.layouts.append(.init(range: range, usedSize: CGSize(width: ceil(rect.width), height: ceil(rect.height))))
                result.pages.append([t1 - t0, t2 - t1, t3 - t2, t4 - t3, t5 - t4, t6 - t5].map { $0 * 1_000 })
                parsedLength = range.upperBound
                nextGlyphIndex = glyphs.upperBound
            }
        }
        result.totalMS = (CACurrentMediaTime() - start) * 1_000
        return result
    }
}
#endif
