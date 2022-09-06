// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

protocol ServerTableViewCellViewModelType {
    var isTopSeparatorHidden: Bool { get }
    var accessoryType: UITableViewCell.AccessoryType { get }
    var backgroundColor: UIColor { get }
    var serverFont: UIFont { get }
    var serverName: String { get }
    var serverColor: UIColor { get }
    var selectionStyle: UITableViewCell.SelectionStyle { get set }
}

protocol ServerImageTableViewCellViewModelType {
    var isAvailableToSelect: Bool { get }
    var backgroundColor: UIColor { get }
    var isSelected: Bool { get }
    var isTopSeparatorHidden: Bool { get }
    var primaryFont: UIFont { get }
    var primaryText: String { get }
    var primaryFontColor: UIColor { get }
    var secondaryFont: UIFont { get }
    var secondaryText: String { get }
    var secondaryFontColor: UIColor { get }
    var selectionStyle: UITableViewCell.SelectionStyle { get set }
    var server: RPCServerOrAuto { get }
    var serverColor: UIColor { get }
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

struct ServerImageViewModel: ServerImageTableViewCellViewModelType, Hashable {

    let isSelected: Bool
    let server: RPCServerOrAuto
    let isTopSeparatorHidden: Bool
    let isAvailableToSelect: Bool
    
    init(server: RPCServerOrAuto, selected: Bool, isAvailableToSelect: Bool = true) {
        self.server = server
        self.isSelected = selected
        self.isAvailableToSelect = isAvailableToSelect
        self.isTopSeparatorHidden = true
    }

    var backgroundColor: UIColor = Configuration.Color.Semantic.tableViewBackground
    var serverColor: UIColor = Configuration.Color.Semantic.tableViewCellPrimaryFont
    var selectionStyle: UITableViewCell.SelectionStyle = .default

    var primaryText: String {
        return server.displayName
    }
    var primaryFont: UIFont = Fonts.regular(size: 20)
    var primaryFontColor: UIColor = Configuration.Color.Semantic.tableViewCellPrimaryFont

    var secondaryText: String {
        switch server {
        case .auto:
            return ""
        case .server(let rpcServer):
            return R.string.localizable.chainIDWithPrefix(rpcServer.chainID)
        }

    }
    var secondaryFont: UIFont = Fonts.regular(size: 15)
    var secondaryFontColor: UIColor = Configuration.Color.Semantic.tableViewCellSecondaryFont
}

struct TokenListServerTableViewCellViewModel: ServerTableViewCellViewModelType {
    private let server: RPCServer
    let isTopSeparatorHidden: Bool

    init(server: RPCServer, isTopSeparatorHidden: Bool) {
        self.server = server
        self.isTopSeparatorHidden = isTopSeparatorHidden
    }

    var accessoryType: UITableViewCell.AccessoryType = LocaleViewCell.selectionAccessoryType.unselected
    var backgroundColor: UIColor = Configuration.Color.Semantic.tableViewHeaderBackground
    var serverFont: UIFont = Fonts.semibold(size: 15)
    var serverColor: UIColor = Configuration.Color.Semantic.tableViewCellSecondaryFont
    var serverName: String {
        return server.displayName.uppercased()
    }
    var selectionStyle: UITableViewCell.SelectionStyle = .none
}

extension TokenListServerTableViewCellViewModel: Hashable {
    static func == (lhs: TokenListServerTableViewCellViewModel, rhs: TokenListServerTableViewCellViewModel) -> Bool {
        return lhs.server == rhs.server
    }
}
