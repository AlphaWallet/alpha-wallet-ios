// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct ParserResult: Equatable {
    let protocolName: String
    let address: String
    let params: [String: String]
}

struct QRURLParser {
    static func from(string: String) -> ParserResult? {
        let result = string.replacingOccurrences(of: "pay-", with: "")
        let parts = result.components(separatedBy: ":")
        if parts.count == 1, let address = parts.first, CryptoAddressValidator.isValidAddress(address) {
            return ParserResult(
                protocolName: "",
                address: address,
                params: [:]
            )
        }

        if parts.count == 2, let address = QRURLParser.getAddress(from: parts.last), CryptoAddressValidator.isValidAddress(address) {
            let secondHalf = parts[1]
            let uncheckedParamParts = Array(secondHalf.components(separatedBy: "?")[1...])
            let paramParts = uncheckedParamParts.isEmpty ? [] : Array(uncheckedParamParts[0].components(separatedBy: "&"))
            var params = QRURLParser.parseParamsFromParamParts(paramParts: paramParts)
            if let chainId = secondHalf.slice(from: "@", to: "/") {
                params["chainId"] = chainId
            } else if let chainId = secondHalf.slice(from: "@", to: "?") {
                params["chainId"] = chainId
            }
            return ParserResult(
                protocolName: parts.first ?? "",
                address: address,
                params: params
            )
        }

        return nil
    }

    private static func getAddress(from: String?) -> String? {
        guard let from = from, from.count >= AddressValidatorType.ethereum.addressLength else {
            return .none
        }
        return from.substring(to: AddressValidatorType.ethereum.addressLength)
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
}
