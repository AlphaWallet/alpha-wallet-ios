// Copyright DApps Platform Inc. All rights reserved.

import UIKit
import WebKit
import PromiseKit
import AlphaWalletFoundation

protocol DappBrowserCoordinatorDelegate: CanOpenURL, RequestAddCustomChainProvider, RequestSwitchChainProvider, BuyCryptoDelegate {
    func didSentTransaction(transaction: SentTransaction, inCoordinator coordinator: DappBrowserCoordinator)
    func handleUniversalLink(_ url: URL, forCoordinator coordinator: DappBrowserCoordinator)
}

// swiftlint:disable type_body_length
final class DappBrowserCoordinator: NSObject, Coordinator {
    private let sessionsProvider: SessionsProvider
    private let keystore: Keystore
    private var config: Config
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private var browserNavBar: DappBrowserNavigationBar? {
        return navigationController.navigationBar as? DappBrowserNavigationBar
    }
    private let wallet: Wallet
    private lazy var browserViewController: BrowserViewController = createBrowserViewController()
    private let browserOnly: Bool
    private let tokensService: TokenViewModelState
    private let bookmarksStore: BookmarksStore
    private let browserHistoryStorage: BrowserHistoryStorage
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
    private let networkService: NetworkService
    private var enableToolbar: Bool = true {
        didSet {
            navigationController.isToolbarHidden = !enableToolbar
        }
    }
    private let assetDefinitionStore: AssetDefinitionStore
    private var currentUrl: URL? {
        return browserViewController.webView.url
    }

    var hasWebPageLoaded: Bool {
        return currentUrl != nil
    }

    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController

    lazy var rootViewController: BrowserHomeViewController = {
        let viewModel = BrowserHomeViewModel(bookmarksStore: bookmarksStore)
        let vc = BrowserHomeViewController(viewModel: viewModel)
        vc.delegate = self

        return vc
    }()

    weak var delegate: DappBrowserCoordinatorDelegate?

    init(sessionsProvider: SessionsProvider,
         keystore: Keystore,
         config: Config,
         browserOnly: Bool,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainResolutionServiceType,
         assetDefinitionStore: AssetDefinitionStore,
         tokensService: TokenViewModelState,
         bookmarksStore: BookmarksStore,
         browserHistoryStorage: BrowserHistoryStorage,
         wallet: Wallet,
         networkService: NetworkService) {

        self.networkService = networkService
        self.wallet = wallet
        self.tokensService = tokensService
        self.navigationController = NavigationController(navigationBarClass: DappBrowserNavigationBar.self, toolbarClass: nil)
        self.sessionsProvider = sessionsProvider
        self.keystore = keystore
        self.config = config
        self.bookmarksStore = bookmarksStore
        self.browserHistoryStorage = browserHistoryStorage
        self.browserOnly = browserOnly
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.assetDefinitionStore = assetDefinitionStore
        super.init()
        //Necessary so that some sites don't bleed into (under) navigation bar after we tweak global styles for navigationBars after adding large title support
        navigationController.navigationBar.isTranslucent = false

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
        let viewModel = BrowserHistoryViewModel(browserHistoryStorage: browserHistoryStorage)
        let controller = BrowserHistoryViewController(viewModel: viewModel)
        controller.delegate = self

        return controller
    }

    private func createMyDappsViewController() -> BookmarksViewController {
        let viewModel = BookmarksViewViewModel(bookmarksStore: bookmarksStore)
        let viewController = BookmarksViewController(viewModel: viewModel)
        viewController.delegate = self

        return viewController
    }

    private func createBrowserViewController() -> BrowserViewController {
        let browserViewController = BrowserViewController(account: wallet, server: server)
        browserViewController.delegate = self
        browserViewController.webView.uiDelegate = self

        return browserViewController
    }

    private enum PendingTransaction {
        case none
        case data(callbackID: Int)
    }

    private var pendingTransaction: PendingTransaction = .none

