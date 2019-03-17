// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TokenCardTableViewCellWithCheckbox: BaseTokenCardTableViewCell {
    //TODO merge the var and func. Look for another occurence of this comment
    var isCheckboxVisible: Bool = true {
        didSet {
            reflectCheckboxVisibility()
        }
    }

    override func showCheckbox() -> Bool {
        return isCheckboxVisible
    }
}
