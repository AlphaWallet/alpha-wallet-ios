//
//  AddressOrEnsNameLabel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2020.
//

import UIKit
import PromiseKit
import CryptoSwift

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

    private var inResolvingState: Bool = false {
        didSet {
            if inResolvingState && shouldShowLoadingIndicator {
                loadingIndicator.startAnimating()
            } else if requestsIdsStore.isEmpty {
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

    init() {
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
        inResolvingState = false
    }

    var blockieImage: BlockiesImage? {
        didSet {
            blockieImageView.image = blockieImage
            blockieImageView.isHidden = blockieImage == nil
        }
    }

    typealias BlockieAndAddressOrEnsResolution = (image: BlockiesImage?, resolution: AddressOrEnsResolution)
    // NOTE: caching ids for call `func resolve(_ value: String)` function, for verifying activity state
    // adds a new id once function get called, and removes once resolve a value.
    private var requestsIdsStore: Set<String> = .init()

    func resolve(_ value: String) -> Promise<BlockieAndAddressOrEnsResolution> {
        let id = UUID().uuidString
        requestsIdsStore.insert(id)
        clear()

        return Promise<BlockieAndAddressOrEnsResolution> { seal in
            if let address = AlphaWallet.Address(string: value) {
                inResolvingState = true

                firstly {
                    ENSReverseLookupCoordinator(server: .forResolvingEns).getENSNameFromResolver(forAddress: address)
                }.then { ens -> Promise<BlockieAndAddressOrEnsResolution> in
                    return BlockiesGenerator().promise(address: address, ens: ens).map { image -> BlockieAndAddressOrEnsResolution in
                        return (image, .resolved(.ensName(ens)))
                    }.recover { _ -> Promise<BlockieAndAddressOrEnsResolution> in
                        return .value((nil, .resolved(.ensName(ens))))
                    }
                }.done { value in
                    // NOTE: improve loading indicator hidding
                    self.requestsIdsStore.removeAll()
                    seal.fulfill(value)
                }.catch { _ in
                    seal.fulfill((nil, .resolved(.none)))
                }
            } else if value.contains(".") {
                inResolvingState = true

                GetENSAddressCoordinator(server: .forResolvingEns).getENSAddressFromResolverPromise(value: value).recover { _ -> Promise<AlphaWallet.Address> in
                    DomainResolver(server: .forResolvingEns).resolveAddress(value)
                }.then { addr -> Promise<BlockieAndAddressOrEnsResolution> in
                    return BlockiesGenerator().promise(address: addr).map { image -> BlockieAndAddressOrEnsResolution in
                        return (image, .resolved(.address(addr)))
                    }.recover { _ -> Promise<BlockieAndAddressOrEnsResolution> in
                        return .value((nil, .resolved(.address(addr))))
                    }
                }.done { value in
                    self.requestsIdsStore.removeAll()
                    seal.fulfill(value)
                }.catch { _ in
                    seal.fulfill((nil, .resolved(.none)))
                }
            } else {
                seal.fulfill((nil, .resolved(.none)))
            }
        }.ensure {
            self.requestsIdsStore.remove(id)

            self.inResolvingState = false
        }
    }
}
