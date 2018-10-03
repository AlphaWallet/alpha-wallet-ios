// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import UIKit
import BigInt
import TrustKeystore
import RealmSwift
import WebKit

protocol BrowserCoordinatorDelegate: class {
    func didSentTransaction(transaction: SentTransaction, in coordinator: BrowserCoordinator)
    func didPressCloseButton(in coordinator: BrowserCoordinator)
}

final class BrowserCoordinator: NSObject, Coordinator {
    private let session: WalletSession
    private let keystore: Keystore

    private lazy var bookmarksViewController: BookmarkViewController = {
        let controller = BookmarkViewController(bookmarksStore: bookmarksStore)
        controller.delegate = self
        return controller
    }()

    private lazy var historyViewController: HistoryViewController = {
        let controller = HistoryViewController(store: historyStore)
        controller.delegate = self
        return controller
    }()

    private lazy var browserViewController: BrowserViewController = {
        let controller = BrowserViewController(account: session.account, config: session.config, server: server)
        controller.delegate = self
        controller.webView.uiDelegate = self
        return controller
    }()
    private let sharedRealm: Realm
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
        return session.config.server
    }
    private var enableToolbar: Bool = true {
        didSet {
            navigationController.isToolbarHidden = !enableToolbar
        }
    }

    var coordinators: [Coordinator] = []
    let navigationController: NavigationController

    lazy var rootViewController: MasterBrowserViewController = {
        let controller = MasterBrowserViewController(
            bookmarksViewController: bookmarksViewController,
            historyViewController: historyViewController,
            browserViewController: browserViewController,
            type: .browser
        )
        controller.delegate = self
        return controller
    }()

    weak var delegate: BrowserCoordinatorDelegate?

    init(
        session: WalletSession,
        keystore: Keystore,
        sharedRealm: Realm
    ) {
        self.navigationController = NavigationController(navigationBarClass: BrowserNavigationBar.self, toolbarClass: nil)
        self.session = session
        self.keystore = keystore
        self.sharedRealm = sharedRealm
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
        rootViewController.browserViewController.goHome()
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    private func executeTransaction(account: Account, action: DappAction, callbackID: Int, transaction: UnconfirmedTransaction, type: ConfirmType, server: RPCServer) {
        let configurator = TransactionConfigurator(
            session: session,
            account: account,
            transaction: transaction
        )
        let coordinator = ConfirmCoordinator(
            session: session,
            configurator: configurator,
            keystore: keystore,
            account: account,
            type: type
        )
        addCoordinator(coordinator)
        coordinator.didCompleted = { [unowned self] result in
            switch result {
            case .success(let type):
                switch type {
                case .signedTransaction(let data):
                    let callback = DappCallback(id: callbackID, value: .signTransaction(data))
                    self.rootViewController.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
                    //TODO do we need to do this for a pending transaction?
//                    self.delegate?.didSentTransaction(transaction: transaction, in: self)
                case .sentTransaction(let transaction):
                    // on send transaction we pass transaction ID only.
                    let data = Data(hex: transaction.id)
                    let callback = DappCallback(id: callbackID, value: .sentTransaction(data))
                    self.rootViewController.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
                    self.delegate?.didSentTransaction(transaction: transaction, in: self)
                }
            case .failure:
                self.rootViewController.browserViewController.notifyFinish(
                    callbackID: callbackID,
                    value: .failure(DAppError.cancelled)
                )
            }
            coordinator.didCompleted = nil
            self.removeCoordinator(coordinator)
            self.navigationController.dismiss(animated: true, completion: nil)
        }
        coordinator.start()
        navigationController.present(coordinator.navigationController, animated: true, completion: nil)
    }

    func openURL(_ url: URL) {
        rootViewController.browserViewController.goTo(url: url)
        handleToolbar(for: url)
    }

    func handleToolbar(for url: URL) {
        let isToolbarHidden = url.absoluteString != Constants.dappsBrowserURL
        navigationController.isToolbarHidden = isToolbarHidden

        if isToolbarHidden {
            rootViewController.select(viewType: .browser)
        }
    }

    func signMessage(with type: SignMesageType, account: Account, callbackID: Int) {
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
                }
                strongSelf.rootViewController.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
            case .failure:
                strongSelf.rootViewController.browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            }
            coordinator.didComplete = nil
            strongSelf.removeCoordinator(coordinator)
        }
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(with: type)
    }

    func presentQRCodeReader() {
        let coordinator = ScanQRCodeCoordinator(
            navigationController: NavigationController()
        )
        coordinator.delegate = self
        addCoordinator(coordinator)
        navigationController.present(coordinator.qrcodeController, animated: true, completion: nil)
    }

    private func presentMoreOptions(sender: UIView) {
        let alertController = makeMoreAlertSheet(sender: sender)
        navigationController.present(alertController, animated: true, completion: nil)
    }

    private func makeMoreAlertSheet(sender: UIView) -> UIAlertController {
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.centerRect
        let reloadAction = UIAlertAction(title: R.string.localizable.reload(), style: .default) { [unowned self] _ in
            self.rootViewController.browserViewController.reload()
        }
        let shareAction = UIAlertAction(title: R.string.localizable.share(), style: .default) { [unowned self] _ in
            self.share()
        }
        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        let addBookmarkAction = UIAlertAction(title: R.string.localizable.browserAddbookmarkButtonTitle(), style: .default) { [unowned self] _ in
            self.rootViewController.browserViewController.addBookmark()
        }
        alertController.addAction(reloadAction)
        alertController.addAction(shareAction)
        alertController.addAction(addBookmarkAction)
        alertController.addAction(cancelAction)
        return alertController
    }

    private func share() {
        guard let url = rootViewController.browserViewController.webView.url else { return }
        rootViewController.displayLoading()
        rootViewController.showShareActivity(from: UIView(), with: [url]) { [weak self] in
            self?.rootViewController.hideLoading()
        }
    }
}

