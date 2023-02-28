//
//  SvgImageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit
import WebKit
import Kingfisher
import AlphaWalletLogger

private let svgImageViewSharedConfiguration: WKWebViewConfiguration = {
    let preferences = WKPreferences()
    preferences.javaScriptEnabled = false
    let configuration = WKWebViewConfiguration()
    configuration.preferences = preferences

    return configuration
}()

final class SvgImageView: WKWebView {

    private (set) var pageHasLoaded: Bool = false
    var rounding: ViewRounding = .none {
        didSet { layoutSubviews() }
    }

    init() {
        //NOTE: set initial frame to avoid `[ViewportSizing] maximumViewportInset cannot be larger than frame`
        super.init(frame: .init(x: 0, y: 0, width: 40, height: 40), configuration: svgImageViewSharedConfiguration)

        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        scrollView.isScrollEnabled = false
        contentMode = .scaleAspectFit
        clipsToBounds = true
        navigationDelegate = self

        isOpaque = false
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        scrollView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    func setImage(svg: String) {
        loadHTMLString(html(svgString: svg), baseURL: nil)
        alpha = 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        cornerRadius = rounding.cornerRadius(view: self)
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
                        border-radius: \(Int(rounding.cornerRadius(view: self)))px;
                    }

                    div > * {
                        border-radius: \(Int(rounding.cornerRadius(view: self)))px;
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
