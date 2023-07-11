// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

public enum AddressOrEip681 {
    case address(AlphaWallet.Address)
    ///Strictly speaking, EIP 681 should be like this:
    ///  ethereum:pay-0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359?value=2.014e18
    ///the "pay-" prefix is optional, if that prefix absent, the payload (0xfb6 here) must be an address. This is because not all ethereum: links are EIP 681
    case eip681(protocolName: String, address: AddressOrDomainName, functionName: String?, params: [String: String])
}

public struct AddressOrEip681Parser {
    public static func from(string: String) -> AddressOrEip681? {
        let string = string.trimmed
        let parts = string.components(separatedBy: ":")
        if parts.count == 1, let address = parts.first.flatMap({ AlphaWallet.Address(string: $0) }) {
            return .address(address)
        }

        guard parts.count == 2, let addressOrNameString = parts.last?.slice(to: "@").slice(to: "/").slice(to: "?"), let address = AddressOrDomainName(string: Eip681Parser.stripOptionalPrefix(from: addressOrNameString)) else { return nil }
        let secondHalf = parts[1]
        let uncheckedParamParts = Array(secondHalf.components(separatedBy: "?")[1...])
        let paramParts = uncheckedParamParts.isEmpty ? [] : Array(uncheckedParamParts[0].components(separatedBy: "&"))
        var params = AddressOrEip681Parser.parseParamsFromParamParts(paramParts: paramParts)
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

public extension String {
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }

    func slice(to: String) -> String {
        if let substringTo = (range(of: to, range: startIndex..<endIndex)?.lowerBound) {
            return String(self[startIndex..<substringTo])
        } else {
            return self
        }
    }
}
