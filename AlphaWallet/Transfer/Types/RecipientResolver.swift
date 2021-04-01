//
//  RecipientResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2020.
//

import UIKit

class RecipientResolver {
    enum Row: Int, CaseIterable {
        case address
        case ens
    }

    let address: AlphaWallet.Address?
    var ensName: String?

    var hasResolvedESNName: Bool {
        if let value = ensName {
            return !value.trimmed.isEmpty
        }
        return false
    }

    init(address: AlphaWallet.Address?) {
        self.address = address
    }

    func resolve(completion: @escaping () -> Void) {
        guard let address = address else { return }
        ENSReverseLookupCoordinator(server: .forResolvingEns).getENSNameFromResolver(forAddress: address) { [weak self] result in
            guard let strongSelf = self else { return }

            strongSelf.ensName = result.value
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
