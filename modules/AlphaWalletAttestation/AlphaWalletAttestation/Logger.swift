// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "attestation")

func infoLog(_ message: Any, callerFunctionName: String = #function) {
    guard Attestation.isLoggingEnabled else { return }
    logger.info("\(String(describing: message)) from: \(callerFunctionName)")
}

func errorLog(_ message: Any, callerFunctionName: String = #function) {
    guard Attestation.isLoggingEnabled else { return }
    logger.error("\(String(describing: message)) from: \(callerFunctionName)")
}
