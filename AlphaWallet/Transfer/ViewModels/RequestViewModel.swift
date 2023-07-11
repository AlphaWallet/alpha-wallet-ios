// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct RequestViewModelInput {
    let copyEns: AnyPublisher<Void, Never>
    let copyAddress: AnyPublisher<Void, Never>
}

struct RequestViewModelOutput {
    let copiedToClipboard: AnyPublisher<String, Never>
    let viewState: AnyPublisher<RequestViewModel.ViewState, Never>
}

class RequestViewModel {
    private let account: Wallet
    private let domainResolutionService: DomainNameResolutionServiceType

    let backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    var instructionAttributedString: NSAttributedString {
        NSAttributedString(string: R.string.localizable.aWalletAddressScanInstructions(), attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.labelTextActive
        ])
    }

    init(account: Wallet, domainResolutionService: DomainNameResolutionServiceType) {
        self.account = account
        self.domainResolutionService = domainResolutionService
    }

    func transform(input: RequestViewModelInput) -> RequestViewModelOutput {
        let ensName = resolveEns()
        let viewState = Publishers.CombineLatest(generateQrCode(), resolveEns())
            .map { [account] qrCode, ensName -> RequestViewModel.ViewState in
                let address = account.address.eip55String
                return .init(title: R.string.localizable.aSettingsContentsMyWalletAddress(), ensName: ensName, address: address, qrCode: qrCode)
            }.eraseToAnyPublisher()

        let copiedEnsName = input.copyEns
            .withLatestFrom(ensName)
            .compactMap { $0 }

        let copiedAddress = input.copyAddress
            .map { [account] _ in account.address.eip55String }

        let copiedToClipboard = Publishers.Merge(copiedEnsName, copiedAddress)
            .handleEvents(receiveOutput: { UIPasteboard.general.string = $0 })
            .map { _ in R.string.localizable.copiedToClipboardTitle(R.string.localizable.address()) }
            .eraseToAnyPublisher()

        return .init(copiedToClipboard: copiedToClipboard, viewState: viewState)
    }

    private func resolveEns() -> AnyPublisher<String?, Never> {
        domainResolutionService.reverseResolveDomainName(address: account.address, server: RPCServer.forResolvingDomainNames)
            .map { ens -> DomainName? in return ens }
            .replaceError(with: nil)
            .prepend(nil)
            .eraseToAnyPublisher()
    }

    private func generateQrCode() -> AnyPublisher<UIImage?, Never> {
        // EIP67 format not being used much yet, use hex value for now
        // let string = "ethereum:\(account.address.address)?value=\(value)"
        let qrCode: PassthroughSubject<UIImage?, Never> = .init()
        DispatchQueue.global(qos: .userInteractive).async { [account] in
            let image = account.address.eip55String.toQRCode()
            DispatchQueue.main.async {
                qrCode.send(image)
            }
        }

        return Publishers.Merge(Just(nil), qrCode).eraseToAnyPublisher()
    }
}

extension RequestViewModel {
    struct ViewState {
        let title: String
        let ensName: String?
        let address: String
        let qrCode: UIImage?
    }
}
