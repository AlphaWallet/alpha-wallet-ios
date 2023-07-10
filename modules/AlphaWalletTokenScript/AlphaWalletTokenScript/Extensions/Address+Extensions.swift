// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress

extension AlphaWallet.Address {
    public var isUEFATicketContract: Bool {
        return self == Constants.uefaMainnet.0
    }

    //Useful for special case for FIFA tickets
    public var isFifaTicketContract: Bool {
        return self == Constants.ticketContractAddress || self == Constants.ticketContractAddressRopsten
    }
}
