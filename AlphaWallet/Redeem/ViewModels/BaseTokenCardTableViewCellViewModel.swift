// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct BaseTokenCardTableViewCellViewModel {
    let tokenHolder: TokenHolder

    init(
            tokenHolder: TokenHolder
    ) {
        self.tokenHolder = tokenHolder
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var status: String {
        return ""
    }

    var checkboxImage: UIImage {
        if tokenHolder.isSelected {
            return R.image.ticket_bundle_checked()!
        } else {
            return R.image.ticket_bundle_unchecked()!
        }
    }

    var areDetailsVisible: Bool {
        return tokenHolder.areDetailsVisible
    }
}
