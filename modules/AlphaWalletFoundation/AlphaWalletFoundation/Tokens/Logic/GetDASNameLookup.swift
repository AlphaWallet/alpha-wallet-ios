//
//  GetDASNameLookup.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.10.2021.
//

import PromiseKit

//FIXME: remove if not needed, seems like not using, but why?
public final class GetDASNameLookup {
    public enum DASNameLookupError: Error {
        case ethRecordNotFound
        case invalidInput
    }

    private static let ethAddressKey = "address.eth"

    private let server: RPCServer
    private let rpcApiProvider: RpcApiProvider

    public init(server: RPCServer, rpcApiProvider: RpcApiProvider) {
        self.server = server
        self.rpcApiProvider = rpcApiProvider
    }

    public static func isValid(value: String) -> Bool {
        return value.trimmed.hasSuffix(".bit")
    }

    public func resolve(rpcURL: URL, rpcHeaders: [String: String], value: String) -> Promise<AlphaWallet.Address> {
        guard GetDASNameLookup.isValid(value: value) else {
            infoLog("[DAS] Invalid lookup: \(value)")
            return .init(error: DASNameLookupError.invalidInput)
        }

        infoLog("[DAS] Looking up value \(value)…")
        let request = JsonRpcRequest(server: server, rpcURL: rpcURL, rpcHeaders: rpcHeaders, request: DASLookupRequest(value: value))
        return firstly {
            rpcApiProvider.dataTaskPromise(request)
        }.map { response -> AlphaWallet.Address in
            infoLog("[DAS] response for value: \(value) response : \(response)")
            if let record = response.records.first(where: { $0.key == GetDASNameLookup.ethAddressKey }), let address = AlphaWallet.Address(string: record.value) {
                infoLog("[DAS] resolve value: \(value) to address: \(address)")
                return address
            } else if response.records.isEmpty, let ownerAddress = response.ownerAddress {
                infoLog("[DAS] No records fallback value: \(value) to ownerAddress: \(ownerAddress)")
                return ownerAddress
            } else {
                infoLog("[DAS] Can't resolve value: \(value)")
            }
            throw DASNameLookupError.ethRecordNotFound
        }
    }
}
