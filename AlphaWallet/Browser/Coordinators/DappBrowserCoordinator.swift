// Copyright DApps Platform Inc. All rights reserved.

import UIKit
import WebKit
import AlphaWalletFoundation
import Combine
import AlphaWalletCore

protocol DappBrowserCoordinatorDelegate: DappRequesterDelegate, CanOpenURL {
    func handleUniversalLink(_ url: URL, forCoordinator coordinator: DappBrowserCoordinator)
}

// swiftlint:disable type_body_length
final class DappBrowserCoordinator: NSObject, Coordinator {
    private let sessionsProvider: SessionsProvider
    private var config: Config
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private var browserNavBar: DappBrowserNavigationBar? {
        return navigationController.navigationBar as? DappBrowserNavigationBar
    }
    private let wallet: Wallet
    private lazy var browserViewController: BrowserViewController = createBrowserViewController()
    private let browserOnly: Bool
    private let bookmarksStore: BookmarksStore
    private let browserHistoryStorage: BrowserHistoryStorage
    private var urlParser: BrowserURLParser {
        return BrowserURLParser()
    }
    private let serversProvider: ServersProvidable
    private var cancellable = Set<AnyCancellable>()
    private var server: RPCServer {
        get { return serversProvider.browserRpcServer }
        set { serversProvider.browserRpcServer = newValue }
    }
    private let networkService: NetworkService
    private var enableToolbar: Bool = true {
        didSet { navigationController.isToolbarHidden = !enableToolbar }
    }
    private var currentUrl: URL? { browserViewController.webView.url }

