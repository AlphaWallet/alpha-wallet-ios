// Copyright DApps Platform Inc. All rights reserved.

import UIKit
import WebKit
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit
import RealmSwift
import Result

protocol DappBrowserCoordinatorDelegate: class {
    func didSentTransaction(transaction: SentTransaction, inCoordinator coordinator: DappBrowserCoordinator)
    func importUniversalLink(url: URL, forCoordinator coordinator: DappBrowserCoordinator)
    func handleUniversalLink(_ url: URL, forCoordinator coordinator: DappBrowserCoordinator)
}

final class DappBrowserCoordinator: NSObject, Coordinator {
    private var session: WalletSession {
        return sessions[server]
    }
    private let sessions: ServerDictionary<WalletSession>
    private let keystore: Keystore
    private let config: Config
    private let analyticsCoordinator: AnalyticsCoordinator
    private var browserNavBar: DappBrowserNavigationBar? {
        return navigationController.navigationBar as? DappBrowserNavigationBar
    }

    private lazy var historyViewController: BrowserHistoryViewController = {
        let controller = BrowserHistoryViewController(store: historyStore)
        controller.configure(viewModel: HistoriesViewModel(store: historyStore))
        controller.delegate = self
        return controller
    }()

    private lazy var browserViewController: BrowserViewController = {
        let controller = BrowserViewController(account: session.account, server: server)
        controller.delegate = self
        controller.webView.uiDelegate = self
        return controller
    }()

    private let sharedRealm: Realm
    private let browserOnly: Bool
    private let nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>

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
        let engine = SearchEngine(rawValue: preferences.get(for: .browserSearchEngine)) ?? .default
        return BrowserURLParser(engine: engine)
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

    private var hasWebPageLoaded: Bool {
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
        analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.navigationController = UINavigationController(navigationBarClass: DappBrowserNavigationBar.self, toolbarClass: nil)
        self.sessions = sessions
        self.keystore = keystore
        self.config = config
        self.sharedRealm = sharedRealm
        self.browserOnly = browserOnly
        self.nativeCryptoCurrencyPrices = nativeCryptoCurrencyPrices
        self.analyticsCoordinator = analyticsCoordinator

        super.init()

        //Necessary so that some sites don't bleed into (under) navigation bar after we tweak global styles for navigationBars after adding large title support
        self.navigationController.navigationBar.isTranslucent = false

        browserNavBar?.navigationBarDelegate = self
        browserNavBar?.configure(server: server)
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    @objc func dismiss() {
        removeAllCoordinators()
        navigationController.dismiss(animated: true)
    }

    private enum PendingTransaction {
        case none
        case data(callbackID: Int)
    }

    private var pendingTransaction: PendingTransaction = .none

    private func executeTransaction(account: AlphaWallet.Address, action: DappAction, callbackID: Int, transaction: UnconfirmedTransaction, type: ConfirmType, server: RPCServer) {
        pendingTransaction = .data(callbackID: callbackID)
        let ethPrice = nativeCryptoCurrencyPrices[server]
        let coordinator = TransactionConfirmationCoordinator(navigationController: navigationController, session: session, transaction: transaction, configuration: .dappTransaction(confirmType: type, keystore: keystore, ethPrice: ethPrice), analyticsCoordinator: analyticsCoordinator)
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
            if case let SessionTaskError.responseError(JSONRPCError.responseError(e)) = error {
                self.browserViewController.notifyFinish(callbackID: callbackID, value: .failure(.nodeError(e.message)))
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

        //TODO maybe not the best idea to check like this. Because it will always create the browserViewController twice the first time (or maybe it's ok. Just once)
        if navigationController.topViewController != browserViewController {
            browserViewController = BrowserViewController(account: session.account, server: server)
            browserViewController.delegate = self
            browserViewController.webView.uiDelegate = self
            pushOntoNavigationController(viewController: browserViewController, animated: animated)
        }
        browserNavBar?.display(url: url)
        if browserOnly {
            browserNavBar?.makeBrowserOnly()
        }

        browserViewController.goTo(url: url)
    }

    func signMessage(with type: SignMessageType, account: AlphaWallet.Address, callbackID: Int) {
        let coordinator = SignMessageCoordinator(
            navigationController: navigationController,
            keystore: keystore,
            account: account
        )
        coordinator.didComplete = { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let data):
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
                strongSelf.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
            case .failure:
                strongSelf.browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            }
            coordinator.didComplete = nil
            strongSelf.removeCoordinator(coordinator)
        }
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(with: type)
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
            self?.browserViewController.reload()
        }
        reloadAction.isEnabled = hasWebPageLoaded

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

