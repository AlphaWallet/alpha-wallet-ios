// 

import Foundation
@testable import Relayer

class DispatcherMock: Dispatching {
    var onConnect: (() -> ())?
    var onDisconnect: (() -> ())?
    var onMessage: ((String) -> ())?
    var sent = false
    func send(_ string: String, completion: @escaping (Error?) -> ()) {
        sent = true
    }
    func connect() {}
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) {}
}
