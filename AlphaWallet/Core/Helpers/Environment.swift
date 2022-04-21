// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

class Environment {
    static var isTestFlight: Bool = {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }()
    static var isDebug: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
}
