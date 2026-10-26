import Foundation

/* 此解析功能对编译优化非常敏感，真实性能请使用release测试，可能会相差几十倍 */
@MainActor
enum ChineseNovelChapterParser {
    private struct Marker {
        let location: Int
        let length: Int
        // 64-bit FNV-1a of the title's UTF-16 units. Catalog detection compares these instead of
        // Strings, so no String is created or hashed for markers that end up being dropped.
        let hash: UInt64

        var upperBound: Int { location + length }
    }

    private static let targetChapterLength = 10000
    private static let maxChapterLength = 18000
    private static let splitSearchWindow = 2000
    private static let catalogDistance = 120
    // TitleMatcher tracks positions in a UInt64 bitmask, so this must stay below 64.
    private static let maxTitleLength = 48

    // When true, a title without a leading 第 (a bare "N+章/节/回/篇") is accepted only if
    // the unit character is followed by whitespace, a separator, or the end of the line.
    // That rejects ordinary sentences such as "一回头，看见了他。" or "两回事".
    // The default (false) keeps exactly the behaviour of the previous regex-based version.
    private static let rejectBareNumeralTitles = false

    // MARK: - Title grammar
    //
    // A line is a chapter title when, after trimming whitespace, it matches one of:
    //
    //   numbered: (正文\s*)? ( (第\s*N+\s*[卷部集]\s*)? (第\s*)? N+\s*[章节回篇]  |  第\s*N+\s*[卷部集] )
    //                        (\s*SEP\s*|\s+)? TAIL
    //   special:  (正文\s*)? ( 序章|序言|前言|楔子|引子|尾声|后记|终章|大结局|作品相关|上架感言
    //                          | 番外(篇|卷)?(\s*N+)? )
    //                        (\s*SEP\s*|\s+)? TAIL
    //
    //   N    = 0-9 ０-９ and Chinese numerals
    //   SEP  = : ： 、 . ． · - — －
    //   TAIL = up to 36 code points of Han, ASCII letters/digits, ０-９, \s and the punctuation below
    //
    // `TitleMatcher` implements this grammar directly on UTF-16 units (it replaces the former
    // NSRegularExpression versions). `mayBeChapterTitle` is a cheap necessary condition that
    // runs first, and a one-lookup check on the first character rejects almost every line
    // before even that.

    private static let chineseNumerals = "零〇一二两三四五六七八九十百千万亿壹贰叁肆伍陆柒捌玖拾佰仟萬億"
    private static let separators = ":：、.．·-—－"
    private static let tailPunctuation = "《》“”\"'()（）【】[]·,:：，。！？!?、.．-—－"

    // Every alternative of the special titles. 番外 additionally accepts (篇|卷)? and a number.
    private static let specialTitleWords = [
        "序章", "序言", "前言", "楔子", "引子", "尾声", "后记", "终章", "大结局", "作品相关", "上架感言", "番外",
    ]

    // MARK: - Character classes

    private enum Flag {
        static let number: UInt16 = 1 << 0        // 0-9, ０-９, Chinese numerals
        static let chapterUnit: UInt16 = 1 << 1   // 章节回篇
        static let volumeUnit: UInt16 = 1 << 2    // 卷部集
        static let di: UInt16 = 1 << 3            // 第
        static let whitespace: UInt16 = 1 << 4    // CharacterSet.whitespacesAndNewlines (trimming)
        static let regexSpace: UInt16 = 1 << 5    // ICU whitespace character class
        static let specialHead: UInt16 = 1 << 6   // first character of a special title
        static let tail: UInt16 = 1 << 7          // character class allowed in TAIL
        static let separator: UInt16 = 1 << 8     // SEP
        static let start: UInt16 = 1 << 9         // may be the first character of a title

        static let anyUnit: UInt16 = chapterUnit | volumeUnit
    }

    // A raw pointer table avoids bounds checks and retain/release in the scan loop.
    // It is filled once and never mutated or freed afterwards.
    private struct CharacterTable: @unchecked Sendable {
        let flags: UnsafePointer<UInt16>
    }

