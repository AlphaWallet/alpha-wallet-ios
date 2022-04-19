
import Foundation
@testable import Relayer

class NetworkMonitoringMock: NetworkMonitoring {
    var onSatisfied: (() -> ())?
    var onUnsatisfied: (() -> ())?
    
    func startMonitoring() { }
}
