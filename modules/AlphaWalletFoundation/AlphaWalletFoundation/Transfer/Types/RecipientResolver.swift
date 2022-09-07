//
//  RecipientResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2020.
//

import Foundation
import Combine

public class RecipientResolver {
    public enum Row: Int, CaseIterable {
        case address
        case ens
    }

    public let address: AlphaWallet.Address?
    public var ensName: String?

    public var hasResolvedEnsName: Bool {
        if let value = ensName {
            return !value.trimmed.isEmpty
        }
        return false
    }
    private let domainResolutionService: DomainResolutionServiceType

    public init(address: AlphaWallet.Address?, domainResolutionService: DomainResolutionServiceType) {
        self.address = address
        self.domainResolutionService = domainResolutionService
    } 

    public func resolveRecipient() -> AnyPublisher<Void, Never> {
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

    public var value: String? {
        if let ensName = ensName, let address = address {
            return String(format: "%@ | %@", ensName, address.truncateMiddle)
        } else {
            return ensName ?? address?.truncateMiddle
        }
    }
}
