//
//  AddressOrEnsNameLabel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2020.
//

import UIKit
import PromiseKit
import Combine
import AlphaWalletFoundation

class AddressOrEnsNameLabel: UILabel {

    enum AddressFormat {
        case full
        case truncateMiddle

        func formattedAddress(_ address: AlphaWallet.Address) -> String {
            switch self {
            case .full:
                return address.eip55String
            case .truncateMiddle:
                return address.truncateMiddle
            }
        }
    }

    private let domainResolutionService: DomainNameResolutionServiceType

    private var currentlyResolving: (value: String, promise: Promise<BlockieAndAddressOrEnsResolution>)? {
        didSet {
            guard shouldShowLoadingIndicator else {
                loadingIndicator.stopAnimating()
                return
            }

            if currentlyResolving == nil {
                loadingIndicator.stopAnimating()
            } else {
                loadingIndicator.startAnimating()
            }
        }
    }

    private var cancelable: AnyCancellable?

    let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.heightAnchor.constraint(equalToConstant: 15).isActive = true
        indicator.widthAnchor.constraint(equalToConstant: 15).isActive = true

        return indicator
    }()

    let blockieImageView: BlockieImageView = {
        let imageView = BlockieImageView(size: .init(width: 20, height: 20))
        imageView.hideWhenImageIsNil = true

        return imageView
    }()

    var addressString: String? {
        switch addressOrEnsName {
        case .address(let value):
            return value.eip55String
        case .domainName, .none:
            return nil
        }
    }

    var addressOrEnsName: AddressOrDomainName? {
        didSet {
            switch addressOrEnsName {
            case .some(.address(let address)):
                text = addressFormat.formattedAddress(address)
            case .some(.domainName(let string)):
                text = string
            case .none:
                text = nil
            }

            isHidden = text == nil
        }
    }

    var stringValue: String? {
        return addressOrEnsName?.stringValue
    }

    var addressFormat: AddressFormat = .truncateMiddle
    var shouldShowLoadingIndicator: Bool = false

    init(domainResolutionService: DomainNameResolutionServiceType) {
        self.domainResolutionService = domainResolutionService
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        numberOfLines = 0
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        textColor = Configuration.Color.Semantic.ensText
        font = Configuration.Font.label
        textAlignment = .center
        clear()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blockieImageView.cornerRadius = 10
    }

    func set(blockieImage: BlockiesImage?) {
        blockieImageView.set(blockieImage: blockieImage)
    }

    func clear() {
        set(blockieImage: nil)
        addressOrEnsName = nil
        currentlyResolving = nil
    }

    func resolve(_ value: String, server: RPCServer) -> Promise<BlockieAndAddressOrEnsResolution> {
        let valueArg = value

        if let currentlyResolving = currentlyResolving, currentlyResolving.value == value {
            return currentlyResolving.promise
        }
        clear()

        let promise = Promise<BlockieAndAddressOrEnsResolution> { seal in
            if let address = AlphaWallet.Address(string: value) {
                Task { @MainActor in
                    do {
                        let blockieAndResolution = try await domainResolutionService.resolveEnsAndBlockie(address: address, server: server)
                        seal.fulfill(blockieAndResolution)
                    } catch {
                        self.clearCurrentlyResolvingIf(value: valueArg)
                    }
                }
            } else if value.contains(".") {
                Task { @MainActor in
                    do {
                        let blockieAndResolution = try await domainResolutionService.resolveAddressAndBlockie(string: value)
                        seal.fulfill(blockieAndResolution)
                    } catch {
                        self.clearCurrentlyResolvingIf(value: valueArg)
                    }
                }
            } else {
                seal.fulfill((nil, .resolved(.none)))
            }
        }.ensure {
            self.clearCurrentlyResolvingIf(value: valueArg)
        }
        currentlyResolving = (value, promise)
        return promise
    }

    private func clearCurrentlyResolvingIf(value: String) {
        if let currentlyResolving = currentlyResolving, currentlyResolving.value == value {
            self.currentlyResolving = nil
        } else {
            //no-op
        }
    }
}
