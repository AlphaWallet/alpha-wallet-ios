// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit

//TODO should we be downloading and caching images ourselves and then displaying HTML with the image data embedded?
class WebImageView: UIView {
    enum ImageType {
        case thumbnail
        case original
    }

    private let webView = WKWebView()
    private let imageView: UIImageView = {
        let v = UIImageView()
        v.backgroundColor = .clear
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        return v
    }()
    private let type: ImageType

    var url: URL? {
        didSet {
            imageView.image = nil
            if let url = url?.rewrittenIfIpfs {
                if url.pathExtension == "svg" {
                    switch type {
                    case .original:
                        webView.load(.init(url: url.rewrittenIfIpfs))
                    case .thumbnail:
                        let html = generateHtmlForThumbnailSvg(url: url)
                        webView.loadHTMLString(html, baseURL: nil)
                    }
                } else {
                    webView.load(.init(url: url.rewrittenIfIpfs))
                }
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

    init(type: ImageType) {
        self.type = type
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

    private func generateHtmlForThumbnailSvg(url: URL) -> String {
        return """
              <html>
                  <head>
                      <style>
                      * {
                          margin: 0;
                          padding: 0;
                      }
                      .imgbox {
                          display: grid;
                          width: 600px;
                          height: 600px;
                      }
                      .center-fit {
                          max-width: 100%;
                          max-height: 100%;
                          margin: auto;
                      }
                  </style>
                  </head>
                  <body>
                      <div class="imgbox">
                          <img class="center-fit" src='\(url.absoluteString)'>
                      </div>
                  </body>
              </html>
              """
    }
}