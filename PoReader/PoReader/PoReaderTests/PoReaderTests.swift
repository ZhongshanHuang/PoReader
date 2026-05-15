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
