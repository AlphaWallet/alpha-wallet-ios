// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletLogger
import PaperTrailLumberjack

public typealias EmailAttachment = (data: Data, mimeType: String, fileName: String)
extension Logger {
    public static var logFilesAttachments: [EmailAttachment] {
        return Self.logFileURLs.compactMap { url -> EmailAttachment? in
            guard let data = try? Data(contentsOf: url), let mimeType = url.mimeType else { return nil }

            return (data, mimeType, url.lastPathComponent)
        }
    }
}

public class RemoteLogger {
    private let isActive: Bool

    public static var instance: RemoteLogger = .init()
    private let logger = DDLog()

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
        paperTrailLogger.port = UInt(Constants.Credentials.paperTrail.port)
        logger.add(paperTrailLogger)
    }

    private func logRpcErrorMessage(_ message: String) {
        guard isActive else { return }
        DDLogVerbose("Build: \(Bundle.main.buildNumber!) | RPC node error: \(message)", ddlog: logger)
    }

    private func logOtherWebApiErrorMessage(_ message: String) {
        guard isActive else { return }
        DDLogVerbose("Build: \(Bundle.main.buildNumber!) | Other web API error: \(message)", ddlog: logger)
    }

    func logRpcOrOtherWebError(_ message: String, url: String) {
        if let server = RPCServer.serverWithRpcURL(url) {
            RemoteLogger.instance.logRpcErrorMessage("\(message) | from: \(server)")
        } else {
            RemoteLogger.instance.logOtherWebApiErrorMessage("\(message) | from: \(url)")
        }
    }
}

//TODO have to reconcile with the other logging functions above. Why and how is this different from the rest?
func logError(_ e: Error, pref: String = "", function f: String = #function, rpcServer: RPCServer? = nil, address: AlphaWallet.Address? = nil) {
    var description = pref
    description += rpcServer.flatMap { " server: \($0)" } ?? ""
    description += address.flatMap { " address: \($0.eip55String)" } ?? ""
    description += " \(e)"
    warnLog(description, callerFunctionName: f)
}
