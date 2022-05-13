//
//  SvgImageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit
import WebKit
import Kingfisher

final class SvgImageView: WKWebView {
    private var pendingLoadWebViewOperation: BlockOperation?

    var rounding: ViewRounding = .none

    init() {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = false
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences

        super.init(frame: .zero, configuration: configuration)

        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        scrollView.isScrollEnabled = false
        contentMode = .scaleAspectFit
        clipsToBounds = true
    }

    func setImage(url: URL) {
        if let data = try? ImageCache.default.diskStorage.value(forKey: url.absoluteString), let svgString = data.flatMap({ String(data: $0, encoding: .utf8) }) {
            alpha = 1
            loadHTMLString(html(svgString: svgString), baseURL: nil)
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
                    }
                    self.pendingLoadWebViewOperation = op

                    OperationQueue.main.addOperations([op], waitUntilFinished: false)

                    try? ImageCache.default.diskStorage.store(value: data, forKey: url.absoluteString)
                } else {
                    debugLog("[SvgImageView] suppose to a svg image, but failure")
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
