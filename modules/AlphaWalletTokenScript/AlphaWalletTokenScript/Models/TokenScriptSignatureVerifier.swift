// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletLogger
import PromiseKit
import SwiftyJSON

public protocol TokenScriptSignatureVerifieble {
    func verificationType(forXml xmlString: String) -> Promise<TokenScriptSignatureVerificationType>
    //NOTE: for test purposes
    func verifyXMLSignatureViaAPI(xml: String, completion: @escaping (TokenScriptSignatureVerifier.VerifierResult) -> Void)
}

public class BaseTokenScriptStatusResolver: TokenScriptStatusResolver {

    private let backingStore: AssetDefinitionBackingStore
    private let signatureVerifier: TokenScriptSignatureVerifieble

    public init(backingStore: AssetDefinitionBackingStore, signatureVerifier: TokenScriptSignatureVerifieble) {
        self.backingStore = backingStore
        self.signatureVerifier = signatureVerifier
    }

    public func computeTokenScriptStatus(forContract contract: AlphaWallet.Address, xmlString: String, isOfficial: Bool) -> Promise<TokenLevelTokenScriptDisplayStatus> {
        if backingStore.hasConflictingFile(forContract: contract) {
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .tokenScriptType2ConflictingFiles, reason: .conflictWithAnotherFile))
        }
        if backingStore.hasOutdatedTokenScript(forContract: contract) {
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .tokenScriptType2OldSchemaVersion, reason: .oldTokenScriptVersion))
        }
        if xmlString.nilIfEmpty == nil {
            return .value(.type0NoTokenScript)
        }

        switch XMLHandler.functional.checkTokenScriptSchema(xmlString) {
        case .supportedTokenScriptVersion:
            return firstly {
                verificationType(forXml: xmlString)
            }.then { [backingStore] verificationStatus -> Promise<TokenLevelTokenScriptDisplayStatus> in
                return Promise { seal in
                    backingStore.writeCacheTokenScriptSignatureVerificationType(verificationStatus, forContract: contract, forXmlString: xmlString)

                    switch verificationStatus {
                    case .verified(let domainName):
                    seal.fulfill(.type1GoodTokenScriptSignatureGoodOrOptional(isDebugMode: !isOfficial, isSigned: true, validatedDomain: domainName, error: .tokenScriptType1SupportedAndSigned))
                    case .verificationFailed:
                        seal.fulfill(.type2BadTokenScript(isDebugMode: !isOfficial, error: .tokenScriptType2InvalidSignature, reason: .invalidSignature))
                    case .notCanonicalizedAndNotSigned:
                        //But should always be debug mode because we can't have a non-canonicalized XML from the official repo
                        seal.fulfill(.type1GoodTokenScriptSignatureGoodOrOptional(isDebugMode: !isOfficial, isSigned: false, validatedDomain: nil, error: .tokenScriptType1SupportedNotCanonicalizedAndUnsigned))
                    }
                }
            }
        case .unsupportedTokenScriptVersion(let isOld):
            if isOld {
                return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .custom("type 2 or bad? Mismatch version. Old version"), reason: .oldTokenScriptVersion))
            } else {
                preconditionFailure("Not expecting an unsupported and new version of TokenScript schema here")
                return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .custom("type 2 or bad? Mismatch version. Unknown schema"), reason: nil))
            }
        case .unknownXml:
            preconditionFailure("Not expecting an unknown XML here when checking TokenScript schema")
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .custom("unknown. Maybe empty invalid? Doesn't even include something that might be our schema"), reason: nil))
        case .others:
            preconditionFailure("Not expecting an unknown error when checking TokenScript schema")
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .custom("Not XML?"), reason: nil))
        }
    }

    private func verificationType(forXml xmlString: String) -> PromiseKit.Promise<TokenScriptSignatureVerificationType> {
        if let cachedVerificationType = backingStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString) {
            return .value(cachedVerificationType)
        } else {
            return signatureVerifier.verificationType(forXml: xmlString)
        }
    }
}

public final class TokenScriptSignatureVerifier: TokenScriptSignatureVerifieble {
    private let tokenScriptFilesProvider: BaseTokenScriptFilesProvider
    private let networking: TokenScriptSignatureNetworking
    private let queue = DispatchQueue(label: "org.alphawallet.swift.TokenScriptSignatureVerifier")
    private let reachability: ReachabilityManagerProtocol
    private let cancellable: AtomicDictionary<String, AnyCancellable> = .init()
    //TODO: remove later when replace with publisher, needed to add waiting for completion of single api call, to avoid multiple uploading of same file
    private let completions: AtomicDictionary<String, [((VerifierResult) -> Void)?]> = .init()
    private let features: TokenScriptFeatures

    public var retryBehavior: RetryBehavior<RunLoop> = .delayed(retries: UInt.max, time: 10)
    //NOTE: we receive 404 error code when uploading file might be something wrong with api, don't retry on 404 error code
    public var retryPredicate: RetryPredicate = { error in
        guard let erorr = error as? SessionTaskError else { return true }
        switch erorr {
        case .responseError(let error):
            guard let wrapper = error as? TokenScriptSignatureNetworking.ResponseError else { return true }
            return !(wrapper.response.statusCode == 404 || wrapper.isCancelled)
        case .requestError, .connectionError:
            return true
        }
    }

