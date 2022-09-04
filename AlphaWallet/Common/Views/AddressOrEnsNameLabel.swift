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

    private let domainResolutionService: DomainResolutionServiceType

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
        return BlockieImageView(size: .init(width: 20, height: 20))
    }()

    var addressString: String? {
        switch addressOrEnsName {
        case .address(let value):
            return value.eip55String
        case .ensName, .none:
            return nil
        }
    }

    var addressOrEnsName: AddressOrEnsName? {
        didSet {
            switch addressOrEnsName {
            case .some(.address(let address)):
                text = addressFormat.formattedAddress(address)
            case .some(.ensName(let string)):
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

    var blockieImage: BlockiesImage? {
        didSet {
            blockieImageView.image = blockieImage
            blockieImageView.isHidden = blockieImage == nil
        }
    }

    init(domainResolutionService: DomainResolutionServiceType) {
        self.domainResolutionService = domainResolutionService
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        numberOfLines = 0
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        textColor = DataEntry.Color.ensText
        font = DataEntry.Font.label
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

    func clear() {
        blockieImage = nil
        addressOrEnsName = nil
        currentlyResolving = nil
    }

    func resolve(_ value: String) -> Promise<BlockieAndAddressOrEnsResolution> {
        let valueArg = value

        if let currentlyResolving = currentlyResolving, currentlyResolving.value == value {
            return currentlyResolving.promise
        }
        clear()

        let promise = Promise<BlockieAndAddressOrEnsResolution> { seal in
            if let address = AlphaWallet.Address(string: value) {
                cancelable?.cancel()
                cancelable = domainResolutionService.resolveEnsAndBlockie(address: address)
                    .sink(receiveCompletion: { _ in
                        seal.fulfill((nil, .resolved(.none)))
                    }, receiveValue: { value in
                        self.clearCurrentlyResolvingIf(value: valueArg)
                        seal.fulfill(value)
                    })
            } else if value.contains(".") {
                cancelable?.cancel()
                cancelable = domainResolutionService.resolveAddressAndBlockie(string: value)
                    .sink(receiveCompletion: { _ in
                        seal.fulfill((nil, .resolved(.none)))
                    }, receiveValue: { value in
                        self.clearCurrentlyResolvingIf(value: valueArg)
                        seal.fulfill(value)
                    })
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
