// Copyright DApps Platform Inc. All rights reserved.

import UIKit
import WebKit
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit
import RealmSwift
import Result

protocol DappBrowserCoordinatorDelegate: class, CanOpenURL {
    func didSentTransaction(transaction: SentTransaction, inCoordinator coordinator: DappBrowserCoordinator)
    func importUniversalLink(url: URL, forCoordinator coordinator: DappBrowserCoordinator)
    func handleUniversalLink(_ url: URL, forCoordinator coordinator: DappBrowserCoordinator)
    func handleCustomUrlScheme(_ url: URL, forCoordinator coordinator: DappBrowserCoordinator)
    func restartToAddEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappBrowserCoordinator)
    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappBrowserCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: DappBrowserCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
}

final class DappBrowserCoordinator: NSObject, Coordinator {
    private var session: WalletSession {
        return sessions[server]
    }
    private let sessions: ServerDictionary<WalletSession>
    private let keystore: Keystore
    private var config: Config
    private let analyticsCoordinator: AnalyticsCoordinator
    private var browserNavBar: DappBrowserNavigationBar? {
        return navigationController.navigationBar as? DappBrowserNavigationBar
    }

    private lazy var browserViewController: BrowserViewController = createBrowserViewController()

    private let sharedRealm: Realm
    private let browserOnly: Bool
    private let nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>
    private let restartQueue: RestartTaskQueue

    private lazy var bookmarksStore: BookmarksStore = {
        return BookmarksStore(realm: sharedRealm)
    }()

    private lazy var historyStore: HistoryStore = {
        return HistoryStore(realm: sharedRealm)
    }()

    private lazy var preferences: PreferencesController = {
        return PreferencesController()
    }()

    private var urlParser: BrowserURLParser {
        return BrowserURLParser()
    }

    private var server: RPCServer {
        get {
            let selected = RPCServer(chainID: Config.getChainId())
            let enabled = config.enabledServers
            if enabled.contains(selected) {
                return selected
            } else {
                let fallback = enabled[0]
                Config.setChainId(fallback.chainID)
                return fallback
            }
        }
        set {
            Config.setChainId(newValue.chainID)
        }
    }

    private var enableToolbar: Bool = true {
        didSet {
            navigationController.isToolbarHidden = !enableToolbar
        }
    }

    private var currentUrl: URL? {
        return browserViewController.webView.url
    }

    var hasWebPageLoaded: Bool {
        return currentUrl != nil
    }

    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController

    lazy var rootViewController: DappsHomeViewController = {
        let vc = DappsHomeViewController(bookmarksStore: bookmarksStore)
        vc.delegate = self
        return vc
    }()

    weak var delegate: DappBrowserCoordinatorDelegate?

   init(
        sessions: ServerDictionary<WalletSession>,
        keystore: Keystore,
        config: Config,
        sharedRealm: Realm,
        browserOnly: Bool,
        nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>,
        restartQueue: RestartTaskQueue,
        analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.navigationController = UINavigationController(navigationBarClass: DappBrowserNavigationBar.self, toolbarClass: nil)
        self.sessions = sessions
        self.keystore = keystore
        self.config = config
        self.sharedRealm = sharedRealm
        self.browserOnly = browserOnly
        self.nativeCryptoCurrencyPrices = nativeCryptoCurrencyPrices
        self.restartQueue = restartQueue
        self.analyticsCoordinator = analyticsCoordinator

        super.init()

        //Necessary so that some sites don't bleed into (under) navigation bar after we tweak global styles for navigationBars after adding large title support
        self.navigationController.navigationBar.isTranslucent = false

        browserNavBar?.navigationBarDelegate = self
        browserNavBar?.configure(server: server)
    }

    func start() {
        //If we hit a bug where the stack doesn't change immediately, be sure that we haven't changed the stack (eg. push/pop) with animation and it hasn't comppleted yet
        navigationController.viewControllers = [rootViewController]
    }