    public init(tokenScriptFilesProvider: BaseTokenScriptFilesProvider, networkService: NetworkService, features: TokenScriptFeatures, reachability: ReachabilityManagerProtocol = ReachabilityManager()) {
        self.tokenScriptFilesProvider = tokenScriptFilesProvider
        self.reachability = reachability
        self.networking = TokenScriptSignatureNetworking(networkService: networkService)
        self.features = features
    }

    public func verificationType(forXml xmlString: String) -> Promise<TokenScriptSignatureVerificationType> {
        return Promise { seal in
            if features.isActivityEnabled {
                if tokenScriptFilesProvider.containsTokenScriptFile(for: xmlString) {
                    seal.fulfill(.verified(domainName: "*.aw.app"))
                    return
                }
            }

            guard features.isTokenScriptSignatureStatusEnabled else {
                //It is safe to return without calling `completion` here since we aren't supposed to be using the results with the feature flag above
                verboseLog("[TokenScript] Signature verification disabled")
                //We call the completion handler so that if the caller is a `Promise`, it will resolve, in order to avoid the warning: "PromiseKit: warning: pending promise deallocated"
                seal.fulfill(.verified(domainName: ""))
                return
            }

            verifyXMLSignatureViaAPI(xml: xmlString) { result in
                switch result {
                case .success(domain: let domain):
                    seal.fulfill(.verified(domainName: domain))
                case .failed, .unknownCn:
                    seal.fulfill(.verificationFailed)
                }
            }
        }
    }

    //TODO log reasons for failures `completion(.failed)` as well as those that triggers retries in in-app Console
    public func verifyXMLSignatureViaAPI(xml: String, completion: @escaping (VerifierResult) -> Void) {
        add(callback: completion, xml: xml)

        guard cancellable[xml] == nil else { return }

        cancellable[xml] = reachability
            .networkBecomeReachablePublisher
            .receive(on: queue)
            .map { _ in xml }
            .setFailureType(to: SessionTaskError.self)
            .flatMapLatest { [networking, retryBehavior, retryPredicate] xml -> AnyPublisher<VerifierResult, SessionTaskError> in
                networking
                    .upload(xmlFile: xml)
                    .retry(retryBehavior, shouldOnlyRetryIf: retryPredicate, scheduler: RunLoop.main)
                    .eraseToAnyPublisher()
            }.replaceError(with: .failed)
            .receive(on: queue)
            .sink(receiveCompletion: { _ in
                self.cancellable[xml] = nil
            }, receiveValue: { result in
                DispatchQueue.main.async {
                    self.fulfill(for: xml, result: result)
                }
            })
    }

    private func add(callback: ((VerifierResult) -> Void)?, xml: String) {
        var callbacks = completions[xml] ?? []
        callbacks.append(callback)

        completions[xml] = callbacks
    }

    private func fulfill(for xml: String, result: TokenScriptSignatureVerifier.VerifierResult) {
        var callbacks = completions[xml] ?? []
        callbacks.forEach { $0?(result) }
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
    private static let validatorBaseUrl = URL(string: Constants.TokenScript.validatorAPI)!
    private static let headers: HTTPHeaders = [
        "cache-control": "no-cache",
        "content-type": "application/x-www-form-urlencoded"
    ]

    struct ResponseError: Error {
        let response: HTTPURLResponse
    }

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func upload(xmlFile xml: String) -> AnyPublisher<TokenScriptSignatureVerifier.VerifierResult, SessionTaskError> {
        guard let xmlAsData = xml.data(using: String.Encoding.utf8) else {
            return .fail(.requestError(URLError(.zeroByteResource)))
        }

        let multipartFormData: (MultipartFormData) -> Void = { multipartFormData in
            multipartFormData.append(xmlAsData, withName: "file", fileName: "file.tsml", mimeType: "text/xml")
        }

        //TODO: more detailed error reporting for failed verifications
        var request = URLRequest(url: TokenScriptSignatureNetworking.validatorBaseUrl)
        request.httpMethod = HTTPMethod.get.rawValue
        request.allHTTPHeaderFields = TokenScriptSignatureNetworking.headers.dictionary

        return networkService
            .upload(multipartFormData: multipartFormData, with: request)
            .flatMap { response -> AnyPublisher<TokenScriptSignatureVerifier.VerifierResult, SessionTaskError> in
                guard response.response.statusCode <= 299 else {
                    //API is coded to fail with 400
                    if response.response.statusCode == 400 {
                        return .just(.failed)
                    } else {
                        return .fail(.responseError(ResponseError(response: response.response)))
                    }
                }

                guard let subject = JSON(response.data)["subject"].string else {
                    //Should never hit
                    return .just(.unknownCn)
                }

                if let domain = TokenScriptSignatureNetworking.functional.keyValuePairs(fromCommaSeparatedKeyValuePairs: subject)["CN"] {
                    return .just(.success(domain: domain))
                } else {
                    return .just(.failed)
                }
            }.eraseToAnyPublisher()
    }
}

extension TokenScriptSignatureNetworking {
    enum functional {}
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
