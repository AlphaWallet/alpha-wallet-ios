// Copyright SIX DAY LLC. All rights reserved.

import Alamofire
import Foundation
import Moya

struct TrustProviderFactory {
    static let policies: [String: ServerTrustPolicy] = [
        :
    ]
    
    static func makeProvider() -> MoyaProvider<TrustService> {
        let manager = Manager(
            configuration: URLSessionConfiguration.default,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )
        return MoyaProvider<TrustService>(manager: manager)
    }
}
