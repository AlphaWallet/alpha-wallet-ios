// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

class TokenScriptForAttestationStore {
    //TODO improve storage when we know more about how the TokenScript store for attestations is used
    private var storage: [URL: String] = [:]

    subscript(url: URL) -> String? {
        get { return storage[url] }
        set { storage[url] = newValue }
    }
}
