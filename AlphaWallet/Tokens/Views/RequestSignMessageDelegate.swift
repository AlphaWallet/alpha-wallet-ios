// Copyright © 2018 Stormbird PTE. LTD.

import Combine
import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletFoundation

protocol RequestSignMessageDelegate: AnyObject {
    func requestSignMessage(message: SignMessageType, server: RPCServer, account: AlphaWallet.Address, source: Analytics.SignMessageRequestSource, requester: RequesterViewModel?) -> AnyPublisher<Data, PromiseError>
}