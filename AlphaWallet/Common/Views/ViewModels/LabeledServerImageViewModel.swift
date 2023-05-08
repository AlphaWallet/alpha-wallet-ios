//
//  LabeledServerImageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.11.2022.
//

import AlphaWalletFoundation
import Foundation

struct LabeledServerImageViewModel {
    let server: RPCServer
    var layout: LabeledServerImageViewModel.Layout = .horizontal

    enum Layout {
        case horizontal
        case vertical
    }
}
