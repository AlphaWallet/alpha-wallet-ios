
import Foundation
import XCTest
@testable import Relayer

final class AutomaticSocketConnectionHandlerTests: XCTestCase {
    var sut: AutomaticSocketConnectionHandler!
    var webSocketSession: WebSocketSessionMock!
    var networkMonitor: NetworkMonitoringMock!
    var socketConnectionObserver: SocketConnectionObserverMock!
    var appStateObserver: AppStateObserving!
    var backgroundTaskRegistrar: BackgroundTaskRegistrarMock!
    override func setUp() {
        webSocketSession = WebSocketSessionMock()
        networkMonitor = NetworkMonitoringMock()
        appStateObserver = AppStateObserverMock()
        socketConnectionObserver = SocketConnectionObserverMock()
        backgroundTaskRegistrar = BackgroundTaskRegistrarMock()
        sut = AutomaticSocketConnectionHandler(
            networkMonitor: networkMonitor,
            socket: webSocketSession,
            appStateObserver: appStateObserver,
        backgroundTaskRegistrar: backgroundTaskRegistrar)
    }
    
    func testDisconnectOnConnectionLoss() {
        webSocketSession.connect()
        XCTAssertTrue(sut.socket.isConnected)
        networkMonitor.onUnsatisfied?()
        XCTAssertFalse(sut.socket.isConnected)
    }

    func testConnectsOnConnectionSatisfied() {
        webSocketSession.disconnect(with: .normalClosure)
        XCTAssertFalse(sut.socket.isConnected)
        networkMonitor.onSatisfied?()
        XCTAssertTrue(sut.socket.isConnected)
    }
    
    func testHandleConnectThrows() {
        XCTAssertThrowsError(try sut.handleConnect())
    }

    func testHandleDisconnectThrows() {
        XCTAssertThrowsError(try sut.handleDisconnect(closeCode: .normalClosure))
    }
    
    func testReconnectsOnEnterForeground() {
        webSocketSession.disconnect(with: .normalClosure)
        appStateObserver.onWillEnterForeground?()
        XCTAssertTrue(sut.socket.isConnected)
    }
    
    func testRegisterTaskOnEnterBackground() {
        XCTAssertNil(backgroundTaskRegistrar.completion)
        appStateObserver.onWillEnterBackground?()
        XCTAssertNotNil(backgroundTaskRegistrar.completion)
    }
    
    func testDisconnectOnEndBackgroundTask() {
        appStateObserver.onWillEnterBackground?()
        XCTAssertTrue(sut.socket.isConnected)
        backgroundTaskRegistrar.completion!()
        XCTAssertFalse(sut.socket.isConnected)
    }
}
