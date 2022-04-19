

import Foundation
import XCTest
@testable import Relayer

final class ManualSocketConnectionHandlerTests: XCTestCase {
    var sut: ManualSocketConnectionHandler!
    var webSocketSession: WebSocketSessionMock!
    var networkMonitor: NetworkMonitoringMock!
    var socketConnectionObserver: SocketConnectionObserverMock!
    override func setUp() {
        webSocketSession = WebSocketSessionMock()
        sut = ManualSocketConnectionHandler(socket: webSocketSession)
    }
    
    func testHandleDisconnect() {
        webSocketSession.connect()
        XCTAssertTrue(webSocketSession.isConnected)
        try! sut.handleDisconnect(closeCode: .normalClosure)
        XCTAssertFalse(webSocketSession.isConnected)
    }
    
    func testHandleConnect() {
        XCTAssertFalse(webSocketSession.isConnected)
        try! sut.handleConnect()
        XCTAssertTrue(webSocketSession.isConnected)
    }
}