    private static let characterTable: CharacterTable = {
        let table = UnsafeMutablePointer<UInt16>.allocate(capacity: 0x10000)
        table.initialize(repeating: 0, count: 0x10000)

        func markRange(_ range: ClosedRange<Int>, _ flags: UInt16) {
            for unit in range { table[unit] |= flags }
        }
        func markCharacters(_ characters: String, _ flags: UInt16) {
            for unit in characters.utf16 { table[Int(unit)] |= flags }
        }

        markRange(0x30...0x39, Flag.number | Flag.tail)
        markRange(0xFF10...0xFF19, Flag.number | Flag.tail)
        markCharacters(chineseNumerals, Flag.number)
        markCharacters("章节回篇", Flag.chapterUnit)
        markCharacters("卷部集", Flag.volumeUnit)
        markCharacters("第", Flag.di)

        // ICU \s, also valid inside TAIL.
        for unit in [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000] {
            table[unit] |= Flag.regexSpace | Flag.whitespace | Flag.tail
        }
        markRange(0x2000...0x200A, Flag.regexSpace | Flag.whitespace | Flag.tail)
        // Trimmed by whitespacesAndNewlines but not matched by \s.
        table[0x200B] |= Flag.whitespace

        // \p{Han} inside the BMP (explicit ranges; supplementary planes are handled in TitleMatcher).
        let hanRanges: [ClosedRange<Int>] = [
            0x2E80...0x2E99, 0x2E9B...0x2EF3, 0x2F00...0x2FD5, 0x3005...0x3005, 0x3007...0x3007,
            0x3021...0x3029, 0x3038...0x303B, 0x3400...0x4DBF, 0x4E00...0x9FFF,
            0xF900...0xFA6D, 0xFA70...0xFAD9,
        ]
        for range in hanRanges { markRange(range, Flag.tail) }
        markRange(0x41...0x5A, Flag.tail)
        markRange(0x61...0x7A, Flag.tail)
        markCharacters(tailPunctuation, Flag.tail)
        markCharacters(separators, Flag.separator | Flag.tail)

        for word in specialTitleWords {
            if let head = word.utf16.first { table[Int(head)] |= Flag.specialHead }
        }

        // Everything that can open a title once leading space/tab/BOM are trimmed:
        // whitespace, 第, numerals, special-title heads, and 正 (of 正文).
        for unit in 0..<0x10000 where table[unit] & (Flag.number | Flag.di | Flag.whitespace | Flag.specialHead) != 0 {
            table[unit] |= Flag.start
        }
        markCharacters("正", Flag.start)

        return CharacterTable(flags: UnsafePointer(table))
    }()

    // First two units of every special title, used by the prefilter.
    private static let specialStartPairs: Set<UInt32> = {
        var pairs = Set<UInt32>()
        for word in specialTitleWords {
            let units = Array(word.utf16)
            pairs.insert(UInt32(units[0]) << 16 | UInt32(units[1]))
        }
        return pairs
    }()

    // MARK: - Entry point

    static func parse(text: NSString) -> [ChapterModel] {
        let length = text.length
        guard length > 0 else { return [] }

        // Everything below works on a UTF-16 buffer; no NSString/String is touched per character.
        return withUTF16(of: text, length: length) { units in
            let markers = removeCatalogMarkers(from: collectMarkers(in: units), textLength: length)
            var builder = ChapterBuilder(text: text, units: units)
            builder.build(from: markers)
            return builder.chapters
        }
    }

    private static func withUTF16<Result>(of text: NSString, length: Int,
                                          _ body: (UnsafeBufferPointer<unichar>) -> Result) -> Result {
        #if canImport(Darwin)
        // Zero-copy: a CF-backed string that stores contiguous UTF-16 exposes its buffer directly.
        if let pointer = CFStringGetCharactersPtr(text as CFString) {
            return withExtendedLifetime(text) {
                body(UnsafeBufferPointer(start: pointer, count: length))
            }
        }
        #endif

        // Fallback (for example a string bridged from a native Swift String): one bulk copy.
        let copy = [unichar](unsafeUninitializedCapacity: length) { buffer, initializedCount in
            if let base = buffer.baseAddress {
                text.getCharacters(base, range: NSRange(location: 0, length: length))
            }
            initializedCount = length
        }
        return copy.withUnsafeBufferPointer(body)
    }

