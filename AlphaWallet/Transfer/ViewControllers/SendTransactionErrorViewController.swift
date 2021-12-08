// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

protocol SendTransactionErrorViewControllerDelegate: AnyObject {
    func rectifyErrorButtonTapped(error: SendTransactionNotRetryableError, inController controller: SendTransactionErrorViewController)
    func linkTapped(_ url: URL, forError error: SendTransactionNotRetryableError, inController controller: SendTransactionErrorViewController)
    func controllerDismiss(_ controller: SendTransactionErrorViewController)
}

class SendTransactionErrorViewController: UIViewController {
    private let server: RPCServer
    private let analyticsCoordinator: AnalyticsCoordinator
    private let error: SendTransactionNotRetryableError
    private lazy var viewModel = SendTransactionErrorViewModel(server: server, error: error)
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: "", isMinimalMode: true))
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))

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

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        return scrollView
    }()

    private var contentSizeObservation: NSKeyValueObservation?

    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = viewModel.footerBackgroundColor
        view.addSubview(buttonsBar)

        return view
    }()

    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissViewController))
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(tap)

        return view
    }()

    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.cornerRadius = 12

        view.addSubview(scrollView)
        view.addSubview(footerBar)
        view.addSubview(headerView)

        return view
    }()

    private lazy var heightConstraint: NSLayoutConstraint = {
        return containerView.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()

    private lazy var bottomConstraint: NSLayoutConstraint = {
        containerView.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }()

    private var allowPresentationAnimation: Bool = true
    private var allowDismissalAnimation: Bool = true

    weak var delegate: SendTransactionErrorViewControllerDelegate?

    init(server: RPCServer, analyticsCoordinator: AnalyticsCoordinator, error: SendTransactionNotRetryableError) {
        self.server = server
        self.analyticsCoordinator = analyticsCoordinator
        self.error = error
        super.init(nibName: nil, bundle: nil)

        view.addSubview(backgroundView)
        view.addSubview(containerView)

        //Can't move this into the closure for creating the button, it'll compile, but tapping button becomes a no-op
        linkButton.addTarget(self, action: #selector(linkButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            backgroundView.bottomAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            heightConstraint,
            bottomConstraint,
            containerView.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 26),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -26),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            footerBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor),

            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
        ])
        headerView.closeButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .initial]) { [weak self] scrollView, _ in
            guard let strongSelf = self, strongSelf.allowDismissalAnimation else { return }

            let statusBarHeight = UIApplication.shared.statusBarFrame.height
            let contentHeight = scrollView.contentSize.height + DataEntry.Metric.TransactionConfirmation.footerHeight + DataEntry.Metric.TransactionConfirmation.headerHeight + UIApplication.shared.bottomSafeAreaHeight
            let newHeight = min(UIScreen.main.bounds.height - statusBarHeight, contentHeight)

            let fillScreenPercentage = strongSelf.heightConstraint.constant / strongSelf.view.bounds.height

            if fillScreenPercentage >= 0.9 {
                strongSelf.heightConstraint.constant = strongSelf.containerView.bounds.height
            } else {
                strongSelf.heightConstraint.constant = newHeight
            }
        }

        generateSubviews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        //NOTE: to display animation correctly we can take 'view.frame.height' and bottom view will smoothly slide up from button ;)
        bottomConstraint.constant = view.frame.height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(true, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presentViewAnimated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(false, animated: false)
        }
    }

    private func presentViewAnimated() {
        guard allowPresentationAnimation else { return }
        allowPresentationAnimation = false

        bottomConstraint.constant = 0

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    func dismissViewAnimated(with completion: @escaping () -> Void) {
        guard allowDismissalAnimation else { return }
        allowDismissalAnimation = false

        bottomConstraint.constant = heightConstraint.constant

        UIView.animate(withDuration: 0.4, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            completion()
        })
    }

    @objc private func dismissViewController() {
        delegate?.controllerDismiss(self)
    }

    @objc private func linkButtonTapped() {
        if let url = viewModel.linkUrl {
            switch viewModel.error {
            case .insufficientFunds:
                analyticsCoordinator.log(navigation: Analytics.Navigation.openHelpUrl, properties: [Analytics.Properties.type.rawValue: Analytics.HelpUrl.insufficientFunds.rawValue])
            case .nonceTooLow, .gasPriceTooLow, .gasLimitTooLow, .gasLimitTooHigh, .possibleChainIdMismatch, .executionReverted:
                break
            }
            delegate?.linkTapped(url, forError: error, inController: self)
        } else {
            assertImpossibleCodePath(message: "Should only show link button if there's a URl")
        }
    }

    private func configure() {
        scrollView.backgroundColor = viewModel.backgroundColor
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
            titleLabel,
            .spacer(height: 20),
            descriptionLabel,
            .spacer(height: 20),
            linkButton,
        ]
        stackView.addArrangedSubviews(views)
    }
}