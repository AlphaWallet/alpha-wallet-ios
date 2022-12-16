// Copyright © 2018 Stormbird PTE. LTD.
import UIKit

struct StatusViewControllerViewModel {
	enum State {
		case processing
		case succeeded
		case failed
	}

    private let inProgressText: String
	private let succeededTextText: String
	private let failedText: String

	var state: State

	var contentsBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
	}
	var image: UIImage? {
		switch state {
		case .processing:
			return nil
		case .succeeded:
			return R.image.onboarding_complete()
		case .failed:
			return R.image.onboarding_failed()
		}
	}
	var titleColor: UIColor {
		return Configuration.Color.Semantic.defaultForegroundText
	}
	var titleFont: UIFont {
		return Fonts.regular(size: 25)
	}
	var activityIndicatorColor: UIColor {
		return Configuration.Color.Semantic.navigationbarPrimaryFont
	}
	var actionButtonTitleColor: UIColor {
        return Configuration.Color.Semantic.primaryButtonTextActive
	}
	var actionButtonBackgroundColor: UIColor {
		return Configuration.Color.Semantic.actionButtonBackground
	}
	var actionButtonTitleFont: UIFont {
		return Fonts.regular(size: 20)
	}
	var titleLabelText: String {
		switch state {
		case .processing:
			return inProgressText
		case .succeeded:
			return succeededTextText
		case .failed:
			return failedText
		}
	}
	var actionButtonTitle: String {
		return R.string.localizable.done()
	}
	var showActivityIndicator: Bool {
		return state == .processing
	}

	init(state: State, inProgressText: String, succeededTextText: String, failedText: String) {
		self.state = state
		self.inProgressText = inProgressText
        self.succeededTextText = succeededTextText
        self.failedText = failedText
	}
}
