// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivityViewControllerDelegate: AnyObject {
    func reinject(viewController: ActivityViewController)
    func goToToken(viewController: ActivityViewController)
    func speedupTransaction(transactionId: String, server: RPCServer, viewController: ActivityViewController)
    func cancelTransaction(transactionId: String, server: RPCServer, viewController: ActivityViewController)
    func goToTransaction(viewController: ActivityViewController)
    func didPressViewContractWebPage(_ contract: AlphaWallet.Address, server: RPCServer, viewController: ActivityViewController)
}

class ActivityViewController: UIViewController {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let roundedBackground = RoundedBackground()
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private let tokenImageView = TokenImageView()
    private let stateView = ActivityStateView()
    private let titleLabel = UILabel()
    private let subTitleLabel = UILabel()
    private let timestampLabel = UILabel()
    private let separator = UIView()
    private let bottomFiller = UIView.spacerWidth()
    lazy private var tokenScriptRendererView: TokenInstanceWebView = {
        let webView = TokenInstanceWebView(analyticsCoordinator: analyticsCoordinator, server: server, wallet: wallet, assetDefinitionStore: assetDefinitionStore)
        webView.isWebViewInteractionEnabled = true
        webView.delegate = self
        webView.isStandalone = true
        webView.isAction = true
        return webView
    }()
    private var isFirstLoad = true
    private let defaultErc20ActivityView = DefaultActivityView()

    private var server: RPCServer {
        viewModel.activity.tokenObject.server
    }

    var viewModel: ActivityViewModel

    weak var delegate: ActivityViewControllerDelegate?
    private let service: ActivitiesServiceType
    private var subscriptionKey: Subscribable<Activity>.SubscribableKey?

