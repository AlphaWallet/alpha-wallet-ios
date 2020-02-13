// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import UIKit
import WebKit
import JavaScriptCore
import Result

protocol BrowserViewControllerDelegate: class {
    func didCall(action: DappAction, callbackID: Int, inBrowserViewController viewController: BrowserViewController)
    func didVisitURL(url: URL, title: String, inBrowserViewController viewController: BrowserViewController)
    func dismissKeyboard(inBrowserViewController viewController: BrowserViewController)
    func forceUpdate(url: URL, inBrowserViewController viewController: BrowserViewController)
}

final class BrowserViewController: UIViewController {
    private var myContext = 0
    private let account: Wallet
    private let server: RPCServer

    private struct Keys {
        static let estimatedProgress = "estimatedProgress"
        static let developerExtrasEnabled = "developerExtrasEnabled"
        static let URL = "URL"
        static let ClientName = "AlphaWallet"
    }

    private lazy var userClient: String = {
        return Keys.ClientName + "/" + (Bundle.main.versionNumber ?? "")
    }()

    private lazy var errorView: BrowserErrorView = {
        let errorView = BrowserErrorView()
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.delegate = self
        return errorView
    }()

    weak var delegate: BrowserViewControllerDelegate?

    lazy var webView: WKWebView = {
        let webView = WKWebView(
            frame: .zero,
            configuration: config
        )
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        if isDebug {
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
        let config = WKWebViewConfiguration.make(forType: .dappBrowser, server: server, address: account.address, in: ScriptMessageProxy(delegate: self))
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

            progressView.topAnchor.constraint(equalTo: view.layoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            errorView.anchorsConstraint(to: webView),
        ])
        view.backgroundColor = .white
        webView.addObserver(self, forKeyPath: Keys.estimatedProgress, options: .new, context: &myContext)

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
        webView.load(URLRequest(url: url))
    }

    func notifyFinish(callbackID: Int, value: Result<DappCallback, DAppError>) {
        let script: String = {
            switch value {
            case .success(let result):
                return "executeCallback(\(callbackID), null, \"\(result.value.object)\")"
            case .failure(let error):
                return "executeCallback(\(callbackID), \"\(error)\", null)"
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

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let change = change else { return }
        if context != &myContext {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if keyPath == Keys.estimatedProgress {
            if let progress = (change[NSKeyValueChangeKey.newKey] as AnyObject).floatValue {
                progressView.progress = progress
                progressView.isHidden = progress == 1
            }
        }
    }

    deinit {
        webView.removeObserver(self, forKeyPath: Keys.estimatedProgress)
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
        handleError(error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleError(error: error)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> ()) {
        guard let url = navigationAction.request.url, let scheme = url.scheme else {
            return decisionHandler(.allow)
        }
        guard ["tel", "mailto"].contains(scheme) else {
            return decisionHandler(.allow)
        }
        let app = UIApplication.shared
        if app.canOpenURL(url) {
            decisionHandler(.cancel)
            app.open(url)
        } else {
            decisionHandler(.allow)
        }
    }
}

extension BrowserViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let command = DappAction.fromMessage(message) else { return }
        let requester = DAppRequester(title: webView.title, url: webView.url)
        let token = TokensDataStore.token(forServer: server)
        let transfer = Transfer(server: server, type: .dapp(token, requester))
        let action = DappAction.fromCommand(command, transfer: transfer)

        delegate?.didCall(action: action, callbackID: command.id, inBrowserViewController: self)
    }
}

extension BrowserViewController: BrowserErrorViewDelegate {
    func didTapReload(_ sender: Button) {
        reload()
    }
}
