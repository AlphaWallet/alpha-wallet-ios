// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivityViewControllerDelegate: class {
    func reinject(viewController: ActivityViewController)
    func goToToken(viewController: ActivityViewController)
    func goToTransaction(viewController: ActivityViewController)
    func didPressViewContractWebPage(_ contract: AlphaWallet.Address, server: RPCServer, viewController: ActivityViewController)
}

class ActivityViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private let assetDefinitionStore: AssetDefinitionStore
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private let tokenImageView = TokenImageView()
    private let stateImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subTitleLabel = UILabel()
    private let timestampLabel = UILabel()
    private let separator = UIView()
    private let bottomFiller = UIView.spacerWidth()
    lazy private var tokenScriptRendererView: TokenInstanceWebView = {
        //TODO pass in keystore or wallet address instead
        let walletAddress = EtherKeystore.current!.address
        let webView = TokenInstanceWebView(server: server, walletAddress: walletAddress, assetDefinitionStore: assetDefinitionStore)
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

    init(assetDefinitionStore: AssetDefinitionStore, viewModel: ActivityViewModel) {
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

        stateImageView.translatesAutoresizingMaskIntoConstraints = false
        stateImageView.contentMode = .scaleAspectFit

        let stackView = [
            .spacer(height: 8),
            timestampLabel,
            .spacer(height: 20),
            tokenImageView,
            .spacer(height: 17),
            titleLabel,
            .spacer(height: 0),
            subTitleLabel,
            .spacer(height: 27),
            separator,
            .spacer(height: 27),
            defaultErc20ActivityView,
            tokenScriptRendererView,
            bottomFiller,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        roundedBackground.addSubview(stackView)
        roundedBackground.addSubview(stateImageView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            //Setting height for labels to get their heights to be correct. If we want to remove them, make sure to test with both the native Activity view and TokenScript (HTML) Activity views
            timestampLabel.heightAnchor.constraint(equalToConstant: 20),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),
            subTitleLabel.heightAnchor.constraint(equalToConstant: 20),

            tokenImageView.heightAnchor.constraint(equalToConstant: 60),
            tokenImageView.widthAnchor.constraint(equalToConstant: 60),

            stateImageView.heightAnchor.constraint(equalToConstant: 24),
            stateImageView.widthAnchor.constraint(equalToConstant: 24),
            stateImageView.trailingAnchor.constraint(equalTo: tokenImageView.trailingAnchor),
            stateImageView.bottomAnchor.constraint(equalTo: tokenImageView.bottomAnchor),

            separator.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -20),
            separator.heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),
            stackView.anchorsConstraint(to: roundedBackground),

            tokenScriptRendererView.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ActivityViewModel) {
        self.viewModel = viewModel

        let tokenAttributes = viewModel.activity.values.token
        let cardAttributes = viewModel.activity.values.card

        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title

        subTitleLabel.text = viewModel.subTitle
        subTitleLabel.textColor = viewModel.subTitleTextColor
        subTitleLabel.font = viewModel.subTitleFont

        timestampLabel.textColor = viewModel.timestampColor
        timestampLabel.font = viewModel.timestampFont
        timestampLabel.text = viewModel.timestamp

        tokenImageView.subscribable = viewModel.iconImage
        stateImageView.image = viewModel.stateImage

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

        buttonsBar.configure(.green(buttons: 1))
        let button = buttonsBar.buttons[0]
        button.setTitle(R.string.localizable.activityGoToToken(), for: .normal)
        button.addTarget(self, action: #selector(goToToken), for: .touchUpInside)
    }

    func isForActivity(_ activity: Activity) -> Bool {
        viewModel.activity.id == activity.id
    }

    @objc private func goToToken() {
        delegate?.goToToken(viewController: self)
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
