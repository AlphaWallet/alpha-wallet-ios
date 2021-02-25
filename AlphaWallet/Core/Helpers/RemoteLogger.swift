// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import PaperTrailLumberjack

class RemoteLogger {
    private let isActive: Bool

    static var instance: RemoteLogger = .init()

    private init() {
        guard !Constants.Credentials.paperTrail.host.isEmpty else {
            isActive = false
            return
        }
        guard Constants.Credentials.paperTrail.port > 0 else {
            isActive = false
            return
        }
        isActive = true
        let paperTrailLogger: RMPaperTrailLogger = RMPaperTrailLogger.sharedInstance()!
        paperTrailLogger.host = Constants.Credentials.paperTrail.host
        paperTrailLogger.port = Constants.Credentials.paperTrail.port
        DDLog.add(paperTrailLogger)
    }

    private func logRpcErrorMessage(_ message: String) {
        guard isActive else { return }
        DDLogVerbose("Build: \(Bundle.main.buildNumber!) | RPC node error: \(message)")
    }

    private func logOtherWebApiErrorMessage(_ message: String) {
        guard isActive else { return }
        DDLogVerbose("Build: \(Bundle.main.buildNumber!) | Other web API error: \(message)")
    }

    func logRpcOrOtherWebError(_ message: String, url: String) {
        if let server = RPCServer.serverWithRpcURL(url) {
            RemoteLogger.instance.logRpcErrorMessage("\(message) | from: \(server)")
        } else {
            RemoteLogger.instance.logOtherWebApiErrorMessage("\(message) | from: \(url)")
        }
    }
}
