// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Alamofire

class TokenScriptSignatureVerifier {

    func verify(xml: String, isOfficial: Bool) -> Promise<TokenScriptSignatureVerificationType> {
        return Promise { seal in
            if isOfficial {
                verifyXMLSignatureViaAPI(xml: xml) { passed in
                    if passed {
                        //TODO get domain from validator
                        seal.fulfill(.verified(domainName: "alphawallet.com"))
                    } else {
                        seal.fulfill(.verificationFailed)
                    }
                }
            } else {
                seal.fulfill(.notCanonicalizedAndNotSigned)
            }
        }
    }

    func verifyXMLSignatureViaAPI(xml: String, completion: @escaping (Bool) -> Void) {
        guard let xmlAsData = xml.data(using: String.Encoding.utf8) else {
            completion(false)
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
                    guard response.result.isSuccess, let unwrappedResponse = response.response, unwrappedResponse.statusCode <= 299 else {
                        completion(false)
                        return
                    }
                    completion(true)
                }
            case .failure(let encodingError):
                NSLog("xxx error: \(encodingError)")
                completion(false)
            }
        })
    }
}