        alertController.addAction(reloadAction)
        alertController.addAction(shareAction)
        alertController.addAction(addBookmarkAction)
        alertController.addAction(switchNetworkAction)
        if browserOnly {
            //no-op
        } else {
            alertController.addAction(scanQrCodeAction)
        }
        alertController.addAction(cancelAction)
        return alertController
    }

    private func share(sender: UIView) {
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
        return RPCServer.allCases.contains { $0.magicLinkHost == url.host }
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

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: TransactionConfirmationResult) {
        coordinator.close { [weak self] in
            guard let strongSelf = self, let delegate = strongSelf.delegate else { return }

            switch (strongSelf.pendingTransaction, result) {
            case (.data(let callbackID), .confirmationResult(let type)):
                switch type {
                case .signedTransaction(let data):
                    let callback = DappCallback(id: callbackID, value: .signTransaction(data))
                    strongSelf.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
                    //TODO do we need to do this for a pending transaction?
    //                    strongSelf.delegate?.didSentTransaction(transaction: transaction, inCoordinator: strongSelf)
                case .sentTransaction(let transaction):
                    // on send transaction we pass transaction ID only.
                    let data = Data(_hex: transaction.id)
                    let callback = DappCallback(id: callbackID, value: .sentTransaction(data))
                    strongSelf.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))

                    delegate.didSentTransaction(transaction: transaction, inCoordinator: strongSelf)
                case .sentRawTransaction:
                    break
                }
            case (.none, .noData), (.none, .confirmationResult), (.data, .noData):
                break
            }

            strongSelf.removeCoordinator(coordinator)
            strongSelf.navigationController.dismiss(animated: true)
        }
    }
}

extension DappBrowserCoordinator: BrowserViewControllerDelegate {
    func didCall(action: DappAction, callbackID: Int, inBrowserViewController viewController: BrowserViewController) {
        guard case .real(let account) = session.account.type else {
            browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            navigationController.topViewController?.displayError(error: InCoordinatorError.onlyWatchAccount)
            return
        }

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
        case .unknown, .sendRawTransaction:
            break
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
}

extension DappBrowserCoordinator: SignMessageCoordinatorDelegate {
    func didCancel(in coordinator: SignMessageCoordinator) {
        coordinator.didComplete = nil
        removeCoordinator(coordinator)
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
    func didTapShowMyDappsViewController(inViewController viewController: DappsHomeViewController) {
        let viewController = MyDappsViewController(bookmarksStore: bookmarksStore)
        viewController.configure(viewModel: .init(bookmarksStore: bookmarksStore))
        viewController.delegate = self
        pushOntoNavigationController(viewController: viewController, animated: true)
    }

    func didTapShowBrowserHistoryViewController(inViewController viewController: DappsHomeViewController) {
        pushOntoNavigationController(viewController: historyViewController, animated: true)
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
    func didTapToEdit(dapp: Bookmark, inViewController viewController: MyDappsViewController) {
        let viewController = EditMyDappViewController()
        viewController.delegate = self
        viewController.configure(viewModel: .init(dapp: dapp))
        viewController.hidesBottomBarWhenPushed = true

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
        let alertController = makeMoreAlertSheet(sender: sender)
        navigationController.present(alertController, animated: true, completion: nil)
    }

    func didTapClose(inNavigationBar navigationBar: DappBrowserNavigationBar) {
        dismiss()
    }

    func didTapChangeServer(inNavigationBar navigationBar: DappBrowserNavigationBar) {
        showServers()
    }

    func didTyped(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar) {
        let text = text.trimmed
        if text.isEmpty {
            if navigationController.topViewController as? DappsAutoCompletionViewController != nil {
                navigationController.popViewController(animated: false)
            }
        }
    }

    func didEnter(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar) {
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
            coordinator.navigationController.popViewController(animated: true)
            removeCoordinator(coordinator)
            `switch`(toServer: server)
        }
    }

    func didSelectDismiss(in coordinator: ServersCoordinator) {
        browserNavBar?.setBrowserBar(hidden: false)

        coordinator.navigationController.popViewController(animated: true)

        removeCoordinator(coordinator)
    }
}
