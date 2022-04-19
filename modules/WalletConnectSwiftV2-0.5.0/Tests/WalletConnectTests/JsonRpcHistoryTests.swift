
import Foundation
import XCTest
import TestingUtils
import WalletConnectUtils
@testable import WalletConnect

final class JsonRpcHistoryTests: XCTestCase {
    
    var sut: WalletConnect.JsonRpcHistory!
            
    override func setUp() {
        sut = JsonRpcHistory(logger: ConsoleLoggerMock(), keyValueStore: KeyValueStore<WalletConnect.JsonRpcRecord>(defaults: RuntimeKeyValueStorage(), identifier: ""))
    }
    
    override func tearDown() {
        sut = nil
    }
    
    func testSetRecord() {
        let recordinput = getTestJsonRpcRecordInput()
        XCTAssertFalse(sut.exist(id: recordinput.request.id))
        try! sut.set(topic: recordinput.topic, request: recordinput.request)
        XCTAssertTrue(sut.exist(id: recordinput.request.id))
    }
    
    func testGetRecord() {
        let recordinput = getTestJsonRpcRecordInput()
        XCTAssertNil(sut.get(id: recordinput.request.id))
        try! sut.set(topic: recordinput.topic, request: recordinput.request)
        XCTAssertNotNil(sut.get(id: recordinput.request.id))
    }
    
    func testResolve() {
        let recordinput = getTestJsonRpcRecordInput()
        try! sut.set(topic: recordinput.topic, request: recordinput.request)
        XCTAssertNil(sut.get(id: recordinput.request.id)?.response)
        let jsonRpcResponse = JSONRPCResponse<AnyCodable>(id: recordinput.request.id, result: AnyCodable(""))
        let response = JsonRpcResult.response(jsonRpcResponse)
        _ = try! sut.resolve(response: response)
        XCTAssertNotNil(sut.get(id: jsonRpcResponse.id)?.response)
    }
    
    func testThrowsOnResolveDuplicate() {
        let recordinput = getTestJsonRpcRecordInput()
        try! sut.set(topic: recordinput.topic, request: recordinput.request)
        let jsonRpcResponse = JSONRPCResponse<AnyCodable>(id: recordinput.request.id, result: AnyCodable(""))
        let response = JsonRpcResult.response(jsonRpcResponse)
        _ = try! sut.resolve(response: response)
        XCTAssertThrowsError(try sut.resolve(response: response))
    }
    
    func testThrowsOnSetDuplicate() {
        let recordinput = getTestJsonRpcRecordInput()
        try! sut.set(topic: recordinput.topic, request: recordinput.request)
        XCTAssertThrowsError(try sut.set(topic: recordinput.topic, request: recordinput.request))
    }
    
    func testDelete() {
        let recordinput = getTestJsonRpcRecordInput()
        try! sut.set(topic: recordinput.topic, request: recordinput.request)
        XCTAssertNotNil(sut.get(id: recordinput.request.id))
        sut.delete(topic: testTopic)
        XCTAssertNil(sut.get(id: recordinput.request.id))
    }
    
    func testGetPending() {
        let recordinput1 = getTestJsonRpcRecordInput(id: 1)
        let recordinput2 = getTestJsonRpcRecordInput(id: 2)
        try! sut.set(topic: recordinput1.topic, request: recordinput1.request)
        try! sut.set(topic: recordinput2.topic, request: recordinput2.request)
        XCTAssertEqual(sut.getPending().count, 2)
        let jsonRpcResponse = JSONRPCResponse<AnyCodable>(id: recordinput1.request.id, result: AnyCodable(""))
        let response = JsonRpcResult.response(jsonRpcResponse)
        _ = try! sut.resolve(response: response)
        XCTAssertEqual(sut.getPending().count, 1)
    }
}

private let testTopic = "test_topic"
private func getTestJsonRpcRecordInput(id: Int64 = 0) -> (topic: String, request: WCRequest) {
    let request = WCRequest(id: id,
              jsonrpc: "2.0",
              method: WCRequest.Method.pairingApprove,
              params: WCRequest.Params.pairingApprove(
                PairingType.ApprovalParams(relay: RelayProtocolOptions(protocol: "waku",
                                                                       params: nil), responder: PairingParticipant(publicKey: "be9225978b6287a02d259ee0d9d1bcb683082d8386b7fb14b58ac95b93b2ef43"),
                                           expiry: 1632742217,
                                           state: PairingState(metadata: AppMetadata(name: "iOS",
                                                                                     description: nil,
                                                                                     url: nil,
                                                                                     icons: nil)))))
    return (topic: testTopic, request: request)
}
