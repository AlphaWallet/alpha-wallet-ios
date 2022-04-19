
import Foundation
import WalletConnectUtils

protocol JsonRpcHistoryRecording {
    func get(id: Int64) -> JsonRpcRecord?
    func set(topic: String, request: WCRequest, chainId: String?) throws
    func delete(topic: String)
    func resolve(response: JsonRpcResult) throws -> JsonRpcRecord
    func exist(id: Int64) -> Bool
}
//TODO -remove and use jsonrpc history only from utils
class JsonRpcHistory: JsonRpcHistoryRecording {
    let storage: KeyValueStore<JsonRpcRecord>
    let logger: ConsoleLogging
    
    init(logger: ConsoleLogging, keyValueStore: KeyValueStore<JsonRpcRecord>) {
        self.logger = logger
        self.storage = keyValueStore
    }
    
    func get(id: Int64) -> JsonRpcRecord? {
        try? storage.get(key: "\(id)")
    }
    
    func set(topic: String, request: WCRequest, chainId: String? = nil) throws {
        guard !exist(id: request.id) else {
            throw WalletConnectError.internal(.jsonRpcDuplicateDetected)
        }
        logger.debug("Setting JSON-RPC request history record - ID: \(request.id)")
        let record = JsonRpcRecord(id: request.id, topic: topic, request: JsonRpcRecord.Request(method: request.method, params: request.params), response: nil, chainId: chainId)
        try storage.set(record, forKey: "\(request.id)")
    }
    
    func delete(topic: String) {
        storage.getAll().forEach { record in
            if record.topic == topic {
                storage.delete(forKey: "\(record.id)")
            }
        }
    }
    
    func resolve(response: JsonRpcResult) throws -> JsonRpcRecord {
        logger.debug("Resolving JSON-RPC response - ID: \(response.id)")
        guard var record = try? storage.get(key: "\(response.id)") else {
            throw WalletConnectError.internal(.noJsonRpcRequestMatchingResponse)
        }
        if record.response != nil {
            throw WalletConnectError.internal(.jsonRpcDuplicateDetected)
        } else {
            record.response = response
            try storage.set(record, forKey: "\(record.id)")
            return record
        }
    }
    
    func exist(id: Int64) -> Bool {
        return (try? storage.get(key: "\(id)")) != nil
    }
    
    public func getPending() -> [JsonRpcRecord] {
        storage.getAll().filter{$0.response == nil}
    }
}
