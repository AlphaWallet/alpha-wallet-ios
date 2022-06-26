//
//  TokensAutodetector.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import AlphaWalletCore
import PromiseKit

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
    private let importToken: ImportToken
    private lazy var tokenProvider = TokenProvider(account: session.account, server: session.server)
    private lazy var erc875BalanceFetcher = GetErc875Balance(forServer: session.server, queue: queue)
    private lazy var erc20BalanceFetcher = GetErc20Balance(forServer: session.server, queue: queue)

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
            importToken: ImportToken
    ) {
        self.importToken = importToken
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
        let alreadyAddedContracts = tokensDataStore.enabledTokens(for: [server]).map { $0.contractAddress }
        let deletedContracts = tokensDataStore.deletedContracts(forServer: server).map { $0.address }
        let hiddenContracts = tokensDataStore.hiddenContracts(forServer: server).map { $0.address }
        let delegateContracts = tokensDataStore.delegateContracts(forServer: server).map { $0.address }

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

    private func autoDetectTransactedTokensImpl(wallet: AlphaWallet.Address, erc20: Bool) -> Promise<[TokenOrContract]> {
        let server = session.server

        return firstly {
            autoDetectTransactedContractsImpl(wallet: wallet, erc20: erc20, server: server)
        }.then(on: queue, { [weak self, importToken] detectedContracts -> Promise<[TokenOrContract]> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            let promises = strongSelf.contractsForTransactedTokens(detectedContracts: detectedContracts, forServer: server)
                .compactMap { contract -> Promise<TokenOrContract> in
                    importToken.fetchTokenOrContract(for: contract, server: server, onlyIfThereIsABalance: false)
                }

            return when(resolved: promises)
                .map(on: strongSelf.queue, { values -> [TokenOrContract] in
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
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .custom, .heco_testnet, .heco, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
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

        let alreadyAddedContracts = tokensDataStore.enabledTokens(for: [server]).map { $0.contractAddress }
        let deletedContracts = tokensDataStore.deletedContracts(forServer: server).map { $0.address }
        let hiddenContracts = tokensDataStore.hiddenContracts(forServer: server).map { $0.address }

        return contractsToDetect.map { $0.contract } - alreadyAddedContracts - deletedContracts - hiddenContracts
    }

    private func fetchCreateErc875OrErc20Token(forContract contract: AlphaWallet.Address, forServer server: RPCServer) -> Promise<TokenOrContract> {
        return tokenProvider.getTokenType(for: contract)
            .then(on: queue, { [session, importToken, erc875BalanceFetcher, erc20BalanceFetcher, queue] tokenType -> Promise<TokenOrContract> in
                switch tokenType {
                case .erc875:
                    //TODO long and very similar code below. Extract function
                    return erc875BalanceFetcher.getERC875TokenBalance(for: session.account.address, contract: contract).then(on: queue, { balance -> Promise<TokenOrContract> in
                        if balance.isEmpty {
                            return .value(.none)
                        } else {
                            return importToken.fetchTokenOrContract(for: contract, server: server, onlyIfThereIsABalance: false)
                        }
                    }).recover(on: queue, { _ -> Guarantee<TokenOrContract> in
                        return .value(.none)
                    })
                case .erc20:
                    return erc20BalanceFetcher.getBalance(for: session.account.address, contract: contract).then(on: queue, { balance -> Promise<TokenOrContract> in
                        if balance > 0 {
                            return importToken.fetchTokenOrContract(for: contract, server: server, onlyIfThereIsABalance: false)
                        } else {
                            return .value(.none)
                        }
                    }).recover(on: queue, { _ -> Guarantee<TokenOrContract> in
                        return .value(.none)
                    })
                case .erc721, .erc721ForTickets, .erc1155, .nativeCryptocurrency:
                    //Handled in PrivateBalanceFetcher.refreshBalanceForErc721Or1155Tokens()
                    return .value(.none)
                }
            })
    }
}

extension SingleChainTokensAutodetector: AutoDetectTransactedTokensOperationDelegate {

    func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> Promise<[TokenOrContract]> {
        let fetchErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: true)
        let fetchNonErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: false)

        return when(resolved: [fetchErc20Tokens, fetchNonErc20Tokens])
            .map(on: queue, { results in
                return results.compactMap { $0.optionalValue }.flatMap { $0 }
            })
    }
}

extension SingleChainTokensAutodetector: AutoDetectTokensOperationDelegate {

    func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer) -> Promise<[TokenOrContract]> {
        let promises = contractsToAutodetectTokens(withContracts: contractsToDetect, forServer: server)
            .map { each -> Promise<TokenOrContract> in
                return fetchCreateErc875OrErc20Token(forContract: each, forServer: server)
            }

        return when(resolved: promises)
            .map(on: queue, { results in
                return results.compactMap { $0.optionalValue }
            })
    }
}
