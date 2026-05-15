import Foundation

enum TextFileDecoder {
    static func decode(_ data: Data) -> NSString? {
        if data.isEmpty { return "" as NSString }

        for encoding in preferredEncodings(for: data) {
            if let string = String(data: data, encoding: encoding) {
                return normalize(string) as NSString
            }
        }
        return nil
    }

    private static func preferredEncodings(for data: Data) -> [String.Encoding] {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return [.utf8] }
        if data.starts(with: [0xFF, 0xFE]) { return [.utf16LittleEndian] }
        if data.starts(with: [0xFE, 0xFF]) { return [.utf16BigEndian] }

        var encodings: [String.Encoding] = [
            .utf8,
            .gb18030,
            .windowsSimplifiedChinese,
            .gb2312,
            .big5Chinese
        ]
        if let utf16Encoding = likelyUTF16Encoding(for: data) {
            encodings.insert(utf16Encoding, at: 1)
        }
        return encodings
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
    static let gb2312 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)))
    static let big5Chinese = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
}
