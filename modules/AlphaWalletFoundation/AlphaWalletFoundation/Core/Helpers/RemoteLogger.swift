// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import PaperTrailLumberjack
import CocoaLumberjack

public func debugLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.debug("\(message) from: \(callerFunctionName)")
}

public func infoLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.info("\(message) from: \(callerFunctionName)")
}

public func warnLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.warn("\(message) from: \(callerFunctionName)")
}

public func verboseLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.verbose("\(message) from: \(callerFunctionName)")
}

public func errorLog(_ message: Any, _ logger: Logger = DDLogger.instance, callerFunctionName: String = #function) {
    logger.error("\(message) from: \(callerFunctionName)")
}

public protocol Logger {
    func debug(_ message: Any)
    func info(_ message: Any)
    func warn(_ message: Any)
    func verbose(_ message: Any)
    func error(_ message: Any)
}

extension Logger {
    public static var logFileURLs: [URL] {
        guard let url = URL(string: DDLogger.logDirectory) else { return [] }

        return (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }
}

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

public final class DDLogger: Logger {
    public static let instance = DDLogger()

    static var logDirectory: String {
        return DDLogFileManagerDefault().logsDirectory
    }
    private let logger = DDLog()

    init() {
        let fileLogger = DDFileLogger(logFileManager: DDLogFileManagerDefault())
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7

        logger.add(DDOSLogger.sharedInstance, with: .debug)
        logger.add(fileLogger, with: .info)
    }

    public func debug(_ message: Any) {
        DDLogDebug(message, ddlog: logger)
    }

    public func info(_ message: Any) {
        DDLogInfo(message, ddlog: logger)
    }

    public func warn(_ message: Any) {
        DDLogWarn(message, ddlog: logger)
    }

    public func verbose(_ message: Any) {
        DDLogVerbose(message, ddlog: logger)
    }

    public func error(_ message: Any) {
        DDLogError(message, ddlog: logger)
    }
}
