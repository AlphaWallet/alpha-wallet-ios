//
//  ImportMagicLinkController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.01.2023.
//

import Foundation
import BigInt
import Combine
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletWeb3

// swiftlint:disable type_body_length
final class ImportMagicLinkController {
    private enum TransactionType {
        case freeTransfer(request: ImportMagicLinkNetworking.FreeTransferRequest)
        case paid(signedOrder: SignedOrder, token: Token)
    }

    private var wallet: Wallet { session.account }
    private var hasCompleted = false
    //TODO: better to make sure tokenHolder is non-optional. But be careful that ImportMagicTokenViewController also handles when viewModel always has a TokenHolder. Needs good defaults in TokenHolder that can be displayed
    private var tokenHolder: TokenHolder?
    private var count: Decimal?
    private var transactionType: TransactionType?
    private let assetDefinitionStore: AssetDefinitionStore
    private let keystore: Keystore
    private var isNotProcessingYet: Bool {
        switch viewStateSubject.value.state {
        case .validating, .promptImport:
            return true
        case .processing, .succeeded, .failed:
            return false
        }
    }

    private var server: RPCServer { return session.server }

    private let tokensService: TokensProcessingPipeline
    private let session: WalletSession
    private let networking: ImportMagicLinkNetworking
    private var signedOrder: SignedOrder?
    private let importToken: TokenImportable & TokenOrContractFetchable
    private let displayViewSubject = PassthroughSubject<Void, Never>()
    private let claimPaidSignedOrderSubject = PassthroughSubject<(signedOrder: SignedOrder, token: Token), Never>()
    private let viewStateSubject: CurrentValueSubject<ViewState, Never> = .init(.init(state: .validating))
    private var canHandleNotEnoughEthForPaidImport: Bool = true
    private let reachability: ReachabilityManagerProtocol

    var claimPaidSignedOrderPublisher: AnyPublisher<(signedOrder: SignedOrder, token: Token), Never> {
        claimPaidSignedOrderSubject.eraseToAnyPublisher()
    }

    var displayViewPublisher: AnyPublisher<Void, Never> {
        displayViewSubject.eraseToAnyPublisher()
    }

    var viewStatePublisher: AnyPublisher<ImportMagicLinkController.ViewState, Never> {
        viewStateSubject.eraseToAnyPublisher()
    }

    init(session: WalletSession,
         assetDefinitionStore: AssetDefinitionStore,
         keystore: Keystore,
         tokensService: TokensProcessingPipeline,
         networkService: NetworkService,
         importToken: TokenImportable & TokenOrContractFetchable,
         reachability: ReachabilityManagerProtocol) {

        self.reachability = reachability
        self.importToken = importToken
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
        self.networking = ImportMagicLinkNetworking(networkService: networkService)
        self.keystore = keystore
        self.tokensService = tokensService
    }

    func start(url: URL) -> Bool {
        return handleMagicLink(url: url)
    }

    func completeClaimPaidSignedOrder(with result: Swift.Result<ConfirmResult, Error>) {
        switch result {
        case .failure:
            showImportError(errorMessage: R.string.localizable.aClaimTokenFailedTitle())
        case .success:
            guard let signedOrder = signedOrder else { return }
            importToken(contract: signedOrder.order.contractAddress)
            showImportSuccessful()
        }
    }

    func process() {
        guard let transactionType = transactionType else { return }
        switch transactionType {
        case .freeTransfer(let request):
            importFreeTransfer(request: request)
        case .paid(let signedOrder, let token):
            self.signedOrder = signedOrder
            claimPaidSignedOrderSubject.send((signedOrder, token))
        }
    }

    private func handlePaidImportsImpl(signedOrder: SignedOrder, balance: BalanceViewModel) {
        if canHandleNotEnoughEthForPaidImport {
            //TODO: we might not need to pass a TokenObject. Maybe something simpler? Especially since name and symbol is unused
            //TODO: not always ERC875
            let token = Token(
                contract: signedOrder.order.contractAddress,
                server: server,
                name: "",
                symbol: "",
                decimals: 0,
                value: signedOrder.order.price,
                isCustom: true,
                isDisabled: false,
                type: .erc875)

            transactionType = .paid(signedOrder: signedOrder, token: token)

            let ethCost = ImportMagicLinkController.functional.convert(ethCost: signedOrder.order.price)
            promptImportUniversalLink(cost: .paid(eth: ethCost, dollar: nil))

            canHandleNotEnoughEthForPaidImport = false
        }

        guard let price = balance.ticker?.price_usd else { return }

        let (ethCost, dollarCost) = ImportMagicLinkController.functional.convert(ethCost: signedOrder.order.price, rate: price)
        //We should not prompt with an updated price if we are already processing or beyond that. Because this will revert the state back
        if isNotProcessingYet {
            promptImportUniversalLink(cost: .paid(eth: ethCost, dollar: dollarCost))
        }
    }

