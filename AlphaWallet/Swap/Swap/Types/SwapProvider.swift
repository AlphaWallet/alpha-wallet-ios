//
//  SwapStepType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import Foundation
import BigInt

struct SwapStep {
    let tool: String
    let subSteps: [SwapSubStep]
}

struct SwapSubStep {
    let gasCost: SwapEstimate.GasCost
    let type: String
    let amount: BigUInt
    let token: SwapQuote.Token
    let tool: String
}
