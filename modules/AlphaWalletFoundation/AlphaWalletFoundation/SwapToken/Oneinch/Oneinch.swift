//
//  OneinchHolder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation
import Combine
import AlphaWalletCore

public class Oneinch: SupportedTokenActionsProvider, SwapTokenViaUrlProvider {
    private (set) public var assets: Loadable<[AlphaWallet.Address: Oneinch.Asset], Error> = .loading
    private let queue = DispatchQueue(label: "org.alphawallet.swift.Oneinch")
    private var cancelable = Set<AnyCancellable>()
    private var objectWillChangeSubject = PassthroughSubject<Void, Never>()
    private var supportedServers: [RPCServer] {
        return [.main, .binance_smart_chain, .polygon, .optimistic, .arbitrum]
    }
    private static let baseURL = "https://1inch.exchange/#"
    private static let referralSlug = "/r/0x98f21584006c79871F176F8D474958a69e04595B"
    //NOTE: for Oneinch exchange service we need to use two addresses, by default it uses Uptrennd token
    private var predefinedAssets: [Oneinch.Asset] {
        [.init(symbol: "ETH", name: "ETH", address: Constants.nativeCryptoAddressInDatabase, decimal: RPCServer.main.decimals)]
    }
    private let networking: OneinchNetworking
    private let reachability: ReachabilityManagerProtocol
    private let retryBehavior: RetryBehavior<RunLoop>
    public static let defaultRetryBehavior: RetryBehavior<RunLoop> = .randomDelayed(retries: 3, delayBeforeRetry: 5, delayUpperRangeValueFrom0To: 15)

    public var objectWillChange: AnyPublisher<Void, Never> {
        objectWillChangeSubject
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    public let action: String
    public let analyticsNavigation: Analytics.Navigation = .onOneinch
    public let analyticsName: String = "Oneinch"

    public init(action: String,
                networking: OneinchNetworking,
                reachability: ReachabilityManagerProtocol = ReachabilityManager(),
                retryBehavior: RetryBehavior<RunLoop> = Oneinch.defaultRetryBehavior) {

        self.action = action
        self.networking = networking
        self.reachability = reachability
        self.retryBehavior = retryBehavior
    }

    public func start() {
        reachability.networkBecomeReachablePublisher
            .receive(on: queue)
            .setFailureType(to: PromiseError.self)
            .flatMapLatest { [networking, retryBehavior] _ -> AnyPublisher<[Asset], PromiseError> in
                networking.retrieveAssets()
                    .retry(retryBehavior, scheduler: RunLoop.main)
                    .eraseToAnyPublisher()
            }.receive(on: queue)
            .sink { [objectWillChangeSubject] result in
                objectWillChangeSubject.send(())

                guard case .failure(let error) = result else { return }
                let request = BaseOneinchNetworking.OneInchAssetsRequest()
                RemoteLogger.instance.logRpcOrOtherWebError("Oneinch error | \(error)", url: request.urlRequest?.url?.absoluteString ?? "")
            } receiveValue: { assets in
                var newAssets: [AlphaWallet.Address: Oneinch.Asset] = [:]
                for asset in self.predefinedAssets + assets {
                    newAssets[asset.address] = asset
                }
                self.assets = .done(newAssets)
            }.store(in: &cancelable)
    }

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
        switch token.server.serverWithEnhancedSupport {
        case .main, .arbitrum:
            return asset(for: token.contractAddress) != nil
        case .main, .xDai, .polygon, .binance_smart_chain, .heco, .rinkeby, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return false
        }
    }

    private func asset(for address: AlphaWallet.Address) -> Oneinch.Asset? {
        guard let assets = assets.value else { return nil }
        return assets[address]
    }

    private func subpath(inputAddress: AlphaWallet.Address) -> String {
        return [asset(for: inputAddress), asset(for: defaultOutputAddress(forInput: inputAddress))].compactMap {
            $0?.symbol
        }.joined(separator: "/")
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
