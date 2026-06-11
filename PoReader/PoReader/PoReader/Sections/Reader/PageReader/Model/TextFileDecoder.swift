import Foundation

enum TextFileDecoder {
    static func decode(_ data: Data) -> NSString? {
        if data.isEmpty { return nil }

        if let bomEncoding = bomEncoding(for: data),
           let string = String(data: data, encoding: bomEncoding) {
            return normalize(string) as NSString
        }

        return preferredDecodedString(from: data).map { normalize($0) as NSString }
    }

    private static func bomEncoding(for data: Data) -> String.Encoding? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return .utf8 }
        if data.starts(with: [0xFF, 0xFE]) { return .utf16LittleEndian }
        if data.starts(with: [0xFE, 0xFF]) { return .utf16BigEndian }
        return nil
    }

    private static func preferredDecodedString(from data: Data) -> String? {
        let commonEncodings = uniqueEncodings([
            .utf8,
            .gb18030,
            .windowsSimplifiedChinese,
            .big5Chinese
        ])
        if let utf16Encoding = likelyUTF16Encoding(for: data) {
            if let string = String(data: data, encoding: utf16Encoding) {
                return string
            }
        }

        var candidates = decodedCandidates(from: data, encodings: commonEncodings, priorityOffset: 0)
        if shouldTryUTF16Fallback(candidates) {
            candidates.append(contentsOf: decodedCandidates(from: data,
                                                            encodings: [.utf16LittleEndian, .utf16BigEndian],
                                                            priorityOffset: commonEncodings.count))
        }

        return candidates.max { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.priority > rhs.priority
            }
            return lhs.score < rhs.score
        }?
        .string
    }

    private static func decodedCandidates(from data: Data, encodings: [String.Encoding], priorityOffset: Int) -> [DecodedCandidate] {
        encodings.enumerated().compactMap { index, encoding -> DecodedCandidate? in
            guard let string = String(data: data, encoding: encoding) else { return nil }
            return DecodedCandidate(encoding: encoding,
                                    string: string,
                                    score: score(string),
                                    priority: priorityOffset + index)
        }
    }

    private static func shouldTryUTF16Fallback(_ candidates: [DecodedCandidate]) -> Bool {
        guard !candidates.contains(where: { $0.encoding == .utf8 }) else { return false }
        return candidates.map(\.score).max() ?? Int.min < 0
    }

    private static func uniqueEncodings(_ encodings: [String.Encoding]) -> [String.Encoding] {
        var result: [String.Encoding] = []
        result.reserveCapacity(encodings.count)
        for encoding in encodings where !result.contains(encoding) {
            result.append(encoding)
        }
        return result
    }

    private struct DecodedCandidate {
        let encoding: String.Encoding
        let string: String
        let score: Int
        let priority: Int
    }

    private static func likelyUTF16Encoding(for data: Data) -> String.Encoding? {
        let sampleCount = min(data.count, 512)
        guard sampleCount >= 4 else { return nil }

        var evenNullCount = 0
        var oddNullCount = 0
        for idx in 0..<sampleCount where data[idx] == 0 {
            if idx.isMultiple(of: 2) {
                evenNullCount += 1
            } else {
                oddNullCount += 1
            }
        }

        let threshold = sampleCount / 8
        if oddNullCount > threshold { return .utf16LittleEndian }
        if evenNullCount > threshold { return .utf16BigEndian }
        return nil
    }

    private static func score(_ string: String) -> Int {
        var totalScore = 0
        var scalarCount = 0
        let maxSampleCount = 4096

        for scalar in string.unicodeScalars {
            scalarCount += 1
            totalScore += score(scalar)
            if scalarCount >= maxSampleCount {
                break
            }
        }

        return totalScore
    }

    private static func score(_ scalar: Unicode.Scalar) -> Int {
        let value = scalar.value

        switch value {
        case 0:
            return -200
        case 9, 10:
            return 1
        case 1..<32, 127..<160:
            return -40
        case 0xFFFD:
            return -300
        case 0xE000...0xF8FF:
            return -30
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0x2A700...0x2B73F, 0x2B740...0x2B81F, 0x2B820...0x2CEAF:
            return 6
        case 0x3000...0x303F, 0xFF00...0xFFEF:
            return 4
        case 32...126:
            return 2
        default:
            return 0
        }
    }

    private static func normalize(_ string: String) -> String {
        var value = string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if value.first == "\u{feff}" {
            value.removeFirst()
        }
        return value
    }
}

private extension String.Encoding {
    static let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    static let windowsSimplifiedChinese = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosChineseSimplif.rawValue)))
    static let big5Chinese = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
}
