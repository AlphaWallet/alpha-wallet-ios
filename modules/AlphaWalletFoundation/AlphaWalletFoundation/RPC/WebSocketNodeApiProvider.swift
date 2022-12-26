//
//  WebSocketNodeApiProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.12.2022.
//

import Foundation
import Combine
import PromiseKit
import JSONRPCKit
import AlphaWalletWeb3

final class WebSocketNodeApiProvider: NSObject, NodeApiProvider {
    private let webSocket: WebSocketTaskConnection
    private let server: RPCServer
    private var cancellable = Set<AnyCancellable>()

    init(url: URL, server: RPCServer) {
        self.server = server

        webSocket = WebSocketTaskConnection(url: url)
        super.init()

        webSocket.event
            .sink { event in
                switch event {
                case .disconnect(let error):
                    break
                case .sentData(let data):
                    break
                case .sentText(let text):
                    break
                case .connected:
                    break
                case .error(let error):
                    break
                case .onText(let text):
                    break
                case .onData(let data):
                    break
                }
            }.store(in: &cancellable)
        
    }

    func dataTaskPromise<R>(_ request: R) -> PromiseKit.Promise<R.Response> where R: JSONRPCKit.Request {
        fatalError()
    }

    func dataTaskPublisher<R>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> where R: JSONRPCKit.Request {
        fatalError()
    }

    func dataTaskPromise<R>(_ request: R) -> PromiseKit.Promise<R.Response> where R: ContractMethodCall {
        fatalError()
    }

    func dataTaskPublisher<R>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> where R: ContractMethodCall {
        fatalError()
    }
}

enum WebSocketEvent {
    case sentData(Data)
    case sentText(String)
    case connected
    case disconnect(error: Error?)
    case error(Error)
    case onText(text: String)
    case onData(data: Data)
}

protocol WebSocketConnection {
    var event: AnyPublisher<WebSocketEvent, Never> { get }

    func send(text: String)
    func send(data: Data)
    func connect()
    func disconnect()
}

class WebSocketTaskConnection: NSObject, WebSocketConnection, URLSessionWebSocketDelegate {
    private (set) var webSocketTask: URLSessionWebSocketTask!
    private (set) var urlSession: URLSession!
    private let delegateQueue = OperationQueue()
    private let subject = PassthroughSubject<WebSocketEvent, Never>()

    var event: AnyPublisher<WebSocketEvent, Never> {
        return subject.eraseToAnyPublisher()
    }

    init(url: URL) {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
        webSocketTask = urlSession.webSocketTask(with: url)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        subject.send(.connected)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        subject.send(.disconnect(error: nil))
    }

    func connect() {
        webSocketTask.resume()

        listen()
    }

    func disconnect() {
        webSocketTask.cancel(with: .goingAway, reason: nil)
    }

    func listen() {
        webSocketTask.receive { [subject] result in
            switch result {
            case .failure(let error):
                subject.send(.error(error))
            case .success(let message):
                switch message {
                case .string(let text):
                    subject.send(.onText(text: text))
                case .data(let data):
                    subject.send(.onData(data: data))
                @unknown default:
                    break
                }

                self.listen()
            }
        }
    }

    func send(text: String) {
        webSocketTask.send(URLSessionWebSocketTask.Message.string(text)) { [subject] error in
            if let error = error {
                subject.send(.error(error))
            } else {
                subject.send(.sentText(text))
            }
        }
    }

    func send(data: Data) {
        webSocketTask.send(URLSessionWebSocketTask.Message.data(data)) { [subject] error in
            if let error = error {
                subject.send(.error(error))
            } else {
                subject.send(.sentData(data))
            }
        }
    }
}
