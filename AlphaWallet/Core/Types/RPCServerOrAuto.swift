//
//  RPCServerOrAuto.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

public enum RPCServerOrAuto: Hashable {
    case auto
    case server(RPCServer)
}