    func showDappsHome() {
        browserNavBar?.clearDisplay()
        navigationController.popToRootViewController(animated: true)
    }

    @objc func dismiss() {
        removeAllCoordinators()
        navigationController.dismiss(animated: true)
    }

    private func createHistoryViewController() -> BrowserHistoryViewController {
        let controller = BrowserHistoryViewController(store: historyStore)
        controller.configure(viewModel: HistoriesViewModel(store: historyStore))
        controller.delegate = self
        return controller
    }

    private func createMyDappsViewController() -> MyDappsViewController {
        let viewController = MyDappsViewController(bookmarksStore: bookmarksStore)
        viewController.configure(viewModel: .init(bookmarksStore: bookmarksStore))
        viewController.delegate = self
        return viewController
    }

    private func createBrowserViewController() -> BrowserViewController {
        let browserViewController = BrowserViewController(account: session.account, server: server)
        browserViewController.delegate = self
        browserViewController.webView.uiDelegate = self

        return browserViewController
    }

    private enum PendingTransaction {
        case none
        case data(callbackID: Int)
    }

    private var pendingTransaction: PendingTransaction = .none

    private func executeTransaction(account: AlphaWallet.Address, action: DappAction, callbackID: Int, transaction: UnconfirmedTransaction, type: ConfirmType, server: RPCServer) {
        pendingTransaction = .data(callbackID: callbackID)
        let ethPrice = nativeCryptoCurrencyPrices[server]
        let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: .dappTransaction(confirmType: type, keystore: keystore, ethPrice: ethPrice), analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .browser)
    }

    private func ethCall(callbackID: Int, from: AlphaWallet.Address?, to: AlphaWallet.Address?, data: String, server: RPCServer) {
        let request = EthCallRequest(from: from, to: to, data: data)
        firstly {
            Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)))
        }.done { result in
            let callback = DappCallback(id: callbackID, value: .ethCall(result))
            self.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
        }.catch { error in
            if case let SessionTaskError.responseError(JSONRPCError.responseError(_, message: message, _)) = error {
                self.browserViewController.notifyFinish(callbackID: callbackID, value: .failure(.nodeError(message)))
            } else {
                //TODO better handle. User didn't cancel
                self.browserViewController.notifyFinish(callbackID: callbackID, value: .failure(.cancelled))
            }
        }
    }

    func open(url: URL, animated: Bool = true, forceReload: Bool = false) {
        //If users tap on the verified button in the import MagicLink UI, we don't want to treat it as a MagicLink to import and show the UI again. Just open in browser. This check means when we tap MagicLinks in browserOnly mode, the import UI doesn't show up; which is probably acceptable
        if !browserOnly && isMagicLink(url) {
            delegate?.importUniversalLink(url: url, forCoordinator: self)
            return
        }

        browserViewController = createBrowserViewController()
        pushOntoNavigationController(viewController: browserViewController, animated: animated)
        navigationController.removeViewControllerOfSameType(except: browserViewController)

        browserNavBar?.display(url: url)
        if browserOnly {
            browserNavBar?.makeBrowserOnly()
        }

        browserViewController.goTo(url: url)
    }

    private func signMessage(with type: SignMessageType, account: AlphaWallet.Address, callbackID: Int) {
        firstly {
            SignMessageCoordinator.promise(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, keystore: keystore, coordinator: self, signType: type, account: account, source: .dappBrowser, walletConnectSession: nil)
        }.done { data in
            let callback: DappCallback
            switch type {
            case .message:
                callback = DappCallback(id: callbackID, value: .signMessage(data))
            case .personalMessage:
                callback = DappCallback(id: callbackID, value: .signPersonalMessage(data))
            case .typedMessage:
                callback = DappCallback(id: callbackID, value: .signTypedMessage(data))
            case .eip712v3And4:
                callback = DappCallback(id: callbackID, value: .signTypedMessageV3(data))
            }

            self.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
        }.catch { _ in
            self.browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
        }
    }

    private func makeMoreAlertSheet(sender: UIView) -> UIAlertController {
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.centerRect

        let reloadAction = UIAlertAction(title: R.string.localizable.reload(), style: .default) { [weak self] _ in
            self?.logReload()
            self?.browserViewController.reload()
        }
        reloadAction.isEnabled = hasWebPageLoaded

        let myBookmarksAction = UIAlertAction(title: R.string.localizable.myBookmarks(), style: .default) { [weak self] _ in
            self?.showMyDapps()
        }

        let historyAction = UIAlertAction(title: R.string.localizable.browserHistory(), style: .default) { [weak self] _ in
            self?.showBrowserHistory()
        }

        let setAsHomePageAction = UIAlertAction(title: R.string.localizable.setAsHomePage(), style: .default) { [weak self] _ in
            self?.config.homePageURL = self?.currentUrl
            UINotificationFeedbackGenerator.show(feedbackType: .success)
        }
        setAsHomePageAction.isEnabled = hasWebPageLoaded

        let shareAction = UIAlertAction(title: R.string.localizable.share(), style: .default) { [weak self] _ in
            self?.share(sender: sender)
        }
        shareAction.isEnabled = hasWebPageLoaded

        let addBookmarkAction = UIAlertAction(title: R.string.localizable.browserAddbookmarkButtonTitle(), style: .default) { [weak self] _ in
            self?.addCurrentPageAsBookmark()
        }
        addBookmarkAction.isEnabled = hasWebPageLoaded

        let switchNetworkAction = UIAlertAction(title: R.string.localizable.dappBrowserSwitchServer(server.name), style: .default) { [weak self] _ in
            self?.showServers()
        }

        let scanQrCodeAction = UIAlertAction(title: R.string.localizable.browserScanQRCodeButtonTitle(), style: .default) { [weak self] _ in
            self?.scanQrCode()
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }

        let mappedAlertActionsToDisplay: [(action: UIAlertAction, flag: Bool)] = [
            (action: reloadAction, flag: true),
            (action: myBookmarksAction, flag: !browserOnly),
            (action: historyAction, flag: !browserOnly),
            (action: setAsHomePageAction, flag: !browserOnly),
            (action: shareAction, flag: true),
            (action: addBookmarkAction, flag: !browserOnly),
            (action: switchNetworkAction, flag: !browserOnly),
            (action: scanQrCodeAction, flag: !browserOnly),
            (action: cancelAction, flag: true)
        ]

        for each in mappedAlertActionsToDisplay {
            guard each.flag else { continue }

            alertController.addAction(each.action)
        }

        return alertController
    }

    private func share(sender: UIView) {
        logShare()
        guard let url = currentUrl else { return }
        rootViewController.displayLoading()
        rootViewController.showShareActivity(fromSource: .view(sender), with: [url]) { [weak self] in
            self?.rootViewController.hideLoading()
        }
    }

    private func openDappInBrowser(_ dapp: Dapp) {
        guard let url = URL(string: dapp.url) else { return }
        open(url: url, animated: false)
    }

    private func openDappInBrowser(_ dapp: Bookmark) {
        guard let url = URL(string: dapp.url) else { return }
        open(url: url, animated: false)
    }

    private func pushOntoNavigationController(viewController: UIViewController, animated: Bool) {
        viewController.navigationItem.setHidesBackButton(true, animated: false)
        viewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(viewController, animated: animated)
    }

    private func deleteDappFromMyDapp(_ dapp: Bookmark) {
        bookmarksStore.delete(bookmarks: [dapp])
        refreshDapps()
    }

    //TODO can we animate changes better?
    func refreshDapps() {
        rootViewController.configure(viewModel: .init(bookmarksStore: bookmarksStore))
        for each in navigationController.viewControllers {
            guard let vc = each as? MyDappsViewController else { continue }
            vc.configure(viewModel: .init(bookmarksStore: bookmarksStore))
        }
    }

    private func addCurrentPageAsBookmark() {
        logAddDapp()
        if let url = currentUrl?.absoluteString, let title = browserViewController.webView.title {
            let bookmark = Bookmark(url: url, title: title)
            bookmarksStore.add(bookmarks: [bookmark])
            refreshDapps()

            UINotificationFeedbackGenerator.show(feedbackType: .success)
        } else {
            UINotificationFeedbackGenerator.show(feedbackType: .error)
        }
    }

    private func scanQrCode() {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: session.account)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .browserScreen)
    }

    private func showServers() {
        logSwitchServer()
        let coordinator = ServersCoordinator(defaultServer: server, config: config, navigationController: navigationController)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)

        browserNavBar?.setBrowserBar(hidden: true)
    }

    private func withCurrentUrl(handler: (URL?) -> Void) {
        handler(browserNavBar?.url)
    }

    func isMagicLink(_ url: URL) -> Bool {
        return RPCServer.availableServers.contains { $0.magicLinkHost == url.host }
    }

    func `switch`(toServer server: RPCServer, url: URL? = nil) {
        self.server = server
        withCurrentUrl { previousUrl in
            //TODO extract method? Clean up
            browserNavBar?.clearDisplay()
            browserNavBar?.configure(server: server)
            start()

            guard let url = url ?? previousUrl else { return }
            open(url: url, animated: false)
        }
    }

    private func addCustomChain(callbackID: Int, customChain: WalletAddEthereumChainObject, inViewController viewController: UIViewController) {
        let coordinator = DappRequestSwitchCustomChainCoordinator(config: config, server: server, callbackId: callbackID, customChain: customChain, restartQueue: restartQueue, analyticsCoordinator: analyticsCoordinator, currentUrl: currentUrl, inViewController: viewController)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    private func switchChain(callbackID: Int, targetChain: WalletSwitchEthereumChainObject, inViewController viewController: UIViewController) {
        let coordinator = DappRequestSwitchExistingChainCoordinator(config: config, server: server, callbackId: callbackID, targetChain: targetChain, restartQueue: restartQueue, analyticsCoordinator: analyticsCoordinator, currentUrl: currentUrl, inViewController: viewController)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }
}

