// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import WebKit

//TODO remove duplicate of SendHeaderView once IFRAME design is clear
class SendHeaderViewWithIntroduction: UIView {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let blockchainLabel = UILabel()
    private let middleBorder = UIView()
    private var footerStackView: UIStackView?
    private let valuePercentageChangeValueLabel = UILabel()
    private let valuePercentageChangePeriodLabel = UILabel()
    private let valueChangeLabel = UILabel()
    private let valueChangeNameLabel = UILabel()
    private let valueLabel = UILabel()
    private let valueNameLabel = UILabel()
    private let introductionWebView = WKWebView(frame: .zero, configuration: .init())
    lazy private var introductionWebViewHeightConstraint = introductionWebView.heightAnchor.constraint(equalToConstant: 200)

    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valuePercentageChangeValueLabel.textAlignment = .center
        valuePercentageChangePeriodLabel.textAlignment = .center
        valueChangeLabel.textAlignment = .center
        valueChangeNameLabel.textAlignment = .center
        valueLabel.textAlignment = .center
        valueNameLabel.textAlignment = .center

        let bottomRowStack = [blockchainLabel].asStackView(spacing: 15)

        let footerValuesStack = [valuePercentageChangeValueLabel, valueChangeLabel, valueLabel].asStackView(distribution: .fillEqually, spacing: 15)

        let footerNamesStack = [valuePercentageChangePeriodLabel, valueChangeNameLabel, valueNameLabel].asStackView(distribution: .fillEqually, spacing: 15)

        footerStackView = [
            .spacer(height: 14),
            footerValuesStack,
            footerNamesStack,
        ].asStackView(axis: .vertical, perpendicularContentHuggingPriority: .defaultLow)
        footerStackView?.translatesAutoresizingMaskIntoConstraints = false

        introductionWebView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        let titleLabelHolder = [UIView.spacerWidth(7), titleLabel, UIView.spacerWidth(7)].asStackView()
        let bottomRowStackHolder = [UIView.spacerWidth(7), bottomRowStack, UIView.spacerWidth(7)].asStackView()

        let stackView = [
            titleLabelHolder,
            bottomRowStackHolder,
            .spacer(height: 7),
            middleBorder,
            footerStackView!,
            introductionWebView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        let backgroundWidthConstraint = background.widthAnchor.constraint(equalTo: widthAnchor)
        backgroundWidthConstraint.priority = .defaultHigh
        // TODO extract constant. Maybe StyleLayout.sideMargin
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.heightAnchor.constraint(equalTo: heightAnchor),
            backgroundWidthConstraint,

            middleBorder.heightAnchor.constraint(equalToConstant: 1),

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 0),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: 0),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),
        ] + [introductionWebViewHeightConstraint])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SendHeaderViewViewModelWithIntroduction) {
        backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title
        titleLabel.adjustsFontSizeToFitWidth = true

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName

        middleBorder.backgroundColor = viewModel.borderColor

        valuePercentageChangePeriodLabel.textColor = viewModel.textColor
        valuePercentageChangePeriodLabel.font = viewModel.textLabelFont
        valuePercentageChangePeriodLabel.text = viewModel.valuePercentageChangePeriod
        valueChangeNameLabel.textColor = viewModel.textColor
        valueChangeNameLabel.font = viewModel.textLabelFont
        valueChangeNameLabel.text = viewModel.valueChangeName
        valueNameLabel.textColor = viewModel.textColor
        valueNameLabel.font = viewModel.textLabelFont
        valueNameLabel.text = viewModel.valueName

        valuePercentageChangeValueLabel.textColor = viewModel.valuePercentageChangeColor
        valuePercentageChangeValueLabel.font = viewModel.textValueFont
        valuePercentageChangeValueLabel.text = viewModel.valuePercentageChangeValue
        valueChangeLabel.textColor = viewModel.textColor
        valueChangeLabel.font = viewModel.textValueFont
        valueChangeLabel.text = viewModel.valueChange
        valueLabel.textColor = viewModel.textColor
        valueLabel.font = viewModel.textValueFont
        valueLabel.text = viewModel.value

        footerStackView?.isHidden = !viewModel.showAlternativeAmount

        let html = viewModel.tbmlIntroductionHtmlString
        if html.isEmpty {
            introductionWebView.isHidden = true
        } else {
            introductionWebView.isHidden = false
            introductionWebView.scrollView.isScrollEnabled = false
            introductionWebView.navigationDelegate = self
            introductionWebView.loadHTMLString(html, baseURL: nil)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "estimatedProgress" else { return }
        guard introductionWebView.estimatedProgress == 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.makeIntroductionWebViewFullHeight()
        }
    }

    private func makeIntroductionWebViewFullHeight() {
        introductionWebViewHeightConstraint.constant = introductionWebView.scrollView.contentSize.height
    }
}

//TODO dup in TokenCardsViewControllerHeaderWithIntroduction
//Block navigation. Still good to have even if we end up using XSLT?
extension SendHeaderViewWithIntroduction: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString, url == "about:blank" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}
