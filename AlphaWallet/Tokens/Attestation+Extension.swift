// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAttestation
import AlphaWalletFoundation

extension Attestation {
    var server: RPCServer {
        return RPCServer(chainID: chainId)
    }
}
