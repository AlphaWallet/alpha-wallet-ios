//
//  Ramp.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import Foundation
import Combine
import AlphaWalletCore

public final class Ramp: SupportedTokenActionsProvider, BuyTokenURLProviderType {
    private var objectWillChangeSubject = PassthroughSubject<Void, Never>()
    private (set) public var assets: Swift.Result<[Asset], Error> = .failure(RampError())
    private let queue: DispatchQueue = .init(label: "org.alphawallet.swift.Ramp")
    private var cancelable = Set<AnyCancellable>()
    private let reachability: ReachabilityManagerProtocol
    private let networkProvider: RampNetworkProviderType
    private let retryBehavior: RetryBehavior<RunLoop>

    public var objectWillChange: AnyPublisher<Void, Never> {
        objectWillChangeSubject
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    public let analyticsNavigation: Analytics.Navigation = .onRamp
    public let analyticsName: String = "Ramp"
    public let action: String

    public init(action: String, networkProvider: RampNetworkProviderType, reachability: ReachabilityManagerProtocol = ReachabilityManager(), retryBehavior: RetryBehavior<RunLoop> = Oneinch.defaultRetryBehavior) {
        self.action = action
        self.reachability = reachability
        self.networkProvider = networkProvider
        self.retryBehavior = retryBehavior
    }

    deinit {
        infoLog("\(self).deinit")
    }

    public func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        let symbol = asset(for: token)?.symbol
        return symbol
            .flatMap { Constants.buyWithRampUrl(asset: $0, wallet: wallet) }
            .flatMap { URL(string: $0) }
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .buy(service: self))]
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return asset(for: token) != nil
    }

    private func asset(for token: TokenActionsIdentifiable) -> Asset? {
        //We only operate for mainnets. This is because we store native cryptos for Ethereum testnets like `.goerli` with symbol "ETH" which would match Ramp's Ethereum token
        func isAssetMatchesForToken(token: TokenActionsIdentifiable, asset: Asset) -> Bool {
            return asset.symbol.lowercased() == token.symbol.trimmingCharacters(in: .controlCharacters).lowercased()
                    && asset.decimals == token.decimals
                    && (asset.address == nil ? token.contractAddress == Constants.nativeCryptoAddressInDatabase : asset.address! == token.contractAddress)
        }

        guard !token.server.isTestnet else { return nil }
        switch assets {
        case .success(let assets):
            return assets.first(where: { isAssetMatchesForToken(token: token, asset: $0) })
        case .failure:
            return nil
        }
    }

    public func start() {
        reachability.networkBecomeReachablePublisher
            .receive(on: queue)
            .setFailureType(to: PromiseError.self)
            .flatMapLatest { [networkProvider, retryBehavior] _ -> AnyPublisher<[Asset], PromiseError> in
                networkProvider.retrieveAssets()
                    .retry(retryBehavior, scheduler: RunLoop.main)
                    .eraseToAnyPublisher()
            }.receive(on: queue)
            .sink { [objectWillChangeSubject] result in
                objectWillChangeSubject.send(())

                guard case .failure(let error) = result else { return }
                let request = RampNetworkProvider.RampRequest()
                RemoteLogger.instance.logRpcOrOtherWebError("Ramp error | \(error)", url: request.urlRequest?.url?.absoluteString ?? "")
            } receiveValue: {
                self.assets = .success($0)
            }.store(in: &cancelable)
    }
}
