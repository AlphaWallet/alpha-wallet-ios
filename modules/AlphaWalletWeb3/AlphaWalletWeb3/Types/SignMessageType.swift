// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletABI

public enum SignMessageType {
    case message(Data)
    case personalMessage(Data)
    case typedMessage([EthTypedData])
    case eip712v3And4(EIP712TypedData)
}