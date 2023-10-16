// Copyright © 2018 Stormbird PTE. LTD.

import Combine
import UIKit
import WebKit
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletTokenScript

class TokenCardRowView: UIView, TokenCardRowViewProtocol {
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenCountLabel = UILabel()
    private let venueLabel = UILabel()
    private let dateLabel = UILabel()
    private let categoryLabel = UILabel()
    private let matchLabel = UILabel()
    private let dateImageView = UIImageView()
    private let seatRangeImageView = UIImageView()
    private let categoryImageView = UIImageView()
    private let cityLabel = UILabel()
    private let timeLabel = UILabel()
    private let teamsLabel = UILabel()
    private var detailsRowStack: UIStackView?
    private var canDetailsBeVisible = true
    private var nativelyRenderedAttributeViews = [UIView]()
    private let row3: UIStackView
    private let spaceAboveBottomRowStack = UIView.spacer(height: 10)
    private var checkboxRelatedConstraintsWhenShown = [NSLayoutConstraint]()
    private var checkboxRelatedConstraintsWhenHidden = [NSLayoutConstraint]()
    private var lastTokenHolder: TokenHolder?
    private var onlyShowTitle: Bool = false {
        didSet {
            if onlyShowTitle {
                canDetailsBeVisible = false
                row3.isHidden = true
                venueLabel.isHidden = true
                spaceAboveBottomRowStack.isHidden = true
            } else {
                canDetailsBeVisible = true
                row3.isHidden = false
                venueLabel.isHidden = false
                spaceAboveBottomRowStack.isHidden = false
            }
        }
    }

        //These are necessary because non-TokenScript views have margins whereas TokenScript views doesn't
    private var constraintsWithLeadingMarginsThatDependsOnWhetherTokenScriptIsUsed: [NSLayoutConstraint] = []
    private var constraintsWithTrailingMarginsThatDependsOnWhetherTokenScriptIsUsed: [NSLayoutConstraint] = []
    private var constraintsWithTopMarginsThatDependsOnWhetherTokenScriptIsUsed: [NSLayoutConstraint] = []
    private var constraintsWithBottomMarginsThatDependsOnWhetherTokenScriptIsUsed: [NSLayoutConstraint] = []

    let background = UIView()
    var checkboxImageView = UIImageView(image: R.image.ticket_bundle_unchecked())
    var stateLabel = UILabel()
    var tokenView: TokenView
    lazy var tokenScriptRendererView: TokenScriptWebView = {
        let webView = TokenScriptWebView(server: server, serverWithInjectableRpcUrl: server, wallet: wallet.type, assetDefinitionStore: assetDefinitionStore)
        webView.delegate = self
        webView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        return webView
    }()
    var showCheckbox: Bool {
        didSet {
            checkboxImageView.isHidden = !showCheckbox
            if showCheckbox {
                NSLayoutConstraint.deactivate(checkboxRelatedConstraintsWhenHidden)
                NSLayoutConstraint.activate(checkboxRelatedConstraintsWhenShown)
            } else {
                NSLayoutConstraint.deactivate(checkboxRelatedConstraintsWhenShown)
                NSLayoutConstraint.activate(checkboxRelatedConstraintsWhenHidden)
            }
        }
    }
    var areDetailsVisible = false {
        didSet {
            guard canDetailsBeVisible else { return }
            detailsRowStack?.isHidden = !areDetailsVisible
        }
    }
    var isStandalone: Bool {
        get {
            return tokenScriptRendererView.isStandalone
        }
        set {
            tokenScriptRendererView.isStandalone = newValue
        }
    }

    private let wallet: Wallet

    init(server: RPCServer, tokenView: TokenView, showCheckbox: Bool = false, assetDefinitionStore: AssetDefinitionStore, wallet: Wallet) {
        self.server = server
        self.tokenView = tokenView
        self.showCheckbox = showCheckbox
        self.assetDefinitionStore = assetDefinitionStore
        self.wallet = wallet

        row3 = [dateImageView, dateLabel, seatRangeImageView, teamsLabel, .spacerWidth(7), categoryImageView, matchLabel].asStackView(spacing: 7, contentHuggingPriority: .required)

        super.init(frame: .zero)
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        checkboxImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkboxImageView)
        checkboxImageView.isHidden = !showCheckbox

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        let row0 = [tokenCountLabel, categoryLabel].asStackView(spacing: 15, contentHuggingPriority: .required)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        let detailsRow0 = [timeLabel, cityLabel].asStackView(contentHuggingPriority: .required, alignment: .top)

        detailsRowStack = [
            .spacer(height: 10),
            detailsRow0,
        ].asStackView(axis: .vertical, contentHuggingPriority: .required)
        detailsRowStack?.isHidden = true

