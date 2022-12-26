// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import Combine
import AlphaWalletFoundation
import AlphaWalletWeb3

protocol ImportMagicLinkCoordinatorDelegate: AnyObject, CanOpenURL {
    func viewControllerForPresenting(in coordinator: ImportMagicLinkCoordinator) -> UIViewController?
    func completed(in coordinator: ImportMagicLinkCoordinator)
    func importPaidSignedOrder(signedOrder: SignedOrder, token: Token, inViewController viewController: ImportMagicTokenViewController, completion: @escaping (Bool) -> Void)
    func didImported(contract: AlphaWallet.Address, in coordinator: ImportMagicLinkCoordinator)
}

//TODO: Extract all logic to separate class
// swiftlint:disable type_body_length
class ImportMagicLinkCoordinator: Coordinator {
    private enum TransactionType {
        case freeTransfer(request: ImportMagicLinkNetworking.FreeTransferRequest)
        case paid(signedOrder: SignedOrder, token: Token)
    }

    private let analytics: AnalyticsLogger
    private var wallet: Wallet { session.account }
    private let config: Config
    private var importTokenViewController: ImportMagicTokenViewController?
    private var hasCompleted = false
    private lazy var getErc875TokenBalance = GetErc875Balance(blockchainProvider: session.blockchainProvider)
    //TODO better to make sure tokenHolder is non-optional. But be careful that ImportMagicTokenViewController also handles when viewModel always has a TokenHolder. Needs good defaults in TokenHolder that can be displayed
    private var tokenHolder: TokenHolder?
    private var count: Decimal?
    private var transactionType: TransactionType?
    private var isShowingImportUserInterface: Bool {
        return delegate?.viewControllerForPresenting(in: self) != nil
    }
    private let assetDefinitionStore: AssetDefinitionStore
    private let url: URL
    private let keystore: Keystore
    private var isNotProcessingYet: Bool {
        switch importTokenViewController?.state {
        case .ready(let viewModel):
            switch viewModel.state {
            case .validating, .promptImport:
                return true
            case .processing, .succeeded, .failed:
                return false
            }
        case .notReady, .none:
            return false
        }
    }

    var coordinators: [Coordinator] = []
    var server: RPCServer { return session.server }

    weak var delegate: ImportMagicLinkCoordinatorDelegate?
    private let tokensService: TokenViewModelState & TokenProvidable
    private var cryptoToFiatRateWhenHandlePaidImportCancelable: AnyCancellable?
    private var cryptoToFiatRateWhenNotEnoughEthForPaidImportCancelable: AnyCancellable?
    private var balanceWhenHandlePaidImportsCancelable: AnyCancellable?
    private let session: WalletSession
    private let networking: ImportMagicLinkNetworking
    private var cancelable = Set<AnyCancellable>()
    private lazy var tokenHolderResolver = TokenHolderResolver(
        assetDefinitionStore: assetDefinitionStore,
        session: session,
        tokensService: tokensService)

    init(analytics: AnalyticsLogger,
         session: WalletSession,
         config: Config,
         assetDefinitionStore: AssetDefinitionStore,
         url: URL,
         keystore: Keystore,
         tokensService: TokenViewModelState & TokenProvidable,
         networkService: NetworkService) {

        self.analytics = analytics
        self.session = session
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.networking = ImportMagicLinkNetworking(networkService: networkService)
        self.url = url
        self.keystore = keystore
        self.tokensService = tokensService
    }

    func start(url: URL) -> Bool {
        return handleMagicLink(url: url)
    }