extension DappBrowserCoordinator: TransactionConfirmationCoordinatorDelegate {

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }

            switch strongSelf.pendingTransaction {
            case .data(let callbackID):
                strongSelf.browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            case .none:
                break
            }

            strongSelf.removeCoordinator(coordinator)
            strongSelf.navigationController.dismiss(animated: true)
        }
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        switch pendingTransaction {
        case .data(let callbackID):
            browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
        case .none:
            break
        }

        removeCoordinator(coordinator)
        navigationController.dismiss(animated: true)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        switch pendingTransaction {
        case .data(let callbackID):
            let data = Data(_hex: transaction.id)
            let callback = DappCallback(id: callbackID, value: .sentTransaction(data))
            browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))

            delegate?.didSentTransaction(transaction: transaction, inCoordinator: self)
        case .none:
            break
        }
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }

            switch (strongSelf.pendingTransaction, result) {
            case (.data(let callbackID), .signedTransaction(let data)):
                let callback = DappCallback(id: callbackID, value: .signTransaction(data))
                strongSelf.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
                //TODO do we need to do this for a pending transaction?
                //strongSelf.delegate?.didSentTransaction(transaction: transaction, inCoordinator: strongSelf)
            case (.data, .sentTransaction):
                //moved up to `didSendTransaction` function
                break
            case (.none, _), (_, .sentTransaction), (_, .sentRawTransaction):
                break
            }

            strongSelf.removeCoordinator(coordinator)
            strongSelf.navigationController.dismiss(animated: true)
        }
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension DappBrowserCoordinator: BrowserViewControllerDelegate {

    func didCall(action: DappAction, callbackID: Int, inBrowserViewController viewController: BrowserViewController) {
        func rejectDappAction() {
            browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            navigationController.topViewController?.displayError(error: InCoordinatorError.onlyWatchAccount)
        }

        func performDappAction(account: AlphaWallet.Address) {
            switch action {
            case .signTransaction(let unconfirmedTransaction):
                executeTransaction(account: account, action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: server)
            case .sendTransaction(let unconfirmedTransaction):
                executeTransaction(account: account, action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: server)
            case .signMessage(let hexMessage):
                signMessage(with: .message(hexMessage.toHexData), account: account, callbackID: callbackID)
            case .signPersonalMessage(let hexMessage):
                signMessage(with: .personalMessage(hexMessage.toHexData), account: account, callbackID: callbackID)
            case .signTypedMessage(let typedData):
                signMessage(with: .typedMessage(typedData), account: account, callbackID: callbackID)
            case .signTypedMessageV3(let typedData):
                signMessage(with: .eip712v3And4(typedData), account: account, callbackID: callbackID)
            case .ethCall(from: let from, to: let to, data: let data):
                //Must use unchecked form for `Address `because `from` and `to` might be 0x0..0. We assume the dapp author knows what they are doing
                let from = AlphaWallet.Address(uncheckedAgainstNullAddress: from)
                let to = AlphaWallet.Address(uncheckedAgainstNullAddress: to)
                ethCall(callbackID: callbackID, from: from, to: to, data: data, server: server)
            case .walletAddEthereumChain(let customChain):
                addCustomChain(callbackID: callbackID, customChain: customChain, inViewController: viewController)
            case .walletSwitchEthereumChain(let targetChain):
                switchChain(callbackID: callbackID, targetChain: targetChain, inViewController: viewController)
            case .unknown, .sendRawTransaction:
                break
            }
        }

        switch session.account.type {
        case .real(let account):
            return performDappAction(account: account)
        case .watch(let account):
            switch action {
            case .signTransaction, .sendTransaction, .signMessage, .signPersonalMessage, .signTypedMessage, .signTypedMessageV3, .ethCall, .unknown, .sendRawTransaction:
                return rejectDappAction()
            case .walletAddEthereumChain, .walletSwitchEthereumChain:
                return performDappAction(account: account)
            }
        }
    }

    func didVisitURL(url: URL, title: String, inBrowserViewController viewController: BrowserViewController) {
        browserNavBar?.display(url: url)
        if let mostRecentUrl = historyStore.histories.first?.url, mostRecentUrl == url.absoluteString {
        } else {
            historyStore.record(url: url, title: title)
        }
    }

    func dismissKeyboard(inBrowserViewController viewController: BrowserViewController) {
        browserNavBar?.cancelEditing()
    }

    func forceUpdate(url: URL, inBrowserViewController viewController: BrowserViewController) {
        browserNavBar?.display(url: url)
    }

    func handleUniversalLink(_ url: URL, inBrowserViewController viewController: BrowserViewController) {
        delegate?.handleUniversalLink(url, forCoordinator: self)
    }

    func handleCustomUrlScheme(_ url: URL, inBrowserViewController viewController: BrowserViewController) {
        delegate?.handleCustomUrlScheme(url, forCoordinator: self)
    }
}

