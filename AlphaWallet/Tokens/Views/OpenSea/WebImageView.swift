// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit

//TODO should we be downloading and caching images ourselves and then displaying HTML with the image data embedded?
class WebImageView: UIView {
    private let webView = WKWebView()
    private let imageView: UIImageView = {
        let v = UIImageView()
        v.backgroundColor = .clear
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        return v
    }()

    var url: URL? {
        didSet {
            imageView.image = nil
            if let url = url?.rewrittenIfIpfs {
                let html = """
                           <html>
                             <body style="background-repeat: no-repeat; background-size: cover; background-image: url('\(url.absoluteString)')" />
                           </html>
                           """
                webView.loadHTMLString(html, baseURL: nil)
            } else {
                webView.loadHTMLString("", baseURL: nil)
            }
        }
    }

    var image: UIImage? {
        didSet {
            imageView.image = image
            webView.loadHTMLString("", baseURL: nil)
        }
    }

    init() {
        url = nil
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false

        super.init(frame: .zero)

        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self),
            imageView.anchorsConstraint(to: self),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}