// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Security

public struct PasswordGenerator {

    public static func generateRandom() -> String {
        return PasswordGenerator.generateRandomString(bytesCount: 32)
    }

    public static func generateRandomString(bytesCount: Int) -> String {
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let _ = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        return randomBytes.map({ String(format: "%02hhx", $0) }).joined(separator: "")
    }
}
