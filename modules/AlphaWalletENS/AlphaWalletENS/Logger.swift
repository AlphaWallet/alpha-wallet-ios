//
//  Logger.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/9/22.
//

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ens")

func verboseLog(_ message: Any, callerFunctionName: String = #function) {
    guard ENS.isLoggingEnabled else { return }
    logger.debug("\(String(describing: message)) from: \(callerFunctionName)")
}
