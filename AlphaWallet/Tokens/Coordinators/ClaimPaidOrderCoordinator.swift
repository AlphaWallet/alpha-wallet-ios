//
// Created by James Sangalli on 7/3/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import AlphaWalletFoundation

protocol ClaimOrderCoordinatorDelegate: CanOpenURL, BuyCryptoDelegate {
    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didFailTransaction error: Error)
    func didClose(in coordinator: ClaimPaidOrderCoordinator)
    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didCompleteTransaction result: ConfirmResult)
}

class ClaimPaidOrderCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let tokensService: TokenViewModelState
    private let keystore: Keystore
    private let session: WalletSession
    private let token: Token
    private let signedOrder: SignedOrder
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private let assetDefinitionStore: AssetDefinitionStore
    private var numberOfTokens: UInt {
        if let tokenIds = signedOrder.order.tokenIds, !tokenIds.isEmpty {
            return UInt(tokenIds.count)
        } else if signedOrder.order.nativeCurrencyDrop {
            return 1
        } else {
            return UInt(signedOrder.order.indices.count)
        }
    }

    var coordinators: [Coordinator] = []
    weak var delegate: ClaimOrderCoordinatorDelegate?

    init(navigationController: UINavigationController, keystore: Keystore, session: WalletSession, token: Token, signedOrder: SignedOrder, analytics: AnalyticsLogger, domainResolutionService: DomainResolutionServiceType, assetDefinitionStore: AssetDefinitionStore, tokensService: TokenViewModelState) {
        self.navigationController = navigationController
        self.tokensService = tokensService
        self.keystore = keystore
        self.session = session
        self.token = token
        self.signedOrder = signedOrder
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.assetDefinitionStore = assetDefinitionStore
    }

    func start() {
        let signature = signedOrder.signature.substring(from: 2)
        let v = UInt8(signature.substring(from: 128), radix: 16)!
        let r = "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64)))
        let s = "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))

        encodeOrder(
                signedOrder: signedOrder,
                expiry: signedOrder.order.expiry,
                v: v,
                r: r,
                s: s,
                contractAddress: signedOrder.order.contractAddress,
                recipient: session.account.address
        ) { result in
            let strongSelf = self
            switch result {
            case .success(let payload):
                do {
                    let transaction = UnconfirmedTransaction(
                            transactionType: .claimPaidErc875MagicLink(strongSelf.token),
                            value: BigInt(strongSelf.signedOrder.order.price),
                            recipient: nil,
                            contract: strongSelf.signedOrder.order.contractAddress,
                            data: payload,
                            gasLimit: nil,
                            gasPrice: nil,
                            nonce: nil
                    )

                    let coordinator = try TransactionConfirmationCoordinator(presentingViewController: strongSelf.navigationController, session: strongSelf.session, transaction: transaction, configuration: .claimPaidErc875MagicLink(confirmType: .signThenSend, price: strongSelf.signedOrder.order.price, numberOfTokens: strongSelf.numberOfTokens), analytics: strongSelf.analytics, domainResolutionService: strongSelf.domainResolutionService, keystore: strongSelf.keystore, assetDefinitionStore: strongSelf.assetDefinitionStore, tokensService: strongSelf.tokensService)
                    coordinator.delegate = self
                    strongSelf.addCoordinator(coordinator)
                    coordinator.start(fromSource: .claimPaidMagicLink)
                } catch {
                    UIApplication.shared
                        .presentedViewController(or: strongSelf.navigationController)
                        .displayError(message: error.prettyError)
                }
            case .failure:
                break
            }
        }
    }

    private func encodeOrder(signedOrder: SignedOrder,
                             expiry: BigUInt,
                             v: UInt8,
                             r: String,
                             s: String,
                             contractAddress: AlphaWallet.Address,
                             recipient: AlphaWallet.Address,
                             completion: @escaping (Result<Data, Error>) -> Void
        ) {
        if let tokenIds = signedOrder.order.tokenIds, !tokenIds.isEmpty {
            encodeSpawnableOrder(expiry: expiry, tokenIds: tokenIds, v: v, r: r, s: s, recipient: recipient) { result in
                completion(result)
            }
        } else if signedOrder.order.nativeCurrencyDrop {
            encodeNativeCurrencyOrder(signedOrder: signedOrder, v: v, r: r, s: s, recipient: recipient) { result in
                completion(result)
            }
        } else {
            encodeNormalOrder(expiry: expiry, indices: signedOrder.order.indices, v: v, r: r, s: s, contractAddress: contractAddress) { result in
                completion(result)
            }
        }
    }

    private func encodeNormalOrder(expiry: BigUInt,
                                   indices: [UInt16],
                                   v: UInt8,
                                   r: String,
                                   s: String,
                                   contractAddress: AlphaWallet.Address,
                                   completion: @escaping (Result<Data, Error>) -> Void) {
        do {
            let parameters: [Any] = [expiry, indices.map({ BigUInt($0) }), BigUInt(v), Data(_hex: r), Data(_hex: s)]
            let arrayType: ABIType
            if contractAddress.isLegacy875Contract {
                arrayType = ABIType.uint(bits: 16)
            } else {
                arrayType = ABIType.uint(bits: 256)
            }
            //trade(uint256,uint16[],uint8,bytes32,bytes32)
            let functionEncoder = Function(name: "trade", parameters: [
                .uint(bits: 256),
                .dynamicArray(arrayType),
                .uint(bits: 8),
                .bytes(32),
                .bytes(32)
            ])
            let encoder = ABIEncoder()
            try encoder.encode(function: functionEncoder, arguments: parameters)
            completion(.success(encoder.data))
        } catch {
            completion(.failure(Web3Error(description: "malformed transaction")))
        }
    }

    private func encodeSpawnableOrder(expiry: BigUInt,
                                      tokenIds: [BigUInt],
                                      v: UInt8,
                                      r: String,
                                      s: String,
                                      recipient: AlphaWallet.Address,
                                      completion: @escaping (Result<Data, Error>) -> Void) {

        do {
            let parameters: [Any] = [expiry, tokenIds, BigUInt(v), Data(_hex: r), Data(_hex: s), recipient]
            let functionEncoder = Function(name: "spawnPassTo", parameters: [
                .uint(bits: 256),
                .dynamicArray(.uint(bits: 256)),
                .uint(bits: 8),
                .bytes(32),
                .bytes(32),
                .address
            ])
            let encoder = ABIEncoder()
            try encoder.encode(function: functionEncoder, arguments: parameters)
            completion(.success(encoder.data))
        } catch {
            completion(.failure(Web3Error(description: "malformed transaction")))
        }
    }

    private func encodeNativeCurrencyOrder(
            signedOrder: SignedOrder,
            v: UInt8,
            r: String,
            s: String,
            recipient: AlphaWallet.Address,
            completion: @escaping (Result<Data, Error>) -> Void
    ) {
        do {
            let parameters: [Any] = [
                signedOrder.order.nonce,
                signedOrder.order.expiry,
                signedOrder.order.count,
                BigUInt(v),
                Data(_hex: r),
                Data(_hex: s),
                recipient
            ]
            let functionEncoder = Function(name: "dropCurrency", parameters: [
                .uint(bits: 256),
                .uint(bits: 256),
                .uint(bits: 256),
                .uint(bits: 8),
                .bytes(32),
                .bytes(32),
                .address
            ])
            let encoder = ABIEncoder()
            try encoder.encode(function: functionEncoder, arguments: parameters)
            completion(.success(encoder.data))
        } catch {
            completion(.failure(Web3Error(description: "malformed transaction")))
        }
    }
}

extension ClaimPaidOrderCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.prettyError)

        delegate?.coordinator(self, didFailTransaction: error)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        delegate?.didClose(in: self)
        removeCoordinator(coordinator)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        // no-op
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.coordinator(strongSelf, didCompleteTransaction: result)
        }
        removeCoordinator(coordinator)
    }

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension ClaimPaidOrderCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