extension DappBrowserCoordinator: BrowserHistoryViewControllerDelegate {
    func didSelect(history: History, inViewController controller: BrowserHistoryViewController) {
        guard let url = history.URL else { return }
        open(url: url)
    }

    func clearHistory(inViewController viewController: BrowserHistoryViewController) {
        historyStore.clearAll()
        viewController.configure(viewModel: HistoriesViewModel(store: historyStore))
    }

    func dismissKeyboard(inViewController viewController: BrowserHistoryViewController) {
        browserNavBar?.cancelEditing()
    }
}

extension DappBrowserCoordinator: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            browserViewController.webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController.alertController(
            title: .none,
            message: message,
            style: .alert,
            in: navigationController
        )
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: { _ in
            completionHandler()
        }))
        navigationController.present(alertController, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController.alertController(
            title: .none,
            message: message,
            style: .alert,
            in: navigationController
        )
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: { _ in
            completionHandler(true)
        }))
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .default, handler: { _ in
            completionHandler(false)
        }))
        navigationController.present(alertController, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController.alertController(
            title: .none,
            message: prompt,
            style: .alert,
            in: navigationController
        )
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: { _ in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .default, handler: { _ in
            completionHandler(nil)
        }))
        navigationController.present(alertController, animated: true, completion: nil)
    }
}

