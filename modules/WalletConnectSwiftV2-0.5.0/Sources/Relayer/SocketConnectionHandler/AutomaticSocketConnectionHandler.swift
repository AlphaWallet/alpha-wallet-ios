
#if os(iOS)
import UIKit
#endif
import Foundation

class AutomaticSocketConnectionHandler: SocketConnectionHandler {
    enum Error: Swift.Error {
        case manualSocketConnectionForbidden
        case manualSocketDisconnectionForbidden
    }
    private var appStateObserver: AppStateObserving
    let socket: WebSocketConnecting
    private var networkMonitor: NetworkMonitoring
    private let backgroundTaskRegistrar: BackgroundTaskRegistering

    init(networkMonitor: NetworkMonitoring = NetworkMonitor(),
         socket: WebSocketConnecting,
         appStateObserver: AppStateObserving = AppStateObserver(),
         backgroundTaskRegistrar: BackgroundTaskRegistering = BackgroundTaskRegistrar()) {
        self.appStateObserver = appStateObserver
        self.socket = socket
        self.networkMonitor = networkMonitor
        self.backgroundTaskRegistrar = backgroundTaskRegistrar
        setUpStateObserving()
        setUpNetworkMonitoring()
        socket.connect()
    }
    
    private func setUpStateObserving() {
        appStateObserver.onWillEnterBackground = { [unowned self] in
            registerBackgroundTask()
        }
        
        appStateObserver.onWillEnterForeground = { [unowned self] in
            socket.connect()
            backgroundTaskRegistrar.endBackgroundTask()
        }
    }
    
    private func setUpNetworkMonitoring() {
        networkMonitor.onSatisfied = { [weak self] in
            self?.handleNetworkSatisfied()
        }
        networkMonitor.onUnsatisfied = { [weak self] in
            self?.handleNetworkUnsatisfied()
        }
        networkMonitor.startMonitoring()
    }
    
    private func registerBackgroundTask() {
        backgroundTaskRegistrar.beginBackgroundTask(name: "Finish Network Tasks") { [unowned self] in
            endBackgroundTask()
        }
    }
    
    func endBackgroundTask() {
        socket.disconnect(with: .normalClosure)
    }
    
    func handleConnect() throws {
        throw Error.manualSocketConnectionForbidden
    }
    
    func handleDisconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {
        throw Error.manualSocketDisconnectionForbidden
    }
    
    func handleNetworkUnsatisfied() {
        socket.disconnect(with: .goingAway)
    }
    
    func handleNetworkSatisfied() {
        if !socket.isConnected {
            socket.connect()
        }
    }
}
