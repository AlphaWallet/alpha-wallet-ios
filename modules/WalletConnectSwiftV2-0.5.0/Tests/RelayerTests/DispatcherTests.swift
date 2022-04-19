
import Foundation
import XCTest
@testable import Relayer

final class DispatcherTests: XCTestCase {
    var sut: Dispatcher!
    var webSocketSession: WebSocketSessionMock!
    var networkMonitor: NetworkMonitoringMock!
    var socketConnectionObserver: SocketConnectionObserverMock!
    override func setUp() {
        webSocketSession = WebSocketSessionMock()
        networkMonitor = NetworkMonitoringMock()
        socketConnectionObserver = SocketConnectionObserverMock()
        sut = Dispatcher(socket: webSocketSession, socketConnectionObserver: socketConnectionObserver, socketConnectionHandler: ManualSocketConnectionHandler(socket: webSocketSession))
    }

    func testSendWhileConnected() {
        try! sut.connect()
        sut.send("1"){_ in}
        XCTAssertEqual(webSocketSession.sendCallCount, 1)
    }
        
    func testTextFramesSentAfterReconnectingSocket() {
        try! sut.disconnect(closeCode: .normalClosure)
        sut.send("1"){_ in}
        sut.send("2"){_ in}
        XCTAssertEqual(webSocketSession.sendCallCount, 0)
        try! sut.connect()
        socketConnectionObserver.onConnect?()
        XCTAssertEqual(webSocketSession.sendCallCount, 2)
    }
    
    func testOnMessage() {
        let expectation = expectation(description: "on message")
        sut.onMessage = { message in
            XCTAssertNotNil(message)
            expectation.fulfill()
        }
        webSocketSession.onMessageReceived?("message")
        waitForExpectations(timeout: 0.001)
    }
    
    func testOnConnect() {
        let expectation = expectation(description: "on connect")
        sut.onConnect = {
            expectation.fulfill()
        }
        socketConnectionObserver.onConnect?()
        waitForExpectations(timeout: 0.001)
    }
    
    func testOnDisconnect() {
        let expectation = expectation(description: "on disconnect")
        sut.onDisconnect = {
            expectation.fulfill()
        }
        socketConnectionObserver.onDisconnect?()
        waitForExpectations(timeout: 0.001)
    }
}


class SocketConnectionObserverMock: SocketConnectionObserving {
    var onConnect: (() -> ())?
    var onDisconnect: (() -> ())?
}
