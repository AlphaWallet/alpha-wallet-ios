// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import PromiseKit

class RemoteCounter {
    private let key: String

    init(key: String) {
        self.key = key
    }

    func log(statName: String, value: Int) {
        let parameters: [String: Any] = [
            "email": key,
            "stat": statName,
            "value": String(value),
        ]
        Alamofire.request(Constants.statHatEndPoint, method: .post, parameters: parameters)
    }
}