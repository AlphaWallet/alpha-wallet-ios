//

import Foundation
import CryptoKit
import Security

extension AES {
    static func randomIV(count: Int = 16) -> Data {
        return Data.randomBytes(count)
    }
}

extension Data {
    public static func randomBytes(_ count: Int) -> Data {
        var randomBytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &randomBytes)
        if status != errSecSuccess {
            fatalError("can't generate secure random data")
        }
        return Data(randomBytes)
    }
}
