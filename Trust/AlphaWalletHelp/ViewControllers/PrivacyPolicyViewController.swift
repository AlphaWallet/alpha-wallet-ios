// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class PrivacyPolicyViewController: AlphaWalletHelpContentsViewController{
	override func url() -> URL? {
		return R.file.privacyPolicyHtml()
	}
}
