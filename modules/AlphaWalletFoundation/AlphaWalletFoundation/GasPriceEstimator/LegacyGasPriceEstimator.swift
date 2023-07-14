//
//  LegacyGasPriceEstimator.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 11.04.2023.
//

import Foundation
import BigInt
import Combine
import AlphaWalletCore
import AlphaWalletLogger

public final class LegacyGasPriceEstimator: NSObject, GasPriceEstimator {
    private let server: RPCServer
    private lazy var subject: CurrentValueSubject<FillableValue<EstimatedValue<BigUInt>>, Never> = {
        let gasPrice = server.defaultLegacyGasPrice(usingGasPrice: initialGasPrice)
        let value = validate(gasPrice: gasPrice).mapValue { EstimatedValue<BigUInt>.estimated($0) }

        return .init(value)
    }()
    private let estimatesSubject: CurrentValueSubject<LegacyGasEstimates, Never>
    private let initialGasPrice: BigUInt?
    private var cancellable = Set<AnyCancellable>()
    private lazy var scheduler = Scheduler(provider: estimatesProvider, useCountdownTimer: true)
    private let estimatesProvider: LegacyEstimatesSchedulerProvider

    public private(set) var selectedGasSpeed: GasSpeed = .standard

    public var gasPrice: FillableValue<GasPrice> {
        return subject.value.mapValue { GasPrice.legacy(gasPrice: $0.value) }
    }

    public var estimatesPublisher: AnyPublisher<GasEstimates, Never> {
        estimatesSubject.map { $0 as GasEstimates }.eraseToAnyPublisher()
    }

    public var gasPricePublisher: AnyPublisher<FillableValue<GasPrice>, Never> {
        return subject.map { $0.mapValue { GasPrice.legacy(gasPrice: $0.value) } }
            .eraseToAnyPublisher()
    }

    public var state: AnyPublisher<GasPriceEstimatorState, Never> {
        scheduler.$state
            .receive(on: RunLoop.main)
            .map { GasPriceEstimatorState(state: $0) }
            .eraseToAnyPublisher()
    }

    public init(blockchainProvider: BlockchainProvider,
                networking: BlockchainExplorer,
                initialGasPrice: BigUInt?) {

        self.server = blockchainProvider.server
        self.initialGasPrice = initialGasPrice

        self.estimatesProvider = LegacyEstimatesSchedulerProvider(
            interval: 15,
            blockchainProvider: blockchainProvider,
            networking: networking)

        let gasPrice = server.defaultLegacyGasPrice(usingGasPrice: initialGasPrice)
        let estimates = LegacyGasEstimates(standard: gasPrice)

        estimatesSubject = .init(estimates)

        super.init()
        selectedGasSpeed = .standard
        handle(gasPrice: .estimated(gasPrice))

        start()
    }

    deinit {
        scheduler.cancel()
    }

    func start() {
        scheduler.start()

        estimatesProvider.publisher
            .sink { [weak self, estimatesSubject, server, subject] result in
                guard let strongSelf = self else { return }

                switch result {
                case .success(let estimates):
                    infoLog("[LegacyEstimator] received estimates: \(estimates)")

                    let estimates = strongSelf.handle(estimates: estimates)
                    estimatesSubject.value = estimates

                    switch strongSelf.selectedGasSpeed {
                    case .custom:
                        guard case .estimated = subject.value.value, let estimate = estimates[.custom] else {
                            //NOTE: rebuild with selected value to make sure warnings and erros have updated, if there any
                            strongSelf.handle(gasPrice: subject.value.value.mapValue { $0 })
                            return
                        }

                        strongSelf.handle(gasPrice: .estimated(estimate.max))
                    case .standard, .slow, .rapid, .fast:
                        guard let estimate = estimates[strongSelf.selectedGasSpeed] else { return }
                        strongSelf.handle(gasPrice: .estimated(estimate.max))
                    }
                case .failure(let error):
                    infoLog("[LegacyEstimator] failed to receive estimates: \(error)")
                    logError(error, rpcServer: server)
                }
            }.store(in: &cancellable)
    }

    private func handle(estimates: LegacyGasEstimates) -> LegacyGasEstimates {
        var estimates = estimates

        if shouldUseEstimatedGasPrice(estimates.standard) {
            //no-op
        } else {
            estimates.standard = estimatesSubject.value.standard
        }
        return estimates
    }

