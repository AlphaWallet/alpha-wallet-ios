// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol StaticHTMLViewControllerDelegate: class, CanOpenURL {
}

class StaticHTMLViewController: UIViewController {
    private let webView = UIWebView()

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
        //So webview is seethrough to reveal its parents background color when HTML is not loaded yet
        webView.isOpaque = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.delegate = self
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

extension StaticHTMLViewController: UIWebViewDelegate {
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        if let url = request.url, url.absoluteString.hasPrefix("http") {
            delegate?.didPressOpenWebPage(url, in: self)
            return false
        } else {
            return true
        }
    }
}
