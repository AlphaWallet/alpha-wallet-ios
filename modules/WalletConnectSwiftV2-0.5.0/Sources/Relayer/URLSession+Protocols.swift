import Foundation

protocol URLSessionProtocol {
    func webSocketTask(with url: URL) -> URLSessionWebSocketTaskProtocol
}

extension URLSession: URLSessionProtocol {
    func webSocketTask(with url: URL) -> URLSessionWebSocketTaskProtocol {
        webSocketTask(with: url) as URLSessionWebSocketTask
    }
}

protocol URLSessionWebSocketTaskProtocol {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void)
    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void)
}

extension URLSessionWebSocketTask: URLSessionWebSocketTaskProtocol {}
