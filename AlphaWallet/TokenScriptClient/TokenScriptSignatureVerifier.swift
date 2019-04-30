// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit

class TokenScriptSignatureVerifier {
    //TODO implement signature verification
    func verify(xml: String, isOfficial: Bool) -> Promise<TokenScriptSignatureVerificationType> {
        return Promise { seal in
            if isOfficial {
                seal.fulfill(.verified(domainName: "alphawallet.com"))
            } else {
                seal.fulfill(.notCanonicalizedAndNotSigned)
            }
        }
    }
}
