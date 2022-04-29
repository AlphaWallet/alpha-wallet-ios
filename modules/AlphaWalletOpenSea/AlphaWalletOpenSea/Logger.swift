//
//  Logger.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/29/22.
//

import Foundation

func infoLog(_ message: Any, callerFunctionName: String = #function) {
    guard AlphaWalletOpenSea.OpenSea.isLoggingEnabled else { return }
    NSLog("\(message) from: \(callerFunctionName)")
}
