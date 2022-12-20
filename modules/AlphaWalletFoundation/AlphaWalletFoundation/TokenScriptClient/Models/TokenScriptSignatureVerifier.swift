// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import SwiftyJSON
import Combine
import AlphaWalletCore

public class TokenScriptSignatureVerifier {
    private let provider: BaseTokenScriptFilesProvider & NetworkServiceProvidable
    private let networking: TokenScriptSignatureNetworking
    private let queue = DispatchQueue(label: "org.alphawallet.swift.TokenScriptSignatureVerifier")
    private let reachability: ReachabilityManagerProtocol
    private let cancellable: AtomicDictionary<String,AnyCancellable> = .init()
    public var retryBehavior: RetryBehavior<RunLoop> = .delayed(retries: UInt.max, time: 10)

    public init(provider: BaseTokenScriptFilesProvider & NetworkServiceProvidable, reachability: ReachabilityManagerProtocol = ReachabilityManager()) {
        self.provider = provider
        self.reachability = reachability
        self.networking = TokenScriptSignatureNetworking(networkService: provider.networkService)
    }

    public func verify(xml: String) -> Promise<TokenScriptSignatureVerificationType> {
        return Promise { seal in
            if Features.default.isAvailable(.isActivityEnabled) {
                if provider.containsTokenScriptFile(for: xml) {
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
    public func verifyXMLSignatureViaAPI(xml: String, completion: @escaping (VerifierResult) -> Void) {
        guard Features.default.isAvailable(.isTokenScriptSignatureStatusEnabled) else {
            //It is safe to return without calling `completion` here since we aren't supposed to be using the results with the feature flag above
            verboseLog("[TokenScript] Signature verification disabled")
            //We call the completion handler so that if the caller is a `Promise`, it will resolve, in order to avoid the warning: "PromiseKit: warning: pending promise deallocated"
            completion(.success(domain: ""))
            return
        }

        cancellable[xml] = reachability
            .networkBecomeReachablePublisher
            .receive(on: queue)
            .map { _ in xml }
            .setFailureType(to: SessionTaskError.self)
            .flatMapLatest { [networking, retryBehavior] xml -> AnyPublisher<VerifierResult, SessionTaskError> in
                networking
                    .upload(xmlFile: xml)
                    .retry(retryBehavior, scheduler: RunLoop.main)
                    .eraseToAnyPublisher()
            }.replaceError(with: .failed)
            .receive(on: queue)
            .sink(receiveCompletion: { [weak self]_ in
                self?.cancellable[xml] = nil
            }, receiveValue: { result in DispatchQueue.main.async { completion(result) } })
    }
}

extension TokenScriptSignatureVerifier {
    public enum VerifierResult {
        case success(domain: String)
        case unknownCn
        case failed
    }
}

class TokenScriptSignatureNetworking {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func upload(xmlFile xml: String) -> AnyPublisher<TokenScriptSignatureVerifier.VerifierResult, SessionTaskError> {
        guard let xmlAsData = xml.data(using: String.Encoding.utf8) else {
            return .fail(.requestError(URLError(.zeroByteResource)))
        }
        let url = URL(string: Constants.TokenScript.validatorAPI)!
        let headers = [
            "cache-control": "no-cache",
            "content-type": "application/x-www-form-urlencoded"
        ]

        let multipartFormData: (MultipartFormData) -> Void = { multipartFormData in
            multipartFormData.append(xmlAsData, withName: "file", fileName: "file.tsml", mimeType: "text/xml")
        }

        //TODO more detailed error reporting for failed verifications
        return networkService
            .upload(multipartFormData: multipartFormData, to: url, headers: headers)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { encodingResult -> AnyPublisher<TokenScriptSignatureVerifier.VerifierResult, SessionTaskError> in
                return AnyPublisher<TokenScriptSignatureVerifier.VerifierResult, SessionTaskError>.create { seal in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.validate()
                        upload.responseJSON { response in
                            guard let unwrappedResponse = response.response else {
                                    //We must be careful to not check NetworkReachabilityManager()?.isReachable == true and presume API server is down. Intermittent connectivity happens. It's harmless to retry if the API server is down anyway
                                seal.send(completion: .failure(.responseError(URLError(.badServerResponse))))
                                return
                            }

                            guard response.result.isSuccess, unwrappedResponse.statusCode <= 299, let value = response.result.value else {
                                    //API is coded to fail with 400
                                if unwrappedResponse.statusCode == 400 {
                                    seal.send(.failed)
                                    seal.send(completion: .finished)
                                } else {
                                    seal.send(completion: .failure(.responseError(URLError(.badServerResponse))))
                                }
                                return
                            }


                            let json = JSON(value)
                            guard let subject = json["subject"].string else {
                                //Should never hit
                                seal.send(.unknownCn)
                                seal.send(completion: .finished)
                                return
                            }

                            if let domain = TokenScriptSignatureNetworking.functional.keyValuePairs(fromCommaSeparatedKeyValuePairs: subject)["CN"] {
                                seal.send(.success(domain: domain))
                                seal.send(completion: .finished)
                            } else {
                                seal.send(.failed)
                                seal.send(completion: .finished)
                            }
                        }
                    case .failure(let error):
                        seal.send(completion: .failure(.responseError(SessionTaskError.responseError(error))))
                    }

                    return AnyCancellable {

                    }
                }
            }.eraseToAnyPublisher()
    }
}

extension TokenScriptSignatureNetworking {
    class functional {}
}

extension TokenScriptSignatureNetworking.functional {
    static func keyValuePairs(fromCommaSeparatedKeyValuePairs commaSeparatedKeyValuePairs: String) -> [String: String] {
        let keyValuePairs: [(String, String)] = commaSeparatedKeyValuePairs.split(separator: ",").map({ each in
            let foo = each.split(separator: "=")
            return (String(foo[0]), String(foo[1]))
        })
        return Dictionary(keyValuePairs, uniquingKeysWith: { $1 })
    }
}
