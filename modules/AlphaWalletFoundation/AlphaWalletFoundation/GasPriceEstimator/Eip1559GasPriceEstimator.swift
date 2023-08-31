//
//  Eip1559GasPriceEstimator.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 13.04.2023.
//

import Foundation
import BigInt
import Combine
import AlphaWalletCore
import AlphaWalletLogger

public final class Eip1559GasPriceEstimator: NSObject, GasPriceEstimator {
    private let server: RPCServer
    private let initialOracleResult: Eip1559FeeOracleResult
    private let subject: CurrentValueSubject<EstimatedValue<Eip1559FeeOracleResult>, Never>
    private let estimatesSubject: CurrentValueSubject<Eip1559FeeEstimates, Never>
    private let initialMaxFeePerGas: BigUInt?
    private let initialMaxPriorityFeePerGas: BigUInt?
    private var cancellable = Set<AnyCancellable>()
    private lazy var scheduler = Scheduler(provider: estimatesProvider, refreshAggressively: true)
    private let estimatesProvider: Eip1559GasPriceEstimatorProvider

    public private(set) var selectedGasSpeed: GasSpeed = .standard

    public var gasPrice: FillableValue<GasPrice> {
        return validate(oracleResult: subject.value.value).mapValue {
            GasPrice.eip1559(
                maxFeePerGas: $0.maxFeePerGas,
                maxPriorityFeePerGas: $0.maxPriorityFeePerGas)
        }
    }

    public var estimatesPublisher: AnyPublisher<GasEstimates, Never> {
        estimatesSubject.map { $0 as GasEstimates }.eraseToAnyPublisher()
    }

    public var gasPricePublisher: AnyPublisher<FillableValue<GasPrice>, Never> {
        return subject.map {
            return self.validate(oracleResult: $0.value).mapValue {
                GasPrice.eip1559(
                    maxFeePerGas: $0.maxFeePerGas,
                    maxPriorityFeePerGas: $0.maxPriorityFeePerGas)
            }
        }.eraseToAnyPublisher()
    }

    public var oraclePublisher: AnyPublisher<FillableValue<Eip1559FeeOracleResult>, Never> {
        return subject
            .map { self.validate(oracleResult: $0.value) }
            .eraseToAnyPublisher()
    }

    public var availableMaxFeeRange: ClosedRange<Double> {
        let estimates = estimatesSubject.value
        let upper = estimates.fastest.flatMap { Decimal(bigUInt: $0.maxFeePerGas, units: .gwei) }.flatMap { $0.doubleValue } ?? 10

        return ClosedRange<Double>(uncheckedBounds: (lower: .zero, upper: upper * 2))
    }

    public var state: AnyPublisher<GasPriceEstimatorState, Never> {
        scheduler.$state
            .receive(on: RunLoop.main)
            .map { GasPriceEstimatorState(state: $0) }
            .eraseToAnyPublisher()
    }