extension DappBrowserCoordinator: DappsHomeViewControllerDelegate {

    private func showMyDapps() {
        logShowDapps()
        let viewController = createMyDappsViewController()
        pushOntoNavigationController(viewController: viewController, animated: true)
        navigationController.removeViewControllerOfSameType(except: viewController)
    }

    private func showBrowserHistory() {
        logShowHistory()
        let viewController = createHistoryViewController()
        pushOntoNavigationController(viewController: viewController, animated: true)
        navigationController.removeViewControllerOfSameType(except: viewController)
    }

    func didTapShowMyDappsViewController(inViewController viewController: DappsHomeViewController) {
        showMyDapps()
    }

    func didTapShowBrowserHistoryViewController(inViewController viewController: DappsHomeViewController) {
        showBrowserHistory()
    }

    func didTapShowDiscoverDappsViewController(inViewController viewController: DappsHomeViewController) {
        let viewController = DiscoverDappsViewController(bookmarksStore: bookmarksStore)
        viewController.configure(viewModel: .init())
        viewController.delegate = self
        pushOntoNavigationController(viewController: viewController, animated: true)
    }

    func didTap(dapp: Bookmark, inViewController viewController: DappsHomeViewController) {
        openDappInBrowser(dapp)
    }

    func delete(dapp: Bookmark, inViewController viewController: DappsHomeViewController) {
        deleteDappFromMyDapp(dapp)
    }

