//
//  TokensAutodetector.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import AlphaWalletCore
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

        var addressAndRPCServer: AddressAndRPCServer? {
            switch self {
            case .ercToken(let eRCToken):
                return .init(address: eRCToken.contract, server: eRCToken.server)
            case .tokenObject(let tokenObject):
                return .init(address: tokenObject.contractAddress, server: tokenObject.server)
            case .delegateContracts, .deletedContracts, .none:
                return nil
            case .fungibleTokenComplete(_, _, _, let contract, let server, _):
                return .init(address: contract, server: server)
            }
        }
    }

}

protocol TokensAutodetector: NSObjectProtocol {
    func start()
}

class SingleChainTokensAutodetector: NSObject, TokensAutodetector {
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private let config: Config
    private let session: WalletSession
    private let queue: DispatchQueue
    private let tokenObjectFetcher: TokenObjectFetcher

    var isAutoDetectingTransactedTokens = false
    var isAutoDetectingTokens = false

    init(
            session: WalletSession,
            config: Config,
            tokensDataStore: TokensDataStore,
            assetDefinitionStore: AssetDefinitionStore,
            withAutoDetectTransactedTokensQueue autoDetectTransactedTokensQueue: OperationQueue,
            withAutoDetectTokensQueue autoDetectTokensQueue: OperationQueue,
            queue: DispatchQueue,
            tokenObjectFetcher: TokenObjectFetcher
    ) {
        self.tokenObjectFetcher = tokenObjectFetcher
        self.queue = queue
        self.session = session
        self.config = config
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
        let operation = AutoDetectTransactedTokensOperation(session: session, tokensDataStore: tokensDataStore, delegate: self)
        autoDetectTransactedTokensQueue.addOperation(operation)
    }

    private func contractsForTransactedTokens(detectedContracts: [AlphaWallet.Address], forServer server: RPCServer) -> [AlphaWallet.Address] {
        let alreadyAddedContracts = tokensDataStore.enabledTokenObjects(forServers: [server]).map { $0.contractAddress }
        let deletedContracts = tokensDataStore.deletedContracts(forServer: server).map { $0.contractAddress }
        let hiddenContracts = tokensDataStore.hiddenContracts(forServer: server).map { $0.contractAddress }
        let delegateContracts = tokensDataStore.delegateContracts(forServer: server).map { $0.contractAddress }

        return detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts
    }

    internal func autoDetectTransactedContractsImpl(wallet: AlphaWallet.Address, erc20: Bool, server: RPCServer) -> Promise<[AlphaWallet.Address]> {
        let startBlock: Int?
        if erc20 {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        } else {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        }

        return firstly {
            GetContractInteractions(queue: queue)
                .getContractList(walletAddress: wallet, server: server, startBlock: startBlock, erc20: erc20)
        }.map(on: queue) { contracts, maxBlockNumber -> [AlphaWallet.Address] in
            if let maxBlockNumber = maxBlockNumber {
                if erc20 {
                    Config.setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(maxBlockNumber, server: server, wallet: wallet)
                } else {
                    Config.setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(maxBlockNumber, server: server, wallet: wallet)
                }
            }

            return contracts
        }
    }

    private func autoDetectTransactedTokensImpl(wallet: AlphaWallet.Address, erc20: Bool) -> Promise<[SingleChainTokensAutodetector.AddTokenObjectOperation]> {
        let server = session.server

        return firstly {
            autoDetectTransactedContractsImpl(wallet: wallet, erc20: erc20, server: server)
        }.then(on: queue, { [weak self] detectedContracts -> Promise<[SingleChainTokensAutodetector.AddTokenObjectOperation]> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            let promises = strongSelf.contractsForTransactedTokens(detectedContracts: detectedContracts, forServer: server)
                .compactMap { contract -> Promise<AddTokenObjectOperation> in
                    strongSelf.tokenObjectFetcher.fetchTokenObject(for: contract, onlyIfThereIsABalance: false)
                }

            return when(resolved: promises)
                .map(on: strongSelf.queue, { values -> [SingleChainTokensAutodetector.AddTokenObjectOperation] in
                    return values.compactMap { $0.optionalValue }
                })
        })
    }

    private func autoDetectPartnerTokens() {
        guard !config.development.isAutoFetchingDisabled else { return }
        switch session.server {
        case .main:
            autoDetectMainnetPartnerTokens()
        case .xDai:
            autoDetectXDaiPartnerTokens()
        case .rinkeby:
            autoDetectRinkebyPartnerTokens()
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .custom, .heco_testnet, .heco, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet:
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

        isAutoDetectingTokens = true
        let operation = AutoDetectTokensOperation(session: session, tokensDataStore: tokensDataStore, delegate: self, tokens: contractsToDetect)
        autoDetectTokensQueue.addOperation(operation)
    }

    private func contractsToAutodetectTokens(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], forServer server: RPCServer) -> [AlphaWallet.Address] {

        let alreadyAddedContracts = tokensDataStore.enabledTokenObjects(forServers: [server]).map { $0.contractAddress }
        let deletedContracts = tokensDataStore.deletedContracts(forServer: server).map { $0.contractAddress }
        let hiddenContracts = tokensDataStore.hiddenContracts(forServer: server).map { $0.contractAddress }

        return contractsToDetect.map { $0.contract } - alreadyAddedContracts - deletedContracts - hiddenContracts
    }

    private func fetchCreateErc875OrErc20Token(forContract contract: AlphaWallet.Address, forServer server: RPCServer) -> Promise<AddTokenObjectOperation> {
        let accountAddress = session.account.address
        let queue = queue

        return TokenProvider(account: session.account, server: server)
            .getTokenType(for: contract)
            .then(on: queue, { [weak tokenObjectFetcher] tokenType -> Promise<AddTokenObjectOperation> in
                guard let tokenObjectFetcher = tokenObjectFetcher else { return .init(error: PMKError.cancelled) }

                switch tokenType {
                case .erc875:
                    //TODO long and very similar code below. Extract function
                    let balanceCoordinator = GetErc875Balance(forServer: server, queue: queue)
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
                    let balanceCoordinator = GetErc20Balance(forServer: server, queue: queue)
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
            })
    }
}

extension SingleChainTokensAutodetector: AutoDetectTransactedTokensOperationDelegate {

    func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> Promise<[SingleChainTokensAutodetector.AddTokenObjectOperation]> {
        let fetchErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: true)
        let fetchNonErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: false)

        return when(resolved: [fetchErc20Tokens, fetchNonErc20Tokens])
            .map(on: queue, { results in
                return results.compactMap { $0.optionalValue }.flatMap { $0 }
            })
    }
}

extension SingleChainTokensAutodetector: AutoDetectTokensOperationDelegate {

    func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer) -> Promise<[SingleChainTokensAutodetector.AddTokenObjectOperation]> {
        let promises = contractsToAutodetectTokens(withContracts: contractsToDetect, forServer: server)
            .map { each -> Promise<AddTokenObjectOperation> in
                return fetchCreateErc875OrErc20Token(forContract: each, forServer: server)
            }

        return when(resolved: promises)
            .map(on: queue, { results in
                return results.compactMap { $0.optionalValue }
            })
    }
}
