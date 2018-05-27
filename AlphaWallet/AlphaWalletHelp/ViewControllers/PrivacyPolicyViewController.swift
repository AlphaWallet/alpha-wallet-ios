// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class PrivacyPolicyViewController: HelpContentsViewController {
	override func url() -> URL? {
		return R.file.privacyPolicyHtml()
	}
}
