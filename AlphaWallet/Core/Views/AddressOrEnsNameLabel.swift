//
//  AddressOrEnsNameLabel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2020.
//

import UIKit

class AddressOrEnsNameLabel: UILabel {

    enum AddressOrEnsResolution {
        case invalidInput
        case resolved(AddressOrEnsName?)
    }

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

    private let serverToResolveEns = RPCServer.main
    private var inResolvingState: Bool = false {
        didSet {
            if inResolvingState && shouldShowLoadingIndicator {
                loadingIndicator.startAnimating()
            } else {
                loadingIndicator.stopAnimating()
            }
        }
    }

    let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .gray)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.heightAnchor.constraint(equalToConstant: 15).isActive = true
        indicator.widthAnchor.constraint(equalToConstant: 15).isActive = true

        return indicator
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

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        numberOfLines = 0
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        textColor = DataEntry.Color.ensText
        font = DataEntry.Font.label
        textAlignment = .center
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func clear() {
        addressOrEnsName = nil
        inResolvingState = false
    }

    func resolve(_ value: String, completion: @escaping ((AddressOrEnsResolution) -> Void)) {
        clear()
        
        if let address = AlphaWallet.Address(string: value) {
            inResolvingState = true
            ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: address) { [weak self] result in
                guard let strongSelf = self else { return }
                strongSelf.inResolvingState = false

                if let resolvedEnsName = result.value {
                    completion(.resolved(.ensName(resolvedEnsName)))
                } else {
                    completion(.resolved(.none))
                }
            }
        } else if value.contains(".") {
            inResolvingState = true

            GetENSAddressCoordinator(server: serverToResolveEns).getENSAddressFromResolver(for: value) { [weak self] result in
                guard let strongSelf = self else { return }
                strongSelf.inResolvingState = false

                if let address = result.value, CryptoAddressValidator.isValidAddress(address.address) {
                    completion(.resolved(.address(AlphaWallet.Address(address: address))))
                } else {
                    completion(.resolved(.none))
                }
            }
        } else {
            completion(.invalidInput)
        }
    }
}
