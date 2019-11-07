// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ServerViewModel {
    private let server: RPCServerOrAuto
    private let isSelected: Bool

    init(server: RPCServerOrAuto, selected: Bool) {
        self.server = server
        self.isSelected = selected
    }

    init(server: RPCServer, selected: Bool) {
        self.server = .server(server)
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
        return Colors.appBackground
    }

    var serverFont: UIFont {
        return Fonts.light(size: 20)!
    }

    var serverName: String {
        return server.displayName
    }
}
