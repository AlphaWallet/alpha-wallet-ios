// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

enum QRCodeValue {
    case address(AlphaWallet.Address)
    ///Strictly speaking, EIP 681 should be like this:
    ///  ethereum:pay-0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359?value=2.014e18
    ///the "pay-" prefix is optional, if that prefix absent, the payload (0xfb6 here) must be an address. This is because not all ethereum: links are EIP 681
    case eip681(protocolName: String, address: AddressOrEnsName, functionName: String?, params: [String: String])
}

struct QRCodeValueParser {
    static func from(string: String) -> QRCodeValue? {
        let string = string.trimmed
        let parts = string.components(separatedBy: ":")
        if parts.count == 1, let address = parts.first.flatMap({ AlphaWallet.Address(string: $0) }) {
            return .address(address)
        }

        guard parts.count == 2, let address = parts.last?.slice(to: "@")?.slice(to: "/")?.slice(to: "?").flatMap({ AddressOrEnsName(string: Eip681Parser.stripOptionalPrefix(from: $0)) }) else { return nil }
        let secondHalf = parts[1]
        let uncheckedParamParts = Array(secondHalf.components(separatedBy: "?")[1...])
        let paramParts = uncheckedParamParts.isEmpty ? [] : Array(uncheckedParamParts[0].components(separatedBy: "&"))
        var params = QRCodeValueParser.parseParamsFromParamParts(paramParts: paramParts)
        if let chainId = secondHalf.slice(from: "@", to: "/") {
            params["chainId"] = chainId
        } else if let chainId = secondHalf.slice(from: "@", to: "?") {
            params["chainId"] = chainId
        }
        let functionName = secondHalf.slice(from: "/", to: "?")
        return .eip681(
            protocolName: parts.first ?? "",
            address: address,
            functionName: functionName,
            params: params
        )
    }

    private static func parseParamsFromParamParts(paramParts: [String]) -> [String: String] {
        if paramParts.isEmpty {
            return [:]
        }
        var params = [String: String]()
        var i = 0
        while i < paramParts.count {
            let tokenizedParamParts = paramParts[i].components(separatedBy: "=")
            if tokenizedParamParts.count < 2 {
                break
            } else {
                params[tokenizedParamParts[0]] = tokenizedParamParts[1]
                i += 1
            }
        }
        return params
    }
}

extension String {
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                substring(with: substringFrom..<substringTo)
            }
        }
    }

    func slice(to: String) -> String? {
        if let substringTo = (range(of: to, range: startIndex..<endIndex)?.lowerBound) {
            return substring(with: startIndex..<substringTo)
        } else {
            return self
        }
    }
}