    func viewControllerWillAppear(_ viewController: DappsHomeViewController) {
        browserNavBar?.enableButtons()
    }

    func dismissKeyboard(inViewController viewController: DappsHomeViewController) {
        browserNavBar?.cancelEditing()
    }
}

extension DappBrowserCoordinator: DiscoverDappsViewControllerDelegate {
    func didTap(dapp: Dapp, inViewController viewController: DiscoverDappsViewController) {
        openDappInBrowser(dapp)
    }

    func didAdd(dapp: Dapp, inViewController viewController: DiscoverDappsViewController) {
        refreshDapps()
    }

    func didRemove(dapp: Dapp, inViewController viewController: DiscoverDappsViewController) {
        refreshDapps()
    }

    func dismissKeyboard(inViewController viewController: DiscoverDappsViewController) {
        browserNavBar?.cancelEditing()
    }
}

extension DappBrowserCoordinator: MyDappsViewControllerDelegate {

    private func createEditMyDappViewController(dapp: Bookmark) -> EditMyDappViewController {
        let viewController = EditMyDappViewController()
        viewController.delegate = self
        viewController.configure(viewModel: .init(dapp: dapp))
        viewController.hidesBottomBarWhenPushed = true

        return viewController
    }

    func didTapToEdit(dapp: Bookmark, inViewController viewController: MyDappsViewController) {
        let viewController = createEditMyDappViewController(dapp: dapp)

        browserNavBar?.setBrowserBar(hidden: true)

        navigationController.pushViewController(viewController, animated: true)
    }

    func didTapToSelect(dapp: Bookmark, inViewController viewController: MyDappsViewController) {
        openDappInBrowser(dapp)
    }

    func delete(dapp: Bookmark, inViewController viewController: MyDappsViewController) {
        deleteDappFromMyDapp(dapp)
        viewController.configure(viewModel: .init(bookmarksStore: bookmarksStore))
    }

    func dismissKeyboard(inViewController viewController: MyDappsViewController) {
        browserNavBar?.cancelEditing()
    }