    public func validate(gasPrice: BigUInt) -> FillableValue<BigUInt> {
        let estimates = estimatesSubject.value

        var errors: [Error] = []
        var warnings: [Warning] = []

        if gasPrice <= 0 {
            errors += [ConfigureTransactionError.gasPriceTooLow]
        }

        if let fastestGasPrice = estimates.fastest, gasPrice > fastestGasPrice {
            warnings += [TransactionConfigurator.GasPriceWarning(server: server, warning: .tooHighCustomGasPrice)]
        }

        //Conversion to gwei is needed so we that 17 (entered) is equal to 17.1 (fetched). Because 17.1 is displayed as "17" in the UI and might confuse the user if it's not treated as equal
        if let slowestGasPrice = estimates.slowest, (gasPrice / BigUInt(EthereumUnit.gwei.rawValue)) < (slowestGasPrice / BigUInt(EthereumUnit.gwei.rawValue)) {
            warnings += [TransactionConfigurator.GasPriceWarning(server: server, warning: .tooLowCustomGasPrice)]
        }

        switch server.serverWithEnhancedSupport {
        case .main:
            if (estimates.standard / BigUInt(EthereumUnit.gwei.rawValue)) > Constants.highStandardEthereumMainnetGasThresholdGwei {
                warnings += [TransactionConfigurator.GasPriceWarning(server: server, warning: .networkCongested)]
            }
        case .xDai, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            break
        }

        return .init(value: gasPrice, warnings: warnings, errors: errors)
    }

    private func handle(gasPrice: EstimatedValue<BigUInt>) {
        let value = validate(gasPrice: gasPrice.value)
        let gasPrice = value.mapValue { EstimatedValue<BigUInt>(value: $0, mapping: gasPrice) }
        subject.send(gasPrice)
    }

    public func shouldUseEstimatedGasPrice(_ estimatedGasPrice: BigUInt) -> Bool {
        //Gas price may be specified in the transaction object, and it will be if we are trying to speedup or cancel a transaction. The replacement transaction will be automatically assigned a slightly higher gas price. We don't want to override that with what we fetch back from gas price estimate if the estimate is lower
        if let specifiedGasPrice = initialGasPrice, specifiedGasPrice > estimatedGasPrice {
            return false
        } else {
            return true
        }
    }

    public func set(gasSpeed: GasSpeed) {
        let estimates = estimatesSubject.value
        guard let gasPrice = estimates[gasSpeed] else {
            return //what should be here?
        }

        selectedGasSpeed = gasSpeed
        handle(gasPrice: .defined(gasPrice.max))// or estimated, called when user manually changes
    }

    public func set(gasCustomPrice: BigUInt) {
        selectedGasSpeed = .custom
        handle(gasPrice: .defined(gasCustomPrice))
    }
}

extension LegacyGasPriceEstimator {

    private class LegacyEstimatesSchedulerProvider: SchedulerProvider {
        private let blockchainProvider: BlockchainProvider
        private let networking: BlockchainExplorer

        let name: String = ""
        let interval: TimeInterval
        var operation: AnyPublisher<Void, PromiseError> {
            estimateGasPrice()
                .handleEvents(receiveOutput: { [publisher] in
                    publisher.send(.success($0))
                }, receiveCompletion: { [publisher] result in
                    guard case .failure(let e) = result else { return }
                    publisher.send(.failure(e))
                })
                .mapToVoid()
                .eraseToAnyPublisher()
        }

        let publisher = PassthroughSubject<Result<LegacyGasEstimates, PromiseError>, Never>()

        init(interval: TimeInterval,
             blockchainProvider: BlockchainProvider,
             networking: BlockchainExplorer) {

            self.networking = networking
            self.interval = interval
            self.blockchainProvider = blockchainProvider
        }

        public func estimateGasPrice() -> AnyPublisher<LegacyGasEstimates, PromiseError> {
            return estimateGasPriceForUsingEtherscanApi(server: blockchainProvider.server)
                .catch { [blockchainProvider] _ in blockchainProvider.gasEstimates() }
                .eraseToAnyPublisher()
        }

        private func estimateGasPriceForUsingEtherscanApi(server: RPCServer) -> AnyPublisher<LegacyGasEstimates, PromiseError> {
            return networking.gasPriceEstimates()
                .handleEvents(receiveOutput: { estimates in
                    infoLog("[Gas] Estimated gas price with gas price estimator API server: \(server) estimate: \(estimates)")
                }).eraseToAnyPublisher()
        }
    }
}
