// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
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