// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import UIKit
import WebKit
import JavaScriptCore
import AlphaWalletFoundation

protocol BrowserViewControllerDelegate: AnyObject {
    func didCall(action: DappAction, callbackID: Int, inBrowserViewController viewController: BrowserViewController)
    func didVisitURL(url: URL, title: String, inBrowserViewController viewController: BrowserViewController)
    func dismissKeyboard(inBrowserViewController viewController: BrowserViewController)
    func forceUpdate(url: URL, inBrowserViewController viewController: BrowserViewController)
    func handleUniversalLink(_ url: URL, inBrowserViewController viewController: BrowserViewController)
}

final class BrowserViewController: UIViewController {
    private let account: Wallet
    private let server: RPCServer

    private struct Keys {
        static let estimatedProgress = "estimatedProgress"
        static let developerExtrasEnabled = "developerExtrasEnabled"
        static let URL = "URL"
        static let ClientName = "AlphaWallet"
    }

    private lazy var userClient: String = {
        Keys.ClientName + "/" + (Bundle.main.versionNumber ?? "") + " 1inchWallet"
    }()

    private lazy var errorView: BrowserErrorView = {
        let errorView = BrowserErrorView()
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.delegate = self
        return errorView
    }()
    private var estimatedProgressObservation: NSKeyValueObservation!

    weak var delegate: BrowserViewControllerDelegate?

    lazy var webView: WKWebView = {
        let webView = WKWebView(
            frame: .init(x: 0, y: 0, width: 40, height: 40),
            configuration: config
        )
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        if Environment.isDebug {
            webView.configuration.preferences.setValue(true, forKey: Keys.developerExtrasEnabled)
        }
        return webView
    }()

    lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = Colors.darkBlue
        progressView.trackTintColor = .clear
        return progressView
    }()

    lazy var config: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration.make(forType: .dappBrowser(server), address: account.address, in: ScriptMessageProxy(delegate: self))
        config.websiteDataStore = WKWebsiteDataStore.default()
        return config
    }()

    init(account: Wallet, server: RPCServer) {
        self.account = account
        self.server = server

        super.init(nibName: nil, bundle: nil)

        view.addSubview(webView)
        injectUserAgent()

        webView.addSubview(progressView)
        webView.bringSubviewToFront(progressView)
        view.addSubview(errorView)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: view),

            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            errorView.anchorsConstraint(to: webView),
        ])
        view.backgroundColor = .white

        estimatedProgressObservation = webView.observe(\.estimatedProgress) { [weak self] webView, _ in
            guard let strongSelf = self else { return }

            let progress = Float(webView.estimatedProgress)

            strongSelf.progressView.progress = progress
            strongSelf.progressView.isHidden = progress == 1
        }

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
            webView.scrollView.contentInset.bottom = keyboardEndFrame.size.height
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        //If there's a external keyboard (or on simulator with software keyboard disabled):
        //    When text input starts. beginRect: size.height=0 endRect: size.height ~54. origin.y remains at ~812 (out of the screen)
        //    When text input ends. beginRect: size.height ~54 endRect: size.height = 0. origin.y remains at 812 (out of the screen)
        //Note the above. keyboardWillHide() is called for both when input starts and ends for external keyboard. Probably because the keyboard is hidden in both cases
        guard let beginRect = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue, let endRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let isExternalKeyboard = beginRect.origin == endRect.origin && (beginRect.size.height == 0 || endRect.size.height == 0)
        let isEnteringEditModeWithExternalKeyboard: Bool
        if isExternalKeyboard {
            isEnteringEditModeWithExternalKeyboard = beginRect.size.height == 0 && endRect.size.height > 0
        } else {
            isEnteringEditModeWithExternalKeyboard = false
        }
        if !isExternalKeyboard || !isEnteringEditModeWithExternalKeyboard {
            webView.scrollView.contentInset.bottom = 0
            //Must exit editing more explicitly (and update the nav bar buttons) because tapping on the web view can hide keyboard
            delegate?.dismissKeyboard(inBrowserViewController: self)
        }
    }

    private func injectUserAgent() {
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] result, _ in
            guard let strongSelf = self, let currentUserAgent = result as? String else { return }
            strongSelf.webView.customUserAgent = currentUserAgent + " " + strongSelf.userClient
        }
    }

    func goTo(url: URL) {
        hideErrorView()
        infoLog("[Browser] Loading URL: \(url.absoluteString)…")
        webView.load(URLRequest(url: url))
    }

    func notifyFinish(callbackID: Int, value: Swift.Result<DappCallback, DAppError>) {
        let script: String = {
            switch value {
            case .success(let result):
                return "executeCallback(\(callbackID), null, \"\(result.value.object)\")"
            case .failure(let error):
                return "executeCallback(\(callbackID), \"\(error.message)\", null)"
            }
        }()
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func reload() {
        hideErrorView()
        webView.reload()
    }

    private func stopLoading() {
        webView.stopLoading()
    }

    private func recordURL() {
        guard let url = webView.url else { return }
        delegate?.didVisitURL(url: url, title: webView.title ?? "", inBrowserViewController: self)
    }

    private func hideErrorView() {
        errorView.isHidden = true
    }

    deinit {
        estimatedProgressObservation.invalidate()
    }

    func handleError(error: Error) {
        if error.code == NSURLErrorCancelled {
            return
        } else {
            if error.domain == NSURLErrorDomain,
                let failedURL = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL {
                delegate?.forceUpdate(url: failedURL, inBrowserViewController: self)
            }
            errorView.show(error: error)
        }
    }
}

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        recordURL()
        hideErrorView()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        hideErrorView()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        infoLog("[Browser] navigation with error: \(error)")
        handleError(error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        infoLog("[Browser] provisional navigation with error: \(error)")
        handleError(error: error)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        infoLog("[Browser] decidePolicyFor url: \(String(describing: navigationAction.request.url?.absoluteString))")

        guard let url = navigationAction.request.url, let scheme = url.scheme else {
            decisionHandler(.allow)
            return
        }
        let app = UIApplication.shared
        if ["tel", "mailto"].contains(scheme), app.canOpenURL(url) {
            app.open(url)
            decisionHandler(.cancel)
            return
        }

        //TODO extract `DeepLink`, if reasonable
        if url.host == "aw.app" && url.path == "/wc", let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.queryItems.isEmpty {
            infoLog("[Browser] Swallowing URL and doing a no-op, url: \(url.absoluteString)")
            decisionHandler(.cancel)
            return
        }

        if DeepLink.supports(url: url) {
            delegate?.handleUniversalLink(url, inBrowserViewController: self)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}

extension BrowserViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let command = DappAction.fromMessage(message) else {
            if message.name == Browser.locationChangedEventName {
                recordURL()
            }
            return
        }
        infoLog("[Browser] dapp command: \(command)")
        let requester = DAppRequester(title: webView.title, url: webView.url)
        let token = MultipleChainsTokensDataStore.functional.token(forServer: server)
        let action = DappAction.fromCommand(command, server: server, transactionType: .dapp(token, requester))

        infoLog("[Browser] dapp action: \(action)")
        delegate?.didCall(action: action, callbackID: command.id, inBrowserViewController: self)
    }
}

extension BrowserViewController: BrowserErrorViewDelegate {
    func didTapReload(_ sender: Button) {
        reload()
    }
}
