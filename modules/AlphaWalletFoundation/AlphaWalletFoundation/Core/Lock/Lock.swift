// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import SAMKeychain
import KeychainSwift

public protocol LockInterface {
    var isPasscodeSet: Bool { get }
}

public class Lock: LockInterface {
    private struct Keys {
        static let service = "alphawallet.lock"
        static let account = "alphawallet.account"
    }

    private let passcodeAttempts = "passcodeAttempts"
    private let maxAttemptTime = "maxAttemptTime"
    private let keychain = KeychainSwift(keyPrefix: Constants.keychainKeyPrefix)

    public var isPasscodeSet: Bool {
        return currentPasscode != nil
    }
    public var currentPasscode: String? {
        return SAMKeychain.password(forService: Keys.service, account: Keys.account)
    }
    public var numberOfAttempts: Int {
        guard let attempts = keychain.get(passcodeAttempts) else {
            return 0
        }
        return Int(attempts)!
    }
    public var recordedMaxAttemptTime: Date {
        //This method is called only when we knew that maxAttemptTime is set. So no worries with !.
        let timeString = keychain.get(maxAttemptTime)!
        return dateFormatter.date(from: timeString)!
    }
    public var isIncorrectMaxAttemptTimeSet: Bool {
        guard let timeString = keychain.get(maxAttemptTime), !timeString.isEmpty  else {
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
        SAMKeychain.setPassword(passcode, forService: Keys.service, account: Keys.account)
    }
    public func deletePasscode() {
        SAMKeychain.deletePassword(forService: Keys.service, account: Keys.account)
        resetPasscodeAttemptHistory()
    }
    public func resetPasscodeAttemptHistory() {
        keychain.delete(passcodeAttempts)
    }
    public func recordIncorrectPasscodeAttempt() {
        var numberOfAttemptsSoFar = numberOfAttempts
        numberOfAttemptsSoFar += 1
        keychain.set(String(numberOfAttemptsSoFar), forKey: passcodeAttempts)
    }
    public func recordIncorrectMaxAttemptTime() {
        let timeString = dateFormatter.string(from: Date())
        keychain.set(timeString, forKey: maxAttemptTime)
    }
    public func removeIncorrectMaxAttemptTime() {
        keychain.delete(maxAttemptTime)
    }
    public init() {}
    public func clear() {
        deletePasscode()
        resetPasscodeAttemptHistory()
        removeIncorrectMaxAttemptTime()
    }
}
