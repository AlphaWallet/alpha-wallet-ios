// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import PaperTrailLumberjack
import CocoaLumberjack

func debugLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.debug("\(message) from: \(callerFunctionName)")
}

func infoLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.info("\(message) from: \(callerFunctionName)")
}

func warnLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.warn("\(message) from: \(callerFunctionName)")
}

func verboseLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.verbose("\(message) from: \(callerFunctionName)")
}

func errorLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.error("\(message) from: \(callerFunctionName)")
}

protocol Logger {
    func debug(_ message: Any)
    func info(_ message: Any)
    func warn(_ message: Any)
    func verbose(_ message: Any)
    func error(_ message: Any)
}

extension Logger {
    static var logFileURLs: [URL] {
        guard let url = URL(string: DDLogger.logDirectory) else { return [] }

        return (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }
}

class RemoteLogger {
    private let isActive: Bool

    static var instance: RemoteLogger = .init()
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
        paperTrailLogger.port = Constants.Credentials.paperTrail.port
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

final class DDLogger: Logger {
    static let instance = DDLogger()

    static var logDirectory: String {
        return DDLogFileManagerDefault().logsDirectory
    }
    private let logger = DDLog()

    init() {
        let fileLogger = DDFileLogger(logFileManager: DDLogFileManagerDefault())
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7

        logger.add(DDASLLogger.sharedInstance, with: .debug)
        logger.add(fileLogger, with: .info)
    }

    func debug(_ message: Any) {
        DDLogDebug(message, ddlog: logger)
    }

    func info(_ message: Any) {
        DDLogInfo(message, ddlog: logger)
    }

    func warn(_ message: Any) {
        DDLogWarn(message, ddlog: logger)
    }

    func verbose(_ message: Any) {
        DDLogVerbose(message, ddlog: logger)
    }

    func error(_ message: Any) {
        DDLogError(message, ddlog: logger)
    }
}