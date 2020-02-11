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

    func verifyXMLSignatureViaAPI(xml: String, completion: @escaping (VerifierResult) -> Void) {
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
                    guard response.result.isSuccess,
                          let unwrappedResponse = response.response,
                          unwrappedResponse.statusCode <= 299,
                          let value = response.result.value
                    else {
                        if let reachable = NetworkReachabilityManager()?.isReachable, !reachable {
                            self.retryAfterDelay(xml: xml, completion: completion)
                            return
                        } else {
                            completion(.failed)
                            return
                        }
                    }
                    let json = JSON(value)
                    guard let subject = json["subject"].string else { 
                        //Should never hit
                        completion(.unknownCn)
                        return
                    }
                    let keyValuePairs = self.keyValuePairs(fromCommaSeparatedKeyValuePairs: subject)
                    if let domain = keyValuePairs["CN"] {
                        completion(.success(domain: domain))
                    } else {
                        completion(.failed)
                    }
                }
            case .failure:
                completion(.failed)
            }
        })
    }

    private func retryAfterDelay(xml: String, completion: @escaping (VerifierResult) -> Void) {
        //TODO instead of a hardcoded delay, observe reachability and retry when there's connectivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.verifyXMLSignatureViaAPI(xml: xml, completion: completion)
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
