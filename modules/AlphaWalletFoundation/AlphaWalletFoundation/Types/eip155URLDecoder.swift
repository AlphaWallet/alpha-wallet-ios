//
//  eip155URLCoder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.11.2021.
//

import Foundation 

public struct Eip155URL {
    let tokenType: TokenInterfaceType?
    let server: RPCServer?
    let path: String
}

extension Eip155URL: CustomStringConvertible {
    public var description: String {
        return [
            tokenType?.rawValue ?? "",
            server.flatMap { String($0.chainID) } ?? "",
            path
        ].joined(separator: "-")
    }
}

public struct eip155URLCoder {
    static let key = "eip155"
    private static let decimalParser = DecimalParser()

    /// Decoding function for urls like `eip155:1/erc721:0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6/2430`
    public static func decode(from string: String) -> Eip155URL? {
        let components = string.components(separatedBy: ":")
        guard components.count >= 3, components[0].contains(eip155URLCoder.key) else { return .none }
        let chainAndTokenTypeComponents = components[1].components(separatedBy: "/")
        guard chainAndTokenTypeComponents.count == 2 else { return .none }
        let server = decimalParser.parseAnyDecimal(from: chainAndTokenTypeComponents[0]).flatMap({ RPCServer(chainID: $0.intValue) })

        return .init(tokenType: TokenInterfaceType(rawValue: chainAndTokenTypeComponents[1]), server: server, path: components[2])
    }

    public static func decodeRPC(from string: String) -> RPCServer? {
        let components = string.components(separatedBy: ":")
        guard components.count >= 2, components[0].contains(eip155URLCoder.key) else { return .none }
        return decimalParser.parseAnyDecimal(from: components[1]).flatMap({ RPCServer(chainID: $0.intValue) })
    }

    ///"eip155:42:0x9E7aAF819E8f227B766E71FAc2DD018A36a0969A"
    public static func encode(rpcServer: RPCServer, address: AlphaWallet.Address? = nil) -> String {
        let elements: [String] = [eip155URLCoder.key, String(rpcServer.chainID), address?.eip55String].compactMap { $0 }
        return elements.joined(separator: ":")
    }
}

extension RPCServer {

    public var eip155: String {
        return eip155URLCoder.encode(rpcServer: self)
    }

    public static func decodeEip155Array(values: Set<String>) -> [RPCServer] {
        return values.compactMap { str in
            if let server = eip155URLCoder.decodeRPC(from: str) {
                return server
            } else if let value = Int(str, radix: 10) {
                return RPCServer(chainID: value)
            } else {
                return nil
            }
        }
    }
}

