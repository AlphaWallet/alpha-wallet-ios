import Foundation
@testable import Relayer

final class URLSessionWebSocketTaskMock: URLSessionWebSocketTaskProtocol {
    
    var didCallResume = false
    var didCallCancel = false
    
    var sendMessageError: Error?
    var lastMessageSent: URLSessionWebSocketTask.Message?
    var didCallSend: Bool {
        lastMessageSent != nil
    }
    
    var receiveMessageResult: Result<URLSessionWebSocketTask.Message, Error>?
    var receiveCallsCount = 0
    var didCallReceive: Bool {
        receiveCallsCount > 0
    }
    
    func resume() {
        didCallResume = true
    }
    
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        didCallCancel = true
    }
    
    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void) {
        lastMessageSent = message
        completionHandler(sendMessageError)
    }
    
    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        receiveCallsCount += 1
        if let result = receiveMessageResult {
            receiveMessageResult = nil
            completionHandler(result)
        }
    }
}