    public init(blockchainProvider: BlockchainProvider,
                initialMaxFeePerGas: BigUInt?,
                initialMaxPriorityFeePerGas: BigUInt?) {

        self.server = blockchainProvider.server
        self.initialMaxFeePerGas = initialMaxFeePerGas
        self.initialMaxPriorityFeePerGas = initialMaxPriorityFeePerGas

        self.estimatesProvider = Eip1559GasPriceEstimatorProvider(
            interval: 15,
            blockchainProvider: blockchainProvider)

        let oracleResult: Eip1559FeeOracleResult
        if let maxFeePerGas = initialMaxFeePerGas, let maxPriorityFeePerGas = initialMaxPriorityFeePerGas {
            oracleResult = Eip1559FeeOracleResult(maxFeePerGas: maxFeePerGas, maxPriorityFeePerGas: maxPriorityFeePerGas)

            let estimates = Eip1559FeeEstimates(estimates: [
                .standard: oracleResult
            ])

            estimatesSubject = .init(estimates)
            selectedGasSpeed = .standard
        } else {
            oracleResult = Eip1559FeeOracleResult(
                maxFeePerGas: Decimal(1).toBigUInt(units: .gwei) ?? BigUInt(),
                maxPriorityFeePerGas: Decimal(1).toBigUInt(units: .gwei) ?? BigUInt())

            estimatesSubject = .init(.init(estimates: [:]))
            selectedGasSpeed = .custom
        }

        self.initialOracleResult = oracleResult
        self.subject = .init(.estimated(oracleResult))
        super.init()

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
                    infoLog("[Eip1559GasPriceEstimator] received estimates: \(estimates)")

                    let estimates = strongSelf.handle(estimates: estimates)
                    estimatesSubject.value = estimates

                    switch strongSelf.selectedGasSpeed {
                    case .custom:
                        guard case .estimated = subject.value else {
                            //NOTE: rebuild with selected value to make sure warnings and errors have updated, if there any
                            strongSelf.handle(oracleResult: subject.value)
                            return
                        }

                        guard let estimate = estimates.estimates[.standard] else { return }
                        //NOTE: switch to standard if initial value hasn't changed
                        strongSelf.selectedGasSpeed = .standard
                        strongSelf.handle(oracleResult: .estimated(estimate))
                    case .standard, .slow, .rapid, .fast:
                        guard let estimate = estimates.estimates[strongSelf.selectedGasSpeed] else { return }
                        strongSelf.handle(oracleResult: .estimated(estimate))
                    }
                case .failure(let error):
                    infoLog("[Eip1559GasPriceEstimator] failed to receive estimates: \(error)")
                    logError(error, rpcServer: server)
                }
            }.store(in: &cancellable)
    }

    private func handle(estimates: Eip1559FeeEstimates) -> Eip1559FeeEstimates {
        var estimates = estimates
        let standard = estimates.estimates[.standard]

        if shouldUseEstimatedGasPrice(standard) {
            //no-op
        } else if let standard = estimatesSubject.value.estimates[.standard] {
            estimates.estimates[.standard] = standard
        }

        return estimates
    }

    public func validate(maxFeePerGas: BigUInt) -> FillableValue<BigUInt> {
        guard let value = Decimal(bigUInt: maxFeePerGas, units: .gwei) else {
            return .init(value: maxFeePerGas, warnings: [], errors: [MaxGasFeeError.invalid])
        }

        let estimates = estimatesSubject.value

        var errors: [Error] = []
        var warnings: [Warning] = []

        if value <= 0 {
            errors += [MaxGasFeeError.zeroMaxFee]
        }

        if let fastest = estimates.fastest, let fastest = Decimal(bigUInt: fastest.maxFeePerGas, units: .gwei), value > fastest {
            warnings += [MaxGasFeeWarning.tooHigh]
        }

        if let slowest = estimates.slowest, let slowest = Decimal(bigUInt: slowest.maxFeePerGas, units: .gwei), value < slowest {
            warnings += [MaxGasFeeWarning.tooLow]
        }

        return .init(value: maxFeePerGas, warnings: warnings, errors: errors)
    }

    public func validate(maxPriorityFee: BigUInt) -> FillableValue<BigUInt> {
        guard let value = Decimal(bigUInt: maxPriorityFee, units: .gwei) else {
            return .init(value: maxPriorityFee, warnings: [], errors: [PriorityFeeError.invalid])
        }

        let estimates = estimatesSubject.value

        var errors: [Error] = []
        var warnings: [Warning] = []

        if value <= 0 {
            errors += [PriorityFeeError.zeroPriorityFee]
        }

        if value > 4 {
            warnings += [PriorityFeeWarning.tooHigh]
        }

        return .init(value: maxPriorityFee, warnings: warnings, errors: errors)
    }

    public func validate(oracleResult: Eip1559FeeOracleResult) -> FillableValue<Eip1559FeeOracleResult> {
        let maxFeePerGas = validate(maxFeePerGas: oracleResult.maxFeePerGas)
        let maxPriorityFeePerGas = validate(maxFeePerGas: oracleResult.maxPriorityFeePerGas)

        return FillableValue<Eip1559FeeOracleResult>(
            value: oracleResult,
            warnings: maxFeePerGas.warnings + maxPriorityFeePerGas.warnings,
            errors: maxFeePerGas.errors + maxPriorityFeePerGas.errors)
    }

    private func handle(oracleResult: EstimatedValue<Eip1559FeeOracleResult>) {
        subject.send(oracleResult)
    }

    public func shouldUseEstimatedGasPrice(_ oracleResult: Eip1559FeeOracleResult?) -> Bool {
        guard let oracleResult = oracleResult, let specifiedMaxFee = initialMaxFeePerGas, let specifiedPriorityFee = initialMaxPriorityFeePerGas else { return true }
        //Gas price may be specified in the transaction object, and it will be if we are trying to speedup or cancel a transaction. The replacement transaction will be automatically assigned a slightly higher gas price. We don't want to override that with what we fetch back from gas price estimate if the estimate is lower
        if specifiedMaxFee > oracleResult.maxFeePerGas && specifiedPriorityFee > oracleResult.maxPriorityFeePerGas {
            return false
        } else {
            return true
        }
    }

    public func set(gasSpeed: GasSpeed) {
        let estimates = estimatesSubject.value.estimates
        guard let oracleResult = estimates[gasSpeed] else {
            return //what should be here?
        }

        selectedGasSpeed = gasSpeed
        handle(oracleResult: .defined(oracleResult))// or estimated, called when user manually changes
    }

    public func set(maxFeePerGas: BigUInt, maxPriorityFeePerGas: BigUInt) {
        let oracle = Eip1559FeeOracleResult(
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas)

        selectedGasSpeed = .custom
        handle(oracleResult: .defined(oracle))
    }
}

