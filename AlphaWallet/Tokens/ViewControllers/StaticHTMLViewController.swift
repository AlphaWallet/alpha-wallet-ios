// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import WebKit

protocol StaticHTMLViewControllerDelegate: class, CanOpenURL {
}

class StaticHTMLViewController: UIViewController {
    lazy private var webViewConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(self, forURLScheme: "tokenscript-resource")
        return config
    }()
    lazy private var webView = WKWebView(frame: .zero, configuration: webViewConfiguration)

    let footer = UIView()
    weak var delegate: StaticHTMLViewControllerDelegate?

    var footerHeight: CGFloat {
        return 0
    }

    var url: URL? {
        return nil
    }

    init(delegate: StaticHTMLViewControllerDelegate?) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = Colors.appBackground

        webView.backgroundColor = Colors.appBackground
        //TODO verify still needed for WKWebView
        //So webview is seethrough to reveal its parents background color when HTML is not loaded yet
        webView.isOpaque = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        if let path = url {
            let html = (try? String(contentsOf: path)) ?? ""
            webView.loadHTMLString(html, baseURL: URL(fileURLWithPath: Bundle.main.bundlePath))
        }
        view.addSubview(webView)

        footer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footer)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: footer.topAnchor),

            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.heightAnchor.constraint(equalToConstant: footerHeight),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension StaticHTMLViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, url.scheme != nil else {
            return decisionHandler(.allow)
        }

        if url.absoluteString.hasPrefix("http") {
            delegate?.didPressOpenWebPage(url, in: self)
            return decisionHandler(.cancel)
        }

        decisionHandler(.allow)
    }
}

extension StaticHTMLViewController: WKURLSchemeHandler {
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if urlSchemeTask.request.url?.path != nil {
            if let fileExtension = urlSchemeTask.request.url?.pathExtension, fileExtension == "otf", let nameWithoutExtension = urlSchemeTask.request.url?.deletingPathExtension().lastPathComponent {
                //TODO maybe good to fail with didFailWithError(error:)
                guard let url = Bundle.main.url(forResource: nameWithoutExtension, withExtension: fileExtension) else { return }
                guard let data = try? Data(contentsOf: url) else { return }
                //mimeType doesn't matter. Blocking is done based on how browser intends to use it
                let response = URLResponse(url: urlSchemeTask.request.url!, mimeType: "font/opentype", expectedContentLength: data.count, textEncodingName: nil)
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
                return
            }
        }
        //TODO maybe good to fail:
        //urlSchemeTask.didFailWithError(error:)
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        //Do nothing
    }
}
