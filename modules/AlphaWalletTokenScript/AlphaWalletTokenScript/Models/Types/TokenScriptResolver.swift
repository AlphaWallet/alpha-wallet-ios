// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress
import AlphaWalletAttestation

public protocol TokenScriptResolver: AnyObject {
    func xmlHandler(forContract contract: AlphaWallet.Address, tokenType: TokenType) -> XMLHandler
    func xmlHandler(forAttestation attestation: Attestation) -> XMLHandler?
    func xmlHandler(forAttestation attestation: Attestation, xmlString: String) -> XMLHandler

    func invalidateSignatureStatus(forContract contract: AlphaWallet.Address)
}
