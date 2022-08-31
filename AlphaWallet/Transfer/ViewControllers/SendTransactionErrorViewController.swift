// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol SendTransactionErrorViewControllerDelegate: AnyObject {
    func rectifyErrorButtonTapped(error: SendTransactionNotRetryableError, inController controller: SendTransactionErrorViewController)
    func linkTapped(_ url: URL, forError error: SendTransactionNotRetryableError, inController controller: SendTransactionErrorViewController)
    func controllerDismiss(_ controller: SendTransactionErrorViewController)
}

class SendTransactionErrorViewController: UIViewController {
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private let error: SendTransactionNotRetryableError
    private lazy var viewModel = SendTransactionErrorViewModel(server: server, error: error)
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: "", isMinimalMode: true))
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))

    private var titleLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.black()
        v.font = Fonts.regular(size: 28)
        return v
    }()

    private var descriptionLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.mine()
        v.font = Fonts.regular(size: 17)
        return v
    }()

    private var linkButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = Fonts.semibold(size: 17)
        b.setTitleColor(R.color.azure(), for: .normal)
        return b
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    private lazy var footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)

    weak var delegate: SendTransactionErrorViewControllerDelegate?

    init(server: RPCServer, analytics: AnalyticsLogger, error: SendTransactionNotRetryableError) {
        self.server = server
        self.analytics = analytics
        self.error = error
        super.init(nibName: nil, bundle: nil)

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view)
        ])

        generateSubviews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()

        headerView.closeButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)
        linkButton.addTarget(self, action: #selector(linkButtonTapped), for: .touchUpInside)
    }

    @objc private func dismissViewController() {
        delegate?.controllerDismiss(self)
    }

    @objc private func linkButtonTapped() {
        if let url = viewModel.linkUrl {
            switch viewModel.error {
            case .insufficientFunds:
                analytics.log(navigation: Analytics.Navigation.openHelpUrl, properties: [Analytics.Properties.type.rawValue: Analytics.HelpUrl.insufficientFunds.rawValue])
            case .nonceTooLow, .gasPriceTooLow, .gasLimitTooLow, .gasLimitTooHigh, .possibleChainIdMismatch, .executionReverted:
                break
            }
            delegate?.linkTapped(url, forError: error, inController: self)
        } else {
            assertImpossibleCodePath(message: "Should only show link button if there's a URl")
        }
    }

    private func configure() {
        view.backgroundColor = viewModel.backgroundColor

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
            button.shrinkBorderColor = Colors.loadingIndicatorBorder
            button.setTitle(rectifyErrorTitle, for: .normal)
            button.addTarget(self, action: #selector(rectifyErrorButtonTapped), for: .touchUpInside)
            buttonsBar.isHidden = false
        } else {
            buttonsBar.isHidden = true
        }
    }

    @objc private func rectifyErrorButtonTapped() {
        delegate?.rectifyErrorButtonTapped(error: error, inController: self)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension SendTransactionErrorViewController {
    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()
        
        let views: [UIView] = [
            headerView,
            [.spacerWidth(15), titleLabel, .spacerWidth(15)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            [.spacerWidth(15), descriptionLabel, .spacerWidth(15)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            linkButton,
            footerBar
        ]

        stackView.addArrangedSubviews(views)
    }
}
