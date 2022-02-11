// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit

enum WebImageViewImage: Hashable, Equatable {
    case url(WebImageURL)
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
        let webView = _WebImageView(scale: scale, align: align)
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

    func setImage(url: WebImageURL?, placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
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
    private let scale: WebImageView.Scale
    private let align: WebImageView.Align

    init(placeholder: UIImage? = R.image.tokenPlaceholderLarge(), scale: WebImageView.Scale = .bestFitDown, align: WebImageView.Align = .center) {
        self.placeholder = placeholder
        self.scale = scale
        self.align = align
        super.init(frame: .zero)

        addSubview(webView)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self),
            imageView.anchorsConstraint(to: self)
        ])

        setWebViewURL(url: nil)
    }

    private func setWebViewURL(url: WebImageURL?) {
        func resetToDisplayPlaceholder() {
            imageView.image = placeholder
            setIsLoadingImageFromURL(false)
        }

        func loadHtmlForImage(url: String) {
            webView.setImage(url: url, handlePageEventClosure: { [weak self] action in
                switch action {
                case .pageDidLoad:
                    break
                case .imageDidLoad, .imageAlreadyLoaded:
                    self?.imageView.image = nil
                    self?.setIsLoadingImageFromURL(true)
                case .imageLoadFailure:
                    resetToDisplayPlaceholder()
                    verboseLog("Loading token icon URL: \(url) error")
                }
            })
        }

        guard let imageURL = url.flatMap({ $0.absoluteString }) else {
            return resetToDisplayPlaceholder()
        }

        loadHtmlForImage(url: imageURL)
    }

    deinit {
        webView.invalidate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension WebImageView {
    enum Align: String {
        case left = "left"
        case right = "right"
        case center = "center"
        case top = "top"
        case bottom = "bottom"
        case topLeft = "top-left"
        case topRight = "top-right"
        case bottomLeft = "bottom-left"
        case bottomRight = "bottom-right"
    }

    enum Scale: String {
        case fill = "fill"
        case bestFill = "best-fill"
        case bestFit = "best-fit"
        case bestFitDown = "best-fit-down"
        case none = "none"
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

    init(scale: WebImageView.Scale = .bestFitDown, align: WebImageView.Align = .center) {
        super.init(frame: .zero)

        webView.configuration.userContentController.add(ScriptMessageProxy(delegate: self), name: "WebImage")

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self)
        ])

        func loadHtmlForImage() {
            let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(_WebImageView.folder)
            let html = generateBaseHtmlPage(scale: scale, align: align)
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

    private func loadImageFor(url: String) {
        let js = """
            setImage("\(url)");
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
        return nil
    }

    func invalidate() {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "WebImage")
        frameObservation.flatMap { $0.invalidate() }
    }

    private func generateBaseHtmlPage(scale: WebImageView.Scale, align: WebImageView.Align) -> String {
        guard let filePath = Bundle.main.path(forResource: "web_image", ofType: "html", inDirectory: _WebImageView.folder) else { return "" }
        guard var html = try? String(contentsOfFile: filePath, encoding: .utf8) else { return "" }
        html = html.replacingOccurrences(of: "<scale>", with: scale.rawValue)
        html = html.replacingOccurrences(of: "<align>", with: align.rawValue)

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
