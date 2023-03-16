//
//  TokenUriMapSupportable.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 16.03.2023.
//

import Foundation
import BigInt

public protocol TokenUriMapSupportable {
    func map(uri: URL) -> URL?
}

public struct TokenUriMapper: TokenUriMapSupportable {
    public let hostMappers: [TokenUriMapSupportable]

    public init(hostMappers: [TokenUriMapSupportable]) {
        self.hostMappers = hostMappers
    }

    public func map(uri: URL) -> URL? {
        hostMappers.compactMap { $0.map(uri: uri) }.first
    }
}

//e.g: need to convert https://api.mintkudos.xyz/metadata/3ba0000000000000000000000000000000000000000000000000000000000000
// to https://api.mintkudos.xyz/metadata/954

public struct HostBasedTokenUriMapper: TokenUriMapSupportable {
    public let host: String

    public init(host: String) {
        self.host = host
    }

    public func map(uri: URL) -> URL? {
        guard var components = URLComponents(url: uri, resolvingAgainstBaseURL: false) else { return nil }
        guard components.host == host else { return nil }
        let path = components.path.components(separatedBy: "/")

        if let tokenIdwithTo64CharsSuffix = path.last, tokenIdwithTo64CharsSuffix.count == 64 {
            let droppedTrailingZeros = Array(tokenIdwithTo64CharsSuffix).map { String($0) }.removing(suffix: "0").joined()
            guard let tokenId = BigInt(droppedTrailingZeros.drop0x, radix: 16) else { return nil }

            let newPath = path.dropFirst(1).map { "/" + $0 }.dropLast(1).joined()
            components.path = newPath + "/" + tokenId.description

            return components.url ?? uri
        }
        return nil
    }
}

fileprivate extension Array where Element: Equatable {

    ///
    /// Removes the trailing elements that match the specified suffix.
    ///
    /// - parameter suffix: The suffix to remove.
    ///
    /// - returns: The initial array without the specified suffix.
    ///
    func removing(suffix: Element) -> [Element] {
        var array = self
        var previousValue = suffix

        for i in (0..<array.endIndex).reversed() {
            let value = array[i]
            guard value == previousValue else {
                break
            }

            array.remove(at: i)
            previousValue = value
        }

        return array
    }
}
