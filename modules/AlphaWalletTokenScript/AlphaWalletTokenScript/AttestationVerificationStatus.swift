// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAttestation
import AlphaWalletTokenScript

public enum AttestationVerificationStatus {
    case trustedIssuer
    case tokenScriptHasMatchingIssuer
    case untrustedIssuer
}

public func computeVerificationStatus(forAttestation attestation: Attestation, xmlHandler: XMLHandler?) -> AttestationVerificationStatus {
    if attestation.isValidAttestationIssuer {
        return .trustedIssuer
    } else {
        if xmlHandler == nil {
            return .untrustedIssuer
        } else {
            return .tokenScriptHasMatchingIssuer
        }
    }
}
