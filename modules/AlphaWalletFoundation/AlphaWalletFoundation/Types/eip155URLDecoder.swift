//
//  Eip155UrlCoder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.11.2021.
//

import Foundation
import AlphaWalletCore
import BigInt

public struct Eip155URL {
    let tokenType: TokenInterfaceType?
    let server: RPCServer?
    let contractAndIdString: String
    let contract: AlphaWallet.Address
    let id: BigUInt

    public init?(tokenType: TokenInterfaceType?, server: RPCServer?, path contractAndIdString: String) {
        self.tokenType = tokenType
        self.server = server
        self.contractAndIdString = contractAndIdString
        guard let (_contract, _id) = functional.parseContractAndId(contractAndIdString) else { return nil }
        self.contract = _contract
        self.id = _id
    }
}

extension Eip155URL {
    enum functional {
    }
}

extension Eip155URL.functional {
    static func parseContractAndId(_ contractAndIdString: String) -> (contract: AlphaWallet.Address, id: BigUInt)? {
        let components = contractAndIdString.split(separator: "/")
        if components.indices.contains(0) && components.indices.contains(1), let contract = AlphaWallet.Address(string: String(components[0])), let id = BigUInt(String(components[1])) {
            return (contract: contract, id: id)
        } else {
            return nil
        }
    }
}

extension Eip155URL: CustomStringConvertible {
    public var description: String {
        return [
            tokenType?.rawValue ?? "",
            server.flatMap { String($0.chainID) } ?? "",
            contractAndIdString
        ].joined(separator: "-")
    }
}

public struct Eip155UrlCoder {
    static let key = "eip155"

    /// Decoding function for urls like `eip155:1/erc721:0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6/2430`
    public static func decode(from string: String) -> Eip155URL? {
        let components = string.components(separatedBy: ":")
        guard components.count >= 3, components[0].contains(Eip155UrlCoder.key) else { return .none }
        let chainAndTokenTypeComponents = components[1].components(separatedBy: "/")
        guard chainAndTokenTypeComponents.count == 2 else { return .none }
        let server = chainAndTokenTypeComponents[0].optionalDecimalValue.flatMap({ RPCServer(chainID: $0.intValue) })

        return .init(tokenType: TokenInterfaceType(rawValue: chainAndTokenTypeComponents[1]), server: server, path: components[2])
    }

    public static func decodeRpc(from string: String) -> RPCServer? {
        let components = string.components(separatedBy: ":")
        guard components.count >= 2, components[0].contains(Eip155UrlCoder.key) else { return .none }
        return components[1].optionalDecimalValue.flatMap { RPCServer(chainIdOptional: $0.intValue) }
    }

    ///"eip155:42:0x9E7aAF819E8f227B766E71FAc2DD018A36a0969A"
    public static func encode(rpcServer: RPCServer, address: AlphaWallet.Address? = nil) -> String {
        let elements: [String] = [Eip155UrlCoder.key, String(rpcServer.chainID), address?.eip55String].compactMap { $0 }
        return elements.joined(separator: ":")
    }
}

extension RPCServer {

    public var eip155: String {
        return Eip155UrlCoder.encode(rpcServer: self)
    }

    public static func decodeEip155Array(values: Set<String>) -> [RPCServer] {
        return values.compactMap { str in
            if let server = Eip155UrlCoder.decodeRpc(from: str) {
                return server
            } else if let value = Int(str, radix: 10) {
                return RPCServer(chainIdOptional: value)
            } else {
                return nil
            }
        }
    }
}
