//
//  RecipientResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2020.
//

import Foundation
import Combine
import CombineExt

public struct RecipientViewModel {
    public var address: AlphaWallet.Address?
    public var ensName: String?
}

public class RecipientResolver {
    public enum Row: Int, CaseIterable {
        case address
        case ens
    }

    public let address: AlphaWallet.Address?
    private var resolution: BlockieAndAddressOrEnsResolution?
    public var ensName: EnsName? {
        resolution?.resolution.value
    }
    public var blockieImage: BlockiesImage? {
        resolution?.image
    }

    public var hasResolvedEnsName: Bool {
        if let value = resolution?.resolution.value {
            return !value.trimmed.isEmpty
        }
        return false
    }
    private let domainResolutionService: DomainResolutionServiceType

    public init(address: AlphaWallet.Address?, domainResolutionService: DomainResolutionServiceType) {
        self.address = address
        self.domainResolutionService = domainResolutionService
    } 

    public func resolveRecipient() -> AnyPublisher<BlockieAndAddressOrEnsResolution?, Never> {
        guard let address = address else {
            return .just((image: nil, resolution: .invalidInput))
        }

        return domainResolutionService.resolveEnsAndBlockie(address: address)
            .map { resolution -> BlockieAndAddressOrEnsResolution? in return resolution }
            .replaceError(with: nil)
            .handleEvents(receiveOutput: { [weak self] in self?.resolution = $0 })
            .eraseToAnyPublisher()
    }

    public var value: String? {
        return address?.eip55String
    }
}
