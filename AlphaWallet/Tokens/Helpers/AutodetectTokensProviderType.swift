//
//  AutodetectTokensProviderType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.06.2021.
//

import UIKit
import PromiseKit

protocol AutodetectTokensProviderDelegate: class {
    func tokensDidChange(inCoordinator coordinator: AutodetectTokensProvider)
}

protocol AutodetectTokensProviderType: class {
    var isAutoDetectingTransactedTokens: Bool { get set }
    var isAutoDetectingTokens: Bool { get set }
    var delegate: AutodetectTokensProviderDelegate? { get set }

    func autoDetectTokensOperation(forServer server: RPCServer, wallet: AlphaWallet.Address, tokens: [(name: String, contract: AlphaWallet.Address)]) -> Operation
    func autoDetectTransactedTokensOperation(forServer server: RPCServer, wallet: AlphaWallet.Address) -> Operation
}

class AutodetectTokensProvider: AutodetectTokensProviderType {
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenProvider: TokenProviderType
    private let queue = DispatchQueue.global()

    var isAutoDetectingTransactedTokens = false
    var isAutoDetectingTokens = false

    weak var delegate: AutodetectTokensProviderDelegate?

    init(keystore: Keystore, storage: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, tokenProvider: TokenProviderType) {
        self.keystore = keystore
        self.storage = storage
        self.tokenProvider = tokenProvider
        self.assetDefinitionStore = assetDefinitionStore
    }

    private func autoDetectTransactedTokensImpl(wallet: AlphaWallet.Address, server: RPCServer, erc20: Bool) -> Promise<Void> {
        func getContractsToAdd(detectedContracts: [AlphaWallet.Address]) -> [AlphaWallet.Address] {
            let alreadyAddedContracts = storage.enabledObject.map { $0.contractAddress }
            let deletedContracts = storage.deletedContracts.map { $0.contractAddress }
            let hiddenContracts = storage.hiddenContracts.map { $0.contractAddress }
            let delegateContracts = storage.delegateContracts.map { $0.contractAddress }

            return detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts
        }

        func addToken(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (TokenObject?) -> Void) {
            tokenProvider.addToken(for: contract, server: server, completion: completion)
        }

        return Promise<Void> { seal in
            let startBlock: Int?
            if erc20 {
                startBlock = Config.getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
            } else {
                startBlock = Config.getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
            }

            GetContractInteractions(queue: queue).getContractList(address: wallet, server: server, startBlock: startBlock, erc20: erc20).done { [weak self] contracts, maxBlockNumber in
                guard let strongSelf = self else { return }
                defer {
                    seal.fulfill(())
                }
                if let maxBlockNumber = maxBlockNumber {
                    if erc20 {
                        Config.setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(maxBlockNumber, server: server, wallet: wallet)
                    } else {
                        Config.setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(maxBlockNumber, server: server, wallet: wallet)
                    }
                }
                let currentAddress = strongSelf.keystore.currentWallet.address
                guard currentAddress.sameContract(as: wallet) else { return }
                let detectedContracts = contracts

                let contractsToAdd = getContractsToAdd(detectedContracts: detectedContracts)
                var contractsPulled = 0
                var hasRefreshedAfterAddingAllContracts = false

                if contractsToAdd.isEmpty { return }

                for eachContract in contractsToAdd {
                    addToken(for: eachContract, server: server) { _ in
                        contractsPulled += 1
                        if contractsPulled == contractsToAdd.count {
                            hasRefreshedAfterAddingAllContracts = true
                            DispatchQueue.main.async {
                                strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
                            }
                        }
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if !hasRefreshedAfterAddingAllContracts {
                        strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
                    }
                }
            }.catch { e in
                seal.reject(e)
            }
        }
    }

    private func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer, completion: @escaping () -> Void) {
        let address = keystore.currentWallet.address
        let alreadyAddedContracts = storage.enabledObject.map { $0.contractAddress }
        let deletedContracts = storage.deletedContracts.map { $0.contractAddress }
        let hiddenContracts = storage.hiddenContracts.map { $0.contractAddress }
        let contracts = contractsToDetect.map { $0.contract } - alreadyAddedContracts - deletedContracts - hiddenContracts
        var contractsProcessed = 0
        guard !contracts.isEmpty else {
            completion()
            return
        }

        for each in contracts {
            storage.getTokenType(for: each) { [weak self] tokenType in
                guard let strongSelf = self else {
                    contractsProcessed += 1
                    if contractsProcessed == contracts.count {
                        completion()
                    }
                    return
                }

                switch tokenType {
                case .erc875:
                    //TODO long and very similar code below. Extract function
                    let balanceCoordinator = GetERC875BalanceCoordinator(forServer: server)
                    balanceCoordinator.getERC875TokenBalance(for: address, contract: each) { result in

                        switch result {
                        case .success(let balance):
                            if !balance.isEmpty {
                                strongSelf.tokenProvider.addToken(for: each, server: server) { _ in
                                    DispatchQueue.main.async {
                                        strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
                                    }
                                }
                            }
                        case .failure:
                            break
                        }
                        contractsProcessed += 1
                        if contractsProcessed == contracts.count {
                            completion()
                        }
                    }
                case .erc20:
                    let balanceCoordinator = GetERC20BalanceCoordinator(forServer: server)
                    balanceCoordinator.getBalance(for: address, contract: each) { result in
                        switch result {
                        case .success(let balance):
                            if balance > 0 {
                                strongSelf.tokenProvider.addToken(for: each, server: server) { _ in
                                    DispatchQueue.main.async {
                                        strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
                                    }
                                }
                            }
                        case .failure:
                            break
                        }
                        contractsProcessed += 1
                        if contractsProcessed == contracts.count {
                            completion()
                        }
                    }
                case .erc721:
                    //Handled in TokensDataStore.refreshBalanceForERC721Tokens()
                    break
                case .erc721ForTickets:
                    //Handled in TokensDataStore.refreshBalanceForNonERC721TicketTokens()
                    break
                case .nativeCryptocurrency:
                    break
                }
            }

        }
    }

