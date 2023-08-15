// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAttestation

extension Attestation {
    var name: String {
        switch attestationType {
        case .smartLayerPass:
            return R.string.localizable.attestationsSmartLayerPass()
        case .others:
            return R.string.localizable.attestationsEas()
        }
    }
}