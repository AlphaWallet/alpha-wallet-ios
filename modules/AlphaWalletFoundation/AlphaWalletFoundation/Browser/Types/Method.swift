// Copyright DApps Platform Inc. All rights reserved.

import Foundation

public enum Method: String, Decodable {
    //case getAccounts
    case sendTransaction
    case signTransaction
    case signPersonalMessage
    case signMessage
    case signTypedMessage
    case ethCall
    case unknown

    public init(string: String) {
        self = Method(rawValue: string) ?? .unknown
    }
}
