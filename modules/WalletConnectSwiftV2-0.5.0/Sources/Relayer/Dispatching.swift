import Foundation
import WalletConnectUtils

protocol Dispatching {
    var onConnect: (()->())? {get set}
    var onDisconnect: (()->())? {get set}
    var onMessage: ((String) -> ())? {get set}
    func send(_ string: String, completion: @escaping (Error?)->())
    func connect() throws
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws
}

final class Dispatcher: NSObject, Dispatching {
    var onConnect: (() -> ())?
    var onDisconnect: (() -> ())?
    var onMessage: ((String) -> ())?
    private var textFramesQueue = Queue<String>()
    var socket: WebSocketSessionProtocol
    var socketConnectionObserver: SocketConnectionObserving
    var socketConnectionHandler: SocketConnectionHandler
    
    init(socket: WebSocketSessionProtocol,
         socketConnectionObserver: SocketConnectionObserving,
         socketConnectionHandler: SocketConnectionHandler) {
        self.socket = socket
        self.socketConnectionObserver = socketConnectionObserver
        self.socketConnectionHandler = socketConnectionHandler
        super.init()
        setUpWebSocketSession()
        setUpSocketConnectionObserving()
    }

    func send(_ string: String, completion: @escaping (Error?) -> Void) {
        if socket.isConnected {
            self.socket.send(string, completionHandler: completion)
            //TODO - enqueue     if fails
        } else {
            textFramesQueue.enqueue(string)
        }
    }
    
    func connect() throws {
        try socketConnectionHandler.handleConnect()
    }
    
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {
        try socketConnectionHandler.handleDisconnect(closeCode: closeCode)
    }
    
    private func setUpWebSocketSession() {
        socket.onMessageReceived = { [weak self] in
            self?.onMessage?($0)
        }
        socket.onMessageError = { error in
            print("WebSocket Error \(error)")
        }
    }
    
    private func setUpSocketConnectionObserving() {
        socketConnectionObserver.onConnect = { [weak self] in
            self?.dequeuePendingTextFrames()
            self?.onConnect?()
        }
        socketConnectionObserver.onDisconnect = { [weak self] in
            self?.onDisconnect?()
        }
    }
    
    private func dequeuePendingTextFrames() {
        while let frame = textFramesQueue.dequeue() {
            send(frame) { error in
                if let error = error {
                    print(error)
                }
            }
        }
    }
}
