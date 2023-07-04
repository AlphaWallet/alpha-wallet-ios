//
//  WalletApiCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.06.2022.
//

import UIKit
import Combine
import PromiseKit
import AlphaWalletFoundation
import AlphaWalletLogger

protocol WalletApiCoordinatorDelegate: AnyObject {
    func didOpenUrl(in service: WalletApiCoordinator, redirectUrl: URL)
}

class WalletApiCoordinator: NSObject, Coordinator {
    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let analytics: AnalyticsLogger
    private let restartHandler: RestartQueueHandler

    var coordinators: [Coordinator] = []
    weak var delegate: WalletApiCoordinatorDelegate?

    init(keystore: Keystore, navigationController: UINavigationController, analytics: AnalyticsLogger, restartHandler: RestartQueueHandler) {
        self.restartHandler = restartHandler
        self.keystore = keystore
        self.navigationController = navigationController
        self.analytics = analytics
        super.init()
    }

    func handle(action: DeepLink.WalletApi) {
        switch action {
        case .connect(let redirectUrl, _, let metadata):
            connect(redirectUrl: redirectUrl, metadata: metadata)
        case .signPersonalMessage(let address, _, let redirectUrl, _, let metadata, let message):
            signPersonalMessage(address: address, redirectUrl: redirectUrl, metadata: metadata, message: message)
        }
    }

    private func validate(addressToConnect address: AlphaWallet.Address?) throws -> AlphaWallet.Address {
        guard let address = address, let wallet = keystore.currentWallet else {
            throw WalletApiError.connectionAddressNotFound
        }

        guard wallet.address == address else {
            throw WalletApiError.requestedWalletNonActive
        }

        return address
    }

    private func connect(redirectUrl: URL, metadata: DeepLink.Metadata) {
        guard let wallet = keystore.currentWallet else { return }
        let proposalType: ProposalType = .deepLink(.init(metadata: metadata, address: wallet.address))

        firstly {
            acceptProposal(proposalType: proposalType)
        }.done { [wallet] result in
            switch result {
            case .deepLink:
                guard let redirectUrl = WalletApiResponse().buildConnectResponse(redirectUrl: redirectUrl, with: .success(wallet.address)) else { return }

                self.delegate?.didOpenUrl(in: self, redirectUrl: redirectUrl)
            case .cancel, .walletConnect:
                guard let redirectUrl = WalletApiResponse().buildConnectResponse(redirectUrl: redirectUrl, with: .failure(WalletApiError.cancelled)) else { return }

                self.delegate?.didOpenUrl(in: self, redirectUrl: redirectUrl)
            }
        }.catch { error in
            guard let redirectUrl = WalletApiResponse().buildConnectResponse(redirectUrl: redirectUrl, with: .failure(error)) else { return }

            self.delegate?.didOpenUrl(in: self, redirectUrl: redirectUrl)
        }
    }

    private func signPersonalMessage(address: AlphaWallet.Address?, redirectUrl: URL, metadata: DeepLink.Metadata, message: String) {
        let responseBuilder = WalletApiResponse()
        do {
            let address = try validate(addressToConnect: address)

            let requester = DeepLinkRequesterViewModel(requester: Requester(shortName: metadata.name, name: metadata.name, server: nil, url: metadata.appUrl, iconUrl: metadata.iconUrl))

            firstly {
                signPersonalMessage(with: .personalMessage(message.asSignableMessageData), account: address, requester: requester)
            }.done { data in
                guard let redirectUrl = responseBuilder.buildSignPersonalMessageResponse(redirectUrl: redirectUrl, with: .success(data)) else { return }

                self.delegate?.didOpenUrl(in: self, redirectUrl: redirectUrl)
            }.catch { error in
                guard let redirectUrl = responseBuilder.buildSignPersonalMessageResponse(redirectUrl: redirectUrl, with: .failure(error)) else { return }

                self.delegate?.didOpenUrl(in: self, redirectUrl: redirectUrl)
            }
        } catch {
            displayError(error) {
                guard let redirectUrl = responseBuilder.buildSignPersonalMessageResponse(redirectUrl: redirectUrl, with: .failure(error)) else { return }
                self.delegate?.didOpenUrl(in: self, redirectUrl: redirectUrl)
            }
        }
    }

    private func displayError(_ error: Error, completion: @escaping () -> Void) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.localizedDescription, completion: completion)
    }

    private func acceptProposal(proposalType: ProposalType) -> Promise<ProposalResult> {
        infoLog("[WalletApi] acceptProposal: \(proposalType)")
        return AcceptProposalCoordinator.promise(navigationController, coordinator: self, proposalType: proposalType, analytics: analytics, restartHandler: restartHandler)
    }

    private func signPersonalMessage(with type: SignMessageType, account: AlphaWallet.Address, requester: RequesterViewModel) -> Promise<Data> {
        infoLog("[WalletApi] signMessage: \(type)")
        return SignMessageCoordinator.promise(analytics: analytics, navigationController: navigationController, keystore: keystore, coordinator: self, signType: type, account: account, source: .deepLink, requester: requester)
    }
}

extension WalletApiCoordinator {
    struct WalletApiResponse {
        /// https://myapp.com?call=connect&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3
        func buildConnectResponse(redirectUrl: URL, with result: Swift.Result<AlphaWallet.Address, Error>) -> URL? {
            let components = NSURLComponents(url: redirectUrl, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []

            switch result {
            case .success(let address):
                components?.queryItems = queryItems + [
                    .init(name: "call", value: "connect"),
                    .init(name: "address", value: address.eip55String)
                ]
            case .failure:
                components?.queryItems = queryItems + [
                    .init(name: "call", value: "connect")
                ]
            }

            return components?.url
        }

        /// https://myapp.com?call=signpersonalmessage&message=0x007bEe82BDd9e866b2bd114780a47f2261C684E3
        func buildSignPersonalMessageResponse(redirectUrl: URL, with result: Swift.Result<Data, Error>) -> URL? {
            let components = NSURLComponents(url: redirectUrl, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            switch result {
            case .success(let data):
                components?.queryItems = queryItems + [
                    .init(name: "call", value: "signpersonalmessage"),
                    .init(name: "signature", value: data.hexEncoded)
                ]
            case .failure:
                components?.queryItems = queryItems + [
                    .init(name: "call", value: "signpersonalmessage")
                ]
            }

            return components?.url
        }
    }
}
