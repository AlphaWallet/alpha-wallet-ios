// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol ServerTableViewCellViewModelType {
    var isTopSeparatorHidden: Bool { get }
    var accessoryType: UITableViewCell.AccessoryType { get }
    var backgroundColor: UIColor { get }
    var serverFont: UIFont { get }
    var serverName: String { get }
    var serverColor: UIColor { get }
    var selectionStyle: UITableViewCell.SelectionStyle { get set }
}

struct ServerViewModel: ServerTableViewCellViewModelType {
    private let server: RPCServerOrAuto
    private let isSelected: Bool
    let isTopSeparatorHidden: Bool

    init(server: RPCServerOrAuto, selected: Bool) {
        self.server = server
        self.isSelected = selected
        self.isTopSeparatorHidden = true
    }

    init(server: RPCServer, selected: Bool) {
        self.server = .server(server)
        self.isSelected = selected
        self.isTopSeparatorHidden = true
    }

    var accessoryType: UITableViewCell.AccessoryType {
        if isSelected {
            return LocaleViewCell.selectionAccessoryType.selected
        } else {
            return LocaleViewCell.selectionAccessoryType.unselected
        }
    }

    var backgroundColor: UIColor = Colors.appBackground

    var serverFont: UIFont = Fonts.regular(size: 17)
    var serverColor: UIColor = Colors.black
    var serverName: String {
        return server.displayName
    }
    var selectionStyle: UITableViewCell.SelectionStyle = .default
}

struct TokenListServerTableViewCellViewModel: ServerTableViewCellViewModelType {
    private let server: RPCServer
    let isTopSeparatorHidden: Bool

    init(server: RPCServer, isTopSeparatorHidden: Bool) {
        self.server = server
        self.isTopSeparatorHidden = isTopSeparatorHidden
    }

    var accessoryType: UITableViewCell.AccessoryType = LocaleViewCell.selectionAccessoryType.unselected
    var backgroundColor: UIColor = R.color.alabaster()!
    var serverFont: UIFont = Fonts.semibold(size: 15)
    var serverColor: UIColor = R.color.dove()!
    var serverName: String {
        return server.displayName.uppercased()
    }
    var selectionStyle: UITableViewCell.SelectionStyle = .none
}
