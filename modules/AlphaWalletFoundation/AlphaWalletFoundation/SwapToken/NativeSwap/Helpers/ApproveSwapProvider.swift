//
//  ApproveSwapProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2022.
//

import Foundation
import PromiseKit
import BigInt
import Combine
import AlphaWalletCore

public protocol ApproveSwapProviderDelegate: AnyObject {
    func promptToSwap(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt, in provider: ApproveSwapProvider)
    func promptForErc20Approval(token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt, in provider: ApproveSwapProvider) -> AnyPublisher<String, PromiseError>
    func changeState(in approveSwapProvider: ApproveSwapProvider, state: ApproveSwapState)
    func didFailure(in approveSwapProvider: ApproveSwapProvider, error: Error)
}

public enum ApproveSwapState {
    case pending
    case checkingForEnoughAllowance
    case waitTillApproveCompleted
    case waitingForUsersAllowanceApprove
    case waitingForUsersSwapApprove
}

public final class ApproveSwapProvider {
    private let configurator: SwapOptionsConfigurator
    private let analytics: AnalyticsLogger
    private lazy var getErc20Allowance = GetErc20Allowance(blockchainProvider: configurator.session.blockchainProvider)
    private var cancellable = Set<AnyCancellable>()

    public weak var delegate: ApproveSwapProviderDelegate?

    public init(configurator: SwapOptionsConfigurator, analytics: AnalyticsLogger) {
        self.configurator = configurator
        self.analytics = analytics
    }

    public func approveSwap(swapQuote: SwapQuote, fromAmount: BigUInt) {
        delegate?.changeState(in: self, state: .checkingForEnoughAllowance)

        getErc20Allowance.hasEnoughAllowance(
            tokenAddress: swapQuote.action.fromToken.address,
            owner: configurator.session.account.address,
            spender: swapQuote.estimate.spender,
            amount: fromAmount)
        .map { (swapQuote, $0.hasEnough, $0.shortOf) }
        .mapError { SwapError.inner($0) }
        .flatMap { [configurator] swapQuote, isApproved, shortOf -> AnyPublisher<SwapQuote, SwapError> in
            if isApproved {
                return .just(swapQuote)
            } else {
                self.delegate?.changeState(in: self, state: .waitingForUsersAllowanceApprove)
                return self.promptApproval(unsignedSwapTransaction: swapQuote.unsignedSwapTransaction, token: swapQuote.action.fromToken.address, server: configurator.server, owner: configurator.session.account.address, spender: swapQuote.estimate.spender, amount: shortOf)
                .flatMap { isApproved -> AnyPublisher<SwapQuote, SwapError> in
                    if isApproved {
                        return .just(swapQuote)
                    } else {
                        return .fail(SwapError.userCancelledApproval)
                    }
                }.eraseToAnyPublisher()
            }
        }.sink(receiveCompletion: { result in
            guard case .failure(let error) = result else { return }
            infoLog("[Swap] Error while swapping. Error: \(error)")
            self.delegate?.didFailure(in: self, error: error)
        }, receiveValue: { [weak self] swapQuote in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.changeState(in: strongSelf, state: .waitingForUsersSwapApprove)
            let fromToken = TokenToSwap(tokenFromQuate: swapQuote.action.fromToken)
            let toToken = TokenToSwap(tokenFromQuate: swapQuote.action.toToken)

            strongSelf.delegate?.promptToSwap(unsignedTransaction: swapQuote.unsignedSwapTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: swapQuote.estimate.toAmount, in: strongSelf)
        }).store(in: &cancellable)
    }

    private func promptApproval(unsignedSwapTransaction: UnsignedSwapTransaction, token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> AnyPublisher<Bool, SwapError> {
        guard let delegate = delegate else {
            return .fail(SwapError.unknownError)
        }

        let provider = WaitTillTransactionCompleted(blockchainProvider: configurator.session.blockchainProvider)

        return delegate
            .promptForErc20Approval(token: token, server: server, owner: owner, spender: spender, amount: amount, in: self)
            .mapError { SwapError.inner($0) }
            .flatMap { [provider] transactionId -> AnyPublisher<Bool, SwapError> in
                self.delegate?.changeState(in: self, state: .waitTillApproveCompleted)

                return provider.waitTillCompleted(hash: transactionId)
                    .map { _ in return true }
                    .catch { error -> AnyPublisher<Bool, SwapError> in
                        if error.embedded is WaitTillTransactionCompleted.NotCompletedYetError {
                            return .fail(SwapError.approveTransactionNotCompleted)
                        } else if let error = error.embedded as? SwapError {
                            switch error {
                            case .userCancelledApproval:
                                return .just(false)
                            case .unableToBuildSwapUnsignedTransactionFromSwapProvider, .invalidJson, .unableToBuildSwapUnsignedTransaction, .approveTransactionNotCompleted, .unknownError, .tokenOrSwapQuoteNotFound, .inner:
                                return .fail(error)
                            }
                        }
                        //Exists to make compiler happy
                        return .just(false)
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }
}
