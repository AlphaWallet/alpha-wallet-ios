
import Foundation

class ManualSocketConnectionHandler: SocketConnectionHandler {
    var socket: WebSocketConnecting
    
    init(socket: WebSocketConnecting) {
        self.socket = socket
    }

    func handleConnect() throws {
        socket.connect()
    }
    
    func handleDisconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {
        socket.disconnect(with: closeCode)
    }
}
