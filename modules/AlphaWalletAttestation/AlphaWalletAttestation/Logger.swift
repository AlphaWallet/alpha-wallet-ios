// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

func verboseLog(_ message: Any, callerFunctionName: String = #function) {
    guard Attestation.isLoggingEnabled else { return }
    NSLog("\(message) from: \(callerFunctionName)")
}