    // MARK: - Marker collection

    private static func collectMarkers(in units: UnsafeBufferPointer<unichar>) -> [Marker] {
        guard let base = units.baseAddress else { return [] }
        let count = units.count
        let table = characterTable.flags
        var markers: [Marker] = []
        var index = 0

        while index < count {
            // Same line terminators as Foundation's getLineStart:
            // \n, \r, \r\n, U+0085, U+2028, U+2029.
            let lineStart = index
            let lineEnd = findLineEnd(base, from: index, count: count)
            index = lineEnd
            if index < count {
                index += (base[index] == 0x0D && index + 1 < count && base[index + 1] == 0x0A) ? 2 : 1
            }

            var start = lineStart
            while start < lineEnd, isTrimCharacter(base[start]) { start += 1 }
            // Cheap reject: almost every line starts with a character that can never open a title.
            guard start < lineEnd, table[Int(base[start])] & Flag.start != 0 else { continue }

            var end = lineEnd
            while end > start, isTrimCharacter(base[end - 1]) { end -= 1 }
            let length = end - start
            guard length <= maxTitleLength else { continue }

            guard mayBeChapterTitle(base, start: start, end: end, table: table),
                  isChapterTitle(base, start: start, end: end, table: table) else { continue }

            markers.append(Marker(location: start, length: length, hash: hashUnits(base + start, length)))
        }
        return markers
    }

    // Index of the first line terminator at or after `start`, or `count` if there is none.
    // Scans 16 UTF-16 units per step. Resolve short lines directly from the SIMD mask;
    // on longer lines, a scalar finish avoids extra vector reductions.
    @inline(__always)
    private static func findLineEnd(_ base: UnsafePointer<unichar>, from start: Int, count: Int) -> Int {
        var i = start
        let raw = UnsafeRawPointer(base)
        let lf = SIMD8<UInt16>(repeating: 0x0A)
        let cr = SIMD8<UInt16>(repeating: 0x0D)
        let nel = SIMD8<UInt16>(repeating: 0x85)
        let ls = SIMD8<UInt16>(repeating: 0x2028)
        let ps = SIMD8<UInt16>(repeating: 0x2029)

        let lanes = SIMD8<UInt16>(0, 1, 2, 3, 4, 5, 6, 7)
        while i + 16 <= count {
            let low = raw.loadUnaligned(fromByteOffset: i * 2, as: SIMD8<UInt16>.self)
            let high = raw.loadUnaligned(fromByteOffset: i * 2 + 16, as: SIMD8<UInt16>.self)
            let lowHit = (low .== lf) .| (low .== cr) .| (low .== nel) .| (low .== ls) .| (low .== ps)
            let highHit = (high .== lf) .| (high .== cr) .| (high .== nel) .| (high .== ls) .| (high .== ps)
            if any(lowHit .| highHit) {
                if i != start { break }
                if any(lowHit) {
                    return i + Int(SIMD8<UInt16>(repeating: 8).replacing(with: lanes, where: lowHit).min())
                }
                return i + 8 + Int(SIMD8<UInt16>(repeating: 8).replacing(with: lanes, where: highHit).min())
            }
            i += 16
        }
        while i < count, !isLineBreak(base[i]) { i += 1 }
        return i
    }

    @inline(__always)
    private static func isLineBreak(_ character: unichar) -> Bool {
        character == 0x0A || character == 0x0D || character == 0x85 || character == 0x2028 || character == 0x2029
    }

