//
//  TokensAutodetector.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import PromiseKit

extension SingleChainTokensAutodetector {
    enum AddTokenObjectOperation {
        case ercToken(ERCToken)
        case tokenObject(TokenObject)
        case delegateContracts([DelegateContract])
        case deletedContracts([DeletedContract])
        ///We re-use the existing balance value to avoid the Wallets tab showing that token (if it already exist) as balance = 0 momentarily
        case fungibleTokenComplete(name: String, symbol: String, decimals: UInt8, contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool)
        case none
    }
}

protocol TokensAutodetector: NSObjectProtocol {
    func start()
}

class SingleChainTokensAutodetector: NSObject, TokensAutodetector {
    private let keystore: Keystore
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private let server: RPCServer
    private let config: Config
    private let account: Wallet
    private let queue: DispatchQueue
    private let tokenObjectFetcher: TokenObjectFetcher

    var isAutoDetectingTransactedTokens = false
    var isAutoDetectingTokens = false

    init(
            account: Wallet,
            server: RPCServer,
            config: Config,
            keystore: Keystore,
            tokensDataStore: TokensDataStore,
            assetDefinitionStore: AssetDefinitionStore,
            withAutoDetectTransactedTokensQueue autoDetectTransactedTokensQueue: OperationQueue,
            withAutoDetectTokensQueue autoDetectTokensQueue: OperationQueue,
            queue: DispatchQueue,
            tokenObjectFetcher: TokenObjectFetcher
    ) {
        self.tokenObjectFetcher = tokenObjectFetcher
        self.queue = queue
        self.account = account
        self.server = server
        self.config = config
        self.keystore = keystore
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
        self.autoDetectTransactedTokensQueue = autoDetectTransactedTokensQueue
        self.autoDetectTokensQueue = autoDetectTokensQueue
    }

    func start() {
        //Since this is called at launch, we don't want it to block launching
        queue.async { [weak self] in
            self?.autoDetectTransactedTokens()
            self?.autoDetectPartnerTokens()
        }
    }

    ///Implementation: We refresh once only, after all the auto detected tokens' data have been pulled because each refresh pulls every tokens' (including those that already exist before the this auto detection) price as well as balance, placing heavy and redundant load on the device. After a timeout, we refresh once just in case it took too long, so user at least gets the chance to see some auto detected tokens
    private func autoDetectTransactedTokens() {
        //TODO we don't auto detect tokens if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
        guard !isRunningTests() else { return }
        guard !config.development.isAutoFetchingDisabled else { return }
        guard !isAutoDetectingTransactedTokens else { return }

        isAutoDetectingTransactedTokens = true
        let operation = AutoDetectTransactedTokensOperation(forServer: server, delegate: self, wallet: keystore.currentWallet.address)
        autoDetectTransactedTokensQueue.addOperation(operation)
    }

    private func contractsForTransactedTokens(detectedContracts: [AlphaWallet.Address], forServer server: RPCServer) -> Promise<[AlphaWallet.Address]> {
        return Promise { seal in
            DispatchQueue.main.async { [weak tokensDataStore] in
                guard let tokensDataStore = tokensDataStore else { seal.reject(PMKError.cancelled); return }

                let alreadyAddedContracts = tokensDataStore.enabledTokenObjects(forServers: [server]).map { $0.contractAddress }
                let deletedContracts = tokensDataStore.deletedContracts(forServer: server).map { $0.contractAddress }
                let hiddenContracts = tokensDataStore.hiddenContracts(forServer: server).map { $0.contractAddress }
                let delegateContracts = tokensDataStore.delegateContracts(forServer: server).map { $0.contractAddress }
                let contractsToAdd = detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts

                seal.fulfill(contractsToAdd)
            }
        }
    }

    internal func autoDetectTransactedContractsImpl(wallet: AlphaWallet.Address, erc20: Bool) -> Promise<[AlphaWallet.Address]> {
        let startBlock: Int?
        if erc20 {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        } else {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        }

        return firstly {
            GetContractInteractions(queue: queue)
                .getContractList(address: wallet, server: server, startBlock: startBlock, erc20: erc20)
        }.then(on: queue) { [weak self] contracts, maxBlockNumber -> Promise<[AlphaWallet.Address]> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            if let maxBlockNumber = maxBlockNumber {
                if erc20 {
                    Config.setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(maxBlockNumber, server: strongSelf.server, wallet: wallet)
                } else {
                    Config.setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(maxBlockNumber, server: strongSelf.server, wallet: wallet)
                }
            }
            //NOTE: Guard safe to protect tokens data store with writing tokens from different user, in case when autodetector stays in memory
            let currentAddress = strongSelf.keystore.currentWallet.address
            guard currentAddress.sameContract(as: wallet) else { return .init(error: PMKError.cancelled) }

            return .value(contracts)
        }
    }

