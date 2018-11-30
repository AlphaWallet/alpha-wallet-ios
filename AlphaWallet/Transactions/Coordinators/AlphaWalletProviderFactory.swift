// Copyright SIX DAY LLC. All rights reserved.

import Alamofire
import Foundation
import Moya

struct AlphaWalletProviderFactory {
    static let policies: [String: ServerTrustPolicy] = [:]
    
    static func makeProvider() -> MoyaProvider<AlphaWalletService> {
        let manager = Manager(
            configuration: URLSessionConfiguration.default,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )
        return MoyaProvider<AlphaWalletService>(manager: manager)
    }
}
