
import Foundation

public class JsonRpcHistory<T> where T: Codable&Equatable {
    enum RecordingError: Error {
        case jsonRpcDuplicateDetected
        case noJsonRpcRequestMatchingResponse
    }
    private let storage: KeyValueStore<JsonRpcRecord>
    private let logger: ConsoleLogging

    public init(logger: ConsoleLogging, keyValueStore: KeyValueStore<JsonRpcRecord>) {
        self.logger = logger
        self.storage = keyValueStore
    }
    
    public func get(id: Int64) -> JsonRpcRecord? {
        try? storage.get(key: "\(id)")
    }
    
    public func set(topic: String, request: JSONRPCRequest<T>, chainId: String? = nil) throws {
        guard !exist(id: request.id) else {
            throw RecordingError.jsonRpcDuplicateDetected
        }
        logger.debug("Setting JSON-RPC request history record")
        let record = JsonRpcRecord(id: request.id, topic: topic, request: JsonRpcRecord.Request(method: request.method, params: AnyCodable(request.params)), response: nil, chainId: chainId)
        try storage.set(record, forKey: "\(request.id)")
    }
    
    public func delete(topic: String) {
        storage.getAll().forEach { record in
            if record.topic == topic {
                storage.delete(forKey: "\(record.id)")
            }
        }
    }
    
    public func resolve(response: JsonRpcResult) throws -> JsonRpcRecord {
        logger.debug("Resolving JSON-RPC response - ID: \(response.id)")
        guard var record = try? storage.get(key: "\(response.id)") else {
            throw RecordingError.noJsonRpcRequestMatchingResponse
        }
        if record.response != nil {
            throw RecordingError.jsonRpcDuplicateDetected
        } else {
            record.response = response
            try storage.set(record, forKey: "\(record.id)")
            return record
        }
    }
    
    public func exist(id: Int64) -> Bool {
        return (try? storage.get(key: "\(id)")) != nil
    }
    
    public func getPending() -> [JsonRpcRecord] {
        storage.getAll().filter{$0.response == nil}
    }
}