extension BrowserCoordinator: BrowserViewControllerDelegate {
    func runAction(action: BrowserAction) {
        switch action {
        case .bookmarks:
            rootViewController.select(viewType: .bookmarks)
        case .addBookmark(let bookmark):
            bookmarksStore.add(bookmarks: [bookmark])
        case .qrCode:
            presentQRCodeReader()
        case .history:
            rootViewController.select(viewType: .history)
        case .navigationAction(let navAction):
            switch navAction {
            case .home:
                enableToolbar = true
                rootViewController.select(viewType: .browser)
                rootViewController.browserViewController.goHome()
            case .close:
                delegate?.didPressCloseButton(in: self)
            case .more(let sender):
                presentMoreOptions(sender: sender)
            case .enter(let string):
                guard let url = urlParser.url(from: string) else { return }
                openURL(url)
            case .goBack:
                rootViewController.browserViewController.webView.goBack()
            case .beginEditing:
                break
}
        case .changeURL(let url):
            handleToolbar(for: url)
        }
    }

    func didCall(action: DappAction, callbackID: Int) {
        guard case .real(let account) = session.account.type else {
            rootViewController.browserViewController.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            navigationController.topViewController?.displayError(error: InCoordinatorError.onlyWatchAccount)
            return
        }
        switch action {
        case .signTransaction(let unconfirmedTransaction):
            executeTransaction(account: account, action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: browserViewController.server)
        case .sendTransaction(let unconfirmedTransaction):
            executeTransaction(account: account, action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: browserViewController.server)
        case .signMessage(let hexMessage):
            signMessage(with: .message(Data(hex: hexMessage)), account: account, callbackID: callbackID)
        case .signPersonalMessage(let hexMessage):
            signMessage(with: .personalMessage(Data(hex: hexMessage)), account: account, callbackID: callbackID)
        case .signTypedMessage(let typedData):
            signMessage(with: .typedMessage(typedData), account: account, callbackID: callbackID)
        case .unknown:
            break
        }
    }

    func didVisitURL(url: URL, title: String) {
        historyStore.record(url: url, title: title)
    }
}

extension BrowserCoordinator: SignMessageCoordinatorDelegate {
    func didCancel(in coordinator: SignMessageCoordinator) {
        coordinator.didComplete = nil
        removeCoordinator(coordinator)
    }
}

extension BrowserCoordinator: ConfirmCoordinatorDelegate {
    func didCancel(in coordinator: ConfirmCoordinator) {
        navigationController.dismiss(animated: true, completion: nil)
        coordinator.didCompleted = nil
        removeCoordinator(coordinator)
    }
}

extension BrowserCoordinator: ScanQRCodeCoordinatorDelegate {
    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
        guard let url = URL(string: result) else {
            return
        }
        openURL(url)
    }
}

extension BrowserCoordinator: BookmarkViewControllerDelegate {
    func didSelectBookmark(_ bookmark: Bookmark, in viewController: BookmarkViewController) {
        guard let url = bookmark.linkURL else {
            return
        }
        openURL(url)
    }
}

extension BrowserCoordinator: HistoryViewControllerDelegate {
    func didSelect(history: History, in controller: HistoryViewController) {
        guard let url = history.URL else {
            return
        }
        openURL(url)
    }
}

extension BrowserCoordinator: WKUIDelegate {
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

extension BrowserCoordinator: MasterBrowserViewControllerDelegate {
    func didPressAction(_ action: BrowserToolbarAction) {
        switch action {
        case .view(let viewType):
            switch viewType {
            case .bookmarks:
                break
            case .history:
                break
            case .browser:
                break
            }
        case .qrCode:
            presentQRCodeReader()
        }
    }
}
