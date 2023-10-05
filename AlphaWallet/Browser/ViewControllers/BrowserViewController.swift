// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import JavaScriptCore
import UIKit
import WebKit
import AlphaWalletBrowser
import AlphaWalletFoundation
import AlphaWalletLogger
import Combine

protocol BrowserViewControllerDelegate: AnyObject {
    func didCall(action: DappAction, callbackId: Int, in viewController: BrowserViewController)
    func didVisitURL(url: URL, title: String, in viewController: BrowserViewController)
    func dismissKeyboard(in viewController: BrowserViewController)
    func forceUpdate(url: URL, in viewController: BrowserViewController)
    func handleUniversalLink(_ url: URL, in viewController: BrowserViewController)
}

final class BrowserViewController: UIViewController {
    private lazy var errorView: BrowserErrorView = {
        let errorView = BrowserErrorView()
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.delegate = self
        return errorView
    }()
    private var cancellable = Set<AnyCancellable>()
    private let decidePolicy = PassthroughSubject<BrowserViewModel.DecidePolicy, Never>()

    weak var delegate: BrowserViewControllerDelegate?

    lazy var webView: WKWebView = {
        let webView = WKWebView(
            frame: .init(x: 0, y: 0, width: 40, height: 40),
            configuration: viewModel.config)
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        if Environment.isDebug {
            webView.configuration.preferences.setValue(true, forKey: BrowserViewModel.Keys.developerExtrasEnabled)
        }
        return webView
    }()

    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = Configuration.Color.Semantic.appTint
        progressView.trackTintColor = .clear
        return progressView
    }()

    private let viewModel: BrowserViewModel

    init(viewModel: BrowserViewModel) {
        self.viewModel = viewModel
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
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: BrowserViewModel) {
        let input = BrowserViewModelInput(
            progress: webView.publisher(for: \.estimatedProgress).eraseToAnyPublisher(),
            decidePolicy: decidePolicy.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.progressBarState
            .sink { [weak progressView] in
                progressView?.progress = $0.value
                progressView?.isHidden = $0.isHidden
            }.store(in: &cancellable)

        output.universalLink
            .sink { [weak self] url in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.handleUniversalLink(url, in: strongSelf)
            }.store(in: &cancellable)

        output.dappAction
            .sink { [weak self] data in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didCall(action: data.action, callbackId: data.callbackId, in: strongSelf)
            }.store(in: &cancellable)

        output.recordUrl
            .sink { [weak self] _ in self?.recordURL() }
            .store(in: &cancellable)

        output.keyboardAction
            .sink { [weak self] state in
                guard let strongSelf = self else { return }
                switch state {
                case .hideKeyboard:
                    strongSelf.webView.scrollView.contentInset.bottom = 0
                    //Must exit editing more explicitly (and update the nav bar buttons) because tapping on the web view can hide keyboard
                    strongSelf.delegate?.dismissKeyboard(in: strongSelf)
                case .adjustBottomInset(let height):
                    strongSelf.webView.scrollView.contentInset.bottom = height
                }
            }.store(in: &cancellable)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func injectUserAgent() {
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] result, _ in
            guard let strongSelf = self, let currentUserAgent = result as? String else { return }
            strongSelf.webView.customUserAgent = currentUserAgent + " " + BrowserViewModel.userClient
        }
    }

    func goTo(url: URL) {
        hideErrorView()
        infoLog("[Browser] Loading URL: \(url.absoluteString)…")
        webView.load(URLRequest(url: url))
    }

    func notifyFinish(callbackId: Int, value: Swift.Result<DappCallback, JsonRpcError>) {
        switch value {
        case .success(let result):
            webView.evaluateJavaScript("executeCallback(\(callbackId), null, \"\(result.value.object)\")")
        case .failure(let error):
            webView.evaluateJavaScript("executeCallback(\(callbackId), {message: \"\(error.message)\", code: \(error.code)}, null)")
        }
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
        delegate?.didVisitURL(url: url, title: webView.title ?? "", in: self)
    }

    private func hideErrorView() {
        errorView.isHidden = true
    }

    func handleError(error: Error) {
        if error.code == NSURLErrorCancelled {
            return
        } else {
            if error.domain == NSURLErrorDomain,
                let failedURL = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL {
                delegate?.forceUpdate(url: failedURL, in: self)
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
        decidePolicy.send((navigationAction, decisionHandler))
    }
}

extension BrowserViewController: PopInteractable {
    func shouldBeginPopInteraction() -> Bool {
        return viewModel.shouldBeginPopInteraction()
    }
}

extension BrowserViewController: BrowserErrorViewDelegate {
    func didTapReload(_ sender: Button) {
        reload()
    }
}
