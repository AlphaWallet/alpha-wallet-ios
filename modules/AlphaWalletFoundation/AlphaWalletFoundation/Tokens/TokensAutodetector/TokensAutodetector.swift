//
//  TokensAutodetector.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import AlphaWalletCore
import Combine

public protocol TokensAutodetector: NSObjectProtocol {
    var tokensOrContractsDetected: AnyPublisher<[TokenOrContract], Never> { get }

    func start()
}

enum Eip20TokenType {
    case erc20
    case erc721
    case erc1155
}

public class SingleChainTokensAutodetector: NSObject, TokensAutodetector {
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private let session: WalletSession
    private let queue = DispatchQueue(label: "org.alphawallet.swift.tokensAutoDetection")
    private let importToken: TokenImportable & TokenOrContractFetchable
    private let tokensDataStore: TokensDataStore
    private let tokensOrContractsDetectedSubject = PassthroughSubject<[TokenOrContract], Never>()
    private let contractToImportStorage: ContractToImportStorage
    public var tokensOrContractsDetected: AnyPublisher<[TokenOrContract], Never> {
        tokensOrContractsDetectedSubject.eraseToAnyPublisher()
    }
    var isAutoDetectingTransactedTokens = false
    var isAutoDetectingTokens = false

    init(session: WalletSession,
         contractToImportStorage: ContractToImportStorage,
         tokensDataStore: TokensDataStore,
         withAutoDetectTransactedTokensQueue autoDetectTransactedTokensQueue: OperationQueue,
         withAutoDetectTokensQueue autoDetectTokensQueue: OperationQueue,
         importToken: TokenImportable & TokenOrContractFetchable) {

        self.contractToImportStorage = contractToImportStorage
        self.importToken = importToken
        self.session = session
        self.tokensDataStore = tokensDataStore
        self.autoDetectTransactedTokensQueue = autoDetectTransactedTokensQueue
        self.autoDetectTokensQueue = autoDetectTokensQueue
    }

    public func start() {
        //TODO we don't auto detect tokens if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
        guard !isRunningTests() else { return }

        //Since this is called at launch, we don't want it to block launching
        queue.async { [weak self] in
            self?.autoDetectTransactedTokens()
            self?.autoDetectPartnerTokens()
        }
    }

    ///Implementation: We refresh once only, after all the auto detected tokens' data have been pulled because each refresh pulls every tokens' (including those that already exist before the this auto detection) price as well as balance, placing heavy and redundant load on the device. After a timeout, we refresh once just in case it took too long, so user at least gets the chance to see some auto detected tokens
    private func autoDetectTransactedTokens() {
        guard !session.config.development.isAutoFetchingDisabled else { return }
        guard !isAutoDetectingTransactedTokens else { return }

        isAutoDetectingTransactedTokens = true
        let operation = AutoDetectTransactedTokensOperation(server: session.server, wallet: session.account, delegate: self)
        autoDetectTransactedTokensQueue.addOperation(operation)
    }

    private func contractsForTransactedTokens(detectedContracts: [AlphaWallet.Address], forServer server: RPCServer) -> [AlphaWallet.Address] {
        let alreadyAddedContracts = tokensDataStore.tokens(for: [server]).map { $0.contractAddress }
        let deletedContracts = tokensDataStore.deletedContracts(forServer: server).map { $0.contractAddress }
        let hiddenContracts = tokensDataStore.hiddenContracts(forServer: server).map { $0.contractAddress }
        let delegateContracts = tokensDataStore.delegateContracts(forServer: server).map { $0.contractAddress }

        return detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts
    }

    internal func autoDetectTransactedContractsImpl(wallet: AlphaWallet.Address, erc20: Bool, server: RPCServer) -> AnyPublisher<[AlphaWallet.Address], Never> {
        let startBlock: Int?
        if erc20 {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        } else {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        }

        func publisher(erc20: Bool, startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
            if erc20 {
                return session.apiNetworking.erc20TokenInteractions(walletAddress: wallet, startBlock: startBlock)
            } else {
                return session.apiNetworking.erc721TokenInteractions(walletAddress: wallet, startBlock: startBlock)
            }
        }

        return publisher(erc20: erc20, startBlock: startBlock)
            .map { data -> [AlphaWallet.Address] in
                if let maxBlockNumber = data.maxBlockNumber {
                    if erc20 {
                        Config.setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(maxBlockNumber, server: server, wallet: wallet)
                    } else {
                        Config.setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(maxBlockNumber, server: server, wallet: wallet)
                    }
                }

                return data.uniqueNonEmptyContracts
            }.replaceError(with: [])
            .eraseToAnyPublisher()
    }

    private func autoDetectTransactedTokensImpl(wallet: AlphaWallet.Address, erc20: Bool) -> AnyPublisher<[TokenOrContract], Never> {
        let server = session.server

        return autoDetectTransactedContractsImpl(wallet: wallet, erc20: erc20, server: server)
            .flatMap { [importToken, queue, weak self] detectedContracts -> AnyPublisher<[TokenOrContract], Never> in
                guard let strongSelf = self else { return .empty() }
                let publishers = strongSelf.contractsForTransactedTokens(detectedContracts: detectedContracts, forServer: server)
                    .map { importToken.fetchTokenOrContract(for: $0, onlyIfThereIsABalance: false).mapToResult() }

                return Publishers.MergeMany(publishers).collect()
                    .map { $0.compactMap { try? $0.get() } }
                    .receive(on: queue)
                    .eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    private func autoDetectPartnerTokens() {
        guard !isRunningTests() else { return }
        guard !session.config.development.isAutoFetchingDisabled, !contractToImportStorage.contractsToDetect.isEmpty else { return }
        guard !isAutoDetectingTokens else { return }
        isAutoDetectingTokens = true

        let operation = AutoDetectTokensOperation(server: session.server, delegate: self, tokens: contractToImportStorage.contractsToDetect)
        autoDetectTokensQueue.addOperation(operation)
    }

    private func contractsToAutodetectTokens(contractsToDetect: [ContractToImport]) -> [ContractToImport] {
        return contractsToDetect.filter {
            !tokensDataStore.tokens(for: [$0.server]).map { $0.contractAddress }.contains($0.contract) &&
            !tokensDataStore.deletedContracts(forServer: $0.server).map { $0.contractAddress }.contains($0.contract) &&
            !tokensDataStore.hiddenContracts(forServer: $0.server).map { $0.contractAddress }.contains($0.contract)
        }
    }
}

extension SingleChainTokensAutodetector: AutoDetectTransactedTokensOperationDelegate {
    public func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> AnyPublisher<[TokenOrContract], Never> {
        let fetchErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: true)
        let fetchNonErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: false)

        return Publishers.CombineLatest(fetchErc20Tokens, fetchNonErc20Tokens)
            .map { $0.0 + $0.1 }
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }
}

extension SingleChainTokensAutodetector: AutoDetectTokensOperationDelegate {

    func autoDetectTokensImpl(withContracts contractsToDetect: [ContractToImport]) -> AnyPublisher<[TokenOrContract], Never> {
        let publishers = contractsToAutodetectTokens(contractsToDetect: contractsToDetect)
            .map { importToken.fetchTokenOrContract(for: $0.contract, onlyIfThereIsABalance: $0.onlyIfThereIsABalance).mapToResult() }

        return Publishers.MergeMany(publishers).collect()
            .map { $0.compactMap { try? $0.get() } }
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    public func didDetect(tokensOrContracts: [TokenOrContract]) {
        tokensOrContractsDetectedSubject.send(tokensOrContracts)
    }
}