    private func usePaymentServerForFreeTransferLinks(signedOrder: SignedOrder) {
        let request = ImportMagicLinkNetworking.FreeTransferRequest(signedOrder: signedOrder, wallet: wallet, server: server)
        transactionType = .freeTransfer(request: request)
        promptImportUniversalLink(cost: .free)
    }

    func completeOrderHandling(signedOrder: SignedOrder) {
        let requiresPaymaster = ImportMagicLinkController.functional.requiresPaymasterForCurrencyLinks(signedOrder: signedOrder, server: server)
        if signedOrder.order.price == 0 {
            networking.checkPaymentServerSupportsContract(contractAddress: signedOrder.order.contractAddress)
                .sinkAsync(receiveCompletion: { _ in

                }, receiveValue: { [weak self] supported in
                    guard let strongSelf = self else { return }

                    //Currency links on mainnet/classic/xdai without a paymaster should be rejected for security reasons (front running)
                    guard supported || !requiresPaymaster else {
                        strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedServerDown())
                        return
                    }
                    if supported {
                        strongSelf.usePaymentServerForFreeTransferLinks(signedOrder: signedOrder)
                    } else {
                        strongSelf.handlePaidImports(signedOrder: signedOrder)
                    }
                })
        } else {
            handlePaidImports(signedOrder: signedOrder)
        }
    }

    private func handleSpawnableLink(signedOrder: SignedOrder, tokens: [BigUInt]) {
        let tokenStrings: [String] = tokens.map { String($0, radix: 16) }
        makeTokenHolder(tokenStrings, signedOrder.order.contractAddress)
        completeOrderHandling(signedOrder: signedOrder)
    }

    private func handleNativeCurrencyDrop(signedOrder: SignedOrder) {
        let amt: Decimal
        let szabosPerEth: Decimal = Decimal(EthereumUnit.ether.rawValue / EthereumUnit.szabo.rawValue)
        //TODO: should be better to put this into the tokenCount that is displayed in green
        if let amount = Decimal(string: signedOrder.order.count.description) {
            amt = amount / szabosPerEth
        } else {
            amt = 0
        }
        count = amt
        let token = TokenScript.Token(
            tokenIdOrEvent: .tokenId(tokenId: 0),
            tokenType: TokenType.nativeCryptocurrency,
            index: 0,
            name: server.symbol,
            symbol: "",
            status: .available,
            values: [:])

        tokenHolder = TokenHolder(tokens: [token], contractAddress: signedOrder.order.contractAddress, hasAssetDefinition: false)

        let r = signedOrder.signature.substring(with: Range(uncheckedBounds: (2, 66)))
        networking.checkIfLinkClaimed(r: r)
            .sinkAsync(receiveValue: { [weak self] claimed in
                if claimed {
                    self?.showImportError(errorMessage: R.string.localizable.aClaimTokenLinkAlreadyRedeemed())
                } else {
                    self?.completeOrderHandling(signedOrder: signedOrder)
                }
            })
    }

    private func handleNormalLinks(signedOrder: SignedOrder, recoverAddress: AlphaWallet.Address, contractAsAddress: AlphaWallet.Address) {
        session.tokenProvider
            .getErc875TokenBalance(for: recoverAddress, contract: contractAsAddress)
            .sinkAsync(receiveCompletion: { [weak self, reachability] _ in
                if !reachability.isReachable {
                    self?.showImportError(errorMessage: R.string.localizable.aClaimTokenNoConnectivityTryAgain())
                } else {
                    self?.showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
                }
            }, receiveValue: { [weak self] balance in
                let filteredTokens = ImportMagicLinkController.functional.checkErc875TokensAreAvailable(indices: signedOrder.order.indices, balance: balance)
                if filteredTokens.isEmpty {
                    self?.showImportError(errorMessage: R.string.localizable.aClaimTokenLinkAlreadyRedeemed())
                } else {
                    self?.makeTokenHolder(filteredTokens, signedOrder.order.contractAddress)
                    self?.completeOrderHandling(signedOrder: signedOrder)
                }
            })
    }

    private func handleMagicLink(url: URL) -> Bool {
        displayViewSubject.send(())

        let isLegacyLink = url.description.hasPrefix(Constants.legacyMagicLinkPrefix)
        let prefix: String
        if isLegacyLink {
            prefix = Constants.legacyMagicLinkPrefix
        } else {
            prefix = server.magicLinkPrefix.description
        }
        guard let signedOrder = UniversalLinkHandler(server: server).parseUniversalLink(url: url.absoluteString, prefix: prefix) else {
            showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
            return false
        }

        viewStateSubject.value.url = url
        viewStateSubject.value.contract = signedOrder.order.contractAddress

        if ImportMagicLinkController.functional.isOrderExpired(signedOrder) {
            showImportError(errorMessage: R.string.localizable.aClaimTokenLinkExpired())
            return true
        }

        guard let ethereumAddress = Web3.Utils.ecrecover(signedOrder: signedOrder) else {
            showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
            return false
        }

        let recoverAddress = AlphaWallet.Address(address: ethereumAddress)
        if signedOrder.order.nativeCurrencyDrop {
            handleNativeCurrencyDrop(signedOrder: signedOrder)
        } else if signedOrder.order.spawnable, let tokens = signedOrder.order.tokenIds {
            handleSpawnableLink(signedOrder: signedOrder, tokens: tokens)
        } else {
            handleNormalLinks(signedOrder: signedOrder, recoverAddress: recoverAddress, contractAsAddress: signedOrder.order.contractAddress)
        }

        return true
    }

    private func handlePaidImports(signedOrder: SignedOrder) {
        let token: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        tokensService.tokenViewModelPublisher(for: token)
            .compactMap { $0?.balance }
            .sinkAsync(receiveValue: { [weak self] balance in
                guard let strongSelf = self else { return }

                if balance.value > signedOrder.order.price {
                    strongSelf.handlePaidImportsImpl(signedOrder: signedOrder, balance: balance)
                } else {
                    strongSelf.notEnoughEthForPaidImport(signedOrder: signedOrder, balance: balance)
                }
            })
    }

    private func notEnoughEthForPaidImport(signedOrder: SignedOrder, balance: BalanceViewModel) {
        let errorMessage: String
        switch server.serverWithEnhancedSupport {
        case .xDai:
            errorMessage = R.string.localizable.aClaimTokenFailedNotEnoughXDAITitle()
        case .main, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            errorMessage = R.string.localizable.aClaimTokenFailedNotEnoughEthTitle()
        }

        if canHandleNotEnoughEthForPaidImport {
            if balance.ticker?.price_usd == nil {
                let ethCost = ImportMagicLinkController.functional.convert(ethCost: signedOrder.order.price)
                showImportError(errorMessage: errorMessage, cost: .paid(eth: ethCost, dollar: nil))
            }

            canHandleNotEnoughEthForPaidImport = false
        }

        guard let price = balance.ticker?.price_usd else { return }

        let (ethCost, dollarCost) = ImportMagicLinkController.functional.convert(ethCost: signedOrder.order.price, rate: price)
        showImportError(errorMessage: errorMessage, cost: .paid(eth: ethCost, dollar: dollarCost))
    }

    private func makeTokenHolder(_ bytes32Tokens: [String], _ contractAddress: AlphaWallet.Address) {
        assetDefinitionStore.fetchXML(forContract: contractAddress, server: server, useCacheAndFetch: true) { [weak self, session] _ in
            guard let strongSelf = self else { return }

            func makeTokenHolder(name: String, symbol: String, type: TokenType? = nil) {
                strongSelf.makeTokenHolderImpl(name: name, symbol: symbol, type: type, bytes32Tokens: bytes32Tokens, contractAddress: contractAddress)
                strongSelf.updateTokenFields()
            }

            if let existingToken = strongSelf.tokensService.tokenViewModel(for: contractAddress, server: strongSelf.server) {
                let name = XMLHandler(token: existingToken, assetDefinitionStore: strongSelf.assetDefinitionStore).getLabel(fallback: existingToken.name)
                makeTokenHolder(name: name, symbol: existingToken.symbol)
            } else {
                let localizedTokenTypeName = R.string.localizable.tokensTitlecase()
                makeTokenHolder(name: localizedTokenTypeName, symbol: "")

                let getContractName = session.tokenProvider.getContractName(for: contractAddress)
                let getContractSymbol = session.tokenProvider.getContractSymbol(for: contractAddress)
                let getTokenType = session.tokenProvider.getTokenType(for: contractAddress)

                Publishers.CombineLatest3(getContractName, getContractSymbol, getTokenType)
                    .sinkAsync(receiveCompletion: { _ in
                        //no-op
                    }, receiveValue: { name, symbol, type in
                        makeTokenHolder(name: name, symbol: symbol, type: type)
                    })
            }
        }
    }

    private func makeTokenHolderImpl(name: String, symbol: String, type: TokenType? = nil, bytes32Tokens: [String], contractAddress: AlphaWallet.Address) {
        //TODO pass in the wallet instead
        guard let tokenType = type ?? (tokensService.tokenViewModel(for: contractAddress, server: server)?.type) else { return }
        var tokens = [TokenScript.Token]()
        let xmlHandler = XMLHandler(contract: contractAddress, tokenType: tokenType, assetDefinitionStore: assetDefinitionStore)
        for i in 0..<bytes32Tokens.count {
            let token = bytes32Tokens[i]
            if let tokenId = BigUInt(token.drop0x, radix: 16) {
                let token = xmlHandler.getToken(
                    name: name,
                    symbol: symbol,
                    fromTokenIdOrEvent: .tokenId(tokenId: tokenId), index: UInt16(i),
                    inWallet: wallet.address,
                    server: server,
                    tokenType: tokenType,
                    assetDefinitionStore: assetDefinitionStore)

                tokens.append(token)
            }
        }

        tokenHolder = TokenHolder(
            tokens: tokens,
            contractAddress: contractAddress,
            hasAssetDefinition: xmlHandler.hasAssetDefinition)
    }

    private func updateTokenFields() {
        guard let tokenHolder = tokenHolder else { return }

        viewStateSubject.value.tokenHolder = tokenHolder
        viewStateSubject.value.count = count
    }

    struct ViewState {
        var url: URL?
        var contract: AlphaWallet.Address?
        var state: ImportMagicTokenViewModel.State
        var tokenHolder: TokenHolder?
        var count: Decimal?
        var cost: ImportMagicTokenViewModel.Cost?
    }

    private func updateImportTokenState(with state: ImportMagicTokenViewModel.State, cost: ImportMagicTokenViewModel.Cost? = nil) {
        guard !hasCompleted else { return }

        viewStateSubject.value.state = state

        if let tokenHolder = tokenHolder {
            viewStateSubject.value.tokenHolder = tokenHolder
            viewStateSubject.value.count = count
        }
        if let cost = cost {
            viewStateSubject.value.cost = cost
        }
        hasCompleted = state.hasCompleted
    }

    private func promptImportUniversalLink(cost: ImportMagicTokenViewModel.Cost) {
        updateImportTokenState(with: .promptImport, cost: cost)
    }

    private func showImportSuccessful() {
        updateImportTokenState(with: .succeeded)
    }

    private func showImportError(errorMessage: String, cost: ImportMagicTokenViewModel.Cost? = nil) {
        updateImportTokenState(with: .failed(errorMessage: errorMessage), cost: cost)
    }

    private func importFreeTransfer(request: ImportMagicLinkNetworking.FreeTransferRequest) {
        updateImportTokenState(with: .processing)

        networking.freeTransfer(request: request)
            .sinkAsync(receiveValue: { [weak self] successful in
                guard let strongSelf = self else { return }

                strongSelf.importToken(contract: request.contractAddress)

                // TODO handle http response
                if successful {
                    strongSelf.showImportSuccessful()
                } else {
                    //TODO: Pass in error message
                    strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedTitle())
                }
            })
    }

    private func importToken(contract: AlphaWallet.Address) {
        importToken.importToken(for: contract, onlyIfThereIsABalance: false)
            .handleEvents(receiveCompletion: { [server, wallet] result in
                guard case .failure(let error) = result else { return }
                debugLog("Error while adding imported token contract: \(contract.eip55String) server: \(server) wallet: \(wallet.address.eip55String) error: \(error)")
            }).sinkAsync()
    }
}
// swiftlint:enable type_body_length

