import Foundation

protocol WebSocketSessionProtocol {
    var onMessageReceived: ((String) -> ())? {get set}
    var onMessageError: ((Error) -> ())? {get set}
    var isConnected: Bool {get}
    func send(_ message: String, completionHandler: @escaping ((Error?) -> Void))
}

protocol WebSocketConnecting {
    var isConnected: Bool {get}
    func connect()
    func disconnect(with closeCode: URLSessionWebSocketTask.CloseCode)
}

final class WebSocketSession: NSObject, WebSocketSessionProtocol, WebSocketConnecting {
    var onMessageReceived: ((String) -> ())?
    var onMessageError: ((Error) -> ())?
    let url: URL
    var isConnected: Bool {
        webSocketTask != nil
    }
    
    private let session: URLSessionProtocol
    
    private var webSocketTask: URLSessionWebSocketTaskProtocol?
    
    init(session: URLSessionProtocol, url: URL) {
        self.session = session
        self.url = url
        super.init()
    }
    
    func connect() {
        webSocketTask = session.webSocketTask(with: url)
        listen()
        webSocketTask?.resume()
    }
    
    func disconnect(with closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure) {
        webSocketTask?.cancel(with: closeCode, reason: nil)
        webSocketTask = nil
    }
    
    func send(_ message: String, completionHandler: @escaping ((Error?) -> Void)) {
        if let webSocketTask = webSocketTask {
            webSocketTask.send(.string(message)) { error in
                if let error = error {
                    completionHandler(NetworkError.sendMessageFailed(error))
                } else {
                    completionHandler(nil)
                }
            }
        } else {
            completionHandler(NetworkError.webSocketNotConnected)
        }
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
            case .failure(let error):
                self?.onMessageError?(NetworkError.receiveMessageFailure(error))
            }
            self?.listen()
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            onMessageReceived?(text)
        case .data(let data):
            print("Transport: Unexpected type of message received: \(data.toHexString())")
        @unknown default:
            print("Transport: Unexpected type of message received")
        }
    }
}
