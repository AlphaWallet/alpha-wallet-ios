
import Foundation

protocol SocketConnectionObserving {
    var onConnect: (()->())? {get set}
    var onDisconnect: (()->())? {get set}
}

class SocketConnectionObserver: NSObject, URLSessionWebSocketDelegate, SocketConnectionObserving {
    var onConnect: (()->())?
    var onDisconnect: (()->())?

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        onConnect?()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onDisconnect?()
    }
}



