// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import UIKit
import BigInt
import TrustKeystore
import RealmSwift
import WebKit

protocol DappBrowserCoordinatorDelegate: class {
    func didSentTransaction(transaction: SentTransaction, inCoordinator coordinator: DappBrowserCoordinator)
}

final class DappBrowserCoordinator: NSObject, Coordinator {
    private let session: WalletSession
    private let keystore: Keystore

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

    lazy var rootViewController: DappsHomeViewController = {
        let vc = DappsHomeViewController(bookmarksStore: bookmarksStore)
        vc.delegate = self
        return vc
    }()

    weak var delegate: DappBrowserCoordinatorDelegate?

    init(
        session: WalletSession,
        keystore: Keystore,
        sharedRealm: Realm
    ) {
        self.navigationController = NavigationController(navigationBarClass: DappBrowserNavigationBar.self, toolbarClass: nil)
        self.session = session
        self.keystore = keystore
        self.sharedRealm = sharedRealm

        super.init()

        (navigationController.navigationBar as? DappBrowserNavigationBar)?.navigationBarDelegate = self
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
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
        coordinator.didCompleted = { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let type):
                switch type {
                case .signedTransaction(let data):
                    let callback = DappCallback(id: callbackID, value: .signTransaction(data))
                    strongSelf.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
                    //TODO do we need to do this for a pending transaction?
//                    strongSelf.delegate?.didSentTransaction(transaction: transaction, inCoordinator: strongSelf)
                case .sentTransaction(let transaction):
                    // on send transaction we pass transaction ID only.
                    let data = Data(hex: transaction.id)
                    let callback = DappCallback(id: callbackID, value: .sentTransaction(data))
                    strongSelf.browserViewController.notifyFinish(callbackID: callbackID, value: .success(callback))
                    strongSelf.delegate?.didSentTransaction(transaction: transaction, inCoordinator: strongSelf)
                }
            case .failure:
                strongSelf.browserViewController.notifyFinish(
                        callbackID: callbackID,
                        value: .failure(DAppError.cancelled)
                )
            }
            coordinator.didCompleted = nil
            strongSelf.removeCoordinator(coordinator)
            strongSelf.navigationController.dismiss(animated: true, completion: nil)
        }
        coordinator.start()
        navigationController.present(coordinator.navigationController, animated: true, completion: nil)
    }

    func open(url: URL, browserOnly: Bool = false, animated: Bool = true) {
        //TODO maybe not the best idea to check like this. Because it will always create the browserViewController twice the first time (or maybe it's ok. Just once)
        if navigationController.topViewController != browserViewController {
            browserViewController = BrowserViewController(account: session.account, config: session.config, server: server)
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

    func signMessage(with type: SignMessageType, account: Account, callbackID: Int) {
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

        let shareAction = UIAlertAction(title: R.string.localizable.share(), style: .default) { [weak self] _ in
            self?.share()
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        let addBookmarkAction = UIAlertAction(title: R.string.localizable.browserAddbookmarkButtonTitle(), style: .default) { [weak self] _ in
            self?.addCurrentPageAsBookmark()
        }
        alertController.addAction(reloadAction)
        alertController.addAction(shareAction)
        alertController.addAction(addBookmarkAction)
        alertController.addAction(cancelAction)
        return alertController
    }

    private func share() {
        guard let url = browserViewController.webView.url else { return }
        rootViewController.displayLoading()
        rootViewController.showShareActivity(from: UIView(), with: [url]) { [weak self] in
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

    private func showDappSuggestions(forText text: String) {
        if let viewController = navigationController.topViewController as? DappsAutoCompletionViewController {
            let hasResults = viewController.filter(withText: text)
            if !hasResults {
                navigationController.popViewController(animated: false)
            }
        } else {
            let viewController = DappsAutoCompletionViewController()
            viewController.delegate = self
            let hasResults = viewController.filter(withText: text)
            if hasResults {
                pushOntoNavigationController(viewController: viewController, animated: false)
            }
        }
    }

    private func pushOntoNavigationController(viewController: UIViewController, animated: Bool) {
        viewController.navigationItem.setHidesBackButton(true, animated: false)
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
        guard let url = browserViewController.webView.url?.absoluteString else { return }
        guard let title = browserViewController.webView.title else { return }
        let bookmark = Bookmark(url: url, title: title)
        bookmarksStore.add(bookmarks: [bookmark])
        refreshDapps()
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
            executeTransaction(account: account, action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: browserViewController.server)
        case .sendTransaction(let unconfirmedTransaction):
            executeTransaction(account: account, action: action, callbackID: callbackID, transaction: unconfirmedTransaction, type: .signThenSend, server: browserViewController.server)
        case .signMessage(let hexMessage):
            let msg = convertMessageToHex(msg: hexMessage)
            signMessage(with: .message(Data(hex: msg)), account: account, callbackID: callbackID)
        case .signPersonalMessage(let hexMessage):
            let msg = convertMessageToHex(msg: hexMessage)
            signMessage(with: .personalMessage(Data(hex: msg)), account: account, callbackID: callbackID)
        case .signTypedMessage(let typedData):
            signMessage(with: .typedMessage(typedData), account: account, callbackID: callbackID)
        case .unknown:
            break
        }
    }

    //allow the message to be passed in as a pure string, if it is then we convert it to hex
    private func convertMessageToHex(msg: String) -> String {
        if msg.hasPrefix("0x") {
            return msg
        } else {
            return msg.hex
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
}

extension DappBrowserCoordinator: SignMessageCoordinatorDelegate {
    func didCancel(in coordinator: SignMessageCoordinator) {
        coordinator.didComplete = nil
        removeCoordinator(coordinator)
    }
}

extension DappBrowserCoordinator: ConfirmCoordinatorDelegate {
    func didCancel(in coordinator: ConfirmCoordinator) {
        navigationController.dismiss(animated: true, completion: nil)
        coordinator.didCompleted = nil
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
        let vc = EditMyDappViewController()
        vc.delegate = self
        vc.configure(viewModel: .init(dapp: dapp))
        vc.hidesBottomBarWhenPushed = true
        navigationController.present(vc, animated: true)
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

    func didTapHome(inNavigationBar navigationBar: DappBrowserNavigationBar) {
        navigationController.popToRootViewController(animated: true)
        browserNavBar?.clearDisplay()
    }

    func didTyped(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar) {
        let text = text.trimmed
        if text.isEmpty {
            if navigationController.topViewController as? DappsAutoCompletionViewController != nil {
                navigationController.popViewController(animated: false)
            }
        } else {
            showDappSuggestions(forText: text)
        }
    }

    func didEnter(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar) {
        guard let url = urlParser.url(from: text) else { return }
        open(url: url, animated: false)
    }
}

extension DappBrowserCoordinator: EditMyDappViewControllerDelegate {
    func didTapSave(dapp: Bookmark, withTitle title: String, url: String, inViewController viewController: EditMyDappViewController) {
        try? sharedRealm.write {
            dapp.title = title
            dapp.url = url
        }
        viewController.dismiss(animated: true)
        refreshDapps()
    }

    func didTapCancel(inViewController viewController: EditMyDappViewController) {
        viewController.dismiss(animated: true)
    }
}
