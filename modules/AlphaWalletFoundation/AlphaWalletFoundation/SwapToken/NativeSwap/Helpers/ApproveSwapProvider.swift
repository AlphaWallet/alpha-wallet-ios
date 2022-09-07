//
//  ApproveSwapProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2022.
//

import Foundation
import PromiseKit
import BigInt 

public protocol ApproveSwapProviderDelegate: class {
    func promptToSwap(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt, in provider: ApproveSwapProvider)
    func promptForErc20Approval(token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt, in provider: ApproveSwapProvider) -> Promise<EthereumTransaction.Hash>
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
    public weak var delegate: ApproveSwapProviderDelegate?

    public init(configurator: SwapOptionsConfigurator, analytics: AnalyticsLogger) {
        self.configurator = configurator
        self.analytics = analytics
    }

    public func approveSwap(swapQuote: SwapQuote, fromAmount: BigUInt) {
        delegate?.changeState(in: self, state: .checkingForEnoughAllowance)

        Erc20.hasEnoughAllowance(server: configurator.server, tokenAddress: swapQuote.action.fromToken.address, owner: configurator.session.account.address, spender: swapQuote.estimate.spender, amount: fromAmount)
            .map { (swapQuote, $0.hasEnough, $0.shortOf) }
        .then { swapQuote, isApproved, shortOf -> Promise<SwapQuote> in
            if isApproved {
                return Promise.value(swapQuote)
            } else {
                self.delegate?.changeState(in: self, state: .waitingForUsersAllowanceApprove)
                return self.promptApproval(unsignedSwapTransaction: swapQuote.unsignedSwapTransaction, token: swapQuote.action.fromToken.address, server: self.configurator.server, owner: self.configurator.session.account.address, spender: swapQuote.estimate.spender, amount: shortOf).map { isApproved in
                    if isApproved {
                        return swapQuote
                    } else {
                        throw SwapError.userCancelledApproval
                    }
                }
            }
        }.done { [weak self] swapQuote in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.changeState(in: strongSelf, state: .waitingForUsersSwapApprove)
            let fromToken = TokenToSwap(tokenFromQuate: swapQuote.action.fromToken)
            let toToken = TokenToSwap(tokenFromQuate: swapQuote.action.toToken)
            strongSelf.delegate?.promptToSwap(unsignedTransaction: swapQuote.unsignedSwapTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: swapQuote.estimate.toAmount, in: strongSelf)
        }.catch { error in
            infoLog("[Swap] Error while swapping. Error: \(error)")
            if let _error = error as? SwapError {
                switch _error {
                case .unableToBuildSwapUnsignedTransaction, .unableToBuildSwapUnsignedTransactionFromSwapProvider, .userCancelledApproval, .approveTransactionNotCompleted, .tokenOrSwapQuoteNotFound:
                    break
                case .unknownError, .invalidJson:
                    self.delegate?.didFailure(in: self, error: _error)
                }
            } else {
                self.delegate?.didFailure(in: self, error: error)
            }
        }
    }

    private func promptApproval(unsignedSwapTransaction: UnsignedSwapTransaction, token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> Promise<Bool> {
        guard let delegate = delegate else {
            return Promise(error: SwapError.unknownError)
        }

        let provider = WaitTillTransactionCompleted(server: server, analytics: analytics)

        return firstly {
            delegate.promptForErc20Approval(token: token, server: server, owner: owner, spender: spender, amount: amount, in: self)
        }.then { [provider] transactionId -> Promise<Bool> in
            self.delegate?.changeState(in: self, state: .waitTillApproveCompleted)
            return firstly {
                provider.waitTillCompleted(hash: transactionId)
            }.map {
                return true
            }.recover { error -> Promise<Bool> in
                if error is EthereumTransaction.NotCompletedYet {
                    throw SwapError.approveTransactionNotCompleted
                } else if let error = error as? SwapError {
                    switch error {
                    case .userCancelledApproval:
                        return .value(false)
                    case .unableToBuildSwapUnsignedTransactionFromSwapProvider, .invalidJson, .unableToBuildSwapUnsignedTransaction, .approveTransactionNotCompleted, .unknownError, .tokenOrSwapQuoteNotFound:
                        throw error
                    }
                }
                //Exists to make compiler happy
                return .value(false)
            }
        }
    }
}
