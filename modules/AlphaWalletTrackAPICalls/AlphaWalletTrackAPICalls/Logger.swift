// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

func infoLog(_ message: Any, callerFunctionName: String = #function) {
    NSLog("\(message) from: \(callerFunctionName)")
}