    private func executeTransaction(action: DappAction, callbackID: Int, transaction: UnconfirmedTransaction, type: ConfirmType, server: RPCServer) {
        pendingTransaction = .data(callbackID: callbackID)
        do {
            guard let session = sessionsProvider.session(for: server) else { throw DappBrowserError.serverUnavailable }

            let coordinator = TransactionConfirmationCoordinator(
                presentingViewController: navigationController,
                session: session,
                transaction: transaction,
                configuration: .dappTransaction(confirmType: type),
                analytics: analytics,
                domainResolutionService: domainResolutionService,
                keystore: keystore,
                assetDefinitionStore: assetDefinitionStore,
                tokensService: tokensService,
                networkService: networkService)

            coordinator.delegate = self
            addCoordinator(coordinator)
            coordinator.start(fromSource: .browser)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.prettyError)
        }
    }

    private func ethCall(callbackID: Int, from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String, server: RPCServer) {
        let request = EthCall(server: server, analytics: analytics)
        firstly {
            request.ethCall(from: from, to: to, value: value, data: data)
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

    func open(url: URL, animated: Bool = true) {
        //If users tap on the verified button in the import MagicLink UI, we don't want to treat it as a MagicLink to import and show the UI again. Just open in browser. This check means when we tap MagicLinks in browserOnly mode, the import UI doesn't show up; which is probably acceptable
        if !browserOnly && isMagicLink(url) {
            delegate?.handleUniversalLink(url, forCoordinator: self)
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
            SignMessageCoordinator.promise(analytics: analytics, navigationController: navigationController, keystore: keystore, coordinator: self, signType: type, account: account, source: .dappBrowser, requester: nil)
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
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
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

    private func openDappInBrowser(_ bookmark: BookmarkObject) {
        guard let url = bookmark.url else { return }
        open(url: url, animated: false)
    }

    private func pushOntoNavigationController(viewController: UIViewController, animated: Bool) {
        viewController.navigationItem.setHidesBackButton(true, animated: false)
        viewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(viewController, animated: animated)
    }

    private func addCurrentPageAsBookmark() {
        logAddDapp()
        if let url = currentUrl?.absoluteString, let title = browserViewController.webView.title {
            let bookmark = BookmarkObject(url: url, title: title)
            bookmarksStore.add(bookmarks: [bookmark])

            UINotificationFeedbackGenerator.show(feedbackType: .success)
        } else {
            UINotificationFeedbackGenerator.show(feedbackType: .error)
        }
    }

    private func scanQrCode() {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analytics: analytics, navigationController: navigationController, account: wallet, domainResolutionService: domainResolutionService)
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

    private func isMagicLink(_ url: URL) -> Bool {
        return RPCServer.availableServers.contains { $0.magicLinkHost == url.host }
    }

    func `switch`(toServer server: RPCServer, url: URL? = nil) {
        self.server = server

        let previousUrl = browserNavBar?.url
        //TODO extract method? Clean up
        browserNavBar?.clearDisplay()
        browserNavBar?.configure(server: server)
        start()

        guard let url = url ?? previousUrl else { return }
        open(url: url, animated: false)
    }

    private func addCustomChain(callbackID: Int, customChain: WalletAddEthereumChainObject, inViewController viewController: UIViewController) {
        delegate?.requestAddCustomChain(server: server, callbackId: .dapp(requestId: callbackID), customChain: customChain)
    }

    private func switchChain(callbackID: Int, targetChain: WalletSwitchEthereumChainObject, inViewController viewController: UIViewController) {
        delegate?.requestSwitchChain(server: server, currentUrl: currentUrl, callbackID: .dapp(requestId: callbackID), targetChain: targetChain)
    }
}
// swiftlint:enable type_body_length

extension DappBrowserCoordinator: TransactionConfirmationCoordinatorDelegate {

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
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

            UIApplication.shared
                .presentedViewController(or: strongSelf.navigationController)
                .displayError(message: error.prettyError)
        }
    }

    func notifyFinish(callbackID: Int, value: Swift.Result<DappCallback, DAppError>) {
        browserViewController.notifyFinish(callbackID: callbackID, value: value)
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

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension DappBrowserCoordinator: BrowserViewControllerDelegate {

    func didCall(action: DappAction, callbackID: Int, inBrowserViewController viewController: BrowserViewController) {
        func rejectDappAction() {
            browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            navigationController.topViewController?.displayError(error: ActiveWalletViewModel.Error.onlyWatchAccount)
        }

        func performDappAction(account: AlphaWallet.Address) {
            switch action {
            case .signTransaction(let unconfirmedTransaction):
                executeTransaction(action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: server)
            case .sendTransaction(let unconfirmedTransaction):
                executeTransaction(action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: server)
            case .signMessage(let hexMessage):
                signMessage(with: .message(hexMessage.asSignableMessageData), account: account, callbackID: callbackID)
            case .signPersonalMessage(let hexMessage):
                signMessage(with: .personalMessage(hexMessage.asSignableMessageData), account: account, callbackID: callbackID)
            case .signTypedMessage(let typedData):
                signMessage(with: .typedMessage(typedData), account: account, callbackID: callbackID)
            case .signTypedMessageV3(let typedData):
                signMessage(with: .eip712v3And4(typedData), account: account, callbackID: callbackID)
            case .ethCall(from: let from, to: let to, value: let value, data: let data):
                //Must use unchecked form for `Address `because `from` and `to` might be 0x0..0. We assume the dapp author knows what they are doing
                let from = AlphaWallet.Address(uncheckedAgainstNullAddress: from)
                let to = AlphaWallet.Address(uncheckedAgainstNullAddress: to)
                ethCall(callbackID: callbackID, from: from, to: to, value: value, data: data, server: server)
            case .walletAddEthereumChain(let customChain):
                addCustomChain(callbackID: callbackID, customChain: customChain, inViewController: viewController)
            case .walletSwitchEthereumChain(let targetChain):
                switchChain(callbackID: callbackID, targetChain: targetChain, inViewController: viewController)
            case .unknown, .sendRawTransaction:
                break
            }
        }

        switch wallet.type {
        case .real(let account):
            return performDappAction(account: account)
        case .watch(let account):
            if config.development.shouldPretendIsRealWallet {
                return performDappAction(account: account)
            } else {
                switch action {
                case .signTransaction, .sendTransaction, .signMessage, .signPersonalMessage, .signTypedMessage, .signTypedMessageV3, .unknown, .sendRawTransaction:
                    return rejectDappAction()
                case .walletAddEthereumChain, .walletSwitchEthereumChain, .ethCall:
                    return performDappAction(account: account)
                }
            }
        }
    }

    func didVisitURL(url: URL, title: String, inBrowserViewController viewController: BrowserViewController) {
        browserNavBar?.display(url: url)
        if let mostRecentUrl = browserHistoryStorage.firstHistoryRecord?.url, mostRecentUrl == url {

        } else {
            browserHistoryStorage.addRecord(url: url, title: title)
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
}

extension DappBrowserCoordinator: BrowserHistoryViewControllerDelegate {
    func didSelect(history: BrowserHistoryRecord, in viewController: BrowserHistoryViewController) {
        open(url: history.url)
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
        navigationController.present(alertController, animated: true)
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
        navigationController.present(alertController, animated: true)
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
        navigationController.present(alertController, animated: true)
    }
}

extension DappBrowserCoordinator: BrowserHomeViewControllerDelegate {

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

    func didTapShowMyDappsViewController(in viewController: BrowserHomeViewController) {
        showMyDapps()
    }

    func didTapShowBrowserHistoryViewController(in viewController: BrowserHomeViewController) {
        showBrowserHistory()
    }

    func didTap(bookmark: BookmarkObject, in viewController: BrowserHomeViewController) {
        openDappInBrowser(bookmark)
    }

    func viewWillAppear(in viewController: BrowserHomeViewController) {
        browserNavBar?.enableButtons()
    }

    func dismissKeyboard(in viewController: BrowserHomeViewController) {
        browserNavBar?.cancelEditing()
    }
}

extension DappBrowserCoordinator: BookmarksViewControllerDelegate {

    private func createEditBookmarkViewController(bookmark: BookmarkObject) -> EditBookmarkViewController {
        let viewModel = EditBookmarkViewModel(bookmark: bookmark, bookmarksStore: bookmarksStore)
        let viewController = EditBookmarkViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true

        return viewController
    }

    func didTapToEdit(bookmark: BookmarkObject, in viewController: BookmarksViewController) {
        let viewController = createEditBookmarkViewController(bookmark: bookmark)

        browserNavBar?.setBrowserBar(hidden: true)

        navigationController.pushViewController(viewController, animated: true)
    }

    func didTapToSelect(bookmark: BookmarkObject, in viewController: BookmarksViewController) {
        openDappInBrowser(bookmark)
    }

    func dismissKeyboard(in viewController: BookmarksViewController) {
        browserNavBar?.cancelEditing()
    }
}

extension DappBrowserCoordinator: DappBrowserNavigationBarDelegate {

    func didTapHome(sender: UIView, in navigationBar: DappBrowserNavigationBar) {
        if let url = config.homePageURL {
            open(url: url, animated: true)
        } else {
            browserNavBar?.clearDisplay()
            navigationController.popToRootViewController(animated: true)
        }
    }

    func didTapBack(in navigationBar: DappBrowserNavigationBar) {
        if let browserVC = navigationController.topViewController as? BrowserViewController, browserVC.webView.canGoBack {
            browserViewController.webView.goBack()
        } else if !(browserNavBar?.isBrowserOnly ?? false) {
            navigationController.popViewController(animated: true)
            if navigationController.topViewController is BrowserHomeViewController {
                browserNavBar?.clearDisplay()
            }
        }
    }

    func didTapForward(in navigationBar: DappBrowserNavigationBar) {
        guard let browserVC = navigationController.topViewController as? BrowserViewController, browserVC.webView.canGoForward else { return }
        browserViewController.webView.goForward()
    }

    func didTapMore(sender: UIView, in navigationBar: DappBrowserNavigationBar) {
        logTapMore()
        let alertController = makeMoreAlertSheet(sender: sender)
        navigationController.present(alertController, animated: true)
    }

    func didTapClose(in navigationBar: DappBrowserNavigationBar) {
        dismiss()
    }

    func didTapChangeServer(in navigationBar: DappBrowserNavigationBar) {
        showServers()
    }

    func didTyped(text: String, in navigationBar: DappBrowserNavigationBar) {
        //no-op
    }

    func didEnter(text: String, in navigationBar: DappBrowserNavigationBar) {
        logEnterUrl()
        guard let url = urlParser.url(from: text.trimmed) else { return }
        open(url: url, animated: false)
    }
}

extension DappBrowserCoordinator: EditBookmarkViewControllerDelegate {

    func didSave(in viewController: EditBookmarkViewController) {
        browserNavBar?.setBrowserBar(hidden: false)

        navigationController.popViewController(animated: true)
    }

    func didClose(in viewController: EditBookmarkViewController) {
        browserNavBar?.setBrowserBar(hidden: false)
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
    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator) {
        removeCoordinator(coordinator)

        browserNavBar?.setBrowserBar(hidden: false)

        switch selection {
        case .server(let server):
            switch server {
            case .auto:
                break
            case .server(let server):
                `switch`(toServer: server)
            }
        case .multipleServers:
            break
        }
    }

    func didClose(in coordinator: ServersCoordinator) {
        browserNavBar?.setBrowserBar(hidden: false)

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
        analytics.log(action: Analytics.Action.reloadBrowser)
    }

    private func logShare() {
        analytics.log(action: Analytics.Action.shareUrl, properties: [Analytics.Properties.source.rawValue: "browser"])
    }

    private func logAddDapp() {
        analytics.log(action: Analytics.Action.addDapp)
    }

    private func logSwitchServer() {
        analytics.log(navigation: Analytics.Navigation.switchServers, properties: [Analytics.Properties.source.rawValue: "browser"])
    }

    private func logShowDapps() {
        analytics.log(navigation: Analytics.Navigation.showDapps)
    }

    private func logShowHistory() {
        analytics.log(navigation: Analytics.Navigation.showHistory)
    }

    private func logTapMore() {
        analytics.log(navigation: Analytics.Navigation.tapBrowserMore)
    }

    private func logEnterUrl() {
        analytics.log(action: Analytics.Action.enterUrl)
    }
}

extension DappBrowserCoordinator {
    enum DappBrowserError: Error, LocalizedError {
        case serverUnavailable

        var localizedDescription: String {
            return "RPC Server Unavailable"
        }
    }
}
