//
//  AddrpcServerViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import UIKit

struct AddrpcServerViewModel {

    var title: String {
        return R.string.localizable.addrpcServerNavigationTitle()
    }

    var saverpcServerTitle: String {
        return R.string.localizable.addrpcServerSaveButtonTitle()
    }

    var networkNameTitle: String {
        return R.string.localizable.addrpcServerNetworkNameTitle()
    }

    var rpcUrlTitle: String {
        return R.string.localizable.addrpcServerRpcUrlTitle()
    }

    var chainIDTitle: String {
        return R.string.localizable.chainID()
    }

    var symbolTitle: String {
        return R.string.localizable.symbol()
    }

    var blockExplorerURLTitle: String {
        return R.string.localizable.addrpcServerBlockExplorerUrlTitle()
    }

    var enableServersHeaderViewModel = SwitchViewViewModel(text: R.string.localizable.addrpcServerIsTestnetTitle(), isOn: false)
}
