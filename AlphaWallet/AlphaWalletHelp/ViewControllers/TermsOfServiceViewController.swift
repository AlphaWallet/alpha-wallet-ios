// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TermsOfServiceViewController: HelpContentsViewController {
	override var url: URL? {
		return R.file.termsOfServiceHtml()
	}
}
