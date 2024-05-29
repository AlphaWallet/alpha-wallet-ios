// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "trackAPICalls")

func infoLog(_ message: Any, callerFunctionName: String = #function) {
    logger.info("\(String(describing: message)) from: \(callerFunctionName)")
}
