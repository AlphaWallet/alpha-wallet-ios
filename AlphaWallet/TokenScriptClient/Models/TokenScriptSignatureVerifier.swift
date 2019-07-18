// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Alamofire
import SwiftyJSON

class TokenScriptSignatureVerifier {

    func verify(xml: String, isOfficial: Bool) -> Promise<TokenScriptSignatureVerificationType> {
        return Promise { seal in
            if isOfficial {
                verifyXMLSignatureViaAPI(xml: xml) { result in
                    if result == "failed" {
                        seal.fulfill(.verificationFailed)
                    } else {
                        seal.fulfill(.verified(domainName: result))
                    }
                }
            } else {
                seal.fulfill(.notCanonicalizedAndNotSigned)
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
                    guard let CN = json["subject"].string else { 
                        //Should never hit
                        completion("unknown CN")
                        return
                    }
                    let domain = CN.replacingOccurrences(of: "CN=", with: "")
                    completion(domain)
                }
            case .failure(let _):
                completion("failed")
            }
        })
    }
}
