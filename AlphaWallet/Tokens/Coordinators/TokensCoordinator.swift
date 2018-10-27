// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import TrustKeystore
import Alamofire

protocol TokensCoordinatorDelegate: class {
    func didPress(for type: PaymentFlow, in coordinator: TokensCoordinator)
    func didPressERC875(for type: PaymentFlow, token: TokenObject, in coordinator: TokensCoordinator)
    func didPressERC721(for type: PaymentFlow, token: TokenObject, in coordinator: TokensCoordinator)
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void)
}

private enum ContractData {
    case name(String)
    case symbol(String)
    case balance([String])
    case decimals(UInt8)
    case nonFungibleTokenComplete(name: String, symbol: String, balance: [String], tokenType: TokenType)
    case fungibleTokenComplete(name: String, symbol: String, decimals: UInt8)
    case delegateTokenComplete
    case failed(networkReachable: Bool?)
}

class TokensCoordinator: Coordinator {
    private let session: WalletSession
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore

    private lazy var tokensViewController: TokensViewController = {
        let controller = TokensViewController(
			session: session,
            account: session.account,
            dataStore: storage
        )
        controller.delegate = self
        return controller
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: TokensCoordinatorDelegate?

    lazy var rootViewController: TokensViewController = {
        return tokensViewController
    }()

    init(
            navigationController: UINavigationController = NavigationController(),
            session: WalletSession,
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.session = session
        self.keystore = keystore
        self.storage = tokensStorage
        self.assetDefinitionStore = assetDefinitionStore
    }

    func start() {
        autoDetectTokens()
        showTokens()
        refreshUponAssetDefinitionChanges()
    }

    func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }
    
    private func refreshUponAssetDefinitionChanges() {
        assetDefinitionStore.subscribe { [weak self] _ in
            self?.storage.fetchTokenNamesForNonFungibleTokensIfEmpty()
        }
    }

