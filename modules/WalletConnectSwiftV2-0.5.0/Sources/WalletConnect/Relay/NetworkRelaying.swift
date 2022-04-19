
import Foundation
import Relayer

extension Relayer: NetworkRelaying {}

protocol NetworkRelaying {
    var onConnect: (()->())? {get set}
    var onMessage: ((_ topic: String, _ message: String) -> ())? {get set}
    func connect() throws
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws
    /// - returns: request id
    @discardableResult func publish(topic: String, payload: String, prompt: Bool, completion: @escaping ((Error?)->())) -> Int64
    /// - returns: request id
    @discardableResult func subscribe(topic: String, completion: @escaping (Error?)->()) -> Int64
    /// - returns: request id
    @discardableResult func unsubscribe(topic: String, completion: @escaping ((Error?)->())) -> Int64?
}
