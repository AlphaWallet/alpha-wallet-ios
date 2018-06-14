// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import TrustKeystore
import Alamofire

protocol TokensCoordinatorDelegate: class {
    func didPress(for type: PaymentFlow, in coordinator: TokensCoordinator)
    func didPressStormBird(for type: PaymentFlow, token: TokenObject, in coordinator: TokensCoordinator)
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void)
}

private enum ContractData {
    case name(String)
    case symbol(String)
    case balance([String])
    case decimals(UInt8)
    case stormBirdComplete(name: String, symbol: String, balance: [String])
    case nonStormBirdComplete(name: String, symbol: String, decimals: UInt8)
    case failed(networkReachable: Bool?)
}

class TokensCoordinator: Coordinator {

    let navigationController: UINavigationController
    let config: Config
    let session: WalletSession
    let keystore: Keystore
    var coordinators: [Coordinator] = []
    let storage: TokensDataStore

    lazy var tokensViewController: TokensViewController = {
        let controller = TokensViewController(
			session: session,
            account: session.account,
            dataStore: storage
        )
        controller.delegate = self
        return controller
    }()
    weak var delegate: TokensCoordinatorDelegate?

    lazy var rootViewController: TokensViewController = {
        return self.tokensViewController
    }()

    init(
        navigationController: UINavigationController = NavigationController(),
        config: Config,
        session: WalletSession,
        keystore: Keystore,
        tokensStorage: TokensDataStore
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.config = config
        self.session = session
        self.keystore = keystore
        self.storage = tokensStorage
    }

    func start() {
        addFIFAToken()
        autoDetectTokens()
        showTokens()
    }

