// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TermsOfServiceViewController: AlphaWalletHelpContentsViewController{
	override func url() -> URL? {
		return R.file.termsOfServiceHtml()
	}
}
