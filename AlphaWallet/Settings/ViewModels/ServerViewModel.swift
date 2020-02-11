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

    var accessoryType: UITableViewCell.AccessoryType {
        if isSelected {
            return LocaleViewCell.selectionAccessoryType.selected
        } else {
            return LocaleViewCell.selectionAccessoryType.unselected
        }
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var serverFont: UIFont {
        return Fonts.regular(size: 17)!
    }

    var serverName: String {
        return server.displayName
    }
}