    func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }

    ///Implementation: We refresh once only, after all the auto detected tokens' data have been pulled because each refresh pulls every tokens' (including those that already exist before the this auto detection) price as well as balance, placing heavy and redundant load on the device. After a timeout, we refresh once just in case it took too long, so user at least gets the chance to see some auto detected tokens
    private func autoDetectTokens() {
        //TODO we don't auto detect tokens if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
        if ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil {
            return
        }

        guard let address = keystore.recentlyUsedWallet?.address else { return }
        let web3 = Web3Swift(url: config.rpcURL)
        GetContractInteractions(web3: web3).getContractList(address: address.eip55String, chainId: config.chainID) { contracts in
            guard let currentAddress = self.keystore.recentlyUsedWallet?.address, currentAddress.eip55String.sameContract(as: address.eip55String) else { return }
            let detectedContracts = contracts.map { $0.lowercased() }
            let alreadyAddedContracts = self.storage.enabledObject.map { $0.address.eip55String.lowercased() }
            let deletedContracts = self.storage.deletedContracts.map { $0.contract.lowercased() }
            let hiddenContracts = self.storage.hiddenContracts.map { $0.contract.lowercased() }
            let contractsToAdd = detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts
            var contractsPulled = 0
            var hasRefreshedAfterAddingAllContracts = false
            for eachContract in contractsToAdd {
                self.addToken(for: eachContract) {
                    contractsPulled += 1
                    if contractsPulled == contractsToAdd.count {
                        hasRefreshedAfterAddingAllContracts = true
                        self.tokensViewController.fetch()
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if !hasRefreshedAfterAddingAllContracts {
                    self.tokensViewController.fetch()
                }
            }
        }
    }

    private func addToken(for contract: String, completion: @escaping () -> Void) {
        fetchContractData(for: contract) { data in
            switch data {
            case .name, .symbol, .balance, .decimals:
                break
            case .stormBirdComplete(let name, let symbol, let balance):
                if let address = Address(string: contract) {
                    let token = ERCToken(
                            contract: address,
                            name: name,
                            symbol: symbol,
                            decimals: 0,
                            isStormBird: true,
                            balance: balance
                    )
                    self.storage.addCustom(token: token)
                    completion()
                }
            case .nonStormBirdComplete(let name, let symbol, let decimals):
                let token = TokenObject(
                        contract: contract,
                        name: name,
                        symbol: symbol,
                        decimals: Int(decimals),
                        value: "0"
                )
                self.storage.add(tokens: [token])
                completion()
            case .failed(let networkReachable):
                if let networkReachable = networkReachable, networkReachable  {
                    self.storage.add(deadContracts: [DeletedContract(contract: contract)])
                }
                completion()
            }
        }
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

    //FIFA add the FIFA token with a hardcoded address for appropriate network if not already present
    private func addFIFAToken() {
        if let token = config.createDefaultTicketToken(), !storage.enabledObject.contains { $0.address.eip55String == token.contract.eip55String } {
            storage.addCustom(token: token)
        }
        tokensViewController.fetch()
    }

    /// Failure to obtain contract data may be due to no-connectivity. So we should check .failed(networkReachable: Bool)
    private func fetchContractData(for address: String, completion: @escaping (ContractData) -> Void) {
        var completedName: String?
        var completedSymbol: String?
        var completedBalance: [String]?
        var completedDecimals: UInt8?
        var failed = false

        func callCompletionOnAllData() {
            if let completedName = completedName, let completedSymbol = completedSymbol, let completedBalance = completedBalance {
                completion(.stormBirdComplete(name: completedName, symbol: completedSymbol, balance: completedBalance))
            } else if let completedName = completedName, let completedSymbol = completedSymbol, let completedDecimals = completedDecimals {
                completion(.nonStormBirdComplete(name: completedName, symbol: completedSymbol, decimals: completedDecimals))
            }
        }

        func callCompletionFailed() {
            guard !failed else { return }
            failed = true
            //TODO maybe better to share an instance of the reachability manager
            completion(.failed(networkReachable: NetworkReachabilityManager()?.isReachable))
        }

        self.storage.getContractName(for: address) { result in
            switch result {
            case .success(let name):
                completedName = name
                completion(.name(name))
                callCompletionOnAllData()
            case .failure:
                callCompletionFailed()
            }
        }

        self.storage.getContractSymbol(for: address) { result in
            switch result {
            case .success(let symbol):
                completedSymbol = symbol
                completion(.symbol(symbol))
                callCompletionOnAllData()
            case .failure:
                callCompletionFailed()
            }
        }

        self.storage.getIsStormBird(for: address) { result in
            switch result {
            case .success(let isStormBird):
                if isStormBird {
                    self.storage.getStormBirdBalance(for: address) { result in
                        switch result {
                        case .success(let balance):
                            completedBalance = balance
                            completion(.balance(balance))
                            callCompletionOnAllData()
                        case .failure:
                            callCompletionFailed()
                        }
                    }
                } else {
                    self.storage.getDecimals(for: address) { result in
                        switch result {
                        case .success(let decimal):
                            completedDecimals = decimal
                            completion(.decimals(decimal))
                            callCompletionOnAllData()
                        case .failure:
                            callCompletionFailed()
                        }
                    }
                }
            case .failure:
                self.storage.getDecimals(for: address) { result in
                    switch result {
                    case .success(let decimal):
                        completedDecimals = decimal
                        completion(.decimals(decimal))
                        callCompletionOnAllData()
                    case .failure:
                        callCompletionFailed()
                    }
                }
            }
        }
    }
}

extension TokensCoordinator: TokensViewControllerDelegate {
    func didSelect(token: TokenObject, in viewController: UIViewController) {

        let type: TokenType = {
            if token.isStormBird {
                return .stormBird
            }
            return TokensDataStore.etherToken(for: session.config) == token ? .ether : .token
        }()

        switch type {
        case .ether:
            delegate?.didPress(for: .send(type: .ether(destination: .none)), in: self)
        case .token:
            delegate?.didPress(for: .send(type: .token(token)), in: self)
        case .stormBird:
            delegate?.didPressStormBird(for: .send(type: .stormBird(token)), token: token, in: self)
        case .stormBirdOrder:
            break
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
        self.fetchContractData(for: address) { data in
            switch data {
            case .name(let name):
                viewController.updateNameValue(name)
            case .symbol(let symbol):
                viewController.updateSymbolValue(symbol)
            case .balance(let balance):
                viewController.updateFormForStormBirdToken(true)
                viewController.updateBalanceValue(balance)
            case .decimals(let decimals):
                viewController.updateFormForStormBirdToken(false)
                viewController.updateDecimalsValue(decimals)
            case .stormBirdComplete:
                break
            case .nonStormBirdComplete:
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
