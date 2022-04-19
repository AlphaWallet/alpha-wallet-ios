
import Foundation

protocol SocketConnectionHandler {
    var socket: WebSocketConnecting {get}
    func handleConnect() throws
    func handleDisconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws
}
