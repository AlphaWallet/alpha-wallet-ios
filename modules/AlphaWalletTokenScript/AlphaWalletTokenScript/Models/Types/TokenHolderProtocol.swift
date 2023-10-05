// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore

public protocol TokenHolderProtocol {
    var tokenId: TokenId { get }
    var contractAddress: AlphaWallet.Address { get }
    var tokenType: TokenType { get }
    var name: String { get }
    var symbol: String { get }
    var count: Int { get }
    var values: [AttributeId: AssetAttributeSyntaxValue] { get }
}

extension TokenHolderProtocol {
    public static func == (lhs: TokenHolderProtocol, rhs: TokenHolderProtocol) -> Bool {
        return lhs.tokenId == rhs.tokenId
    }
}
