// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

//TODO might be unnecessary in the future. Full-text search for TokenRowViewProtocol
class TokenListFormatTableViewCellWithoutCheckbox: BaseTokenListFormatTableViewCell {
    override func showCheckbox() -> Bool {
        return false
    }
}
