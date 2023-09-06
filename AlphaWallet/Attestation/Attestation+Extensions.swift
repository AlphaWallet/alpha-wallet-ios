// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAttestation

extension Attestation {
    enum AttestationType {
        case smartLayerPass
        case others
    }

    var name: String {
        switch attestationType {
        case .smartLayerPass:
            return R.string.localizable.attestationsSmartLayerPass()
        case .others:
            return R.string.localizable.attestationsEas()
        }
    }

    var attestationType: AttestationType {
        if let eventId = stringProperty(withName: SmartLayerPass.typeFieldName), eventId == "SMARTLAYER" {
            return .smartLayerPass
        } else {
            return .others
        }
    }
}