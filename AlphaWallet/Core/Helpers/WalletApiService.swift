//
//  WalletApiService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.06.2022.
//

import UIKit
import Combine
import PromiseKit

protocol WalletApiServiceDelegate: AnyObject {
    func didOpenUrl(in service: WalletApiService, redirectUrl: URL)
}

class WalletApiService: NSObject, Coordinator {
    enum WalletApiServiceError: LocalizedError {
        case connectionAddressNotFound
        case requestedWalletNonActive
        case requestedServerDisabled
        case cancelled

        var localizedDescription: String {
            switch self {
            case .connectionAddressNotFound:
                return "Connection Address not Found"
            case .requestedWalletNonActive:
                return "Requested Wallet Non Active"
            case .requestedServerDisabled:
                return "Requested Server Is Disabled"
            case .cancelled:
                return "Operation Cancelled"
            }
        }
    }

    private let sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never>
    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let analyticsCoordinator: AnalyticsCoordinator

    var coordinators: [Coordinator] = []
    weak var delegate: WalletApiServiceDelegate?

    init(keystore: Keystore, navigationController: UINavigationController, analyticsCoordinator: AnalyticsCoordinator, sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never>) {
        self.sessionsSubject = sessionsSubject
        self.keystore = keystore
        self.navigationController = navigationController
        self.analyticsCoordinator = analyticsCoordinator
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

    private var wallet: Wallet {
        return sessionsSubject.value.anyValue.account
    }

    private func isActiveWallet(address: AlphaWallet.Address) -> Bool {
        return wallet.address.sameContract(as: address)
    }

    private func validate(addressToConnect address: AlphaWallet.Address?) throws -> AlphaWallet.Address {
        guard let address = address else {
            throw WalletApiServiceError.connectionAddressNotFound
        }

        guard isActiveWallet(address: address) else {
            throw WalletApiServiceError.requestedWalletNonActive
        }

        return address
    }

    private func connect(redirectUrl: URL, metadata: DeepLink.Metadata) {
        let proposalType: ProposalType = .deepLink(.init(metadata: metadata, address: wallet.address))

        firstly {
            acceptProposal(proposalType: proposalType)
        }.done { [wallet] result in
            switch result {
            case .deepLink:
                guard let redirectUrl = WalletApiResponse().buildConnectResponse(redirectUrl: redirectUrl, with: .success(wallet.address)) else { return }

                self.delegate?.didOpenUrl(in: self, redirectUrl: redirectUrl)
            case .cancel, .walletConnect:
                guard let redirectUrl = WalletApiResponse().buildConnectResponse(redirectUrl: redirectUrl, with: .failure(WalletApiServiceError.cancelled)) else { return }

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
                signPersonalMessage(with: .personalMessage(message.toHexData), account: address, requester: requester)
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
            .displayError(message: error.prettyError, completion: completion)
    }

    private func acceptProposal(proposalType: ProposalType) -> Promise<ProposalResult> {
        infoLog("[WalletApi] acceptProposal: \(proposalType)")
        return AcceptProposalCoordinator.promise(navigationController, coordinator: self, proposalType: proposalType, analyticsCoordinator: analyticsCoordinator)
    }

    private func signPersonalMessage(with type: SignMessageType, account: AlphaWallet.Address, requester: RequesterViewModel) -> Promise<Data> {
        infoLog("[WalletApi] signMessage: \(type)")

        return SignMessageCoordinator.promise(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, keystore: keystore, coordinator: self, signType: type, account: account, source: .deepLink, requester: requester)
    }
}

extension WalletApiService {
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
                    .init(name: "message", value: data.hexEncoded)
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
