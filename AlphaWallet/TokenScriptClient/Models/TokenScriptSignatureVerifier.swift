// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Alamofire
import SwiftyJSON

class TokenScriptSignatureVerifier {
    enum VerifierResult {
        case success(domain: String)
        case unknownCn
        case failed
    }

    func verify(xml: String) -> Promise<TokenScriptSignatureVerificationType> {
        return Promise { seal in
            if Features.isActivityEnabled {
                if TokenScript.baseTokenScriptFiles.values.contains(xml) {
                    seal.fulfill(.verified(domainName: "*.aw.app"))
                    return
                }
            }

            verifyXMLSignatureViaAPI(xml: xml) { result in
                switch result {
                case .success(domain: let domain):
                    seal.fulfill(.verified(domainName: domain))
                case .failed:
                    seal.fulfill(.verificationFailed)
                case .unknownCn:
                    seal.fulfill(.verificationFailed)
                }
            }
        }
    }

    //TODO log reasons for failures `completion(.failed)` as well as those that triggers retries in in-app Console
    func verifyXMLSignatureViaAPI(xml: String, retryAttempt: Int = 0, completion: @escaping (VerifierResult) -> Void) {
        guard let xmlAsData = xml.data(using: String.Encoding.utf8) else {
            completion(.failed)
            return
        }
        let url = URL(string: Constants.tokenScriptValidatorAPI)!
        let headers = [
            "cache-control": "no-cache",
            "content-type": "application/x-www-form-urlencoded"
        ]
        //TODO more detailed error reporting for failed verifications
        Alamofire.upload(
                multipartFormData: {
                    multipartFormData in
                multipartFormData.append(xmlAsData, withName: "file", fileName: "file.tsml", mimeType: "text/xml")
        },
        to: url,
        headers: headers,
        encodingCompletion: { encodingResult in
            switch encodingResult {
            case .success(let upload, _, _):
                upload.validate()
                upload.responseJSON { response in
                    guard let unwrappedResponse = response.response else {
                        //We must be careful to not check NetworkReachabilityManager()?.isReachable == true and presume API server is down. Intermittent connectivity happens. It's harmless to retry if the API server is down anyway
                        self.retryAfterDelay(xml: xml, retryAttempt: retryAttempt + 1, completion: completion)
                        return
                    }
                    guard response.result.isSuccess, unwrappedResponse.statusCode <= 299, let value = response.result.value else {
                        //API is coded to fail with 400
                        if unwrappedResponse.statusCode == 400 {
                            completion(.failed)
                        } else {
                            self.retryAfterDelay(xml: xml, retryAttempt: retryAttempt + 1, completion: completion)
                        }
                        return
                    }
                    let json = JSON(value)
                    guard let subject = json["subject"].string else {
                        //Should never hit
                        completion(.unknownCn)
                        return
                    }
                    if let domain = self.keyValuePairs(fromCommaSeparatedKeyValuePairs: subject)["CN"] {
                        completion(.success(domain: domain))
                    } else {
                        completion(.failed)
                    }
                }
            case .failure:
                self.retryAfterDelay(xml: xml, retryAttempt: retryAttempt + 1, completion: completion)
            }
        })
    }

    ///Because of strong references, retry attempts will retain self and not go away even when we close the view controller that triggered this signature verification. So backing off before retrying is important
    //TODO fix strong references so that when caller goes away, retry attempts stop
    private func retryAfterDelay(xml: String, retryAttempt: Int, completion: @escaping (VerifierResult) -> Void) {
        //TODO instead of a hardcoded delay, observe reachability and retry when there's connectivity. Be careful with reachability status. It's not always accurate. A request can fail and isReachable=true. We should retry in that case
        let delay = Double(10 * retryAttempt)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.verifyXMLSignatureViaAPI(xml: xml, retryAttempt: retryAttempt, completion: completion)
        }
    }

    private func keyValuePairs(fromCommaSeparatedKeyValuePairs commaSeparatedKeyValuePairs: String) -> [String: String] {
        let keyValuePairs: [(String, String)] = commaSeparatedKeyValuePairs.split(separator: ",").map({ each in
            let foo = each.split(separator: "=")
            return (String(foo[0]), String(foo[1]))
        })
        return Dictionary(keyValuePairs, uniquingKeysWith: { $1 })
    }
}
