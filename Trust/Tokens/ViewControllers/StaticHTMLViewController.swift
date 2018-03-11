// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class StaticHTMLViewController: UIViewController {
    let webView = UIWebView()
    let footer = UIView()

    init() {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = Colors.appBackground

        webView.backgroundColor = Colors.appBackground
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.delegate = self
        if let path = url() {
            let html = try! String(contentsOf: path)
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
            footer.heightAnchor.constraint(equalToConstant: footerHeight()),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func url() -> URL? {
            return nil
        }

        func footerHeight() -> CGFloat {
            return 0
        }
    }

    extension StaticHTMLViewController: UIWebViewDelegate {
        func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
            if let url = request.url, url.absoluteString.hasPrefix("http") {
                openURL(url)
                return false
            } else {
            return true
        }
    }
}
