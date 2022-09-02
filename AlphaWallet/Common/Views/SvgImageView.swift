//
//  SvgImageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit
import WebKit
import Kingfisher
import AlphaWalletFoundation

private let svgImageViewSharedConfiguration: WKWebViewConfiguration = {
    let preferences = WKPreferences()
    preferences.javaScriptEnabled = false
    let configuration = WKWebViewConfiguration()
    configuration.preferences = preferences

    return configuration
}()

final class SvgImageView: WKWebView {
    private var pendingLoadWebViewOperation: BlockOperation?
    private (set) var pageHasLoaded: Bool = false
    var rounding: ViewRounding = .none

    init() {
        //NOTE: set initial frame to avoid `[ViewportSizing] maximumViewportInset cannot be larger than frame`
        super.init(frame: .init(x: 0, y: 0, width: 40, height: 40), configuration: svgImageViewSharedConfiguration)

        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        scrollView.isScrollEnabled = false
        contentMode = .scaleAspectFit
        clipsToBounds = true
        navigationDelegate = self
    }

    func setImage(url: URL, completion: @escaping () -> Void) {
        if let data = try? ImageCache.default.diskStorage.value(forKey: url.absoluteString), let svgString = data.flatMap({ String(data: $0, encoding: .utf8) }) {
            loadHTMLString(html(svgString: svgString), baseURL: nil)
            alpha = 1
            completion()
        } else {
            alpha = 0

            DispatchQueue.global(qos: .userInteractive).async {
                if let data = try? Data(contentsOf: url), let svgString = String(data: data, encoding: .utf8) {
                    if let op = self.pendingLoadWebViewOperation {
                        op.cancel()
                    }

                    let op = BlockOperation {
                        self.loadHTMLString(self.html(svgString: svgString), baseURL: nil)
                        self.alpha = 1
                        completion()
                    }
                    self.pendingLoadWebViewOperation = op

                    OperationQueue.main.addOperations([op], waitUntilFinished: false)

                    try? ImageCache.default.diskStorage.store(value: data, forKey: url.absoluteString)
                } else {
                    warnLog("[SvgImageView] suppose to a svg image, but failure")
                }
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        switch rounding {
        case .none:
            cornerRadius = 0
        case .circle:
            cornerRadius = bounds.width / 2
        case .custom(let radius):
            cornerRadius = radius
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: WKWebView
extension SvgImageView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        pageHasLoaded = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageHasLoaded = true
    }
}

extension SvgImageView {

    func html(svgString: String) -> String {
        """
        <!DOCTYPE html>
        <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width,initial-scale=1.0">
                <title></title>
                <style type="text/css">
                    html {
                        width: 100%;
                        height: 100%;
                        padding: 0;
                        margin: 0;
                    }

                    body {
                        margin: 0;
                        padding: 0;
                    }

                    div {
                        width: 100%;
                        height: 100%;
                        margin: 0;
                        padding: 0;
                    }

                    svg {
                        width: inherit;
                        height: inherit;
                        max-width: 100%;
                        max-height: 100%;
                        border-radius: \(Int(rounding.cornerRadius2(view: self)))px;
                    }

                    div > * {
                        border-radius: \(Int(rounding.cornerRadius2(view: self)))px;
                    }
                </style>
            </head>
            <body>
            <div>
                \(svgString)
            </div>
            </body>
        </html>
        """
    }
}
