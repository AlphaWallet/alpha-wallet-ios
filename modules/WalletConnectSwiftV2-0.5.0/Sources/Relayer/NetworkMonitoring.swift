
import Foundation
import Network

protocol NetworkMonitoring {
    var onSatisfied: (()->())? {get set}
    var onUnsatisfied: (()->())? {get set}
    func startMonitoring()
}

class NetworkMonitor: NetworkMonitoring {
    var onSatisfied: (() -> ())?
    var onUnsatisfied: (() -> ())?
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.walletconnect.sdk.network.monitor")
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.onSatisfied?()
            } else {
                self?.onUnsatisfied?()
            }
        }
        monitor.start(queue: monitorQueue)
    }
}