        let row1 = venueLabel
        let stackView = [
            tokenScriptRendererView,
            stateLabel,
            row0,
            row1,
            spaceAboveBottomRowStack,
            row3,
            detailsRowStack!,
        ].asStackView(axis: .vertical, contentHuggingPriority: .required)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .leading
        background.addSubview(stackView)

        nativelyRenderedAttributeViews = [stateLabel, row0, row1, spaceAboveBottomRowStack, row3, detailsRowStack!]

        constraintsWithLeadingMarginsThatDependsOnWhetherTokenScriptIsUsed = [
            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
        ]
        constraintsWithTrailingMarginsThatDependsOnWhetherTokenScriptIsUsed = [
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
        ]

        constraintsWithTopMarginsThatDependsOnWhetherTokenScriptIsUsed = [
            background.topAnchor.constraint(equalTo: topAnchor),
            stackView.topAnchor.constraint(equalTo: background.topAnchor),
        ]
        constraintsWithBottomMarginsThatDependsOnWhetherTokenScriptIsUsed = [
            background.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor),
        ]

            // TODO extract constant. Maybe DataEntry.Metric.sideMargin
        let xMargin  = CGFloat(7)
        checkboxRelatedConstraintsWhenShown.append(checkboxImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
        checkboxRelatedConstraintsWhenShown.append(checkboxImageView.centerYAnchor.constraint(equalTo: centerYAnchor))
        checkboxRelatedConstraintsWhenShown.append(background.leadingAnchor.constraint(equalTo: checkboxImageView.trailingAnchor, constant: xMargin))
        if ScreenChecker().isNarrowScreen {
            checkboxRelatedConstraintsWhenShown.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 20))
            checkboxRelatedConstraintsWhenShown.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 20))
        } else {
                //Have to be hardcoded and not rely on the image's size because different string lengths for the text fields can force the checkbox to shrink
            checkboxRelatedConstraintsWhenShown.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 28))
            checkboxRelatedConstraintsWhenShown.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 28))
        }
        let c1 = background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0)
        constraintsWithLeadingMarginsThatDependsOnWhetherTokenScriptIsUsed.append(c1)
        checkboxRelatedConstraintsWhenHidden.append(c1)
        if showCheckbox {
            NSLayoutConstraint.activate(checkboxRelatedConstraintsWhenShown)
        } else {
            NSLayoutConstraint.activate(checkboxRelatedConstraintsWhenHidden)
        }

        NSLayoutConstraint.activate([
            detailsRowStack!.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            constraintsWithLeadingMarginsThatDependsOnWhetherTokenScriptIsUsed,
            constraintsWithTrailingMarginsThatDependsOnWhetherTokenScriptIsUsed,
            constraintsWithTopMarginsThatDependsOnWhetherTokenScriptIsUsed,
            constraintsWithBottomMarginsThatDependsOnWhetherTokenScriptIsUsed,

            tokenScriptRendererView.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            stateLabel.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        lastTokenHolder = tokenHolder
        configure(viewModel: TokenCardRowViewModel(tokenHolder: tokenHolder, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
    }
    private var cancellable = Set<AnyCancellable>()

        // swiftlint:disable function_body_length
    func configure(viewModel: TokenCardRowViewModelProtocol) {
        cancellable.cancellAll()
        backgroundColor = viewModel.contentsBackgroundColor
        background.backgroundColor = viewModel.contentsBackgroundColor

        stateLabel.backgroundColor = viewModel.stateBackgroundColor
        stateLabel.layer.cornerRadius = 8
        stateLabel.clipsToBounds = true
        stateLabel.textColor = viewModel.stateColor
        stateLabel.font = viewModel.subtitleFont

        tokenCountLabel.textColor = viewModel.countColor
        tokenCountLabel.font = viewModel.tokenCountFont

        venueLabel.textColor = viewModel.titleColor
        venueLabel.font = viewModel.venueFont

        dateLabel.textColor = viewModel.subtitleColor
        dateLabel.font = viewModel.subtitleFont

        categoryLabel.textColor = viewModel.titleColor
        categoryLabel.font = viewModel.titleFont

        matchLabel.textColor = viewModel.subtitleColor
        matchLabel.font = viewModel.subtitleFont

        dateImageView.image = R.image.calendar()?.withRenderingMode(.alwaysTemplate)
        seatRangeImageView.image = R.image.ticket()?.withRenderingMode(.alwaysTemplate)
        categoryImageView.image = R.image.category()?.withRenderingMode(.alwaysTemplate)

        dateImageView.tintColor = viewModel.iconsColor
        seatRangeImageView.tintColor = viewModel.iconsColor
        categoryImageView.tintColor = viewModel.iconsColor

        cityLabel.textColor = viewModel.subtitleColor
        cityLabel.font = viewModel.detailsFont
        cityLabel.numberOfLines = 0

        timeLabel.textColor = viewModel.subtitleColor
        timeLabel.font = viewModel.detailsFont

        teamsLabel.textColor = viewModel.subtitleColor
        teamsLabel.font = viewModel.subtitleFont

        tokenCountLabel.text = viewModel.tokenCount

        venueLabel.text = viewModel.venue

        dateLabel.text = viewModel.date

        timeLabel.text = viewModel.time

        cityLabel.text = viewModel.city

        categoryLabel.text = viewModel.category

        teamsLabel.text = viewModel.teams

        matchLabel.text = viewModel.match

        onlyShowTitle = viewModel.onlyShowTitle

        if viewModel.isMeetupContract {
            teamsLabel.text = viewModel.match
            matchLabel.text = viewModel.numero

            viewModel.buildingPublisher()
                .assign(to: \.text, on: venueLabel)
                .store(in: &cancellable)

            viewModel.streetLocalityStateCountryPublisher()
                .sink { [weak self] string in
                    self?.timeLabel.text = ""
                    self?.cityLabel.text = "\(viewModel.time), \(string)"
                }.store(in: &cancellable)
        } else {
            //do nothing
        }

        if viewModel.hasTokenScriptHtml {
            canDetailsBeVisible = false
            nativelyRenderedAttributeViews.hideAll()
            tokenScriptRendererView.isHidden = false
            tokenScriptRendererView.loadHtml(viewModel.tokenScriptHtml.html, urlFragment: viewModel.tokenScriptHtml.urlFragment)
                //TODO not good to explicitly check for different types. Easy to miss
            if let viewModel = viewModel as? TokenCardRowViewModel {
                tokenScriptRendererView.update(withTokenHolder: viewModel.tokenHolder, isFungible: false)
            } else if let viewModel = viewModel as? ImportMagicTokenCardRowViewModel, let tokenHolder = viewModel.tokenHolder {
                tokenScriptRendererView.update(withTokenHolder: tokenHolder, isFungible: false)
            }
        } else {
            nativelyRenderedAttributeViews.showAll()
                //TODO we can't change it here. Because it is set (correctly) earlier. Fix this inconsistency
            tokenScriptRendererView.isHidden = true
        }

        for each in constraintsWithLeadingMarginsThatDependsOnWhetherTokenScriptIsUsed {
            if viewModel.hasTokenScriptHtml {
                each.constant = 0
            } else {
                each.constant = 7
            }
        }
        for each in constraintsWithTrailingMarginsThatDependsOnWhetherTokenScriptIsUsed {
            if viewModel.hasTokenScriptHtml {
                each.constant = 0
            } else {
                each.constant = -7
            }
        }
        for each in constraintsWithTopMarginsThatDependsOnWhetherTokenScriptIsUsed {
            if viewModel.hasTokenScriptHtml {
                each.constant = 0
            } else {
                each.constant = 5
            }
        }
        for each in constraintsWithBottomMarginsThatDependsOnWhetherTokenScriptIsUsed {
            if viewModel.hasTokenScriptHtml {
                each.constant = 0
            } else {
                each.constant = -5
            }
        }

        adjustmentsToHandleWhenCategoryLabelTextIsTooLong()
    }
        // swiftlint:enable function_body_length

    private func adjustmentsToHandleWhenCategoryLabelTextIsTooLong() {
        tokenCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        categoryLabel.adjustsFontSizeToFitWidth = true
    }
}

extension TokenCardRowView: TokenRowView {
    func configure(tokenHolder: TokenHolder) {
        lastTokenHolder = tokenHolder
        configure(viewModel: TokenCardRowViewModel(tokenHolder: tokenHolder, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
    }
}

extension TokenCardRowView: TokenScriptWebViewDelegate {
    func requestSignMessage(message: SignMessageType, server: RPCServer, account: AlphaWallet.Address, inTokenScriptWebView tokenScriptWebView: TokenScriptWebView) -> AnyPublisher<Data, PromiseError> {
        return .fail(PromiseError(error: JsonRpcError.requestRejected))
    }

    func shouldClose(tokenScriptWebView: TokenScriptWebView) {
        //no-op
    }

    func reinject(tokenScriptWebView: TokenScriptWebView) {
        //Refresh if view, but not item-view
        if isStandalone {
            guard let lastTokenHolder = lastTokenHolder else { return }
            configure(tokenHolder: lastTokenHolder)
        } else {
            //no-op for item-views
        }
    }
}
