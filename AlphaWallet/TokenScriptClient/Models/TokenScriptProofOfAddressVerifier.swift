//
// Created by James Sangalli on 2019-08-15.
//

import Foundation
import AWSLambda

class TokenScriptProofOfAddressVerifier {

    func deriveTrustAddress(tsml: String, contractAddress: String) -> AnyObject? {
        let lambdaInvoker = AWSLambdaInvoker.default()
        let jsonObject: [String: Any] = [
            "file" : tsml,
            "address" : contractAddress
        ]
        return lambdaInvoker.invokeFunction("DeriveTrustAddress", jsonObject: jsonObject)
                .continueWith(block: {(task: AWSTask<AnyObject>) -> Any? in
                    if(task.error != nil) {
                        print("Error: \(task.error!)")
                        return nil
                    } else {
                        guard let result = task.result as? NSDictionary else { return nil }
                        //result contains both the trust and revoke addresses
                        return result
                    }
                })
    }

}
