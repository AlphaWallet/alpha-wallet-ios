// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletTokenScript

public class FetchTokenScriptFiles {
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensDataStore: TokensDataStore
    private let sessionsProvider: SessionsProvider
    private let queue = DispatchQueue(label: "com.FetchAssetDefinitions.UpdateQueue")
    private var cancellable = Set<AnyCancellable>()

    public init(assetDefinitionStore: AssetDefinitionStore,
                tokensDataStore: TokensDataStore,
                sessionsProvider: SessionsProvider) {

        self.assetDefinitionStore = assetDefinitionStore
        self.tokensDataStore = tokensDataStore
        self.sessionsProvider = sessionsProvider
    }

    public func start() {
        sessionsProvider.sessions
            .compactMap { $0.keys }
            .receive(on: queue)
            .map { [tokensDataStore] in tokensDataStore.tokens(for: Array($0)) }
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
                let contractsWithTokenScriptFileFromOfficialRepo = assetDefinitionStore.contractsWithTokenScriptFileFromOfficialRepo.map { AddressAndOptionalRPCServer(address: $0, server: nil) }

                let contractsAndServers = Array(Set(contractsInDatabase + contractsWithTokenScriptFileFromOfficialRepo))
                assetDefinitionStore.fetchXMLs(forContractsAndServers: contractsAndServers)
            }.store(in: &cancellable)
    }
}
