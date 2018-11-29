// Copyright SIX DAY LLC. All rights reserved.

import Alamofire
import Foundation
import Moya

struct TrustProviderFactory {
    static let policies: [String: ServerAlphaWalletPolicy] = [
        :
    ]

    static func makeProvider() -> MoyaProvider<TrustService> {
        let manager = Manager(
            configuration: URLSessionConfiguration.default,
            serverTrustPolicyManager: ServerAlphaWalletPolicyManager(policies: policies)
        )
        return MoyaProvider<TrustService>(manager: manager)
    }
}
