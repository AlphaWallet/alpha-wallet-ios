// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

class Environment {
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}
