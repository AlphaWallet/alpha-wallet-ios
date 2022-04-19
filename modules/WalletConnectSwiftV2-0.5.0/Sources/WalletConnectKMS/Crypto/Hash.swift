//

import Foundation
import CryptoKit

extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }
}

extension Data {
    public func sha256() -> Data {
        SHA256.hash(data: self).data
    }

    public func sha512() -> Data {
        SHA512.hash(data: self).data
    }
}
