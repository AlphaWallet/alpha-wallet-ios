// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit

enum WebImageViewImage: Hashable, Equatable {
    case url(URL)
    case image(UIImage)

    static func == (lhs: WebImageViewImage, rhs: WebImageViewImage) -> Bool {
        switch (lhs, rhs) {
        case (.url(let v1), .url(let v2)):
            return v1 == v2
        case (.image(let v1), .image(let v2)):
            return v1 == v2
        case (_, _):
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .url(let uRL):
            hasher.combine(uRL)
        case .image(let uIImage):
            hasher.combine(uIImage)
        }
    }
}

//TODO should we be downloading and caching images ourselves and then displaying HTML with the image data embedded?
class WebImageView: UIView {

    enum WebImageError: Error {
        case loadURL(url: URL)
        case invalidURL
    }

    private lazy var webView: _WebImageView = {
        let webView = _WebImageView()
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

    func setImage(image: UIImage) {
        setImage(rawUIImage: image)
    }

    func setImage(url: URL?, placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        self.placeholder = placeholder

        if let url = url {
            setWebViewURL(url: url)
        } else if let placeholder = self.placeholder {
            setImage(rawUIImage: placeholder)
        } else {
            setWebViewURL(url: url)
        }
    }

    private func setImage(rawUIImage image: UIImage) {
        imageView.image = image

        setIsLoadingImageFromURL(false)
    }

    private func setIsLoadingImageFromURL(_ value: Bool) {
        imageView.isHidden = value
        webView.isHidden = !imageView.isHidden
    }

    private var placeholder: UIImage?

    init(placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        self.placeholder = placeholder

        super.init(frame: .zero)

        addSubview(webView)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self),
            imageView.anchorsConstraint(to: self)
        ])

        setWebViewURL(url: nil)
    }

    private func setWebViewURL(url: URL?) {
        func resetToDisplayPlaceholder() {
            imageView.image = placeholder
            setIsLoadingImageFromURL(false)
        }

        func loadHtmlForImage(url: String) {
            webView.setImage(url: url, handlePageEventClosure: { action in
                switch action {
                case .pageDidLoad:
                    break
                case .imageDidLoad, .imageAlreadyLoaded:
                    self.imageView.image = nil
                    self.setIsLoadingImageFromURL(true)
                case .imageLoadFailure:
                    resetToDisplayPlaceholder()
                    verbose("Loading token icon URL: \(url) error")
                }
            })
        }

        guard let imageURL = url.flatMap({ $0.rewrittenIfIpfs }).flatMap({ $0.absoluteString }) else {
            return resetToDisplayPlaceholder()
        } 

        loadHtmlForImage(url: imageURL)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class _WebImageView: UIView {
    private static let folder = "WebImage"

    enum WebImageError: Error {
        case loadURL(url: URL)
        case invalidURL
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

    private var frameObservation: NSKeyValueObservation?
    private var privateHandlePageEventClosure: ((WebPageAction) -> Void)?
    private var handlePageEventClosure: ((WebPageAction) -> Void)?
    private var pageDidLoad: Bool = false
    private var pendingToLoadURL: String?

    init() {
        super.init(frame: .zero)

        webView.configuration.userContentController.add(self, name: "WebImage")
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self)
        ])

        func loadHtmlForImage() {
            let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(_WebImageView.folder)
            let html = generateBaseHtmlPage()
            webView.loadHTMLString(html, baseURL: resourceURL)
        }

        privateHandlePageEventClosure = { [weak self] action in
            guard let strongSelf = self else { return }

            switch action {
            case .pageDidLoad:
                guard !strongSelf.pageDidLoad else { return }
                strongSelf.pageDidLoad = true
                
                strongSelf.subscribeForFrameChange(completion: {
                    if let url = strongSelf.pendingToLoadURL {
                        strongSelf.pendingToLoadURL = .none

                        strongSelf.loadImageFor(url: url)
                    }
                })
            case .imageLoadFailure, .imageDidLoad, .imageAlreadyLoaded:
                break
            }
            strongSelf.handlePageEventClosure?(action)
        }

        loadHtmlForImage()
    }

    func setImage(url: String, handlePageEventClosure: @escaping (WebPageAction) -> Void) {
        self.handlePageEventClosure = handlePageEventClosure

        guard pageDidLoad else {
            pendingToLoadURL = url
            return
        }

        loadImageFor(url: url)
    }

    private func loadImageFor(url: String, completion: @escaping () -> Void = {}) {
        let js = """
            replaceImageView("\(url)");
         """

        execute(script: js)
    }

    private func invalidateContainerOnload() {
        guard frame.size.width != 0 else { return }

        let js = """
           setTimeout(function() {
                document.getElementById("container").style.width = '\((frame.size.width + 0.1).rounded(.down))px';
           }, 100);
         """

        execute(script: js)
    }

    private func subscribeForFrameChange(completion: @escaping () -> Void) {
        frameObservation.flatMap { $0.invalidate() }

        frameObservation = observe(\.bounds, options: [.new, .initial]) { [weak self] observer, _ in
            guard let strongSelf = self else { return }

            let size = observer.frame.size
            guard size.width != 0 && size.height != 0 else { return }

            let js = """
                document.getElementById("container").style.width = '\((size.width).rounded(.up))px';
                document.getElementById("container").style.height = '\((size.height).rounded(.up))px';
             """

            strongSelf.execute(script: js, completion: { _ in
                completion()
            })
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func generateBaseHtmlPage() -> String {
        guard let filePath = Bundle.main.path(forResource: "web_image", ofType: "html", inDirectory: _WebImageView.folder) else { return "" }
        guard let html = try? String(contentsOfFile: filePath, encoding: .utf8) else { return "" }

        return html
    }

    private func execute(script: String, completion: @escaping (Error?) -> Void = { _ in }) {
        webView.evaluateJavaScript(script) { (_, error: Error?) in
            completion(error)
        }
    }
}

extension _WebImageView: WKScriptMessageHandler {

    enum WebPageAction {
        private static let loadImageFailureKey = "loadImageFailure"
        private static let loadImageSucceedKey = "loadImageSucceed"
        private static let pageDidLoadKey = "pageDidLoad"

        case imageDidLoad(url: URL)
        case imageLoadFailure(url: URL)
        case pageDidLoad
        case imageAlreadyLoaded

        init?(string: String) {
            let components = string.components(separatedBy: " aw_separator ")

            if components[0] == WebPageAction.loadImageSucceedKey {
                guard components.count == 2 else { return nil }
                guard let url = URL(string: components[1]) else { return nil }

                self = .imageDidLoad(url: url)
            } else if components[0] == WebPageAction.loadImageFailureKey {
                guard components.count == 2 else { return nil }
                guard let url = URL(string: components[1]) else { return nil }

                self = .imageLoadFailure(url: url)
            } else if components[0] == WebPageAction.pageDidLoadKey {
                self = .pageDidLoad
            } else {
                return nil
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let action = (message.body as? String).flatMap({ WebPageAction(string: $0) }) else { return }
        privateHandlePageEventClosure?(action)
    }
}

