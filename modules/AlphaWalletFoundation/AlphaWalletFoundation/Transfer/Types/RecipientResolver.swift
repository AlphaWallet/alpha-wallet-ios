//
//  RecipientResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2020.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletENS
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
    private let server: RPCServer
    private var resolution: Loadable<BlockieAndAddressOrEnsResolution, Error> = .loading
    public var ensName: DomainName? {
        resolution.value?.resolution.value
    }
    public var blockieImage: BlockiesImage? {
        resolution.value?.image
    }

    public var hasResolvedEnsName: Bool {
        if let value = resolution.value?.resolution.value {
            return !value.trimmed.isEmpty
        }
        return false
    }
    private let domainResolutionService: DomainNameResolutionServiceType

    public init(address: AlphaWallet.Address?, server: RPCServer, domainResolutionService: DomainNameResolutionServiceType) {
        self.address = address
        self.server = server
        self.domainResolutionService = domainResolutionService
    }

    private struct RecipientResolutionError: Error {
        let message: String
    }

    public func resolveRecipient() async -> Loadable<BlockieAndAddressOrEnsResolution, Error> {
        guard let address = address else {
            resolution = .failure(RecipientResolutionError(message: "address not found"))
            return resolution
        }

        do {
            let resolution = try await domainResolutionService.resolveEnsAndBlockie(address: address, server: server)
            self.resolution = .done(resolution)
        } catch {
            self.resolution = .failure(error)
        }
        return resolution
    }

    public var value: String? {
        return address?.eip55String
    }
}
