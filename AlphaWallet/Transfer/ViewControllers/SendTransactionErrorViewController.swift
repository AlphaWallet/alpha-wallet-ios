// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol SendTransactionErrorViewControllerDelegate: AnyObject {
    func rectifyErrorButtonTapped(error: SendTransactionNotRetryableError, in viewController: SendTransactionErrorViewController)
    func linkTapped(_ url: URL, forError error: SendTransactionNotRetryableError, in viewController: SendTransactionErrorViewController)
    func didClose(in viewController: SendTransactionErrorViewController)
}

class SendTransactionErrorViewController: UIViewController {
    private let analytics: AnalyticsLogger
    private let viewModel: SendTransactionErrorViewModel
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: "", isMinimalMode: true))
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))

    private var titleLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = Configuration.Color.Semantic.defaultForegroundText
        v.font = Fonts.regular(size: 28)
        return v
    }()

    private var descriptionLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = Configuration.Color.Semantic.defaultHeadlineText
        v.font = Fonts.regular(size: 17)
        return v
    }()

    private var linkButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = Fonts.semibold(size: 17)
        b.setTitleColor(Configuration.Color.Semantic.appTint, for: .normal)
        return b
    }()

    private lazy var footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)

    weak var delegate: SendTransactionErrorViewControllerDelegate?

    init(analytics: AnalyticsLogger, viewModel: SendTransactionErrorViewModel) {
        self.analytics = analytics
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let stackView = [
            headerView,
            [.spacerWidth(15), titleLabel, .spacerWidth(15)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            [.spacerWidth(15), descriptionLabel, .spacerWidth(15)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            linkButton,
            footerBar
        ].asStackView(axis: .vertical, spacing: 0)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()

        headerView.closeButton.addTarget(self, action: #selector(closeButtonSelected), for: .touchUpInside)
        linkButton.addTarget(self, action: #selector(linkButtonTapped), for: .touchUpInside)
    }

    @objc private func closeButtonSelected() {
        delegate?.didClose(in: self)
    }

    @objc private func linkButtonTapped() {
        if let url = viewModel.linkUrl {
            switch viewModel.error.type {
            case .insufficientFunds:
                analytics.log(navigation: Analytics.Navigation.openHelpUrl, properties: [Analytics.Properties.type.rawValue: Analytics.HelpUrl.insufficientFunds.rawValue])
            case .nonceTooLow, .gasPriceTooLow, .gasLimitTooLow, .gasLimitTooHigh, .possibleChainIdMismatch, .executionReverted, .unknown:
                break
            }
            delegate?.linkTapped(url, forError: viewModel.error, in: self)
        } else {
            preconditionFailure("Should only show link button if there's a URl")
        }
    }

    private func configure() {
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.description

        if let linkTitle = viewModel.linkTitle {
            linkButton.setTitle(linkTitle, for: .normal)
            linkButton.isHidden = false
        } else {
            linkButton.isHidden = true
        }

        if let rectifyErrorTitle = viewModel.rectifyErrorButtonTitle {
            buttonsBar.configure()
            let button = buttonsBar.buttons[0]
            button.shrinkBorderColor = Configuration.Color.Semantic.loadingIndicatorBorder
            button.setTitle(rectifyErrorTitle, for: .normal)
            button.addTarget(self, action: #selector(rectifyErrorButtonTapped), for: .touchUpInside)
            footerBar.isHidden = false
        } else {
            footerBar.isHidden = true
        }
    }

    @objc private func rectifyErrorButtonTapped() {
        delegate?.rectifyErrorButtonTapped(error: viewModel.error, in: self)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}
