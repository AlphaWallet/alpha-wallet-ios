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

protocol ServerImageTableViewCellViewModelType {
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

struct ServerImageViewModel: ServerImageTableViewCellViewModelType {

    let isSelected: Bool
    let server: RPCServerOrAuto
    let isTopSeparatorHidden: Bool

    init(server: RPCServerOrAuto, selected: Bool) {
        self.server = server
        self.isSelected = selected
        self.isTopSeparatorHidden = true
    }

    var backgroundColor: UIColor = Colors.appBackground
    var serverColor: UIColor = Colors.black
    var selectionStyle: UITableViewCell.SelectionStyle = .default

    var primaryText: String {
        return server.displayName
    }
    var primaryFont: UIFont = R.font.sourceSansProRegular(size: 20.0)!
    var primaryFontColor: UIColor = R.color.black()!

    var secondaryText: String {
        switch server {
        case .auto:
            return ""
        case .server(let rpcServer):
            return "ChainID: \(rpcServer.chainID)"
        }

    }
    var secondaryFont: UIFont = R.font.sourceSansProRegular(size: 15.0)!
    var secondaryFontColor: UIColor = R.color.dove()!
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
