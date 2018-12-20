// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import WebKit

protocol TokenCardsViewControllerHeaderWithIntroductionDelegate: class {
    func didUpdate(height: CGFloat, ofHeader header: TokenCardsViewControllerHeaderWithIntroduction)
}

//TODO remove duplicate of TokenCardsViewControllerHeader once IFRAME design is clear
class TokenCardsViewControllerHeaderWithIntroduction: UIView {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let blockchainLabel = UILabel()
    private let separator = UILabel()
    private let issuerLabel = UILabel()
    private let introductionWebView = WKWebView(frame: .zero, configuration: .init())
    lazy private var introductionWebViewHeightConstraint = introductionWebView.heightAnchor.constraint(equalToConstant: 200)
    weak var delegate: TokenCardsViewControllerHeaderWithIntroductionDelegate?


    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        introductionWebView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        let bottomRowStack = [blockchainLabel, separator, issuerLabel].asStackView(spacing: 15)
        let stackView = [
            titleLabel,
            bottomRowStack,
            introductionWebView,
        ].asStackView(axis: .vertical, spacing: 15)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        let backgroundWidthConstraint = background.widthAnchor.constraint(equalTo: widthAnchor)
        backgroundWidthConstraint.priority = .defaultHigh
        // TODO extract constant. Maybe StyleLayout.sideMargin
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            backgroundWidthConstraint,

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),
        ] + [introductionWebViewHeightConstraint])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TokensCardViewControllerHeaderViewModelWithIntroduction) {
        backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title
        titleLabel.adjustsFontSizeToFitWidth = true

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName

        issuerLabel.textColor = viewModel.subtitleColor
        issuerLabel.font = viewModel.subtitleFont
        let issuer = viewModel.issuer
        if issuer.isEmpty {
            issuerLabel.text = ""
        } else {
            issuerLabel.text = issuer
        }
        separator.textColor = viewModel.subtitleColor
        separator.font = viewModel.subtitleFont
        separator.text = viewModel.issuerSeparator

        let html = viewModel.tbmlIntroductionHtmlString
        if html.isEmpty {
            introductionWebView.isHidden = true
            frame = CGRect(x: 0, y: 0, width: 300, height: 90)
        } else {
            introductionWebView.isHidden = false
            introductionWebView.scrollView.isScrollEnabled = false
            introductionWebView.navigationDelegate = self
            introductionWebView.loadHTMLString(html, baseURL: nil)
            frame = CGRect(x: 0, y: 0, width: 300, height: 90 + introductionWebViewHeightConstraint.constant)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "estimatedProgress" else { return }
        guard introductionWebView.estimatedProgress == 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.makeIntroductionWebViewFullHeight()
        }
    }

    private func makeIntroductionWebViewFullHeight() {
        introductionWebViewHeightConstraint.constant = introductionWebView.scrollView.contentSize.height
        frame = CGRect(x: 0, y: 0, width: 300, height: 90 + introductionWebViewHeightConstraint.constant)
        delegate?.didUpdate(height: frame.size.height, ofHeader: self)
    }
}

//Block navigation. Still good to have even if we end up using XSLT?
extension TokenCardsViewControllerHeaderWithIntroduction: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString, url == "about:blank" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}
