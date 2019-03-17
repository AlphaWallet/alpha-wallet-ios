// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

//TODO might be unnecessary in the future. Full-text search for TokenRowViewProtocol
class OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox: BaseOpenSeaNonFungibleTokenCardTableViewCell {
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
