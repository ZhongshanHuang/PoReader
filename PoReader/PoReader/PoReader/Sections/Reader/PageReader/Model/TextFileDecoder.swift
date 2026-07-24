import Foundation

enum TextFileDecoder {
    static func decode(_ data: Data) -> NSString? {
        if data.isEmpty { return nil }

        guard let encoding = preferredEncoding(for: data),
              let string = String(data: data, encoding: encoding) else { return nil }
        return normalize(string) as NSString
    }

    private static func preferredEncoding(for data: Data) -> String.Encoding? {
        if let encoding = bomEncoding(for: data) { return encoding }
        if let encoding = likelyUTF16Encoding(for: data) { return encoding }
        return bestSampledEncoding(for: sampleData(from: data))
    }

    private static func bomEncoding(for data: Data) -> String.Encoding? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return .utf8 }
        if data.starts(with: [0xFF, 0xFE]) { return .utf16LittleEndian }
        if data.starts(with: [0xFE, 0xFF]) { return .utf16BigEndian }
        return nil
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

    private static func bestSampledEncoding(for sample: Data) -> String.Encoding? {
        let legacyCandidates = decodedSamples(from: sample,
                                              encodings: legacyEncodings,
                                              priorityOffset: 0)

        if let bestLegacyCandidate = bestDecodedSample(in: legacyCandidates),
           bestLegacyCandidate.readabilityScore >= 0 {
            return bestLegacyCandidate.encoding
        }

        let utf16Candidates = decodedSamples(from: sample,
                                             encodings: utf16Encodings,
                                             priorityOffset: legacyEncodings.count)
        return bestDecodedSample(in: legacyCandidates + utf16Candidates)?.encoding
    }

    private static func decodedSamples(from sample: Data,
                                       encodings: [String.Encoding],
                                       priorityOffset: Int) -> [DecodedSample] {
        encodings.enumerated().compactMap { index, encoding in
            guard let string = decodeSample(sample, using: encoding) else { return nil }
            return DecodedSample(encoding: encoding,
                                 readabilityScore: readabilityScore(of: string),
                                 priority: priorityOffset + index)
        }
    }

    private static func bestDecodedSample(in candidates: [DecodedSample]) -> DecodedSample? {
        candidates.max { lhs, rhs in
            if lhs.readabilityScore == rhs.readabilityScore {
                return lhs.priority > rhs.priority
            }
            return lhs.readabilityScore < rhs.readabilityScore
        }
    }

    private static func sampleData(from data: Data) -> Data {
        Data(data.prefix(sampleByteLimit))
    }

    private static func decodeSample(_ sample: Data, using encoding: String.Encoding) -> String? {
        if let string = String(data: sample, encoding: encoding) {
            return string
        }

        guard sample.count > 1 else { return nil }
        for trimCount in 1...min(4, sample.count - 1) {
            let trimmedSample = sample.prefix(sample.count - trimCount)
            if let string = String(data: trimmedSample, encoding: encoding) {
                return string
            }
        }
        return nil
    }

    /// Scores a small decoded sample so encodings that technically succeed but produce gibberish
    /// lose to encodings that produce readable Chinese/ASCII text.
    private static func readabilityScore(of string: String) -> Int {
        var totalScore = 0
        var scalarCount = 0

        for scalar in string.unicodeScalars {
            scalarCount += 1
            totalScore += readabilityScore(of: scalar)
            if scalarCount >= sampleScalarLimit {
                break
            }
        }

        return totalScore
    }

    private static func readabilityScore(of scalar: Unicode.Scalar) -> Int {
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

    private static let sampleByteLimit = 64 * 1024
    private static let sampleScalarLimit = 4096

    private static let legacyEncodings: [String.Encoding] = [
        .utf8,
        .gb18030,
        .big5Chinese
    ]

    private static let utf16Encodings: [String.Encoding] = [
        .utf16LittleEndian,
        .utf16BigEndian
    ]

    private struct DecodedSample {
        let encoding: String.Encoding
        let readabilityScore: Int
        let priority: Int
    }
}

private extension String.Encoding {
    static let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    static let big5Chinese = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
}
