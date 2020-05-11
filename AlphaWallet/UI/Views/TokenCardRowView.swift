// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import WebKit

protocol TokenCardRowViewDelegate: class {
    func heightChangedFor(tokenCardRowView: TokenCardRowView)
}

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
	lazy private var tokenScriptRendererView: TokenInstanceWebView = {
		//TODO pass in keystore or wallet address instead
		let walletAddress = EtherKeystore.current!.address
		//TODO this can't sign personal message because we didn't set a delegate, but we don't need it also
		let webView = TokenInstanceWebView(server: server, walletAddress: walletAddress, assetDefinitionStore: assetDefinitionStore)
		webView.delegate = self
		return webView
	}()

    //These are necessary because non-TokenScript views have margins whereas TokenScript views doesn't
	private var constraintsWithLeadingMarginsThatDependsOnWhetherTokenScriptIsUsed: [NSLayoutConstraint] = []
	private var constraintsWithTrailingMarginsThatDependsOnWhetherTokenScriptIsUsed: [NSLayoutConstraint] = []
	private var constraintsWithTopMarginsThatDependsOnWhetherTokenScriptIsUsed: [NSLayoutConstraint] = []
	private var constraintsWithBottomMarginsThatDependsOnWhetherTokenScriptIsUsed: [NSLayoutConstraint] = []

	weak var delegate: TokenCardRowViewDelegate?
	let background = UIView()
	var checkboxImageView = UIImageView(image: R.image.ticket_bundle_unchecked())
	var stateLabel = UILabel()
	var tokenView: TokenView
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
	var additionalHeightToCompensateForAutoLayout: CGFloat {
		return 0
	}
	var shouldOnlyRenderIfHeightIsCached: Bool = false {
        didSet {
			tokenScriptRendererView.shouldOnlyRenderIfHeightIsCached = shouldOnlyRenderIfHeightIsCached
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

	init(server: RPCServer, tokenView: TokenView, showCheckbox: Bool = false, assetDefinitionStore: AssetDefinitionStore) {
		self.server = server
		self.tokenView = tokenView
        self.showCheckbox = showCheckbox
		self.assetDefinitionStore = assetDefinitionStore

		row3 = [dateImageView, dateLabel, seatRangeImageView, teamsLabel, .spacerWidth(7), categoryImageView, matchLabel].asStackView(spacing: 7, contentHuggingPriority: .required)

		super.init(frame: .zero)

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

		// TODO extract constant. Maybe StyleLayout.sideMargin
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

	func configure(tokenHolder: TokenHolder, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        configure(viewModel: TokenCardRowViewModel(tokenHolder: tokenHolder, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
	}

// swiftlint:disable function_body_length
	func configure(viewModel: TokenCardRowViewModelProtocol) {
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

			viewModel.subscribeBuilding { [weak self] building in
				self?.venueLabel.text = building
			}

			viewModel.subscribeStreetLocalityStateCountry { [weak self] streetLocalityStateCountry in
				guard let strongSelf = self else { return }
				strongSelf.timeLabel.text = ""
				strongSelf.cityLabel.text = "\(viewModel.time), \(streetLocalityStateCountry)"
			}
		} else {
			//do nothing
		}

		if viewModel.hasTokenScriptHtml {
			canDetailsBeVisible = false
			nativelyRenderedAttributeViews.hideAll()
			tokenScriptRendererView.isHidden = false
			let (html: html, hash: hash) = viewModel.tokenScriptHtml
			tokenScriptRendererView.loadHtml(html, hash: hash)
			//TODO not good to explicitly check for different types. Easy to miss
			if let viewModel = viewModel as? TokenCardRowViewModel {
				tokenScriptRendererView.update(withTokenHolder: viewModel.tokenHolder, isFungible: false)
			} else if let viewModel = viewModel as? ImportMagicTokenCardRowViewModel, let tokenHolder = viewModel.tokenHolder {
				tokenScriptRendererView.update(withTokenHolder: tokenHolder, isFungible: false)
			}
		} else {
			nativelyRenderedAttributeViews.showAll()
			//TODO we can't change it here. Because it is set (correctly) earlier. Fix this inconsistency
//			canDetailsBeVisible = true
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
		configure(viewModel: TokenCardRowViewModel(tokenHolder: tokenHolder, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
	}
}

extension TokenCardRowView: TokenInstanceWebViewDelegate {
	func navigationControllerFor(tokenInstanceWebView: TokenInstanceWebView) -> UINavigationController? {
		return nil
	}

	func shouldClose(tokenInstanceWebView: TokenInstanceWebView) {
        //no-op
	}

	func heightChangedFor(tokenInstanceWebView: TokenInstanceWebView) {
        delegate?.heightChangedFor(tokenCardRowView: self)
	}

	func reinject(tokenInstanceWebView: TokenInstanceWebView) {
		//no-op
    }
}
