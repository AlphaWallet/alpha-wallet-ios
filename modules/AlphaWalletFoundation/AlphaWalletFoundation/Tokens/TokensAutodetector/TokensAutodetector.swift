//
//  TokensAutodetector.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import AlphaWalletCore
import PromiseKit
import Combine

public protocol TokensAutodetector: NSObjectProtocol {
    var tokensOrContractsDetected: AnyPublisher<[TokenOrContract], Never> { get }

    func start()
}

public protocol DetectedContractsProvideble {
    /// Tokens contracts
    func alreadyAddedContracts(for server: RPCServer) -> [AlphaWallet.Address]
    /// Not using anymore, leave it to avoid migration fixing
    func deletedContracts(for server: RPCServer) -> [AlphaWallet.Address]
    /// Also seems like not supported
    func hiddenContracts(for server: RPCServer) -> [AlphaWallet.Address]
    /// Partially resolved token contracts
    func delegateContracts(for server: RPCServer) -> [AlphaWallet.Address]
}

public class SingleChainTokensAutodetector: NSObject, TokensAutodetector {
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private let session: WalletSession
    private let queue: DispatchQueue = DispatchQueue(label: "org.alphawallet.swift.tokensAutoDetection")
    private let importToken: ImportToken
    private let detectedTokens: DetectedContractsProvideble
    private let tokensOrContractsDetectedSubject = PassthroughSubject<[TokenOrContract], Never>()
    private let getContractInteractions = GetContractInteractions()

    public var tokensOrContractsDetected: AnyPublisher<[TokenOrContract], Never> {
        tokensOrContractsDetectedSubject.eraseToAnyPublisher()
    }
    public var isAutoDetectingTransactedTokens = false
    var isAutoDetectingTokens = false

    init(
            session: WalletSession,
            detectedTokens: DetectedContractsProvideble,
            withAutoDetectTransactedTokensQueue autoDetectTransactedTokensQueue: OperationQueue,
            withAutoDetectTokensQueue autoDetectTokensQueue: OperationQueue,
            importToken: ImportToken
    ) {
        self.importToken = importToken
        self.session = session
        self.detectedTokens = detectedTokens
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
        let operation = AutoDetectTransactedTokensOperation(session: session, delegate: self)
        autoDetectTransactedTokensQueue.addOperation(operation)
    }

    private func contractsForTransactedTokens(detectedContracts: [AlphaWallet.Address], forServer server: RPCServer) -> [AlphaWallet.Address] {
        let alreadyAddedContracts = detectedTokens.alreadyAddedContracts(for: server)
        let deletedContracts = detectedTokens.deletedContracts(for: server)
        let hiddenContracts = detectedTokens.hiddenContracts(for: server)
        let delegateContracts = detectedTokens.delegateContracts(for: server)

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
            getContractInteractions.getContractList(walletAddress: wallet, server: server, startBlock: startBlock, erc20: erc20)
        }.map(on: queue, { contracts, maxBlockNumber -> [AlphaWallet.Address] in
            if let maxBlockNumber = maxBlockNumber {
                if erc20 {
                    Config.setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(maxBlockNumber, server: server, wallet: wallet)
                } else {
                    Config.setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(maxBlockNumber, server: server, wallet: wallet)
                }
            }

            return contracts
        })
    }

    private func autoDetectTransactedTokensImpl(wallet: AlphaWallet.Address, erc20: Bool) -> Promise<[TokenOrContract]> {
        let server = session.server

        return firstly {
            autoDetectTransactedContractsImpl(wallet: wallet, erc20: erc20, server: server)
        }.then(on: queue, { [weak self, importToken, queue] detectedContracts -> Promise<[TokenOrContract]> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            let promises = strongSelf.contractsForTransactedTokens(detectedContracts: detectedContracts, forServer: server)
                .map { importToken.fetchTokenOrContract(for: $0, server: server, onlyIfThereIsABalance: false) }

            return when(resolved: promises)
                .map(on: queue, { $0.compactMap { $0.optionalValue } })
        })
    }

    //TODO consolidate with adding `Constants.uefaMainnet` which is done elsewhere
    private func autoDetectPartnerTokens() {
        guard !session.config.development.isAutoFetchingDisabled else { return }
        switch session.server.serverWithEnhancedSupport {
        case .main:
            autoDetectMainnetPartnerTokens()
        case .xDai:
            autoDetectXDaiPartnerTokens()
        case .rinkeby:
            autoDetectRinkebyPartnerTokens()
        case .candle, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            break
        }
    }

    private func autoDetectMainnetPartnerTokens() {
        autoDetectTokens(contractsToDetect: Constants.partnerContracts)
    }

    private func autoDetectXDaiPartnerTokens() {
        autoDetectTokens(contractsToDetect: Constants.ethDenverXDaiPartnerContracts)
    }

    private func autoDetectRinkebyPartnerTokens() {
        autoDetectTokens(contractsToDetect: Constants.rinkebyPartnerContracts)
    }

    private func autoDetectTokens(contractsToDetect: [(name: String, contract: AlphaWallet.Address)]) {
        guard !isAutoDetectingTokens else { return }

        isAutoDetectingTokens = true
        let operation = AutoDetectTokensOperation(session: session, delegate: self, tokens: contractsToDetect)
        autoDetectTokensQueue.addOperation(operation)
    }

    private func contractsToAutodetectTokens(contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer) -> [AlphaWallet.Address] {
        let alreadyAddedContracts = detectedTokens.alreadyAddedContracts(for: server)
        let deletedContracts = detectedTokens.deletedContracts(for: server)
        let hiddenContracts = detectedTokens.hiddenContracts(for: server)

        return contractsToDetect.map { $0.contract } - alreadyAddedContracts - deletedContracts - hiddenContracts
    }
}

extension SingleChainTokensAutodetector: AutoDetectTransactedTokensOperationDelegate {
    public func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> Promise<[TokenOrContract]> {
        let fetchErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: true)
        let fetchNonErc20Tokens = autoDetectTransactedTokensImpl(wallet: wallet, erc20: false)

        return when(resolved: [fetchErc20Tokens, fetchNonErc20Tokens]).map(on: queue, { results in
            return results.compactMap { $0.optionalValue }.flatMap { $0 }
        })
    }
}

extension SingleChainTokensAutodetector: AutoDetectTokensOperationDelegate {

    func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer) -> Promise<[TokenOrContract]> {
        let promises = contractsToAutodetectTokens(contractsToDetect: contractsToDetect, server: server)
            .map { importToken.fetchErc875OrErc20Token(for: $0, server: server) }

        return when(resolved: promises).map(on: queue, { results in
            return results.compactMap { $0.optionalValue }
        })
    }

    public func didDetect(tokensOrContracts: [TokenOrContract]) {
        let tokensOrContracts = tokensOrContracts.filter { tokenOrContract in
            switch tokenOrContract {
            case .delegateContracts, .deletedContracts, .nonFungibleToken, .token, .fungibleTokenComplete:
                return true
            case .none:
                return false
            }
        }

        tokensOrContractsDetectedSubject.send(tokensOrContracts)
    }

}
