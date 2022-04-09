//
//  Logger.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/9/22.
//

import Foundation

func verboseLog(_ message: Any, callerFunctionName: String = #function) {
    guard ENS.isLoggingEnabled else { return }
    NSLog("\(message) from: \(callerFunctionName)")
}