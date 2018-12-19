// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import WebKit

//TODO remove duplicate of TokenCardsViewControllerHeader once IFRAME design is clear
class TokenCardsViewControllerHeaderWithIntroduction: UIView {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let blockchainLabel = UILabel()
    private let separator = UILabel()
    private let issuerLabel = UILabel()
    private let introductionWebView = WKWebView(frame: .zero, configuration: .init())

    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

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

            introductionWebView.heightAnchor.constraint(equalToConstant: 200),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TokensCardViewControllerHeaderViewModelWithIntroduction) {
        let html = viewModel.tbmlIntroductionHtmlString
        if html.isEmpty {
            frame = CGRect(x: 0, y: 0, width: 300, height: 90)
        } else {
            frame = CGRect(x: 0, y: 0, width: 300, height: 290)
        }
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

        if html.isEmpty {
            introductionWebView.isHidden = true
        } else {
            introductionWebView.isHidden = false
            introductionWebView.scrollView.isScrollEnabled = false
            introductionWebView.navigationDelegate = self
            introductionWebView.loadHTMLString(html, baseURL: nil)
        }
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