    private static func hashUnits(_ base: UnsafePointer<unichar>, _ count: Int) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for i in 0..<count {
            hash = (hash ^ UInt64(base[i])) &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    // Necessary condition for the title grammar:
    //   [whitespace] [正文 whitespace] ( special-title start | [第|numeral|whitespace]+ 章节回篇卷部集 )
    // Every string the grammar accepts satisfies this; the converse is not true.
    private static func mayBeChapterTitle(_ base: UnsafePointer<unichar>, start: Int, end: Int,
                                          table: UnsafePointer<UInt16>) -> Bool {
        var i = start

        // Titles are matched after trimming whitespacesAndNewlines, which is wider than isTrimCharacter.
        while i < end, table[Int(base[i])] & Flag.whitespace != 0 { i += 1 }

        // 正文 (U+6B63 U+6587)
        if end - i >= 2, base[i] == 0x6B63, base[i + 1] == 0x6587 {
            i += 2
            while i < end, table[Int(base[i])] & Flag.whitespace != 0 { i += 1 }
        }
        guard i < end else { return false }

        // Special titles: 序章, 前言, 番外 ...
        if table[Int(base[i])] & Flag.specialHead != 0,
           end - i >= 2,
           specialStartPairs.contains(UInt32(base[i]) << 16 | UInt32(base[i + 1])) {
            return true
        }

        // Numbered titles: 第一章, 12章, 第二卷 第三章, ...
        var sawNumber = false
        while i < end {
            let flags = table[Int(base[i])]
            if flags & Flag.number != 0 {
                sawNumber = true
            } else if flags & (Flag.di | Flag.whitespace) == 0 {
                break
            }
            i += 1
        }
        guard sawNumber, i < end else { return false }
        return table[Int(base[i])] & Flag.anyUnit != 0
    }

    private static func isChapterTitle(_ base: UnsafePointer<unichar>, start: Int, end: Int,
                                       table: UnsafePointer<UInt16>) -> Bool {
        var s = start
        var e = end
        while s < e, table[Int(base[s])] & Flag.whitespace != 0 { s += 1 }
        while e > s, table[Int(base[e - 1])] & Flag.whitespace != 0 { e -= 1 }

        let matcher = TitleMatcher(units: UnsafeBufferPointer(start: base + s, count: e - s),
                                   table: table,
                                   rejectBareNumerals: rejectBareNumeralTitles)
        return matcher.isChapterTitle()
    }

    // MARK: - Title matcher

    // Matches the grammar above without backtracking. A "position set" is a UInt64 bitmask:
    // bit i means "the first i units have been consumed". Every grammar element maps one set
    // to the next, and the title is accepted if some position reached after the head leaves a
    // valid tail. Because all alternatives are explored at once, the result is identical to
    // what a backtracking regex would return.
    @MainActor
    private struct TitleMatcher {
        static let tailLimit = 36
        static let prefixWord = Array("正文".utf16)
        static let fanwaiWord = Array("番外".utf16)
        static let fanwaiSuffixes = Array("篇卷".utf16)
        static let specialWords = ChineseNovelChapterParser.specialTitleWords.map { Array($0.utf16) }

        let units: UnsafeBufferPointer<unichar>
        let table: UnsafePointer<UInt16>
        let rejectBareNumerals: Bool

        func isChapterTitle() -> Bool {
            guard !units.isEmpty, units.count < 64 else { return false }

            // (?:正文\s*)?
            let origin: UInt64 = 1
            let prefixed = origin | star(word(origin, Self.prefixWord), Flag.regexSpace)

            let ends = numberedHeadEnds(from: prefixed) | specialHeadEnds(from: prefixed)
            var pending = ends
            while pending != 0 {
                let position = pending.trailingZeroBitCount
                pending &= pending - 1
                if suffixMatches(from: position) { return true }
            }
            return false
        }

        // Positions after the head of a numbered title.
        private func numberedHeadEnds(from prefixed: UInt64) -> UInt64 {
            // 第\s*N+\s*[卷部集]  (alternative B ends here)
            let volumeNumber = plus(star(step(prefixed, Flag.di), Flag.regexSpace), Flag.number)
            let volumeEnd = step(star(volumeNumber, Flag.regexSpace), Flag.volumeUnit)
            // The optional volume prefix of alternative A also swallows trailing \s*.
            let afterVolume = star(volumeEnd, Flag.regexSpace)

            // (?:第\s*)?  -- starts that have a 第 or a volume before the chapter number
            let afterDi = star(step(prefixed | afterVolume, Flag.di), Flag.regexSpace)
            let chapterStarts = afterDi | afterVolume

            // N+\s*[章节回篇]
            func chapterEnds(_ starts: UInt64) -> UInt64 {
                step(star(plus(starts, Flag.number), Flag.regexSpace), Flag.chapterUnit)
            }

            var ends = volumeEnd | chapterEnds(chapterStarts)

            // Bare "N+章" with no 第 anywhere in front of the number.
            let bareEnds = chapterEnds(prefixed)
            ends |= rejectBareNumerals ? onlyBeforeBoundary(bareEnds) : bareEnds
            return ends
        }

        // Positions after the head of a special title.
        private func specialHeadEnds(from prefixed: UInt64) -> UInt64 {
            var ends: UInt64 = 0
            for text in Self.specialWords { ends |= word(prefixed, text) }

            // 番外(?:篇|卷)?(?:\s*N+)?
            let fanwai = word(prefixed, Self.fanwaiWord)
            let withSuffix = fanwai | step(fanwai, where: { Self.fanwaiSuffixes.contains($0) })
            let withNumber = plus(star(withSuffix, Flag.regexSpace), Flag.number)
            return ends | withSuffix | withNumber
        }

        // (?:\s*SEP\s*|\s+)? TAIL$  starting at `position`.
        private func suffixMatches(from position: Int) -> Bool {
            // Everything the separator group can consume is also a TAIL character, so taking the
            // longest possible group leaves the shortest tail and is always the best choice.
            var i = position
            while i < units.count, has(Flag.regexSpace, units[i]) { i += 1 }
            if i < units.count, has(Flag.separator, units[i]) {
                i += 1
                while i < units.count, has(Flag.regexSpace, units[i]) { i += 1 }
            }

            // Remaining units must all be TAIL characters, at most tailLimit code points.
            var codePoints = 0
            while i < units.count {
                let unit = units[i]
                if (0xD800...0xDBFF).contains(unit), i + 1 < units.count, (0xDC00...0xDFFF).contains(units[i + 1]) {
                    let high = UInt32(unit) - 0xD800
                    let low = UInt32(units[i + 1]) - 0xDC00
                    let scalar: UInt32 = 0x10000 + (high << 10) + low
                    guard Self.isSupplementaryHan(scalar) else { return false }
                    i += 2
                } else {
                    guard has(Flag.tail, unit) else { return false }
                    i += 1
                }
                codePoints += 1
            }
            return codePoints <= Self.tailLimit
        }

        // Rare path: use the platform's ICU property so supplementary Han characters
        // follow the same Unicode version and exact ranges as the original title regex.
        private static let hanExpression = try! NSRegularExpression(pattern: #"\A\p{Han}\z"#)

        private static func isSupplementaryHan(_ scalar: UInt32) -> Bool {
            guard let value = UnicodeScalar(scalar) else { return false }
            let text = String(value)
            return hanExpression.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) != nil
        }

        // Keeps only positions followed by whitespace, a separator, or the end of the title.
        private func onlyBeforeBoundary(_ positions: UInt64) -> UInt64 {
            var kept: UInt64 = 0
            for position in 0...units.count where positions & bit(position) != 0 {
                if position == units.count || has(Flag.regexSpace | Flag.separator, units[position]) {
                    kept |= bit(position)
                }
            }
            return kept
        }

        // MARK: Position-set primitives

        private func bit(_ position: Int) -> UInt64 {
            1 << UInt64(position)
        }

        private func has(_ flags: UInt16, _ unit: unichar) -> Bool {
            table[Int(unit)] & flags != 0
        }

        // Consume exactly one unit that satisfies `predicate`.
        private func step(_ set: UInt64, where predicate: (unichar) -> Bool) -> UInt64 {
            var result: UInt64 = 0
            // Only visit active positions. Bit units.count is an accepting position,
            // not an input index, and must not be dereferenced.
            var pending = set & (bit(units.count) - 1)
            while pending != 0 {
                let i = pending.trailingZeroBitCount
                pending &= pending - 1
                if predicate(units[i]) { result |= bit(i + 1) }
            }
            return result
        }

        // Consume zero or more matching units. Process the lowest active bit first;
        // a newly reached position can only be ahead of the one just consumed.
        private func star(_ set: UInt64, where predicate: (unichar) -> Bool) -> UInt64 {
            var result = set
            let inputMask = bit(units.count) - 1
            var pending = set & inputMask
            while pending != 0 {
                let i = pending.trailingZeroBitCount
                pending &= pending - 1
                if predicate(units[i]) {
                    let next = bit(i + 1)
                    result |= next
                    pending |= next & inputMask
                }
            }
            return result
        }

        private func step(_ set: UInt64, _ flags: UInt16) -> UInt64 {
            step(set, where: { has(flags, $0) })
        }

        private func star(_ set: UInt64, _ flags: UInt16) -> UInt64 {
            star(set, where: { has(flags, $0) })
        }

        private func plus(_ set: UInt64, _ flags: UInt16) -> UInt64 {
            star(step(set, flags), flags)
        }

        private func word(_ set: UInt64, _ text: [unichar]) -> UInt64 {
            var current = set
            for unit in text {
                guard current != 0 else { return 0 }
                current = step(current, where: { $0 == unit })
            }
            return current
        }
    }

    // MARK: - Catalog filtering

    private static func removeCatalogMarkers(from markers: [Marker], textLength: Int) -> [Marker] {
        guard markers.count >= 3 else { return markers }

        var kept: [Marker] = []
        kept.reserveCapacity(markers.count)
        var clusterStart = 0
        var clusterTitles = Set<UInt64>()
        clusterTitles.insert(markers[0].hash)

        // Clusters are closed in order, so surviving markers can be appended as we go.
        func closeCluster(at end: Int) {
            let size = end - clusterStart + 1
            let isFrontCatalog = markers[clusterStart].location < min(80000, max(textLength / 4, 1))
            let isCatalog = size >= 3 && (isFrontCatalog || size >= 8)
            if !isCatalog {
                kept.append(contentsOf: markers[clusterStart...end])
            }
        }

        for idx in 1..<markers.count {
            let distance = markers[idx].location - markers[idx - 1].upperBound
            if distance > catalogDistance || clusterTitles.contains(markers[idx].hash) {
                closeCluster(at: idx - 1)
                clusterStart = idx
                clusterTitles.removeAll(keepingCapacity: true)
            }
            clusterTitles.insert(markers[idx].hash)
        }
        closeCluster(at: markers.count - 1)
        return kept
    }

    // MARK: - Chapter building

    @MainActor
    private struct ChapterBuilder {
        let text: NSString
        let units: UnsafeBufferPointer<unichar>
        var chapters: [ChapterModel] = []

        mutating func build(from markers: [Marker]) {
            let length = units.count
            guard let first = markers.first else {
                chapters.reserveCapacity(length / ChineseNovelChapterParser.targetChapterLength + 1)
                appendSplitChapters(title: nil, location: 0, length: length)
                return
            }
            chapters.reserveCapacity(markers.count + 1)

            var firstStart = first.location
            let prefixContainsCatalog = firstStart > 0 && containsCatalogMark(before: firstStart)

            if firstStart > 100, !prefixContainsCatalog {
                appendChapter(title: "序言", location: 0, length: firstStart)
            } else if !prefixContainsCatalog {
                firstStart = 0
            }

            let last = markers.count - 1
            for index in markers.indices {
                let marker = markers[index]
                let start = index == 0 ? firstStart : marker.location
                let end = index == last ? length : markers[index + 1].location
                appendChapter(title: makeTitle(marker), location: start, length: end - start)
            }
        }

        // "目录" (U+76EE U+5F55) anywhere in units[0..<limit], searched in place.
        private func containsCatalogMark(before limit: Int) -> Bool {
            var i = 0
            while i + 1 < limit {
                if units[i] == 0x76EE, units[i + 1] == 0x5F55 { return true }
                i += 1
            }
            return false
        }

        // The only place a String is created: once per surviving chapter title,
        // straight from the UTF-16 buffer (no NSString round trip).
        private func makeTitle(_ marker: Marker) -> String {
            guard let base = units.baseAddress else { return "" }
            return String(decoding: UnsafeBufferPointer(start: base + marker.location, count: marker.length),
                          as: UTF16.self)
        }

        private mutating func appendChapter(title: String?, location: Int, length: Int) {
            guard length > 0 else { return }

            if length <= ChineseNovelChapterParser.maxChapterLength {
                chapters.append(ChapterModel(idx: chapters.count, title: title, sourceText: text,
                                             range: NSRange(location: location, length: length)))
            } else {
                appendSplitChapters(title: title, location: location, length: length)
            }
        }

        // Unrecognized text always uses targetChapterLength. Recognized chapters only
        // enter this path above maxChapterLength, preserving their existing boundaries.
        private mutating func appendSplitChapters(title: String?, location: Int, length: Int) {
            var cursor = location
            let upperBound = location + length
            while cursor < upperBound {
                let split = splitLocation(from: cursor, upperBound: upperBound)
                chapters.append(ChapterModel(idx: chapters.count, title: title, sourceText: text,
                                             range: NSRange(location: cursor, length: split - cursor)))
                cursor = split
            }
        }

        private func splitLocation(from start: Int, upperBound: Int) -> Int {
            let desired = min(start + ChineseNovelChapterParser.targetChapterLength, upperBound)
            if desired >= upperBound { return upperBound }

            let window = ChineseNovelChapterParser.splitSearchWindow
            let lowerBound = max(start + 1, desired - window)
            if let backward = lineBreakLocation(from: min(desired, upperBound - 1), through: lowerBound,
                                                upperBound: upperBound, reversed: true),
               backward > start {
                return backward
            }

            let forwardBound = min(upperBound - 1, desired + window)
            if let forward = lineBreakLocation(from: desired, through: forwardBound,
                                               upperBound: upperBound, reversed: false),
               forward > start {
                return forward
            }

            return composedCharacterBoundary(proposed: desired, from: start, upperBound: upperBound)
        }

        private func lineBreakLocation(from start: Int, through end: Int, upperBound: Int, reversed: Bool) -> Int? {
            var index = start
            if reversed {
                while index >= end {
                    if let location = locationAfterLineBreak(at: index, upperBound: upperBound) { return location }
                    index -= 1
                }
            } else {
                while index <= end {
                    if let location = locationAfterLineBreak(at: index, upperBound: upperBound) { return location }
                    index += 1
                }
            }
            return nil
        }

        private func locationAfterLineBreak(at index: Int, upperBound: Int) -> Int? {
            let character = units[index]
            if character == 10 { return index + 1 }
            if character == 13 {
                if index + 1 < upperBound, units[index + 1] == 10 {
                    return index + 2
                }
                return index + 1
            }
            return nil
        }

        // Rare path (no line break within the search window); keeps NSString's notion of
        // composed character sequences so surrogate pairs and combining marks are never split.
        private func composedCharacterBoundary(proposed: Int, from start: Int, upperBound: Int) -> Int {
            let location = min(max(proposed, start + 1), upperBound)
            if location >= upperBound { return upperBound }

            let range = text.rangeOfComposedCharacterSequence(at: location)
            if range.location <= start {
                return min(location + 1, upperBound)
            }
            return range.location
        }
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
