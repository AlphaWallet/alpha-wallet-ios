// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit
import Kingfisher

enum WebImageViewImage {
    case url(WebImageURL)
    case image(UIImage)
}

final class FixedContentModeImageView: UIImageView {
    var fixedContentMode: UIView.ContentMode {
        didSet { self.layoutSubviews() }
    }

    init(fixedContentMode contentMode: UIView.ContentMode) {
        self.fixedContentMode = contentMode
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentMode = fixedContentMode
        layer.masksToBounds = true
        clipsToBounds = true
    }
}

final class WebImageView: UIView {

    private lazy var imageView: FixedContentModeImageView = {
        let imageView = FixedContentModeImageView(fixedContentMode: contentMode)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = Colors.appBackground

        return imageView
    }()

    private lazy var webView: WKWebView = {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = false
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = false
        webView.contentMode = .scaleAspectFit

        return webView
    }()

    private var pendingLoadWebViewOperation: BlockOperation?

    override var contentMode: UIView.ContentMode {
        didSet { imageView.fixedContentMode = contentMode }
    }

    init(placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        clipsToBounds = true

        addSubview(imageView)
        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self),
            imageView.anchorsConstraint(to: self)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(image: UIImage) {
        webView.alpha = 0
        imageView.image = image
    }

    func setImage(url: WebImageURL?, placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        guard let url = url?.url else {
            webView.alpha = 0
            imageView.image = placeholder
            return
        }

        if url.pathExtension == "svg" {
            imageView.image = nil

            if let data = try? ImageCache.default.diskStorage.value(forKey: url.absoluteString), let svgString = data.flatMap({ String(data: $0, encoding: .utf8) }) {
                webView.alpha = 1
                webView.loadHTMLString(html(svgString: svgString), baseURL: nil)
            } else {
                webView.alpha = 0

                DispatchQueue.global(qos: .utility).async {
                    if let data = try? Data(contentsOf: url), let svgString = String(data: data, encoding: .utf8) {
                        if let op = self.pendingLoadWebViewOperation {
                            op.cancel()
                        }

                        let op = BlockOperation {
                            self.webView.loadHTMLString(self.html(svgString: svgString), baseURL: nil)
                            self.webView.alpha = 1
                        }
                        self.pendingLoadWebViewOperation = op

                        OperationQueue.main.addOperations([op], waitUntilFinished: false)

                        try? ImageCache.default.diskStorage.store(value: data, forKey: url.absoluteString)
                    }
                }
            }
        } else {
            webView.alpha = 0
            imageView.kf.setImage(with: url, placeholder: placeholder)
        }
    }
}

extension WebImageView {

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
