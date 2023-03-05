//
//  DappRequesterDelegate.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.02.2023.
//

import Foundation
import AlphaWalletCore
import AlphaWalletFoundation
import Combine

protocol DappRequesterDelegate: AnyObject, RequestSignMessageDelegate {

    func requestGetTransactionCount(session: WalletSession,
                                    source: Analytics.SignMessageRequestSource) -> AnyPublisher<Data, PromiseError>

    func requestEthCall(from: AlphaWallet.Address?,
                        to: AlphaWallet.Address?,
                        value: String?,
                        data: String,
                        source: Analytics.SignMessageRequestSource,
                        session: WalletSession) -> AnyPublisher<String, PromiseError>

    func requestSendTransaction(session: WalletSession,
                                source: Analytics.TransactionConfirmationSource,
                                requester: RequesterViewModel?,
                                transaction: UnconfirmedTransaction,
                                configuration: TransactionType.Configuration) -> AnyPublisher<SentTransaction, PromiseError>

    func requestSendRawTransaction(session: WalletSession,
                                   source: Analytics.TransactionConfirmationSource,
                                   requester: DappRequesterViewModel?,
                                   transaction: String) -> AnyPublisher<String, PromiseError>

    func requestSignTransaction(session: WalletSession,
                                source: Analytics.TransactionConfirmationSource,
                                requester: RequesterViewModel?,
                                transaction: UnconfirmedTransaction,
                                configuration: TransactionType.Configuration) -> AnyPublisher<Data, PromiseError>

    func requestAddCustomChain(server: RPCServer,
                               customChain: WalletAddEthereumChainObject) -> AnyPublisher<SwitchCustomChainOperation, PromiseError>

    func requestSwitchChain(server: RPCServer,
                            currentUrl: URL?,
                            targetChain: WalletSwitchEthereumChainObject) -> AnyPublisher<SwitchExistingChainOperation, PromiseError>
}
