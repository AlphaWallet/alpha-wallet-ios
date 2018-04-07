// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct StatusViewControllerViewModel {
	enum State {
		case processing
		case succeeded
		case failed
	}
	var state: State
    let inProgressText: String
	let succeededTextText: String
	let failedText: String

	var contentsBackgroundColor: UIColor {
		return Colors.appWhite
	}
	var image: UIImage? {
		switch state {
		case .processing:
			return nil
		case .succeeded:
			return R.image.onboarding_complete()
		case .failed:
			 //TODO return a failed version
			return R.image.onboarding_complete()
		}
	}
	var titleColor: UIColor {
		return Colors.appText
	}
	var titleFont: UIFont {
		return Fonts.light(size: 25)!
	}
	var activityIndicatorColor: UIColor {
		return Colors.appBackground
	}
	var actionButtonTitleColor: UIColor {
		return Colors.appWhite
	}
	var actionButtonBackgroundColor: UIColor {
		return Colors.appBackground
	}
	var actionButtonTitleFont: UIFont {
		return Fonts.regular(size: 20)!
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
		return R.string.localizable.aClaimTicketDoneButtonTitle()
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