    var hasWebPageLoaded: Bool { currentUrl != nil }

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
         config: Config,
         browserOnly: Bool,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType,
         bookmarksStore: BookmarksStore,
         browserHistoryStorage: BrowserHistoryStorage,
         wallet: Wallet,
         networkService: NetworkService,
         serversProvider: ServersProvidable) {

        self.serversProvider = serversProvider
        self.networkService = networkService
        self.wallet = wallet
        self.navigationController = NavigationController(navigationBarClass: DappBrowserNavigationBar.self, toolbarClass: nil)
        self.sessionsProvider = sessionsProvider
        self.config = config
        self.bookmarksStore = bookmarksStore
        self.browserHistoryStorage = browserHistoryStorage
        self.browserOnly = browserOnly
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        super.init()
        //Necessary so that some sites don't bleed into (under) navigation bar after we tweak global styles for navigationBars after adding large title support
        navigationController.navigationBar.isTranslucent = false

        browserNavBar?.navigationBarDelegate = self
        browserNavBar?.configure(server: server)
    }

    func start() {
        //If we hit a bug where the stack doesn't change immediately, be sure that we haven't changed the stack (eg. push/pop) with animation and it hasn't completed yet
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
        let viewModel = BrowserViewModel(
            wallet: wallet,
            server: server,
            browserOnly: browserOnly)

        let browserViewController = BrowserViewController(viewModel: viewModel)
        browserViewController.delegate = self
        browserViewController.webView.uiDelegate = self

        return browserViewController
    }

    private func requestSignTransaction(session: WalletSession,
                                        delegate: DappBrowserCoordinatorDelegate,
                                        callbackId: Int,
                                        transaction: UnconfirmedTransaction) {

        delegate.requestSignTransaction(session: session, source: .browser, requester: nil, transaction: transaction, configuration: .dappTransaction(confirmType: .sign))
            .sink(receiveCompletion: { [browserViewController] result in
                guard case .failure = result else { return }
                browserViewController.notifyFinish(callbackId: callbackId, value: .failure(.responseError))
            }, receiveValue: { [browserViewController] data in
                let callback = DappCallback(id: callbackId, value: .signTransaction(data))
                browserViewController.notifyFinish(callbackId: callbackId, value: .success(callback))
            }).store(in: &cancellable)
    }

    private func requestSendTransaction(session: WalletSession,
                                        delegate: DappBrowserCoordinatorDelegate,
                                        callbackId: Int,
                                        transaction: UnconfirmedTransaction) {

        delegate.requestSendTransaction(session: session, source: .browser, requester: nil, transaction: transaction, configuration: .dappTransaction(confirmType: .signThenSend))
            .sink(receiveCompletion: { [browserViewController] result in
                guard case .failure = result else { return }
                browserViewController.notifyFinish(callbackId: callbackId, value: .failure(.responseError))
            }, receiveValue: { [browserViewController] transaction in
                let callback = DappCallback(id: callbackId, value: .sentTransaction(Data(_hex: transaction.id)))
                browserViewController.notifyFinish(callbackId: callbackId, value: .success(callback))
            }).store(in: &cancellable)
    }

    private func requestEthCall(session: WalletSession,
                                delegate: DappBrowserCoordinatorDelegate,
                                callbackId: Int,
                                from: AlphaWallet.Address?,
                                to: AlphaWallet.Address?,
                                value: String?,
                                data: String) {

        delegate.requestEthCall(from: from, to: to, value: value, data: data, source: .dappBrowser, session: session)
            .sink(receiveCompletion: { [browserViewController] result in
                guard case .failure(let error) = result else { return }

                if case JSONRPCError.responseError(let code, let message, _) = error.embedded {
                    browserViewController.notifyFinish(callbackId: callbackId, value: .failure(.init(code: code, message: message)))
                } else {
                    //TODO better handle. User didn't cancel
                    browserViewController.notifyFinish(callbackId: callbackId, value: .failure(.responseError))
                }

            }, receiveValue: { [browserViewController] value in
                let callback = DappCallback(id: callbackId, value: .ethCall(value))
                browserViewController.notifyFinish(callbackId: callbackId, value: .success(callback))
            }).store(in: &cancellable)
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

    private func validateMessage(session: WalletSession, message: SignMessageType) -> AnyPublisher<Void, PromiseError> {
        do {
            switch message {
            case .eip712v3And4(let typedData):
                let validator = DappOrTokenScriptEip712v3And4Validator(server: session.server, source: .dappBrowser)
                try validator.validate(message: typedData)
            case .typedMessage(let typedData):
                let validator = TypedMessageValidator()
                try validator.validate(message: typedData)
            case .message, .personalMessage:
                break
            }
            return .just(())
        } catch {
            return .fail(PromiseError(error: error))
        }
    }

    private func requestSignMessage(session: WalletSession,
                                    delegate: DappBrowserCoordinatorDelegate,
                                    message: SignMessageType,
                                    callbackId: Int) {

        validateMessage(session: session, message: message)
            .flatMap { _ in
                delegate.requestSignMessage(
                    message: message,
                    server: session.server,
                    account: session.account.address,
                    source: .dappBrowser,
                    requester: nil)
            }.sink(receiveCompletion: { [browserViewController] result in
                guard case .failure = result else { return }
                browserViewController.notifyFinish(callbackId: callbackId, value: .failure(.responseError))
            }, receiveValue: { [browserViewController] data in
                let callback: DappCallback
                switch message {
                case .message:
                    callback = DappCallback(id: callbackId, value: .signMessage(data))
                case .personalMessage:
                    callback = DappCallback(id: callbackId, value: .signPersonalMessage(data))
                case .typedMessage:
                    callback = DappCallback(id: callbackId, value: .signTypedMessage(data))
                case .eip712v3And4:
                    callback = DappCallback(id: callbackId, value: .signEip712v3And4(data))
                }

                browserViewController.notifyFinish(callbackId: callbackId, value: .success(callback))
            }).store(in: &cancellable)
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

        let coordinator = ScanQRCodeCoordinator(
            analytics: analytics,
            navigationController: navigationController,
            account: wallet,
            domainResolutionService: domainResolutionService)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .browserScreen)
    }

    private func showServers() {
        logSwitchServer()

        let coordinator = ServersCoordinator(
            defaultServer: server,
            serversProvider: serversProvider,
            navigationController: navigationController)

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

    private func requestAddCustomChain(session: WalletSession,
                                       delegate: DappBrowserCoordinatorDelegate,
                                       callbackId: Int,
                                       customChain: WalletAddEthereumChainObject) {

        delegate.requestAddCustomChain(server: server, customChain: customChain)
            .sink(receiveCompletion: { [weak self] result in
                guard case .failure(let e) = result else { return }
                let error = e.embedded as? JsonRpcError ?? .internalError

                self?.notifyFinish(callbackId: callbackId, value: .failure(error))
            }, receiveValue: { [weak self] operation in
                switch operation {
                case .notifySuccessful:
                    let callback = DappCallback(id: callbackId, value: .walletAddEthereumChain)
                    self?.notifyFinish(callbackId: callbackId, value: .success(callback))
                case .switchBrowserToExistingServer:
                    break //no-op handled in parent
                case .restartToEnableAndSwitchBrowserToServer:
                    break
                case .restartToAddEnableAndSwitchBrowserToServer:
                    guard let server = customChain.server else { return }
                    self?.switch(toServer: server)
                }
            }).store(in: &cancellable)
    }

    private func requestSwitchChain(session: WalletSession,
                                    delegate: DappBrowserCoordinatorDelegate,
                                    callbackId: Int,
                                    targetChain: WalletSwitchEthereumChainObject) {

        delegate.requestSwitchChain(server: server, currentUrl: currentUrl, targetChain: targetChain)
            .sink(receiveCompletion: { [weak self] result in
                guard case .failure(let e) = result else { return }
                let error = e.embedded as? JsonRpcError ?? .internalError

                self?.notifyFinish(callbackId: callbackId, value: .failure(error))
            }, receiveValue: { [weak self] operation in
                switch operation {
                case .notifySuccessful:
                    let callback = DappCallback(id: callbackId, value: .walletSwitchEthereumChain)
                    self?.notifyFinish(callbackId: callbackId, value: .success(callback))
                case .switchBrowserToExistingServer(let server, let url):
                    self?.switch(toServer: server, url: url)
                case .restartToEnableAndSwitchBrowserToServer:
                    break
                }
            }).store(in: &cancellable)
    }

    private func notifyFinish(callbackId: Int, value: Swift.Result<DappCallback, JsonRpcError>) {
        browserViewController.notifyFinish(callbackId: callbackId, value: value)
    }
}
// swiftlint:enable type_body_length