    @discardableResult private func handlePaidImportsImpl(signedOrder: SignedOrder) -> Bool {
        guard isShowingImportUserInterface else { return false }

        //TODO we might not need to pass a TokenObject. Maybe something simpler? Especially since name and symbol is unused
        //TODO: not always ERC875
        let token = Token(
            contract: signedOrder.order.contractAddress,
            server: server,
            name: "",
            symbol: "",
            decimals: 0,
            value: BigInt(signedOrder.order.price),
            isCustom: true,
            isDisabled: false,
            type: .erc875)
        transactionType = .paid(signedOrder: signedOrder, token: token)

        let ethCost = convert(ethCost: signedOrder.order.price)
        promptImportUniversalLink(cost: .paid(eth: ethCost, dollar: nil))

        cryptoToFiatRateWhenHandlePaidImportCancelable?.cancel()
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        cryptoToFiatRateWhenHandlePaidImportCancelable = tokensService.tokenViewModelPublisher(for: etherToken)
            .compactMap { $0?.balance.ticker?.price_usd }
            .sink { [weak self] price in
                guard let celf = self else { return }

                let (ethCost, dollarCost) = celf.convert(ethCost: signedOrder.order.price, rate: price)
                //We should not prompt with an updated price if we are already processing or beyond that. Because this will revert the state back
                if celf.isNotProcessingYet {
                    celf.promptImportUniversalLink(cost: .paid(eth: ethCost, dollar: dollarCost))
                }
            }

        return true
    }

    @discardableResult private func usePaymentServerForFreeTransferLinks(signedOrder: SignedOrder) -> Bool {
        guard isShowingImportUserInterface else { return false }
        let request = ImportMagicLinkNetworking.FreeTransferRequest(signedOrder: signedOrder, wallet: wallet, server: server)
        transactionType = .freeTransfer(request: request)
        promptImportUniversalLink(cost: .free)

        return true
    }

