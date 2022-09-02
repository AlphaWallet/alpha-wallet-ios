// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public protocol Lock {
    var isPasscodeSet: Bool { get }
    var currentPasscode: String? { get }
    var numberOfAttempts: Int { get }
    var recordedMaxAttemptTime: Date { get }
    var isIncorrectMaxAttemptTimeSet: Bool { get }

    func isPasscodeValid(passcode: String) -> Bool
    func setPasscode(passcode: String)
    func deletePasscode()
    func resetPasscodeAttemptHistory()
    func recordIncorrectPasscodeAttempt()
    func recordIncorrectMaxAttemptTime()
    func removeIncorrectMaxAttemptTime()
    func clear()
}

open class SecuredLock: Lock {
    private struct Keys {
        static let service = "alphawallet.lock"
        static let account = "alphawallet.account"
    }

    private let passcodeAttempts = "passcodeAttempts"
    private let maxAttemptTime = "maxAttemptTime"
    private let securedStorage: SecuredStorage & SecuredPasswordStorage
    public var isPasscodeSet: Bool {
        return currentPasscode != nil
    }
    public var currentPasscode: String? {
        return securedStorage.password(forService: Keys.service, account: Keys.account)
    }
    public var numberOfAttempts: Int {
        guard let attempts = securedStorage.get(passcodeAttempts, prompt: nil, withContext: nil), let value = Int(attempts) else {
            return 0
        }
        return value
    }
    public var recordedMaxAttemptTime: Date {
        //This method is called only when we knew that maxAttemptTime is set. So no worries with !.
        let timeString = securedStorage.get(maxAttemptTime, prompt: nil, withContext: nil)!
        return dateFormatter.date(from: timeString)!
    }
    public var isIncorrectMaxAttemptTimeSet: Bool {
        guard let timeString = securedStorage.get(maxAttemptTime, prompt: nil, withContext: nil), !timeString.isEmpty  else {
            return false
        }
        return true
    }
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = DateFormatter.Style.short
        dateFormatter.timeStyle = DateFormatter.Style.short
        return dateFormatter
    }
    public func isPasscodeValid(passcode: String) -> Bool {
        return passcode == currentPasscode
    }
    public func setPasscode(passcode: String) {
        securedStorage.setPasword(passcode, forService: Keys.service, account: Keys.account)
    }
    public func deletePasscode() {
        securedStorage.deletePasword(forService: Keys.service, account: Keys.account)
        resetPasscodeAttemptHistory()
    }
    public func resetPasscodeAttemptHistory() {
        securedStorage.delete(passcodeAttempts)
    }
    public func recordIncorrectPasscodeAttempt() {
        var numberOfAttemptsSoFar = numberOfAttempts
        numberOfAttemptsSoFar += 1
        securedStorage.set(String(numberOfAttemptsSoFar), forKey: passcodeAttempts, withAccess: nil)
    }
    public func recordIncorrectMaxAttemptTime() {
        let timeString = dateFormatter.string(from: Date())
        securedStorage.set(timeString, forKey: maxAttemptTime, withAccess: nil)
    }
    public func removeIncorrectMaxAttemptTime() {
        securedStorage.delete(maxAttemptTime)
    }
    public init(securedStorage: SecuredStorage & SecuredPasswordStorage) {
        self.securedStorage = securedStorage
    }

    public func clear() {
        deletePasscode()
        resetPasscodeAttemptHistory()
        removeIncorrectMaxAttemptTime()
    }
}
