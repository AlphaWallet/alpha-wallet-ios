//
//  ConfirmResult.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

enum ConfirmType {
    case sign
    case signThenSend
}

enum ConfirmResult {
    case signedTransaction(Data)
    case sentTransaction(SentTransaction)
    case sentRawTransaction(id: String, original: String)
}
