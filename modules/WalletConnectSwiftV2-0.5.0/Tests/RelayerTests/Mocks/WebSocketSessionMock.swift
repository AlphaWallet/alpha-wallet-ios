
import Foundation
@testable import Relayer

class WebSocketSessionMock: WebSocketSessionProtocol, WebSocketConnecting {
    var onConnect: (() -> ())?
    var onDisconnect: (() -> ())?
    var onMessageReceived: ((String) -> ())?
    var onMessageError: ((Error) -> ())?
    var sendCallCount: Int = 0
    var isConnected: Bool = false
    
    func connect() {
        isConnected = true
        onConnect?()
    }
    
    func disconnect(with closeCode: URLSessionWebSocketTask.CloseCode) {
        isConnected = false
        onDisconnect?()
    }
    
    func send(_ message: String, completionHandler: @escaping ((Error?) -> Void)) {
        sendCallCount+=1
    }
}
