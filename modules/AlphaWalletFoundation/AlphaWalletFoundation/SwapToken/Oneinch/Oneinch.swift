//
//  OneinchHolder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation
import Combine
import Alamofire
import AlphaWalletCore

public class Oneinch: SupportedTokenActionsProvider, SwapTokenViaUrlProvider {
    private var assets: [AlphaWallet.Address: Oneinch.Asset] = .init()
    private let queue = DispatchQueue(label: "org.alphawallet.swift.Oneinch")
    private var cancelable = Set<AnyCancellable>()
    private var objectWillChangeSubject = PassthroughSubject<Void, Never>()
    private var supportedServers: [RPCServer] {
        return [.main, .binance_smart_chain, .polygon, .optimistic, .arbitrum]
    }
    private let decoder = JSONDecoder()
    private static let baseURL = "https://1inch.exchange/#"
    private static let referralSlug = "/r/0x98f21584006c79871F176F8D474958a69e04595B"
    //NOTE: for Oneinch exchange service we need to use two addresses, by default it uses Uptrennd token
    private var predefinedAssets: [Oneinch.Asset] {
        [.init(symbol: "ETH", name: "ETH", address: Constants.nativeCryptoAddressInDatabase, decimal: RPCServer.main.decimals)]
    }

    public var objectWillChange: AnyPublisher<Void, Never> {
        objectWillChangeSubject.receive(on: RunLoop.main).eraseToAnyPublisher()
    }

    public let action: String
    public let analyticsNavigation: Analytics.Navigation = .onOneinch
    public let analyticsName: String = "Oneinch"

    public func url(token: TokenActionsIdentifiable) -> URL? {
        var components = URLComponents()
        components.path = Oneinch.referralSlug + "/" + subpath(inputAddress: token.contractAddress)
        //NOTE: URLComponents doesn't allow path to contain # symbol
        guard let pathWithQueryItems = components.url?.absoluteString else { return nil }

        return URL(string: Oneinch.baseURL + pathWithQueryItems)
    }

    public func rpcServer(forToken token: TokenActionsIdentifiable) -> RPCServer? {
        supportedServers.contains(where: { $0 == token.server }) ? token.server : .main
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .swap(service: self))]
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        switch token.server {
        case .main, .arbitrum:
            return asset(for: token.contractAddress) != nil
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_sigma1, .artis_tau1, .custom, .poa, .callisto, .xDai, .classic, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .palm, .palmTestnet, .arbitrumRinkeby, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
            return false
        }
    }

    private func asset(for address: AlphaWallet.Address) -> Oneinch.Asset? {
        return assets[address]
    }

    public init(action: String) {
        self.action = action
    }

    public func start() {
        let request = OneInchAssetsRequest()
        Just(request)
            .receive(on: queue)
            .setFailureType(to: PromiseError.self)
            .flatMap { request -> AnyPublisher<[Asset], PromiseError> in
                self.retrieveAssets(request)
            }.sink { [objectWillChangeSubject] result in
                objectWillChangeSubject.send(())

                guard case .failure(let error) = result else { return }
                RemoteLogger.instance.logRpcOrOtherWebError("Oneinch error | \(error)", url: request.urlRequest?.url?.absoluteString ?? "")
            } receiveValue: { assets in
                for asset in self.predefinedAssets + assets {
                    self.assets[asset.address] = asset
                } 
            }.store(in: &cancelable)
    }

    private func subpath(inputAddress: AlphaWallet.Address) -> String {
        return [asset(for: inputAddress), asset(for: defaultOutputAddress(forInput: inputAddress))].compactMap {
            $0?.symbol
        }.joined(separator: "/")
    }

    private func retrieveAssets(_ request: OneInchAssetsRequest) -> AnyPublisher<[Oneinch.Asset], PromiseError> {
        return Alamofire.request(request)
            .responseDataPublisher(queue: queue)
            .tryMap { [decoder] in try decoder.decode(AssetsResponse.self, from: $0.data).tokens.map { $0.value } }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private func defaultOutputAddress(forInput input: AlphaWallet.Address) -> AlphaWallet.Address {
        if input == Constants.nativeCryptoAddressInDatabase {
            //TODO extract a list of known/popular token contracts we use in the app? Would that be too much dependency?
            return AlphaWallet.Address(string: "0xdAC17F958D2ee523a2206206994597C13D831ec7")!
        } else {
            return Constants.nativeCryptoAddressInDatabase
        }
    }
}

private struct OneInchAssetsRequest: URLRequestConvertible {
    func asURLRequest() throws -> URLRequest {
        guard var components = URLComponents(url: Constants.OneInch.exchangeUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
        components.path = "/v3.0/1/tokens"
        let url = try components.asURL()
        return try URLRequest(url: url, method: .get)
    }
}