    func autoDetectTokensOperation(forServer server: RPCServer, wallet: AlphaWallet.Address, tokens: [(name: String, contract: AlphaWallet.Address)]) -> Operation {
        AutoDetectTokensOperation(forServer: server, provider: self, wallet: wallet, tokens: tokens)
    }

    func autoDetectTransactedTokensOperation(forServer server: RPCServer, wallet: AlphaWallet.Address) -> Operation {
        AutoDetectTransactedTokensOperation(forServer: server, provider: self, wallet: wallet)
    }

    private class AutoDetectTokensOperation: Operation {
        private weak var provider: AutodetectTokensProvider?
        private let wallet: AlphaWallet.Address
        private let tokens: [(name: String, contract: AlphaWallet.Address)]
        override var isExecuting: Bool {
            return provider?.isAutoDetectingTokens ?? false
        }
        override var isFinished: Bool {
            return !isExecuting
        }
        override var isAsynchronous: Bool {
            return true
        }
        private let server: RPCServer

        init(forServer server: RPCServer, provider: AutodetectTokensProvider, wallet: AlphaWallet.Address, tokens: [(name: String, contract: AlphaWallet.Address)]) {
            self.provider = provider
            self.wallet = wallet
            self.tokens = tokens
            self.server = server
            super.init()
            self.queuePriority = server.networkRequestsQueuePriority
        }

        override func main() {
            guard let strongProvider = provider else { return }

            strongProvider.autoDetectTokensImpl(withContracts: tokens, server: server) { [weak self, weak provider] in
                guard let strongSelf = self, let strongProvider = provider else { return }

                strongSelf.willChangeValue(forKey: "isExecuting")
                strongSelf.willChangeValue(forKey: "isFinished")

                strongProvider.isAutoDetectingTokens = false

                strongSelf.didChangeValue(forKey: "isExecuting")
                strongSelf.didChangeValue(forKey: "isFinished")
            }
        } 
    }

    private class AutoDetectTransactedTokensOperation: Operation {
        private weak var provider: AutodetectTokensProvider?
        private let wallet: AlphaWallet.Address
        private let server: RPCServer

        override var isExecuting: Bool {
            return provider?.isAutoDetectingTransactedTokens ?? false
        }

        override var isFinished: Bool {
            return !isExecuting
        }

        override var isAsynchronous: Bool {
            return true
        }

        init(forServer server: RPCServer, provider: AutodetectTokensProvider, wallet: AlphaWallet.Address) {
            self.provider = provider
            self.wallet = wallet
            self.server = server
            super.init()
            self.queuePriority = server.networkRequestsQueuePriority
        }

        override func main() {
            guard let strongProvider = provider else { return }

            let fetchErc20Tokens = strongProvider.autoDetectTransactedTokensImpl(wallet: wallet, server: server, erc20: true)
            let fetchNonErc20Tokens = strongProvider.autoDetectTransactedTokensImpl(wallet: wallet, server: server, erc20: false)

            when(fulfilled: [fetchErc20Tokens, fetchNonErc20Tokens]).done { [weak self, weak provider] _ in
                guard let strongSelf = self, let strongProvider = provider else { return }

                strongSelf.willChangeValue(forKey: "isExecuting")
                strongSelf.willChangeValue(forKey: "isFinished")
                strongProvider.isAutoDetectingTransactedTokens = false
                strongSelf.didChangeValue(forKey: "isExecuting")
                strongSelf.didChangeValue(forKey: "isFinished")
            }.cauterize()
        }
    }
}
