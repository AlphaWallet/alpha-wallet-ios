// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ServerViewModel {
    let server: RPCServer
    let isSelected: Bool

    init(server: RPCServer, selected: Bool) {
        self.server = server
        self.isSelected = selected
    }

    var selectionIcon: UIImage {
        if isSelected {
            return R.image.ticket_bundle_checked()!
        } else {
            return R.image.ticket_bundle_unchecked()!
        }
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return backgroundColor
    }

    var contentsBorderColor: UIColor {
        return Colors.appHighlightGreen
    }

    var contentsBorderWidth: CGFloat {
        return 1
    }

    var serverFont: UIFont {
        return Fonts.light(size: 20)!
    }

    var serverName: String {
        return server.displayName
    }
}