extension DappBrowserCoordinator: BrowserViewControllerDelegate {

    private func performDappAction(action: DappAction,
                                   callbackId: Int,
                                   session: WalletSession,
                                   delegate: DappBrowserCoordinatorDelegate) {
        switch action {
        case .signTransaction(let unconfirmedTransaction):
            requestSignTransaction(
                session: session,
                delegate: delegate,
                callbackId: callbackId,
                transaction: unconfirmedTransaction)
        case .sendTransaction(let unconfirmedTransaction):
            requestSendTransaction(
                session: session,
                delegate: delegate,
                callbackId: callbackId,
                transaction: unconfirmedTransaction)
        case .signMessage(let hexMessage):
            requestSignMessage(
                session: session,
                delegate: delegate,
                message: .message(hexMessage.asSignableMessageData),
                callbackId: callbackId)
        case .signPersonalMessage(let hexMessage):
            requestSignMessage(
                session: session,
                delegate: delegate,
                message: .personalMessage(hexMessage.asSignableMessageData),
                callbackId: callbackId)
        case .signTypedMessage(let typedData):
            requestSignMessage(
                session: session,
                delegate: delegate,
                message: .typedMessage(typedData),
                callbackId: callbackId)
        case .signEip712v3And4(let typedData):

            requestSignMessage(
                session: session,
                delegate: delegate,
                message: .eip712v3And4(typedData),
                callbackId: callbackId)
        case .ethCall(from: let from, to: let to, value: let value, data: let data):
            //Must use unchecked form for `Address `because `from` and `to` might be 0x0..0. We assume the dapp author knows what they are doing
            let from = AlphaWallet.Address(uncheckedAgainstNullAddress: from)
            let to = AlphaWallet.Address(uncheckedAgainstNullAddress: to)
            requestEthCall(
                session: session,
                delegate: delegate,
                callbackId: callbackId,
                from: from,
                to: to,
                value: value,
                data: data)
        case .walletAddEthereumChain(let customChain):
            requestAddCustomChain(
                session: session,
                delegate: delegate,
                callbackId: callbackId,
                customChain: customChain)
        case .walletSwitchEthereumChain(let targetChain):
            requestSwitchChain(
                session: session,
                delegate: delegate,
                callbackId: callbackId,
                targetChain: targetChain)
        case .unknown, .sendRawTransaction:
            break
        }
    }

    func didCall(action: DappAction, callbackId: Int, in viewController: BrowserViewController) {
        guard let session = sessionsProvider.session(for: server) else {
            browserViewController.notifyFinish(callbackId: callbackId, value: .failure(.requestRejected))
            return
        }
        guard let delegate = delegate else {
            browserViewController.notifyFinish(callbackId: callbackId, value: .failure(.requestRejected))
            return
        }

        func rejectDappAction() {
            browserViewController.notifyFinish(callbackId: callbackId, value: .failure(JsonRpcError.requestRejected))
            navigationController.topViewController?.displayError(error: ActiveWalletViewModel.Error.onlyWatchAccount)
        }

        switch wallet.type {
        case .real, .hardware:
            performDappAction(action: action, callbackId: callbackId, session: session, delegate: delegate)
        case .watch:
            if config.development.shouldPretendIsRealWallet {
                performDappAction(action: action, callbackId: callbackId, session: session, delegate: delegate)
            } else {
                switch action {
                case .signTransaction, .sendTransaction, .signMessage, .signPersonalMessage, .signTypedMessage, .signEip712v3And4, .unknown, .sendRawTransaction:
                    rejectDappAction()
                case .walletAddEthereumChain, .walletSwitchEthereumChain, .ethCall:
                    performDappAction(action: action, callbackId: callbackId, session: session, delegate: delegate)
                }
            }
        }
    }

    func didVisitURL(url: URL, title: String, in viewController: BrowserViewController) {
        browserNavBar?.display(url: url)
        if let mostRecentUrl = browserHistoryStorage.firstHistoryRecord?.url, mostRecentUrl == url {

        } else {
            browserHistoryStorage.addRecord(url: url, title: title)
        }
    }

    func dismissKeyboard(in viewController: BrowserViewController) {
        browserNavBar?.cancelEditing()
    }

    func forceUpdate(url: URL, in viewController: BrowserViewController) {
        browserNavBar?.display(url: url)
    }

    func handleUniversalLink(_ url: URL, in viewController: BrowserViewController) {
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
            in: navigationController)
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
            in: navigationController)
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
            in: navigationController)
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

    func didScan(result: String, decodedValue: QrCodeValue, in coordinator: ScanQRCodeCoordinator) {
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

        var errorDescription: String? {
            return "RPC Server Unavailable"
        }
    }
}