    func didReorderDapps(inViewController viewController: MyDappsViewController) {
        refreshDapps()
    }
}

extension DappBrowserCoordinator: DappsAutoCompletionViewControllerDelegate {
    func didTap(dapp: Dapp, inViewController viewController: DappsAutoCompletionViewController) {
        openDappInBrowser(dapp)
    }

    func dismissKeyboard(inViewController viewController: DappsAutoCompletionViewController) {
        browserNavBar?.cancelEditing()
    }
}

extension DappBrowserCoordinator: DappBrowserNavigationBarDelegate {

    func didTapHome(sender: UIView, inNavigationBar navigationBar: DappBrowserNavigationBar) {
        if let url = config.homePageURL {
            open(url: url, animated: true, forceReload: true)
        } else {
            browserNavBar?.clearDisplay()
            navigationController.popToRootViewController(animated: true)
        }
    }

    func didTapBack(inNavigationBar navigationBar: DappBrowserNavigationBar) {
        if let browserVC = navigationController.topViewController as? BrowserViewController, browserVC.webView.canGoBack {
            browserViewController.webView.goBack()
        } else if !(browserNavBar?.isBrowserOnly ?? false) {
            navigationController.popViewController(animated: true)
            if let viewController = navigationController.topViewController as? DappsAutoCompletionViewController {
                browserNavBar?.display(string: viewController.text)
            } else if navigationController.topViewController is DappsHomeViewController {
                browserNavBar?.clearDisplay()
            }
        }
    }

    func didTapForward(inNavigationBar navigationBar: DappBrowserNavigationBar) {
        guard let browserVC = navigationController.topViewController as? BrowserViewController, browserVC.webView.canGoForward else { return }
        browserViewController.webView.goForward()
    }

    func didTapMore(sender: UIView, inNavigationBar navigationBar: DappBrowserNavigationBar) {
        logTapMore()
        let alertController = makeMoreAlertSheet(sender: sender)
        navigationController.present(alertController, animated: true)
    }

    func didTapClose(inNavigationBar navigationBar: DappBrowserNavigationBar) {
        dismiss()
    }

    func didTapChangeServer(inNavigationBar navigationBar: DappBrowserNavigationBar) {
        showServers()
    }

    func didTyped(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar) {
        if navigationController.topViewController as? DappsAutoCompletionViewController != nil && text.trimmed.isEmpty {
            navigationController.popViewController(animated: false)
        }
    }

    func didEnter(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar) {
        logEnterUrl()
        guard let url = urlParser.url(from: text.trimmed) else { return }
        open(url: url, animated: false)
    }
}

extension DappBrowserCoordinator: EditMyDappViewControllerDelegate {
    func didTapSave(dapp: Bookmark, withTitle title: String, url: String, inViewController viewController: EditMyDappViewController) {
        try? sharedRealm.write {
            dapp.title = title
            dapp.url = url
        }
        browserNavBar?.setBrowserBar(hidden: false)

        navigationController.popViewController(animated: true)
        refreshDapps()
    }

    func didTapCancel(inViewController viewController: EditMyDappViewController) {
        browserNavBar?.setBrowserBar(hidden: false)

        navigationController.popViewController(animated: true)
    }
}

extension DappBrowserCoordinator: ScanQRCodeCoordinatorDelegate {
    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)

        guard let url = URL(string: result) else { return }
        open(url: url, animated: false)
    }
}

extension DappBrowserCoordinator: ServersCoordinatorDelegate {
    func didSelectServer(server: RPCServerOrAuto, in coordinator: ServersCoordinator) {
        browserNavBar?.setBrowserBar(hidden: false)

        switch server {
        case .auto:
            break
        case .server(let server):
            coordinator.navigationController.popViewController(animated: true) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.removeCoordinator(coordinator)
                strongSelf.`switch`(toServer: server)
            }
        }
    }

    func didSelectDismiss(in coordinator: ServersCoordinator) {
        browserNavBar?.setBrowserBar(hidden: false)

        coordinator.navigationController.popViewController(animated: true)

        removeCoordinator(coordinator)
    }
}

