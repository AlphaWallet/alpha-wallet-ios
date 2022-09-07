//
//  LocalNotification.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation

public enum LocalNotification: Equatable {
    case receiveEther(transaction: String, amount: String, server: RPCServer)
}
