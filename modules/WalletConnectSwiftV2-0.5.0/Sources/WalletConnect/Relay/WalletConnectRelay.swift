
import Foundation
import Combine
import WalletConnectUtils
import WalletConnectKMS

struct WCResponse {
    let topic: String
    let chainId: String?
    let requestMethod: WCRequest.Method
    let requestParams: WCRequest.Params
    let result: JsonRpcResult
}

protocol WalletConnectRelaying: AnyObject {
    var onPairingResponse: ((WCResponse) -> Void)? {get set} // Temporary workaround
    var onResponse: ((WCResponse) -> Void)? {get set}
    var transportConnectionPublisher: AnyPublisher<Void, Never> {get}
    var wcRequestPublisher: AnyPublisher<WCRequestSubscriptionPayload, Never> {get}
    func request(_ wcMethod: WCMethod, onTopic topic: String, completion: ((Result<JSONRPCResponse<AnyCodable>, JSONRPCErrorResponse>)->())?)
    func request(topic: String, payload: WCRequest, completion: ((Result<JSONRPCResponse<AnyCodable>, JSONRPCErrorResponse>)->())?) 
    func respond(topic: String, response: JsonRpcResult, completion: @escaping ((Error?)->()))
    func respondSuccess(for payload: WCRequestSubscriptionPayload)
    func respondError(for payload: WCRequestSubscriptionPayload, reason: ReasonCode)
    func subscribe(topic: String)
    func unsubscribe(topic: String)
}

extension WalletConnectRelaying {
    func request(_ wcMethod: WCMethod, onTopic topic: String) {
        request(wcMethod, onTopic: topic, completion: nil)
    }
}

class WalletConnectRelay: WalletConnectRelaying {
    
    var onPairingResponse: ((WCResponse) -> Void)?
    var onResponse: ((WCResponse) -> Void)?
    
    private var networkRelayer: NetworkRelaying
    private let serializer: Serializing
    private let jsonRpcHistory: JsonRpcHistoryRecording
    
    var transportConnectionPublisher: AnyPublisher<Void, Never> {
        transportConnectionPublisherSubject.eraseToAnyPublisher()
    }
    private let transportConnectionPublisherSubject = PassthroughSubject<Void, Never>()
    
    //rename to request publisher
    var wcRequestPublisher: AnyPublisher<WCRequestSubscriptionPayload, Never> {
        wcRequestPublisherSubject.eraseToAnyPublisher()
    }
    private let wcRequestPublisherSubject = PassthroughSubject<WCRequestSubscriptionPayload, Never>()
    
    private var wcResponsePublisher: AnyPublisher<JsonRpcResult, Never> {
        wcResponsePublisherSubject.eraseToAnyPublisher()
    }
    private let wcResponsePublisherSubject = PassthroughSubject<JsonRpcResult, Never>()
    let logger: ConsoleLogging
    
    init(networkRelayer: NetworkRelaying,
         serializer: Serializing,
         logger: ConsoleLogging,
         jsonRpcHistory: JsonRpcHistoryRecording) {
        self.networkRelayer = networkRelayer
        self.serializer = serializer
        self.logger = logger
        self.jsonRpcHistory = jsonRpcHistory
        setUpPublishers()
    }
    
    func request(_ wcMethod: WCMethod, onTopic topic: String, completion: ((Result<JSONRPCResponse<AnyCodable>, JSONRPCErrorResponse>) -> ())?) {
        request(topic: topic, payload: wcMethod.asRequest(), completion: completion)
    }
    
    func request(topic: String, payload: WCRequest, completion: ((Result<JSONRPCResponse<AnyCodable>, JSONRPCErrorResponse>)->())?) {
        do {
            try jsonRpcHistory.set(topic: topic, request: payload, chainId: getChainId(payload))
            let message = try serializer.serialize(topic: topic, encodable: payload)
            let prompt = shouldPrompt(payload.method)
            networkRelayer.publish(topic: topic, payload: message, prompt: prompt) { [weak self] error in
                guard let self = self else {return}
                if let error = error {
                    self.logger.error(error)
                } else {
                    var cancellable: AnyCancellable!
                    cancellable = self.wcResponsePublisher
                        .filter {$0.id == payload.id}
                        .sink { (response) in
                            cancellable.cancel()
                            self.logger.debug("WC Relay - received response on topic: \(topic)")
                            switch response {
                            case .response(let response):
                                completion?(.success(response))
                            case .error(let error):
                                self.logger.debug("Request error: \(error)")
                                completion?(.failure(error))
                            }
                        }
                }
            }
        } catch WalletConnectError.internal(.jsonRpcDuplicateDetected) {
            logger.info("Info: Json Rpc Duplicate Detected")
        } catch {
            logger.error(error)
        }
    }
    
