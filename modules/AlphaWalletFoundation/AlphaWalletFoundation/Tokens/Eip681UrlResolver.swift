// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import Combine

public final class Eip681UrlResolver {
    public enum Resolution {
        case address(AlphaWallet.Address)
        case transaction(transactionType: TransactionType, token: Token)
    }

    public enum MissingRpcServerStrategy {
        case fallbackToFirstMatching
        case fallbackToAnyMatching
        case fallbackToPreffered(RPCServer)
    }

    private let config: Config
    private let importToken: ImportToken
    private let missingRPCServerStrategy: MissingRpcServerStrategy

    public init(config: Config, importToken: ImportToken, missingRPCServerStrategy: MissingRpcServerStrategy) {
        self.importToken = importToken
        self.config = config
        self.missingRPCServerStrategy = missingRPCServerStrategy
    }

    @discardableResult public func resolvePublisher(url: URL) -> AnyPublisher<Eip681UrlResolver.Resolution, CheckEIP681Error> {
        return resolve(url: url).publisher
            .receive(on: RunLoop.main)
            .mapError { return $0.embedded as? CheckEIP681Error ?? .embeded(error: $0.embedded) }
            .eraseToAnyPublisher()
    }

    @discardableResult public func resolve(url: URL) -> Promise<Eip681UrlResolver.Resolution> {
        switch AddressOrEip681Parser.from(string: url.absoluteString) {
        case .address(let address):
            return .value(.address(address))
        case .eip681(let protocolName, let address, let functionName, let params):
            return resolve(protocolName: protocolName, address: address, functionName: functionName, params: params)
        case .none:
            return .init(error: CheckEIP681Error.notEIP681)
        }
    }

    @discardableResult public func resolve(protocolName: String, address: AddressOrEnsName, functionName: String?, params: [String: String]) -> Promise<Eip681UrlResolver.Resolution> {
        Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params)
            .parse()
            .then { [importToken] result -> Promise<Eip681UrlResolver.Resolution> in
                guard let (contract: contract, customServer, recipient, amount) = result.parameters else {
                    return .init(error: CheckEIP681Error.parameterInvalid)
                }
                guard let server = self.serverFromEip681LinkOrDefault(customServer) else {
                    return .init(error: CheckEIP681Error.missingRpcServer)
                }

                return importToken
                    .importToken(for: contract, server: server)
                    .map { token -> Eip681UrlResolver.Resolution in
                        switch token.type {
                        case .erc20, .nativeCryptocurrency:
                            let transactionType = Eip681UrlResolver.transferFungibleTransactionType(token, recipient: recipient, amount: amount)
                            return .transaction(transactionType: transactionType, token: token)
                        case .erc1155, .erc721, .erc721ForTickets, .erc875:
                            throw CheckEIP681Error.tokenTypeNotSupported
                        }
                    }
            }
    }

    private func serverFromEip681LinkOrDefault(_ serverInLink: RPCServer?) -> RPCServer? {
        if let server = serverInLink {
            return server
        } else {
            switch missingRPCServerStrategy {
            case .fallbackToAnyMatching:
                return serverInLink ?? config.anyEnabledServer()
            case .fallbackToFirstMatching:
                //Specs https://eips.ethereum.org/EIPS/eip-681 says we should fallback to the current chainId, but since we support multiple chains at the same time, we only fallback if there is exactly 1 enabled network
                return config.enabledServers.count == 1 ? config.enabledServers[0] : nil
            case .fallbackToPreffered(let server):
                return server
            }
        }
    }

    private static func transferFungibleTransactionType(_ token: Token, recipient: AddressOrEnsName?, amount: String) -> TransactionType {
        let formatter = EtherNumberFormatter.full
        let amount = amount.scientificAmountToBigInt.flatMap { formatter.string(from: $0, decimals: token.decimals) }

        return TransactionType(fungibleToken: token, recipient: recipient, amount: amount)
    }
}
