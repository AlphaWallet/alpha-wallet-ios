// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension String {
    internal var hex: String {
        guard let data = self.data(using: .utf8) else {
            return String()
        }

        return data.map {
            String(format: "%02x", $0)
        }.joined()
    }

    internal var hexEncoded: String {
        guard let data = self.data(using: .utf8) else {
            return String()
        }
        return data.hexEncoded
    }

    internal var has0xPrefix: Bool {
        return hasPrefix("0x")
    }

    internal var isPrivateKey: Bool {
        let value = self.drop0x.components(separatedBy: " ").joined()
        return value.count == 64
    }

    public var drop0x: String {
        if count > 2 && substring(with: 0..<2) == "0x" {
            return String(dropFirst(2))
        }
        return self
    }

    internal var add0x: String {
        if hasPrefix("0x") {
            return self
        } else {
            return "0x" + self
        }
    }

    internal func index(from: Int) -> Index {
        return index(startIndex, offsetBy: from)
    }

    internal func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    internal func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    internal func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
}

extension StringProtocol {

    internal func chunked(into size: Int) -> [SubSequence] {
        var chunks: [SubSequence] = []

        var i = startIndex

        while let nextIndex = index(i, offsetBy: size, limitedBy: endIndex) {
            chunks.append(self[i ..< nextIndex])
            i = nextIndex
        }

        let finalChunk = self[i ..< endIndex]

        if finalChunk.isEmpty == false {
            chunks.append(finalChunk)
        }

        return chunks
    }
}