extension ImportMagicLinkController {
    enum functional {}
}

extension ImportMagicLinkController.functional {

    static func requiresPaymasterForCurrencyLinks(signedOrder: SignedOrder, server: RPCServer) -> Bool {
        guard signedOrder.order.nativeCurrencyDrop else { return false }
        guard signedOrder.order.price == 0 else { return false }
        return !server.isTestnet
    }

    static func isOrderExpired(_ signedOrder: SignedOrder) -> Bool {
        return Date(timeIntervalSince1970: TimeInterval(signedOrder.order.expiry)).isEarlierThan(date: Date())
    }

    static func convert(ethCost: BigUInt, rate: Double) -> (ethCost: Decimal, dollarCost: Decimal) {
        let etherCostDecimal = convert(ethCost: ethCost)
        let dollarCost = Decimal(rate) * etherCostDecimal
        return (etherCostDecimal, dollarCost)
    }

    static func convert(ethCost: BigUInt) -> Decimal {
        let etherCostDecimal = Decimal(string: ethCost.description)! /  Decimal(EthereumUnit.ether.rawValue)
        return etherCostDecimal
    }

    static func checkErc875TokensAreAvailable(indices: [UInt16], balance: [String]) -> [String] {
        var filteredTokens = [String]()
        if balance.count < indices.count {
            return [String]()
        }
        for i in 0..<indices.count {
            let token: String = balance[Int(indices[i])]
            //all of the indices provided should map to a valid non null token
            if isZeroBalance(token, tokenType: .erc875) {
                //if null token at any index then the deal cannot happen
                return [String]()
            }
            filteredTokens.append(token)
        }
        return filteredTokens
    }

}