    init(analyticsCoordinator: AnalyticsCoordinator, wallet: Wallet, assetDefinitionStore: AssetDefinitionStore, viewModel: ActivityViewModel, service: ActivitiesServiceType) {
        self.service = service
        self.analyticsCoordinator = analyticsCoordinator
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        let viewTransactionButton = UIBarButtonItem(image: R.image.statement(), style: .plain, target: self, action: #selector(showTransaction))
        navigationItem.rightBarButtonItem = viewTransactionButton

        title = viewModel.viewControllerTitle
        view.backgroundColor = viewModel.backgroundColor

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tokenImageView.contentMode = .scaleAspectFit
        let tap = UITapGestureRecognizer(target: self, action: #selector(showContractWebPage))
        tokenImageView.addGestureRecognizer(tap)

        let stackView = [
            .spacer(height: 26),
            timestampLabel,
            .spacer(height: 13),
            tokenImageView,
            .spacer(height: 17),
            titleLabel,
            .spacer(height: 25),
            defaultErc20ActivityView,
            tokenScriptRendererView,
            bottomFiller,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        roundedBackground.addSubview(stackView)
        roundedBackground.addSubview(stateView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        roundedBackground.addSubview(footerBar)

        var constraints: [LayoutConstraintsWrapper] = [
            //Setting height for labels to get their heights to be correct. If we want to remove them, make sure to test with both the native Activity view and TokenScript (HTML) Activity views
            timestampLabel.heightAnchor.constraint(equalToConstant: 20),
            titleLabel.heightAnchor.constraint(equalToConstant: 26),
            subTitleLabel.heightAnchor.constraint(equalToConstant: 20),

            tokenImageView.heightAnchor.constraint(equalToConstant: 105),
            tokenImageView.widthAnchor.constraint(equalToConstant: 105),

            stackView.anchorsConstraint(to: roundedBackground),

            tokenScriptRendererView.widthAnchor.constraint(equalTo: stackView.widthAnchor),

        ] + roundedBackground.createConstraintsWithContainer(view: view)
        + stateView.anchorConstraints(to: tokenImageView, size: .init(width: 24, height: 24), bottomOffset: .zero)
        let footerConstraints: [NSLayoutConstraint] = footerBar.anchorsConstraint(to: view)
        constraints += footerConstraints
        NSLayoutConstraint.activate(constraints)

        configure(viewModel: viewModel)

        subscriptionKey = service.subscribableUpdatedActivity.subscribe { [weak self] activity in
            guard let strongSelf = self, let activity = activity, strongSelf.isForActivity(activity) else { return }

            strongSelf.configure(viewModel: .init(activity: activity))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.largeTitleDisplayMode = .never
    }

    func configure(viewModel: ActivityViewModel) {
        self.viewModel = viewModel

        let tokenAttributes = viewModel.activity.values.token
        let cardAttributes = viewModel.activity.values.card

        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.font = viewModel.titleFont
        titleLabel.attributedText = viewModel.title

        subTitleLabel.text = viewModel.subTitle
        subTitleLabel.textColor = viewModel.subTitleTextColor
        subTitleLabel.font = viewModel.subTitleFont

        timestampLabel.textColor = viewModel.timestampColor
        timestampLabel.font = viewModel.timestampFont
        timestampLabel.text = viewModel.timestamp

        tokenImageView.subscribable = viewModel.iconImage
        stateView.configure(viewModel: viewModel.activityStateViewViewModel)

        timestampLabel.textAlignment = .center
        titleLabel.textAlignment = .center
        subTitleLabel.textAlignment = .center

        separator.backgroundColor = GroupedTable.Color.cellSeparator

        switch viewModel.activity.nativeViewType {
        case .erc20Received, .erc20Sent, .erc20OwnerApproved, .erc20ApprovalObtained, .erc721Sent, .erc721Received, .erc721OwnerApproved, .erc721ApprovalObtained, .nativeCryptoSent, .nativeCryptoReceived:
            defaultErc20ActivityView.isHidden = false
            bottomFiller.isHidden = false
            tokenScriptRendererView.isHidden = true
            defaultErc20ActivityView.configure(viewModel: .init(activity: viewModel.activity))
        case .none:
            defaultErc20ActivityView.isHidden = true
            bottomFiller.isHidden = true
            tokenScriptRendererView.isHidden = false

            let (html: html, hash: hash) = viewModel.activity.viewHtml
            tokenScriptRendererView.loadHtml(html, hash: hash)

            tokenScriptRendererView.update(withId: .init(viewModel.activity.id), resolvedTokenAttributeNameValues: tokenAttributes, resolvedCardAttributeNameValues: cardAttributes, isFirstUpdate: isFirstLoad)
            isFirstLoad = false
        }

        buttonsBar.viewController = self
        if Features.isSpeedupAndCancelEnabled && viewModel.isPendingTransaction {
            buttonsBar.configure(.combined(buttons: 3))
            configureSpeedupButton(buttonsBar.buttons[0])
            configureCancelButton(buttonsBar.buttons[1])
            configureGoToTokenButton(buttonsBar.buttons[2])
        } else {
            buttonsBar.configure(.green(buttons: 1))
            configureGoToTokenButton(buttonsBar.buttons[0])
        }
    }

    private func configureGoToTokenButton(_ button: BarButton) {
        button.setTitle(R.string.localizable.activityGoToToken(), for: .normal)
        button.addTarget(self, action: #selector(goToToken), for: .touchUpInside)
    }

    private func configureSpeedupButton(_ button: BarButton) {
        button.setTitle(R.string.localizable.activitySpeedup(), for: .normal)
        button.addTarget(self, action: #selector(speedup), for: .touchUpInside)
    }

    private func configureCancelButton(_ button: BarButton) {
        button.setTitle(R.string.localizable.activityCancel(), for: .normal)
        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
    }

    func isForActivity(_ activity: Activity) -> Bool {
        viewModel.activity.id == activity.id
    }

    @objc private func goToToken() {
        delegate?.goToToken(viewController: self)
    }

    @objc private func speedup() {
        delegate?.speedupTransaction(transactionId: viewModel.activity.transactionId, server: viewModel.activity.server, viewController: self)
    }

    @objc private func cancel() {
        delegate?.cancelTransaction(transactionId: viewModel.activity.transactionId, server: viewModel.activity.server, viewController: self)
    }

    @objc private func showContractWebPage() {
        delegate?.didPressViewContractWebPage(viewModel.activity.tokenObject.contractAddress, server: viewModel.activity.tokenObject.server, viewController: self)
    }

    @objc private func showTransaction() {
        delegate?.goToTransaction(viewController: self)
    }
}

extension ActivityViewController: TokenInstanceWebViewDelegate {
    //TODO not good. But quick and dirty to ship
    func navigationControllerFor(tokenInstanceWebView: TokenInstanceWebView) -> UINavigationController? {
        navigationController
    }

    func shouldClose(tokenInstanceWebView: TokenInstanceWebView) {
        //no-op
    }

    func heightChangedFor(tokenInstanceWebView: TokenInstanceWebView) {
        //no-op. Auto layout handles it
    }

    func reinject(tokenInstanceWebView: TokenInstanceWebView) {
        delegate?.reinject(viewController: self)
    }
}
