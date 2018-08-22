// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct BaseTokenTableViewCellViewModel {
    let TokenHolder: TokenHolder

    init(
            TokenHolder: TokenHolder
    ) {
        self.TokenHolder = TokenHolder
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var status: String {
        return ""
    }

    var checkboxImage: UIImage {
        if TokenHolder.isSelected {
            return R.image.Token_bundle_checked()!
        } else {
            return R.image.Token_bundle_unchecked()!
        }
    }

    var areDetailsVisible: Bool {
        return TokenHolder.areDetailsVisible
    }
}
