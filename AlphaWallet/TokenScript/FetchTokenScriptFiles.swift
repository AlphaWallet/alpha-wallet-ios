// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletAttestation
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletTokenScript

public class FetchTokenScriptFilesImpl: FetchTokenScriptFiles {
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensDataStore: TokensDataStore
    private let sessionsProvider: SessionsProvider
    private let queue = DispatchQueue(label: "com.FetchAssetDefinitions.UpdateQueue")
    private var cancellable = Set<AnyCancellable>()

    public init(wallet: Wallet, assetDefinitionStore: AssetDefinitionStore, tokensDataStore: TokensDataStore, sessionsProvider: SessionsProvider) {
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensDataStore = tokensDataStore
        self.sessionsProvider = sessionsProvider
    }

    public func start() {
        if TokenScript.shouldDisableFetchTokenScriptXMLFiles {
            return
        }
        fetchForTokens()
        fetchForAttestations()
    }

    private func fetchForTokens() {
        sessionsProvider.sessions
            .map { $0.keys }
            .receive(on: queue)
            .flatMap { [tokensDataStore] servers in
                asFuture {
                    await tokensDataStore.tokens(for: Array(servers))
                }
            }
            .map { tokens in
                return tokens.filter {
                    switch $0.type {
                    case .erc20, .erc721, .erc875, .erc721ForTickets, .erc1155:
                        return true
                    case .nativeCryptocurrency:
                        return false
                    }
                }.map { AddressAndOptionalRPCServer(address: $0.contractAddress, server: $0.server) }
            }.sink { [assetDefinitionStore] contractsInDatabase in
                assetDefinitionStore.fetchXMLs(forContractsAndServers: contractsInDatabase)
            }.store(in: &cancellable)
    }

    private func fetchForAttestations() {
        let attestations = AttestationsStore(wallet: wallet.address).attestations
        for each in attestations {
            Task { @MainActor in
                await assetDefinitionStore.fetchXMLForAttestationIfScriptURL(each)
            }
        }
    }
}
