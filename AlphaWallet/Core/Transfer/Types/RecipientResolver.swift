//
//  RecipientResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2020.
//

import Foundation
import Combine

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

    func resolveRecipient() -> AnyPublisher<Void, Never> {
        guard let address = address else {
            return .just(())
        }

        return domainResolutionService.resolveEns(address: address)
            .map { ens -> EnsName? in return ens }
            .replaceError(with: nil)
            .handleEvents(receiveOutput: { [weak self] ensName in
                self?.ensName = ensName
            }).mapToVoid()
            .eraseToAnyPublisher()
    }

    var value: String? {
        if let ensName = ensName, let address = address {
            return String(format: "%@ | %@", ensName, address.truncateMiddle)
        } else {
            return ensName ?? address?.truncateMiddle
        }
    }
}
