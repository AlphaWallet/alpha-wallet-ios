enum NetworkError: Error {
    case webSocketNotConnected
    case sendMessageFailed(Error)
    case receiveMessageFailure(Error)
}

extension NetworkError {
    
    var localizedDescription: String {
        switch self {
        case .webSocketNotConnected:
            return "Web socket is not connected to any URL."
        case .sendMessageFailed(let error):
            return "Failed to send a message through the web socket: \(error)"
        case .receiveMessageFailure(let error):
            return "An error happened when receiving a web socket message: \(error)"
        }
    }
}
