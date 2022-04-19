import XCTest
@testable import Relayer

final class WebSocketSessionTests: XCTestCase {
    
    var sut: WebSocketSession!
    
    var webSocketTaskMock: URLSessionWebSocketTaskMock!
    var sessionMock: URLSessionMock!
    var url: URL!
    override func setUp() {
        webSocketTaskMock = URLSessionWebSocketTaskMock()
        sessionMock = URLSessionMock(webSocketTaskMock: webSocketTaskMock)
        url = URL.stub()
        sut = WebSocketSession(session: sessionMock, url: url)
    }
    
    override func tearDown() {
        sut = nil
        sessionMock = nil
        webSocketTaskMock = nil
    }
    
    func testInitIsNotConnected() {
        XCTAssertFalse(sut.isConnected)
    }
    
    func testConnect() {
        sut.connect()
        XCTAssertTrue(sut.isConnected)
        XCTAssertTrue(webSocketTaskMock.didCallResume)
        XCTAssertTrue(webSocketTaskMock.didCallReceive)
        XCTAssertEqual(sessionMock.lastSessionTaskURL, url)
    }
    
    func testDisconnect() {
        sut.connect()
        sut.disconnect()
        XCTAssertFalse(sut.isConnected)
        XCTAssertTrue(webSocketTaskMock.didCallCancel)
    }
    
    func testSendMessageSuccessCallbacksNoError() {
        let expectedMessage = "message"
        
        sut.connect()
        sut.send(expectedMessage) { error in
            XCTAssertNil(error)
        }
        
        XCTAssertTrue(webSocketTaskMock.didCallSend)
        guard case .string(let message) = webSocketTaskMock.lastMessageSent else { XCTFail(); return }
        XCTAssertEqual(message, expectedMessage)
    }
    
    func testSendMessageFailsIfNotConnected() {
        sut.send("") { error in
            XCTAssertNotNil(error)
            XCTAssert(error?.asNetworkError?.isWebSocketError == true)
        }
        XCTAssertFalse(webSocketTaskMock.didCallSend)
    }

    func testSendMessageFailure() {
        webSocketTaskMock.sendMessageError = NSError.mock()
        
        sut.connect()
        sut.send("") { error in
            XCTAssertNotNil(error)
            XCTAssert(error?.asNetworkError?.isSendMessageError == true)
        }
        XCTAssertTrue(webSocketTaskMock.didCallSend)
    }
    
    func testReceiveMessageSuccess() {
        let expectedMessage = "message"
        var callbackMessage: String? = nil
        sut.onMessageReceived = { callbackMessage = $0 }
        webSocketTaskMock.receiveMessageResult = .success(.string(expectedMessage))
        
        sut.connect()
        
        XCTAssertEqual(callbackMessage, expectedMessage)
        XCTAssert(webSocketTaskMock.receiveCallsCount == 2)
    }
    
    func testReceiveMessageSuccessButUnexpectedType() {
        var callbackMessage: String? = nil
        sut.onMessageReceived = { callbackMessage = $0 }
        var didCallbackError = false
        sut.onMessageError = { _ in didCallbackError = true }
        webSocketTaskMock.receiveMessageResult = .success(.data("message".data(using: .utf8)!))
        
        sut.connect()
        
        XCTAssertNil(callbackMessage)
        XCTAssertFalse(didCallbackError)
        XCTAssert(webSocketTaskMock.receiveCallsCount == 2)
    }
    
    func testReceiveMessageFailure() {
        sut.onMessageError = { error in
            XCTAssertNotNil(error)
            XCTAssert(error.asNetworkError?.isReceiveMessageError == true)
        }
        webSocketTaskMock.receiveMessageResult = .failure(NSError.mock())
        
        sut.connect()
        
        XCTAssert(webSocketTaskMock.receiveCallsCount == 2)
    }
}