    ///Implementation: We refresh once only, after all the auto detected tokens' data have been pulled because each refresh pulls every tokens' (including those that already exist before the this auto detection) price as well as balance, placing heavy and redundant load on the device. After a timeout, we refresh once just in case it took too long, so user at least gets the chance to see some auto detected tokens
    private func autoDetectTokens() {
        //TODO we don't auto detect tokens if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
        if ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil {
            return
        }

        guard let address = keystore.recentlyUsedWallet?.address else { return }
        GetContractInteractions().getContractList(address: address.eip55String, chainId: session.config.chainID) { [weak self] contracts in
            guard let strongSelf = self else { return }
            guard let currentAddress = strongSelf.keystore.recentlyUsedWallet?.address, currentAddress.eip55String.sameContract(as: address.eip55String) else { return }
            let detectedContracts = contracts.map { $0.lowercased() }
            let alreadyAddedContracts = strongSelf.storage.enabledObject.map { $0.address.eip55String.lowercased() }
            let deletedContracts = strongSelf.storage.deletedContracts.map { $0.contract.lowercased() }
            let hiddenContracts = strongSelf.storage.hiddenContracts.map { $0.contract.lowercased() }
            let delegateContracts = strongSelf.storage.delegateContracts.map { $0.contract.lowercased() }
            let contractsToAdd = detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts
            var contractsPulled = 0
            var hasRefreshedAfterAddingAllContracts = false
            DispatchQueue.global().async { [weak self] in
                guard let strongSelf = self else { return }
                for eachContract in contractsToAdd {
                    strongSelf.addToken(for: eachContract) {
                        contractsPulled += 1
                        if contractsPulled == contractsToAdd.count {
                            hasRefreshedAfterAddingAllContracts = true
                            DispatchQueue.main.async {
                                strongSelf.tokensViewController.fetch()
                            }
                        }
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if !hasRefreshedAfterAddingAllContracts {
                        strongSelf.tokensViewController.fetch()
                    }
                }
            }
        }
    }

    private func addToken(for contract: String, completion: @escaping () -> Void) {
        fetchContractData(for: contract) { [weak self] data in
            guard let strongSelf = self else { return }
            switch data {
            case .name, .symbol, .balance, .decimals:
                break
            case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                if let address = Address(string: contract) {
                    let token = ERCToken(
                            contract: address,
                            name: name,
                            symbol: symbol,
                            decimals: 0,
                            type: tokenType,
                            balance: balance
                    )
                    strongSelf.storage.addCustom(token: token)
                    completion()
                }
            case .fungibleTokenComplete(let name, let symbol, let decimals):
                if let address = Address(string: contract) {
                    let token = TokenObject(
                            contract: address.eip55String,
                            name: name,
                            symbol: symbol,
                            decimals: Int(decimals),
                            value: "0",
                            type: .erc20
                    )
                    strongSelf.storage.add(tokens: [token])
                    completion()
                }
            case .delegateTokenComplete:
                strongSelf.storage.add(delegateContracts: [DelegateContract(contract: contract)])
                completion()
            case .failed(let networkReachable):
                if let networkReachable = networkReachable, networkReachable {
                    strongSelf.storage.add(deadContracts: [DeletedContract(contract: contract)])
                }
                completion()
            }
        }
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func addImportedToken(for contract: String) {
        delete(hiddenContract: contract)
        addToken(for: contract) { [weak self] in
            self?.tokensViewController.fetch()
        }
    }

    private func delete(hiddenContract contract: String) {
        guard let hiddenContract = storage.hiddenContracts.first(where: { $0.contract.sameContract(as: contract) }) else { return }
        //TODO we need to make sure it's all uppercase?
        storage.delete(hiddenContracts: [hiddenContract])
    }

    func newTokenViewController() -> NewTokenViewController {
        let controller = NewTokenViewController()
        controller.delegate = self
        return controller
    }

    @objc func addToken() {
        let controller = newTokenViewController()
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .formSheet
        navigationController.present(nav, animated: true, completion: nil)
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    @objc func edit() {
        //edit tokens disabled
//        let controller = EditTokensViewController(
//            session: session,
//            storage: storage
//        )
//        navigationController.pushViewController(controller, animated: true)
    }

    /// Failure to obtain contract data may be due to no-connectivity. So we should check .failed(networkReachable: Bool)
    private func fetchContractData(for address: String, completion: @escaping (ContractData) -> Void) {
        var completedName: String?
        var completedSymbol: String?
        var completedBalance: [String]?
        var completedDecimals: UInt8?
        var completedTokenType: TokenType?
        var failed = false

        func callCompletionFailed() {
            guard !failed else { return }
            failed = true
            //TODO maybe better to share an instance of the reachability manager
            completion(.failed(networkReachable: NetworkReachabilityManager()?.isReachable))
        }

        func callCompletionAsDelegateTokenOrNot() {
            assert(completedSymbol != nil && completedSymbol?.isEmpty == true)
            //Must check because we also get an empty symbol (and name) if there's no connectivity
            //TODO maybe better to share an instance of the reachability manager
            if let reachabilityManager = NetworkReachabilityManager(), reachabilityManager.isReachable {
                completion(.delegateTokenComplete)
            } else {
                callCompletionFailed()
            }
        }

        func callCompletionOnAllData() {
            if let completedName = completedName, let completedSymbol = completedSymbol, let completedBalance = completedBalance, let tokenType = completedTokenType {
                if completedSymbol.isEmpty {
                    callCompletionAsDelegateTokenOrNot()
                } else {
                    completion(.nonFungibleTokenComplete(name: completedName, symbol: completedSymbol, balance: completedBalance, tokenType: tokenType))
                }
            } else if let completedName = completedName, let completedSymbol = completedSymbol, let completedDecimals = completedDecimals {
                if completedSymbol.isEmpty {
                    callCompletionAsDelegateTokenOrNot()
                } else {
                    completion(.fungibleTokenComplete(name: completedName, symbol: completedSymbol, decimals: completedDecimals))
                }
            }
        }

        assetDefinitionStore.fetchXML(forContract: address)

        storage.getContractName(for: address) { result in
            switch result {
            case .success(let name):
                completedName = name
                completion(.name(name))
                callCompletionOnAllData()
            case .failure:
                callCompletionFailed()
            }
        }

        storage.getContractSymbol(for: address) { result in
            switch result {
            case .success(let symbol):
                completedSymbol = symbol
                completion(.symbol(symbol))
                callCompletionOnAllData()
            case .failure:
                callCompletionFailed()
            }
        }

        storage.getTokenType(for: address) { [weak self] tokenType in
            guard let strongSelf = self else { return }
            completedTokenType = tokenType
            switch tokenType {
            case .erc875:
                strongSelf.storage.getERC875Balance(for: address) { result in
                    switch result {
                    case .success(let balance):
                        completedBalance = balance
                        completion(.balance(balance))
                        callCompletionOnAllData()
                    case .failure:
                        callCompletionFailed()
                    }
                }
            case .erc721:
                strongSelf.storage.getERC721Balance(for: address) { result in
                    switch result {
                    case .success(let balance):
                        completedBalance = balance
                        completion(.balance(balance))
                        callCompletionOnAllData()
                    case .failure:
                        callCompletionFailed()
                    }
                }
            case .erc20:
                strongSelf.storage.getDecimals(for: address) { result in
                    switch result {
                    case .success(let decimal):
                        completedDecimals = decimal
                        completion(.decimals(decimal))
                        callCompletionOnAllData()
                    case .failure:
                        callCompletionFailed()
                    }
                }
            case .ether:
                break
            }
        }
    }
}

extension TokensCoordinator: TokensViewControllerDelegate {
    func didSelect(token: TokenObject, in viewController: UIViewController) {
        switch token.type {
        case .ether:
            delegate?.didPress(for: .send(type: .ether(config: session.config, destination: .none)), in: self)
        case .erc20:
            delegate?.didPress(for: .send(type: .ERC20Token(token)), in: self)
        case .erc721:
            delegate?.didPressERC721(for: .send(type: .ERC721Token(token)), token: token, in: self)
        case .erc875:
            delegate?.didPressERC875(for: .send(type: .ERC875Token(token)), token: token, in: self)
        }
    }

    func didDelete(token: TokenObject, in viewController: UIViewController) {
        storage.add(hiddenContracts: [HiddenContract(contract: token.contract)])
        storage.delete(tokens: [token])
        tokensViewController.fetch()
    }

    func didPressAddToken(in viewController: UIViewController) {
        addToken()
    }
}

extension TokensCoordinator: NewTokenViewControllerDelegate {
    func didAddToken(token: ERCToken, in viewController: NewTokenViewController) {
        storage.addCustom(token: token)
        tokensViewController.fetch()
        dismiss()
    }

    func didAddAddress(address: String, in viewController: NewTokenViewController) {
        fetchContractData(for: address) { data in
            switch data {
            case .name(let name):
                viewController.updateNameValue(name)
            case .symbol(let symbol):
                viewController.updateSymbolValue(symbol)
            case .balance(let balance):
                viewController.updateBalanceValue(balance)
            case .decimals(let decimals):
                viewController.updateDecimalsValue(decimals)
            case .nonFungibleTokenComplete(_, _, _, let tokenType):
                viewController.updateForm(forTokenType: tokenType)
            case .fungibleTokenComplete:
                viewController.updateForm(forTokenType: .erc20)
            case .delegateTokenComplete:
                viewController.updateForm(forTokenType: .erc20)
                break
            case .failed:
                break
            }
        }
    }
}

func -<T: Equatable>(left: [T], right: [T]) -> [T] {
    return left.filter { l in
        !right.contains { $0 == l }
    }
}