    func respond(topic: String, response: JsonRpcResult, completion: @escaping ((Error?)->())) {
        do {
            _ = try jsonRpcHistory.resolve(response: response)
            let message = try serializer.serialize(topic: topic, encodable: response.value)
            logger.debug("Responding....topic: \(topic)")
            networkRelayer.publish(topic: topic, payload: message, prompt: false) { error in
                completion(error)
            }
        } catch WalletConnectError.internal(.jsonRpcDuplicateDetected) {
            logger.info("Info: Json Rpc Duplicate Detected")
        } catch {
            completion(error)
        }
    }
    
    func respondSuccess(for payload: WCRequestSubscriptionPayload) {
        let response = JSONRPCResponse<AnyCodable>(id: payload.wcRequest.id, result: AnyCodable(true))
        respond(topic: payload.topic, response: JsonRpcResult.response(response)) { _ in } // TODO: Move error handling to relayer package
    }
    
    func respondError(for payload: WCRequestSubscriptionPayload, reason: ReasonCode) {
        let response = JSONRPCErrorResponse(id: payload.wcRequest.id, error: JSONRPCErrorResponse.Error(code: reason.code, message: reason.message))
        respond(topic: payload.topic, response: JsonRpcResult.error(response)) { _ in } // TODO: Move error handling to relayer package
    }
    
    func subscribe(topic: String)  {
        networkRelayer.subscribe(topic: topic) { [weak self] error in
            if let error = error {
                self?.logger.error(error)
            }
        }
    }

    func unsubscribe(topic: String) {
        networkRelayer.unsubscribe(topic: topic) { [weak self] error in
            if let error = error {
                self?.logger.error(error)
            } else {
                self?.jsonRpcHistory.delete(topic: topic)
            }
        }
    }
    
    //MARK: - Private
    private func setUpPublishers() {
        networkRelayer.onConnect = { [weak self] in
            self?.transportConnectionPublisherSubject.send()
        }
        networkRelayer.onMessage = { [unowned self] topic, message in
            manageSubscription(topic, message)
        }
    }
    
    private func manageSubscription(_ topic: String, _ message: String) {
        if let deserializedJsonRpcRequest: WCRequest = serializer.tryDeserialize(topic: topic, message: message) {
            handleWCRequest(topic: topic, request: deserializedJsonRpcRequest)
        } else if let deserializedJsonRpcResponse: JSONRPCResponse<AnyCodable> = serializer.tryDeserialize(topic: topic, message: message) {
            handleJsonRpcResponse(response: deserializedJsonRpcResponse)
        } else if let deserializedJsonRpcError: JSONRPCErrorResponse = serializer.tryDeserialize(topic: topic, message: message) {
            handleJsonRpcErrorResponse(response: deserializedJsonRpcError)
        } else {
            logger.warn("Warning: WalletConnect Relay - Received unknown object type from networking relay")
        }
    }
    
    private func handleWCRequest(topic: String, request: WCRequest) {
        do {
            try jsonRpcHistory.set(topic: topic, request: request, chainId: getChainId(request))
            let payload = WCRequestSubscriptionPayload(topic: topic, wcRequest: request)
            wcRequestPublisherSubject.send(payload)
        } catch WalletConnectError.internal(.jsonRpcDuplicateDetected) {
            logger.info("Info: Json Rpc Duplicate Detected")
        } catch {
            logger.error(error)
        }
    }
    
    private func handleJsonRpcResponse(response: JSONRPCResponse<AnyCodable>) {
        do {
            let record = try jsonRpcHistory.resolve(response: JsonRpcResult.response(response))
            let wcResponse = WCResponse(
                topic: record.topic,
                chainId: record.chainId,
                requestMethod: record.request.method,
                requestParams: record.request.params,
                result: JsonRpcResult.response(response))
            wcResponsePublisherSubject.send(.response(response))
            onPairingResponse?(wcResponse)
            onResponse?(wcResponse)
        } catch  {
            logger.info("Info: \(error.localizedDescription)")
        }
    }
    
    private func handleJsonRpcErrorResponse(response: JSONRPCErrorResponse) {
        do {
            let record = try jsonRpcHistory.resolve(response: JsonRpcResult.error(response))
            let wcResponse = WCResponse(
                topic: record.topic,
                chainId: record.chainId,
                requestMethod: record.request.method,
                requestParams: record.request.params,
                result: JsonRpcResult.error(response))
            wcResponsePublisherSubject.send(.error(response))
            onPairingResponse?(wcResponse)
            onResponse?(wcResponse)
        } catch {
            logger.info("Info: \(error.localizedDescription)")
        }
    }
    
    private func shouldPrompt(_ method: WCRequest.Method) -> Bool {
        switch method {
        case .sessionPayload, .pairingPayload:
            return true
        default:
            return false
        }
    }
    
    func getChainId(_ request: WCRequest) -> String? {
        guard case let .sessionPayload(payload) = request.params else {return nil}
        return payload.chainId
    }
}
