//
//  Logger.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/29/22.
//

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "opensea")

func infoLog(_ message: Any, callerFunctionName: String = #function) {
    guard AlphaWalletOpenSea.OpenSea.isLoggingEnabled else { return }
    logger.info("\(String(describing: message)) from: \(callerFunctionName)")
}