extension Eip1559GasPriceEstimator {

    private class Eip1559GasPriceEstimatorProvider: SchedulerProvider {
        private let blockchainProvider: BlockchainProvider
        private let oracleProvider: Eip1559FeeOracle

        var name: String { "Eip1559GasPriceEstimatorProvider.\(blockchainProvider.server)" }
        let interval: TimeInterval
        var operation: AnyPublisher<Void, PromiseError> {
            estimateGasPrice()
                .handleEvents(receiveOutput: { [publisher] in
                    publisher.send(.success($0))
                }, receiveCompletion: { [publisher] result in
                    guard case .failure(let e) = result else { return }
                    publisher.send(.failure(e))
                }).mapToVoid()
                .eraseToAnyPublisher()
        }

        let publisher = PassthroughSubject<Result<Eip1559FeeEstimates, PromiseError>, Never>()

        init(interval: TimeInterval,
             blockchainProvider: BlockchainProvider) {

            self.oracleProvider = Eip1559FeeOracle(blockchainProvider: blockchainProvider)
            self.interval = interval
            self.blockchainProvider = blockchainProvider
        }

        public func estimateGasPrice() -> AnyPublisher<Eip1559FeeEstimates, PromiseError> {
            return AnyPublisher<Eip1559FeeEstimates, PromiseError>.create { [oracleProvider] seal in
                return Task { @MainActor in
                    do {
                        let estimates = try await oracleProvider.eip1559FeeEstimates()
                        seal.send(estimates)
                        seal.send(completion: .finished)
                    } catch {
                        seal.send(completion: .failure(PromiseError(error: error)))
                    }
                }.asCancellable()
            }
        }
    }
}

extension Eip1559GasPriceEstimator {

    public enum MaxGasFeeError: Error {
        case zeroMaxFee
        case invalid
    }

    public enum MaxGasFeeWarning: Warning {
        case tooHigh
        case tooLow
    }

    public enum PriorityFeeError: Error {
        case zeroPriorityFee
        case invalid
    }

    public enum PriorityFeeWarning: Warning {
        case tooHigh
        case tooLow
    }
}
