//
//  SwapTokenUsing.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

public enum SwapTokenUsing {
    case url(url: URL, server: RPCServer?)
    case native(swapPair: SwapPair)
}
