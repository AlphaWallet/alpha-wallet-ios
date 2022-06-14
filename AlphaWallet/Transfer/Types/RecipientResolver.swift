//
//  RecipientResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2020.
//

import Foundation

class RecipientResolver {
    enum Row: Int, CaseIterable {
        case address
        case ens
    }

    let address: AlphaWallet.Address?
    var ensName: String?

    var hasResolvedEnsName: Bool {
        if let value = ensName {
            return !value.trimmed.isEmpty
        }
        return false
    }
    private let domainResolutionService: DomainResolutionServiceType

    init(address: AlphaWallet.Address?, domainResolutionService: DomainResolutionServiceType) {
        self.address = address
        self.domainResolutionService = domainResolutionService
    }

    func resolve(completion: @escaping () -> Void) {
        guard let address = address else { return }
        domainResolutionService.resolveEns(address: address).done { [weak self] result in
            guard let strongSelf = self else { return }

            strongSelf.ensName = result.resolution.value
            completion()
        }.catch { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.ensName = nil
            completion()
        }
    }

    var value: String? {
        if let ensName = ensName, let address = address {
            return String(format: "%@ | %@", ensName, address.truncateMiddle)
        } else {
            return ensName ?? address?.truncateMiddle
        }
    }
}
