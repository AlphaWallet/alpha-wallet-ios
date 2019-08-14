// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Alamofire
import SwiftyJSON

class TokenScriptSignatureVerifier {

    func verify(xml: String) -> Promise<TokenScriptSignatureVerificationType> {
        return Promise { seal in
            verifyXMLSignatureViaAPI(xml: xml) { result in
                if result == "failed" {
                    seal.fulfill(.verificationFailed)
                } else {
                    seal.fulfill(.verified(domainName: result))
                }
            }
        }
    }

    func verifyXMLSignatureViaAPI(xml: String, completion: @escaping (String) -> Void) {
        guard let xmlAsData = xml.data(using: String.Encoding.utf8) else {
            completion("failed")
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
                        completion("failed")
                        return
                    }
                    let json = JSON(value)
                    guard let subject = json["subject"].string else { 
                        //Should never hit
                        completion("unknown CN")
                        return
                    }
                    let keyValuePairs = self.keyValuePairs(fromCommaSeparatedKeyValuePairs: subject)
                    if let domain = keyValuePairs["CN"] {
                        completion(domain)
                    } else {
                        completion("failed")
                    }
                }
            case .failure(let _):
                completion("failed")
            }
        })
    }

    private func keyValuePairs(fromCommaSeparatedKeyValuePairs commaSeparatedKeyValuePairs: String) -> [String: String] {
        let keyValuePairs: [(String, String)] = commaSeparatedKeyValuePairs.split(separator: ",").map({ each in
            let foo = each.split(separator: "=")
            return (String(foo[0]), String(foo[1]))
        })
        return Dictionary(keyValuePairs, uniquingKeysWith: { $1 })
    }
}
