
import Foundation
import Combine
import WalletConnectUtils
@testable import WalletConnect
@testable import TestingUtils

class MockedWCRelay: WalletConnectRelaying {
    
    var onPairingResponse: ((WCResponse) -> Void)?
    var onResponse: ((WCResponse) -> Void)?
    
    var onPairingApproveResponse: ((String) -> Void)?
    
    var transportConnectionPublisher: AnyPublisher<Void, Never> {
        transportConnectionPublisherSubject.eraseToAnyPublisher()
    }
    private let transportConnectionPublisherSubject = PassthroughSubject<Void, Never>()
    
    private let wcRequestPublisherSubject = PassthroughSubject<WCRequestSubscriptionPayload, Never>()
    var wcRequestPublisher: AnyPublisher<WCRequestSubscriptionPayload, Never> {
        wcRequestPublisherSubject.eraseToAnyPublisher()
    }
    var didCallRequest = false
    var didCallSubscribe = false
    var didCallUnsubscribe = false
    var didRespondSuccess = false
    var lastErrorCode = -1
    var error: Error? = nil
    
    private(set) var requests: [(topic: String, request: WCRequest)] = []
    
    func request(_ wcMethod: WCMethod, onTopic topic: String, completion: ((Result<JSONRPCResponse<AnyCodable>, JSONRPCErrorResponse>) -> ())?) {
        request(topic: topic, payload: wcMethod.asRequest(), completion: completion)
    }
    
    func request(topic: String, payload: WCRequest, completion: ((Result<JSONRPCResponse<AnyCodable>, JSONRPCErrorResponse>) -> ())?) {
        didCallRequest = true
        requests.append((topic, payload))
    }
    
    func respond(topic: String, response: JsonRpcResult, completion: @escaping ((Error?) -> ())) {
        completion(error)
    }
    
    func respondSuccess(for payload: WCRequestSubscriptionPayload) {
        didRespondSuccess = true
    }
    
    func respondError(for payload: WCRequestSubscriptionPayload, reason: ReasonCode) {
        lastErrorCode = reason.code
    }
    
    func subscribe(topic: String) {
        didCallSubscribe = true
    }
    
    func unsubscribe(topic: String) {
        didCallUnsubscribe = true
    }
    
    func sendSubscriptionPayloadOn(topic: String) {
        let payload = WCRequestSubscriptionPayload(topic: topic,
                                                   wcRequest: pairingApproveJSONRPCRequest)
        wcRequestPublisherSubject.send(payload)
    }
}

fileprivate let pairingApproveJSONRPCRequest = WCRequest(
    id: 0,
    jsonrpc: "2.0",
    method: WCRequest.Method.pairingApprove,
    params: WCRequest.Params.pairingApprove(
        PairingType.ApprovalParams(
            relay: RelayProtocolOptions(
                protocol: "waku",
                params: nil),
            responder: PairingParticipant(publicKey: "be9225978b6287a02d259ee0d9d1bcb683082d8386b7fb14b58ac95b93b2ef43"),
            expiry: 1632742217,
            state: PairingState(metadata: AppMetadata(
                name: "iOS",
                description: nil,
                url: nil,
                icons: nil))))
)
