// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit

//TODO should we be downloading and caching images ourselves and then displaying HTML with the image data embedded?
class WebImageView: UIView {
    enum ImageType {
        case thumbnail
        case original
    }

    private lazy var webView: WKWebView = {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.contentMode = .scaleToFill
        webView.autoresizesSubviews = true

        return webView
    }()

    private let imageView: UIImageView = {
        let v = UIImageView()
        v.backgroundColor = .clear
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()
    private let type: ImageType

    var url: URL? {
        didSet {
            setWebViewURL(url: url)
        }
    }

    var image: UIImage? {
        didSet {
            loadedUrl = .none
            imageView.image = image
            setIsLoadingImageFromURL(false)
            webView.loadHTMLString("", baseURL: nil)
        }
    }

    private func setIsLoadingImageFromURL(_ value: Bool) {
        imageView.isHidden = value
        webView.isHidden = !imageView.isHidden
    }
    ///svg thumbnail image size
    private var size: CGSize
    private var frameObservation: NSKeyValueObservation?

    init(type: ImageType, size: CGSize) {

        self.type = type
        self.size = size

        super.init(frame: .zero)

        addSubview(webView)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self),
            imageView.anchorsConstraint(to: self)
        ])

        subscribeForFrameChange()
        setWebViewURL(url: nil)
    }

    private func subscribeForFrameChange() {
        frameObservation.flatMap { $0.invalidate() }

        frameObservation = observe(\.bounds, options: [.new]) { observer, _ in
            self.size = observer.frame.size
        }
    }
    private var loadedUrl: URL?

    private func setWebViewURL(url: URL?) {
        if let loadedUrl = loadedUrl, loadedUrl == url {
            return
        }

        imageView.image = nil
        setIsLoadingImageFromURL(true)

        func loadHtmlIFrameFor(url: URL) {
            let html = generateHtmlForThumbnailSvg(url: url, size: size)
            webView.loadHTMLString(html, baseURL: nil)
        }

        func loadHtmlForSvg(url: URL) {
            let html = generateHtmlForThumbnailSvg(url: url, size: size)
            webView.loadHTMLString(html, baseURL: nil)
        }

        if let url = url?.rewrittenIfIpfs {
            if url.pathExtension == "svg" {
                switch type {
                case .original:
                    loadHtmlIFrameFor(url: url)
                case .thumbnail:
                    loadHtmlForSvg(url: url)
                }
            } else {
                loadHtmlIFrameFor(url: url)
            }
        } else {
            webView.loadHTMLString("", baseURL: nil)
        }
        loadedUrl = url
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func generateHtmlForThumbnailSvg(url: URL, size: CGSize) -> String {
        return """
              <html>
                  <head>
                      <meta name="viewport" content="width=device-width, shrink-to-fit=YES">
                      <style>
                      * {
                          margin: 0;
                          padding: 0;
                      }
                      .center-fit {
                          max-width: 100%;
                          max-height: 100%;
                          margin: auto;
                      }
                      .sized {
                          width: \(size.width)px;
                          height: \(size.height)px;
                      }
                  </style>
                  </head>
                  <body>
                      <div class="center-fit">
                          <img class="sized" src="\(url.absoluteString)" onload = "didLoadImage()"/>
                          <script>
                              function didLoadImage() {
                                //NOTE: seems like it needs some delay to rerender image
                                setTimeout(function() {
                                    document.getElementsByClassName('sized')[0].style.width = '\(size.width + 0.1)px'
                                }, 100);
                              }
                          </script>
                      </div>
                  </body>
              </html>
              """
    }
}