    private func autoDetectTransactedTokensImpl(wallet: AlphaWallet.Address, erc20: Bool) -> Promise<[SingleChainTokensAutodetector.AddTokenObjectOperation]> {
        let server = server

        return firstly {
            autoDetectTransactedContractsImpl(wallet: wallet, erc20: erc20)
        }.then(on: queue, { [weak self] detectedContracts -> Promise<[AlphaWallet.Address]> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }
            return strongSelf.contractsForTransactedTokens(detectedContracts: detectedContracts, forServer: server)
        }).then(on: queue, { [weak self] contractsToAdd -> Promise<[SingleChainTokensAutodetector.AddTokenObjectOperation]> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            let promises = contractsToAdd.compactMap { contract -> Promise<AddTokenObjectOperation> in
                strongSelf.tokenObjectFetcher.fetchTokenObject(for: contract, onlyIfThereIsABalance: false)
            }

            return when(resolved: promises).map(on: .main, { values -> [SingleChainTokensAutodetector.AddTokenObjectOperation] in
                let values = values.compactMap { $0.optionalValue }
                strongSelf.tokensDataStore.addTokenObjects(values: values)

                return values
            })
        })
    }

    private func autoDetectPartnerTokens() {
        guard !config.development.isAutoFetchingDisabled else { return }
        switch server {
        case .main:
            autoDetectMainnetPartnerTokens()
        case .xDai:
            autoDetectXDaiPartnerTokens()
        case .rinkeby:
            autoDetectRinkebyPartnerTokens()
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .custom, .heco_testnet, .heco, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            break
        }
    }

    private func autoDetectMainnetPartnerTokens() {
        autoDetectTokens(withContracts: Constants.partnerContracts)
    }

    private func autoDetectXDaiPartnerTokens() {
        autoDetectTokens(withContracts: Constants.ethDenverXDaiPartnerContracts)
    }

    private func autoDetectRinkebyPartnerTokens() {
        autoDetectTokens(withContracts: Constants.rinkebyPartnerContracts)
    }

    private func autoDetectTokens(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)]) {
        guard !isAutoDetectingTokens else { return }

        let address = keystore.currentWallet.address
        isAutoDetectingTokens = true
        let operation = AutoDetectTokensOperation(forServer: server, delegate: self, wallet: address, tokens: contractsToDetect)
        autoDetectTokensQueue.addOperation(operation)
    }

    private func contractsToAutodetectTokens(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], forServer server: RPCServer) -> Promise<[AlphaWallet.Address]> {
        return Promise { seal in
            DispatchQueue.main.async { [weak tokensDataStore] in
                guard let tokensDataStore = tokensDataStore else { return }

                let alreadyAddedContracts = tokensDataStore.enabledTokenObjects(forServers: [server]).map { $0.contractAddress }
                let deletedContracts = tokensDataStore.deletedContracts(forServer: server).map { $0.contractAddress }
                let hiddenContracts = tokensDataStore.hiddenContracts(forServer: server).map { $0.contractAddress }

                seal.fulfill(contractsToDetect.map { $0.contract } - alreadyAddedContracts - deletedContracts - hiddenContracts)
            }
        }
    }

    private func fetchCreateErc875OrErc20Token(forContract contract: AlphaWallet.Address, forServer server: RPCServer) -> Promise<AddTokenObjectOperation> {
        let account = keystore.currentWallet
        let accountAddress = account.address
        let queue = queue

        return TokenProvider(account: account, server: server)
            .getTokenType(for: contract)
            .then { [weak tokenObjectFetcher] tokenType -> Promise<AddTokenObjectOperation> in
                guard let tokenObjectFetcher = tokenObjectFetcher else { return .init(error: PMKError.cancelled) }

                switch tokenType {
                case .erc875:
                    //TODO long and very similar code below. Extract function
                    let balanceCoordinator = GetERC875BalanceCoordinator(forServer: server, queue: queue)
                    return balanceCoordinator.getERC875TokenBalance(for: accountAddress, contract: contract).then { balance -> Promise<AddTokenObjectOperation> in
                        if balance.isEmpty {
                            return .value(.none)
                        } else {
                            return tokenObjectFetcher.fetchTokenObject(for: contract, onlyIfThereIsABalance: false)
                        }
                    }.recover { _ -> Guarantee<AddTokenObjectOperation> in
                        return .value(.none)
                    }
                case .erc20:
                    let balanceCoordinator = GetERC20BalanceCoordinator(forServer: server, queue: queue)
                    return balanceCoordinator.getBalance(for: accountAddress, contract: contract).then { balance -> Promise<AddTokenObjectOperation> in
                        if balance > 0 {
                            return tokenObjectFetcher.fetchTokenObject(for: contract, onlyIfThereIsABalance: false)
                        } else {
                            return .value(.none)
                        }
                    }.recover { _ -> Guarantee<AddTokenObjectOperation> in
                        return .value(.none)
                    }
                case .erc721, .erc721ForTickets, .erc1155, .nativeCryptocurrency:
                    //Handled in PrivateBalanceFetcher.refreshBalanceForErc721Or1155Tokens()
                    return .value(.none)
                }
            }
    }
}

extension SingleChainTokensAutodetector: AutoDetectTransactedTokensOperationDelegate {

    func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> Promise<Void> {
        let fetchErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: true)
        let fetchNonErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: false)

        return when(resolved: [fetchErc20Tokens, fetchNonErc20Tokens])
            .then(on: .main, { [weak tokensDataStore] operations -> Promise<Void> in
                guard let tokensDataStore = tokensDataStore else { return .init(error: PMKError.cancelled) }

                let values = operations.compactMap { $0.optionalValue }.flatMap { $0 }
                tokensDataStore.addTokenObjects(values: values)

                return .init()
            })
    }
}

extension SingleChainTokensAutodetector: AutoDetectTokensOperationDelegate {

    func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer) -> Promise<Void> {
        let server = server
        let queue = queue

        return contractsToAutodetectTokens(withContracts: contractsToDetect, forServer: server)
            .then(on: queue, { contracts -> Promise<[AddTokenObjectOperation]> in
                let promises = contracts.map { each -> Promise<AddTokenObjectOperation> in
                    return self.fetchCreateErc875OrErc20Token(forContract: each, forServer: server)
                }

                return when(resolved: promises).map(on: queue, { results -> [AddTokenObjectOperation] in
                    return results.compactMap { $0.optionalValue }
                })
            }).then(on: .main, { [weak tokensDataStore] values -> Promise<Void> in
                guard let tokensDataStore = tokensDataStore else { return .init(error: PMKError.cancelled) }
                tokensDataStore.addTokenObjects(values: values)

                return .init()
            }).asVoid()
    }
}
