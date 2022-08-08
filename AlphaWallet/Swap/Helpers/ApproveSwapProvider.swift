//
//  ApproveSwapProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2022.
//

import Foundation
import PromiseKit
import BigInt
import Result

protocol ApproveSwapProviderDelegate: class {
    func promptToSwap(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt, in provider: ApproveSwapProvider)
    func promptForErc20Approval(token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt, in provider: ApproveSwapProvider) -> Promise<EthereumTransaction.Id>
    func changeState(in approveSwapProvider: ApproveSwapProvider, state: ApproveSwapState)
    func didFailure(in approveSwapProvider: ApproveSwapProvider, error: Error)
}

enum ApproveSwapState {
    case pending
    case checkingForEnoughAllowance
    case waitTillApproveCompleted
    case waitingForUsersAllowanceApprove
    case waitingForUsersSwapApprove
}

final class ApproveSwapProvider {
    private let configurator: SwapOptionsConfigurator
    private let analytics: AnalyticsLogger
    weak var delegate: ApproveSwapProviderDelegate?

    init(configurator: SwapOptionsConfigurator, analytics: AnalyticsLogger) {
        self.configurator = configurator
        self.analytics = analytics
    }

    func approveSwap(value: (swapQuote: SwapQuote, tokens: FromAndToTokens), fromAmount: BigUInt) {
        delegate?.changeState(in: self, state: .checkingForEnoughAllowance)

        Erc20.hasEnoughAllowance(server: configurator.server, tokenAddress: value.tokens.from.address, owner: configurator.session.account.address, spender: value.swapQuote.estimate.spender, amount: fromAmount)
            .map { (value.swapQuote, $0.hasEnough, $0.shortOf) }
        .then { swapQuote, isApproved, shortOf -> Promise<SwapQuote> in
            if isApproved {
                return Promise.value(swapQuote)
            } else {
                self.delegate?.changeState(in: self, state: .waitingForUsersAllowanceApprove)
                return self.promptApproval(unsignedSwapTransaction: swapQuote.unsignedSwapTransaction, token: value.tokens.from.address, server: self.configurator.server, owner: self.configurator.session.account.address, spender: swapQuote.estimate.spender, amount: shortOf).map { isApproved in
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
            strongSelf.delegate?.promptToSwap(unsignedTransaction: swapQuote.unsignedSwapTransaction, fromToken: value.tokens.from, fromAmount: fromAmount, toToken: value.tokens.to, toAmount: swapQuote.estimate.toAmount, in: strongSelf)
        }.catch { error in
            infoLog("[Swap] Error while swapping. Error: \(error)")
            if let error = error as? SwapError {
                switch error {
                case .userCancelledApproval, .approveTransactionNotCompleted, .unableToBuildSwapUnsignedTransactionFromSwapProvider, .tokenOrSwapQuoteNotFound:
                    break
                case .unknownError:
                    self.delegate?.didFailure(in: self, error: error)
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

        return firstly {
            delegate.promptForErc20Approval(token: token, server: server, owner: owner, spender: spender, amount: amount, in: self)
        }.then { transactionId -> Promise<Bool> in
            self.delegate?.changeState(in: self, state: .waitTillApproveCompleted)
            return firstly {
                EthereumTransaction.waitTillCompleted(transactionId: transactionId, server: server, analytics: self.analytics)
            }.map {
                return true
            }.recover { error -> Promise<Bool> in
                if error is EthereumTransaction.NotCompletedYet {
                    throw SwapError.approveTransactionNotCompleted
                } else if let error = error as? SwapError {
                    switch error {
                    case .userCancelledApproval:
                        return .value(false)
                    case .unableToBuildSwapUnsignedTransactionFromSwapProvider, .approveTransactionNotCompleted, .unknownError, .tokenOrSwapQuoteNotFound:
                        throw error
                    }
                }
                //Exists to make compiler happy
                return .value(false)
            }
        }
    }
}