extension DappBrowserCoordinator: CanOpenURL {
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

// MARK: Analytics
extension DappBrowserCoordinator {
    private func logReload() {
        analyticsCoordinator.log(action: Analytics.Action.reloadBrowser)
    }

    private func logShare() {
        analyticsCoordinator.log(action: Analytics.Action.shareUrl, properties: [Analytics.Properties.source.rawValue: "browser"])
    }

    private func logAddDapp() {
        analyticsCoordinator.log(action: Analytics.Action.addDapp)
    }

    private func logSwitchServer() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.switchServers, properties: [Analytics.Properties.source.rawValue: "browser"])
    }

    private func logShowDapps() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.showDapps)
    }

    private func logShowHistory() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.showHistory)
    }

    private func logTapMore() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.tapBrowserMore)
    }

    private func logEnterUrl() {
        analyticsCoordinator.log(action: Analytics.Action.enterUrl)
    }
}

extension DappBrowserCoordinator: DappRequestSwitchCustomChainCoordinatorDelegate {
    func notifySuccessful(withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        let callback = DappCallback(id: callbackId, value: .walletAddEthereumChain)
        browserViewController.notifyFinish(callbackID: callbackId, value: .success(callback))
        removeCoordinator(coordinator)
    }

    func switchBrowserToExistingServer(_ server: RPCServer, url: URL?, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        `switch`(toServer: server, url: url)
        removeCoordinator(coordinator)
    }

    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        delegate?.restartToEnableAndSwitchBrowserToServer(inCoordinator: self)
        removeCoordinator(coordinator)
    }

    func restartToAddEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        delegate?.restartToAddEnableAndSwitchBrowserToServer(inCoordinator: self)
        removeCoordinator(coordinator)
    }

    func userCancelled(withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        browserViewController.notifyFinish(callbackID: callbackId, value: .failure(DAppError.cancelled))
        removeCoordinator(coordinator)
    }

    func failed(withErrorMessage errorMessage: String, withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        let error = DAppError.nodeError(errorMessage)
        browserViewController.notifyFinish(callbackID: callbackId, value: .failure(error))
        removeCoordinator(coordinator)
    }

    func failed(withError error: DAppError, withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        browserViewController.notifyFinish(callbackID: callbackId, value: .failure(error))
        removeCoordinator(coordinator)
    }

    func cleanup(coordinator: DappRequestSwitchCustomChainCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension DappBrowserCoordinator: DappRequestSwitchExistingChainCoordinatorDelegate {
    func notifySuccessful(withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        let callback = DappCallback(id: callbackId, value: .walletSwitchEthereumChain)
        browserViewController.notifyFinish(callbackID: callbackId, value: .success(callback))
        removeCoordinator(coordinator)
    }

    func switchBrowserToExistingServer(_ server: RPCServer, url: URL?, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        `switch`(toServer: server, url: url)
        removeCoordinator(coordinator)
    }

    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        delegate?.restartToEnableAndSwitchBrowserToServer(inCoordinator: self)
        removeCoordinator(coordinator)
    }
    func userCancelled(withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        browserViewController.notifyFinish(callbackID: callbackId, value: .failure(DAppError.cancelled))
        removeCoordinator(coordinator)
    }

    func failed(withErrorMessage errorMessage: String, withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        let error = DAppError.nodeError(errorMessage)
        browserViewController.notifyFinish(callbackID: callbackId, value: .failure(error))
        removeCoordinator(coordinator)
    }
}

extension UINavigationController {
    /// Removes all instances of view controller from navigation stack of type `T` skipping instance `avoidToRemove`
    func removeViewControllerOfSameType<T>(except avoidToRemove: T) where T: UIViewController {
        viewControllers = viewControllers.filter { !($0 is T) || $0 == avoidToRemove }
    }
}