    func completeOrderHandling(signedOrder: SignedOrder) {
        let requiresPaymaster = requiresPaymasterForCurrencyLinks(signedOrder: signedOrder)
        if signedOrder.order.price == 0 {
            networking.checkPaymentServerSupportsContract(contractAddress: signedOrder.order.contractAddress)
                .sink { supported in
                    //Currency links on mainnet/classic/xdai without a paymaster should be rejected for security reasons (front running)
                    guard supported || !requiresPaymaster else {
                        self.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedServerDown())
                        return
                    }
                    if supported {
                        self.usePaymentServerForFreeTransferLinks(signedOrder: signedOrder)
                    } else {
                        self.handlePaidImports(signedOrder: signedOrder)
                    }
                }.store(in: &cancelable)
        } else {
            self.handlePaidImports(signedOrder: signedOrder)
        }
    }

    private func requiresPaymasterForCurrencyLinks(signedOrder: SignedOrder) -> Bool {
        guard signedOrder.order.nativeCurrencyDrop else { return false }
        guard signedOrder.order.price == 0 else { return false }
        return !server.isTestnet
    }

    private func handleSpawnableLink(signedOrder: SignedOrder, tokens: [BigUInt]) {
        let tokenStrings: [String] = tokens.map { String($0, radix: 16) }
        self.buildTokenHolder(tokenStrings, signedOrder.order.contractAddress)
        completeOrderHandling(signedOrder: signedOrder)
    }

    private func handleNativeCurrencyDrop(signedOrder: SignedOrder) {
        let amt: Decimal
        let szabosPerEth: Decimal = Decimal(EthereumUnit.ether.rawValue / EthereumUnit.szabo.rawValue)
            //TODO should be better to put this into the tokenCount that is displayed in green
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

        self.tokenHolder = TokenHolder(tokens: [token], contractAddress: signedOrder.order.contractAddress, hasAssetDefinition: false)
        let r = signedOrder.signature.substring(with: Range(uncheckedBounds: (2, 66)))
        networking.checkIfLinkClaimed(r: r)
            .sink(receiveValue: { claimed in
                if claimed {
                    self.showImportError(errorMessage: R.string.localizable.aClaimTokenLinkAlreadyRedeemed())
                } else {
                    self.completeOrderHandling(signedOrder: signedOrder)
                }
            }).store(in: &cancelable)
    }

    private func handleNormalLinks(signedOrder: SignedOrder, recoverAddress: AlphaWallet.Address, contractAsAddress: AlphaWallet.Address) {
        getErc875TokenBalance.getErc875TokenBalance(for: recoverAddress, contract: contractAsAddress).done({ [weak self] balance in
            guard let strongSelf = self else { return }
            let filteredTokens: [String] = strongSelf.checkErc875TokensAreAvailable(
                indices: signedOrder.order.indices,
                balance: balance
            )
            if filteredTokens.isEmpty {
                strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenLinkAlreadyRedeemed())
                return
            }

            strongSelf.buildTokenHolder(filteredTokens, signedOrder.order.contractAddress)

            strongSelf.completeOrderHandling(signedOrder: signedOrder)
        }).catch({ [weak self]  _ in
            if !ReachabilityManager().isReachable {
                self?.showImportError(errorMessage: R.string.localizable.aClaimTokenNoConnectivityTryAgain())
            } else {
                self?.showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
            }
        })
    }

    static func isOrderExpired(_ signedOrder: SignedOrder) -> Bool {
        return Date(timeIntervalSince1970: TimeInterval(signedOrder.order.expiry)).isEarlierThan(date: Date())
    }

    private func handleMagicLink(url: URL) -> Bool {
        preparingToImportUniversalLink()
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
        importTokenViewController?.url = url
        importTokenViewController?.contract = signedOrder.order.contractAddress

        if Self.isOrderExpired(signedOrder) {
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
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        balanceWhenHandlePaidImportsCancelable = tokensService.tokenViewModelPublisher(for: etherToken)
            .compactMap { $0?.balance.value }
            .first()
            .sink { [weak self] balance in
                guard let celf = self else { return }

                if balance > signedOrder.order.price {
                    celf.handlePaidImportsImpl(signedOrder: signedOrder)
                } else {
                    celf.notEnoughEthForPaidImport(signedOrder: signedOrder)
                }
                celf.balanceWhenHandlePaidImportsCancelable?.cancel()
            }
    }

    private func notEnoughEthForPaidImport(signedOrder: SignedOrder) {
        let errorMessage: String
        switch server.serverWithEnhancedSupport {
        case .xDai:
            errorMessage = R.string.localizable.aClaimTokenFailedNotEnoughXDAITitle()
        case .main, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            errorMessage = R.string.localizable.aClaimTokenFailedNotEnoughEthTitle()
        }
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        if tokensService.tokenViewModel(for: etherToken).flatMap({ $0.balance.ticker?.price_usd }) == nil {
            let ethCost = convert(ethCost: signedOrder.order.price)
            showImportError(
                errorMessage: errorMessage,
                cost: .paid(eth: ethCost, dollar: nil)
            )
        }
        cryptoToFiatRateWhenNotEnoughEthForPaidImportCancelable?.cancel()

        cryptoToFiatRateWhenNotEnoughEthForPaidImportCancelable = tokensService.tokenViewModelPublisher(for: etherToken)
            .compactMap { $0?.balance.ticker?.price_usd }
            .sink { [weak self] price in
                guard let celf = self else { return }

                let (ethCost, dollarCost) = celf.convert(ethCost: signedOrder.order.price, rate: price)
                celf.showImportError(errorMessage: errorMessage, cost: .paid(eth: ethCost, dollar: dollarCost))
            }
    }

    private func checkErc875TokensAreAvailable(indices: [UInt16], balance: [String]) -> [String] {
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

    class TokenHolderResolver {
        enum TokenHolderResolverError: Error {
            case tokenTypeMissing
            case embedded(error: Error)
        }

        private let assetDefinitionStore: AssetDefinitionStore
        private let session: WalletSession
        private let tokensService: TokenViewModelState & TokenProvidable

        init(assetDefinitionStore: AssetDefinitionStore,
             session: WalletSession,
             tokensService: TokenViewModelState & TokenProvidable) {

            self.assetDefinitionStore = assetDefinitionStore
            self.tokensService = tokensService
            self.session = session
        }

        func buildTokenHolder(bytes32Tokens: [String], contractAddress: AlphaWallet.Address) -> AnyPublisher<TokenHolder, TokenHolderResolverError> {
            return assetDefinitionStore
                .fetchXmlPublisher(contract: contractAddress, server: session.server, useCacheAndFetch: true)
                .setFailureType(to: TokenHolderResolverError.self)
                .flatMap { [tokensService, session, assetDefinitionStore] _ -> AnyPublisher<TokenHolder, TokenHolderResolverError> in

                    if let existingToken = tokensService.token(for: contractAddress, server: session.server) {
                        let name = XMLHandler(token: existingToken, assetDefinitionStore: assetDefinitionStore).getLabel(fallback: existingToken.name)
                        do {
                            let tokenHolder = try self.buildTokenHolder(
                                name: name,
                                symbol: existingToken.symbol,
                                bytes32Tokens: bytes32Tokens,
                                contractAddress: contractAddress)

                            return .just(tokenHolder)
                        } catch {
                            return .fail(TokenHolderResolverError.embedded(error: error))
                        }
                    } else {
                        return Publishers.Merge(
                            self.buildEmptySymbolTokenHolder(bytes32Tokens: bytes32Tokens, contractAddress: contractAddress),
                            self.resolveTokenHolder(bytes32Tokens: bytes32Tokens, contractAddress: contractAddress))
                        .eraseToAnyPublisher()
                    }
                }.receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }

        private func resolveTokenHolder(bytes32Tokens: [String], contractAddress: AlphaWallet.Address) -> AnyPublisher<TokenHolder, TokenHolderResolverError> {
            return Publishers.CombineLatest3(
                session.tokenProvider.getContractName(for: contractAddress).publisher,
                session.tokenProvider.getContractSymbol(for: contractAddress).publisher,
                session.tokenProvider.getTokenType(for: contractAddress).publisher)
                .tryMap { try self.buildTokenHolder(name: $0, symbol: $1, type: $2, bytes32Tokens: bytes32Tokens, contractAddress: contractAddress) }
                .mapError { TokenHolderResolverError.embedded(error: $0) }
                .eraseToAnyPublisher()
        }

        private func buildEmptySymbolTokenHolder(bytes32Tokens: [String], contractAddress: AlphaWallet.Address) -> AnyPublisher<TokenHolder, TokenHolderResolverError> {
            AnyPublisher<TokenHolder, TokenHolderResolverError>.create { seal in
                do {
                    let tokenHolder = try self.buildTokenHolder(
                        name: R.string.localizable.tokensTitlecase(),
                        symbol: "",
                        bytes32Tokens: bytes32Tokens,
                        contractAddress: contractAddress)

                    seal.send(tokenHolder)
                    seal.send(completion: .finished)
                } catch {
                    seal.send(completion: .finished)
                }

                return AnyCancellable { }
            }.eraseToAnyPublisher()
        }

        private func buildTokenHolder(name: String,
                                      symbol: String,
                                      type: TokenType? = nil,
                                      bytes32Tokens: [String],
                                      contractAddress: AlphaWallet.Address) throws -> TokenHolder {

            let token = tokensService.token(for: contractAddress, server: session.server)
            guard let tokenType = type ?? token?.type else { throw TokenHolderResolverError.tokenTypeMissing }

            return TokenAdaptor.getTokenHolders(
                name: name,
                symbol: symbol,
                tokenType: tokenType,
                bytes32Tokens: bytes32Tokens,
                contractAddress: contractAddress,
                server: session.server,
                wallet: session.account,
                assetDefinitionStore: assetDefinitionStore)
        }
    }

    private func buildTokenHolder(_ bytes32Tokens: [String], _ contractAddress: AlphaWallet.Address) {
        tokenHolderResolver
            .buildTokenHolder(bytes32Tokens: bytes32Tokens, contractAddress: contractAddress)
            .sink(receiveCompletion: { result in
                guard case .failure(let e) = result else { return }
                debugLog("[TokenHolderResolver] resolve failure with error: \(e)")
            }, receiveValue: { [weak self] tokenHolder in
                self?.tokenHolder = tokenHolder
                self?.updateTokenFields()
            }).store(in: &cancelable)
    }

    private func preparingToImportUniversalLink() {
        guard let viewController = delegate?.viewControllerForPresenting(in: self) else { return }
        importTokenViewController = ImportMagicTokenViewController(analytics: analytics, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        guard let vc = importTokenViewController else { return }
        vc.delegate = self
        vc.configure(viewModel: .init(state: .validating, server: server))
        let nc = NavigationController(rootViewController: vc)
        nc.makePresentationFullScreenForiOS13Migration()
        viewController.present(nc, animated: true)
    }

    private func updateTokenFields() {
        guard let tokenHolder = tokenHolder else { return }
        guard let vc = importTokenViewController, case .ready(var viewModel) = vc.state else { return }
        viewModel.tokenHolder = tokenHolder
        viewModel.count = count
        vc.configure(viewModel: viewModel)
    }

    private func updateImportTokenController(with state: ImportMagicTokenViewControllerViewModel.State, cost: ImportMagicTokenViewControllerViewModel.Cost? = nil) {
        guard !hasCompleted else { return }
        if let vc = importTokenViewController, case .ready(var viewModel) = vc.state {
            viewModel.state = state
            if let tokenHolder = tokenHolder {
                viewModel.tokenHolder = tokenHolder
                viewModel.count = count
            }
            if let cost = cost {
                viewModel.cost = cost
            }
            vc.configure(viewModel: viewModel)
        }
        hasCompleted = state.hasCompleted
    }

    private func promptImportUniversalLink(cost: ImportMagicTokenViewControllerViewModel.Cost) {
        updateImportTokenController(with: .promptImport, cost: cost)
    }

    private func showImportSuccessful() {
        updateImportTokenController(with: .succeeded)
    }

    private func showImportError(errorMessage: String, cost: ImportMagicTokenViewControllerViewModel.Cost? = nil) {
        updateImportTokenController(with: .failed(errorMessage: errorMessage), cost: cost)
    }

    private func importPaidSignedOrder(signedOrder: SignedOrder, token: Token) {
        guard let importTokenViewController = importTokenViewController else { return }
        delegate?.importPaidSignedOrder(signedOrder: signedOrder, token: token, inViewController: importTokenViewController) { [weak self] successful in
            guard let strongSelf = self else { return }
            guard let vc = strongSelf.importTokenViewController, case .ready = vc.state else { return }
            if successful {
                strongSelf.delegate?.didImported(contract: signedOrder.order.contractAddress, in: strongSelf)
                strongSelf.showImportSuccessful()
            } else {
                //TODO Pass in error message
                strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedTitle())
            }
        }
    }

    private func importFreeTransfer(request: ImportMagicLinkNetworking.FreeTransferRequest) {
        updateImportTokenController(with: .processing)

        networking.freeTransfer(request: request)
            .sink { [weak self] successful in
                guard let strongSelf = self else { return }

                strongSelf.delegate?.didImported(contract: request.contractAddress, in: strongSelf)

                guard let vc = strongSelf.importTokenViewController, case .ready = vc.state else { return }
                // TODO handle http response
                if successful {
                    strongSelf.showImportSuccessful()
                } else {
                    //TODO: Pass in error message
                    strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedTitle())
                }
            }.store(in: &cancelable)
    }

    private func convert(ethCost: BigUInt, rate: Double) -> (ethCost: Decimal, dollarCost: Decimal) {
        let etherCostDecimal = convert(ethCost: ethCost)
        let dollarCost = Decimal(rate) * etherCostDecimal
        return (etherCostDecimal, dollarCost)
    }

    private func convert(ethCost: BigUInt) -> Decimal {
        let etherCostDecimal = Decimal(string: ethCost.description)! /  Decimal(EthereumUnit.ether.rawValue)
        return etherCostDecimal
    }
}
// swiftlint:enable type_body_length

extension ImportMagicLinkCoordinator: ImportMagicTokenViewControllerDelegate {
    func didPressDone(in viewController: ImportMagicTokenViewController) {
        viewController.dismiss(animated: true)
        delegate?.completed(in: self)
    }

    func didPressImport(in viewController: ImportMagicTokenViewController) {
        guard let transactionType = transactionType else { return }
        switch transactionType {
        case .freeTransfer(let request):
            importFreeTransfer(request: request)
        case .paid(let signedOrder, let token):
            importPaidSignedOrder(signedOrder: signedOrder, token: token)
        }
    }
}

extension ImportMagicLinkCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
