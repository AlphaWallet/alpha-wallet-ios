
import Foundation
import XCTest
import WalletConnectUtils
import TestingUtils
@testable import WalletConnect
@testable import WalletConnectKMS

fileprivate extension Session.Permissions {
    static func stub(methods: Set<String> = [], notifications: [String] = []) -> Session.Permissions {
        Session.Permissions(blockchains: [], methods: methods, notifications: notifications)
    }
}

final class ClientTests: XCTestCase {
    
    let defaultTimeout: TimeInterval = 5.0
    
    let relayHost = "relay.dev.walletconnect.com"
    let projectId = "52af113ee0c1e1a20f4995730196c13e"
    var proposer: ClientDelegate!
    var responder: ClientDelegate!
    
    override func setUp() {
        proposer = Self.makeClientDelegate(isController: false, relayHost: relayHost, prefix: "🍏P", projectId: projectId)
        responder = Self.makeClientDelegate(isController: true, relayHost: relayHost, prefix: "🍎R", projectId: projectId)
    }

    static func makeClientDelegate(isController: Bool, relayHost: String, prefix: String, projectId: String) -> ClientDelegate {
        let logger = ConsoleLogger(suffix: prefix, loggingLevel: .debug)
        let keychain = KeychainStorage(keychainService: KeychainServiceFake(), serviceIdentifier: "")
        let client = WalletConnectClient(
            metadata: AppMetadata(name: nil, description: nil, url: nil, icons: nil),
            projectId: projectId,
            relayHost: relayHost,
            logger: logger,
            kms: KeyManagementService(keychain: keychain),
            keyValueStorage: RuntimeKeyValueStorage())
        return ClientDelegate(client: client)
    }
    
    func testNewPairingWithoutSession() {
        let proposerSettlesPairingExpectation = expectation(description: "Proposer settles pairing")
        let responderSettlesPairingExpectation = expectation(description: "Responder settles pairing")
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        
        _ = try! responder.client.pair(uri: uri)
        responder.onPairingSettled = { _ in
            responderSettlesPairingExpectation.fulfill()
        }
        proposer.onPairingSettled = { pairing in
            proposerSettlesPairingExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }

    func testNewSession() {
        let proposerSettlesSessionExpectation = expectation(description: "Proposer settles session")
        let responderSettlesSessionExpectation = expectation(description: "Responder settles session")
        let account = Account("eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdb")!
        
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        try! responder.client.pair(uri: uri)
        responder.onSessionProposal = { [unowned self] proposal in
            self.responder.client.approve(proposal: proposal, accounts: [account])
        }
        responder.onSessionSettled = { sessionSettled in
            // FIXME: Commented assertion
//            XCTAssertEqual(account, sessionSettled.state.accounts[0])
            responderSettlesSessionExpectation.fulfill()
        }
        proposer.onSessionSettled = { sessionSettled in
            // FIXME: Commented assertion
//            XCTAssertEqual(account, sessionSettled.state.accounts[0])
            proposerSettlesSessionExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testNewSessionOnExistingPairing() {
        let proposerSettlesSessionExpectation = expectation(description: "Proposer settles session")
        proposerSettlesSessionExpectation.expectedFulfillmentCount = 2
        let responderSettlesSessionExpectation = expectation(description: "Responder settles session")
        responderSettlesSessionExpectation.expectedFulfillmentCount = 2
        var pairingTopic: String!
        var initiatedSecondSession = false
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions, topic: nil)!
        try! responder.client.pair(uri: uri)
        proposer.onPairingSettled = { pairing in
            pairingTopic = pairing.topic
        }
        responder.onSessionProposal = { [unowned self] proposal in
            responder.client.approve(proposal: proposal, accounts: [])
        }
        responder.onSessionSettled = { sessionSettled in
            responderSettlesSessionExpectation.fulfill()
        }
        proposer.onSessionSettled = { [unowned self] sessionSettled in
            proposerSettlesSessionExpectation.fulfill()
            if !initiatedSecondSession {
                let _ = try! proposer.client.connect(sessionPermissions: permissions, topic: pairingTopic)
                initiatedSecondSession = true
            }
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }

    func testResponderRejectsSession() {
        let sessionRejectExpectation = expectation(description: "Proposer is notified on session rejection")
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        _ = try! responder.client.pair(uri: uri)
        responder.onSessionProposal = {[unowned self] proposal in
            self.responder.client.reject(proposal: proposal, reason: .disapprovedChains)
        }
        proposer.onSessionRejected = { _, reason in
            XCTAssertEqual(reason.code, 5000)
            sessionRejectExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testDeleteSession() {
        let sessionDeleteExpectation = expectation(description: "Responder is notified on session deletion")
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        _ = try! responder.client.pair(uri: uri)
        responder.onSessionProposal = {[unowned self]  proposal in
            self.responder.client.approve(proposal: proposal, accounts: [])
        }
        proposer.onSessionSettled = {[unowned self]  settledSession in
            self.proposer.client.disconnect(topic: settledSession.topic, reason: Reason(code: 5900, message: "User disconnected session"))
        }
        responder.onSessionDelete = {
            sessionDeleteExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testProposerRequestSessionPayload() {
        let requestExpectation = expectation(description: "Responder receives request")
        let responseExpectation = expectation(description: "Proposer receives response")
        let method = "eth_sendTransaction"
        let params = [try! JSONDecoder().decode(EthSendTransaction.self, from: ethSendTransaction.data(using: .utf8)!)]
        let responseParams = "0x4355c47d63924e8a72e509b65029052eb6c299d53a04e167c5775fd466751c9d07299936d304c153f6443dfa05f40ff007d72911b6f72307f996231605b915621c"
        let permissions = Session.Permissions.stub(methods: [method])
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        _ = try! responder.client.pair(uri: uri)
        responder.onSessionProposal = {[unowned self]  proposal in
            self.responder.client.approve(proposal: proposal, accounts: [])
        }
        proposer.onSessionSettled = {[unowned self]  settledSession in
            let requestParams = Request(id: 0, topic: settledSession.topic, method: method, params: AnyCodable(params), chainId: nil)
            self.proposer.client.request(params: requestParams)
        }
        proposer.onSessionResponse = { response in
            switch response.result {
            case .response(let jsonRpcResponse):
                let response = try! jsonRpcResponse.result.get(String.self)
                XCTAssertEqual(response, responseParams)
                responseExpectation.fulfill()
            case .error(_):
                XCTFail()
            }
        }
        responder.onSessionRequest = {[unowned self]  sessionRequest in
            XCTAssertEqual(sessionRequest.method, method)
            let ethSendTrancastionParams = try! sessionRequest.params.get([EthSendTransaction].self)
            XCTAssertEqual(ethSendTrancastionParams, params)
            let jsonrpcResponse = JSONRPCResponse<AnyCodable>(id: sessionRequest.id, result: AnyCodable(responseParams))
            self.responder.client.respond(topic: sessionRequest.topic, response: .response(jsonrpcResponse))
            requestExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    
    func testSessionPayloadFailureResponse() {
        let failureResponseExpectation = expectation(description: "Proposer receives failure response")
        let method = "eth_sendTransaction"
        let params = [try! JSONDecoder().decode(EthSendTransaction.self, from: ethSendTransaction.data(using: .utf8)!)]
        let error = JSONRPCErrorResponse.Error(code: 0, message: "error_message")
        let permissions = Session.Permissions.stub(methods: [method])
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        _ = try! responder.client.pair(uri: uri)
        responder.onSessionProposal = {[unowned self]  proposal in
            self.responder.client.approve(proposal: proposal, accounts: [])
        }
        proposer.onSessionSettled = {[unowned self]  settledSession in
            let requestParams = Request(id: 0, topic: settledSession.topic, method: method, params: AnyCodable(params), chainId: nil)
            self.proposer.client.request(params: requestParams)
        }
        proposer.onSessionResponse = { response in
            switch response.result {
            case .response(_):
                XCTFail()
            case .error(let errorResponse):
                XCTAssertEqual(error, errorResponse.error)
                failureResponseExpectation.fulfill()
            }

        }
        responder.onSessionRequest = {[unowned self]  sessionRequest in
            let jsonrpcErrorResponse = JSONRPCErrorResponse(id: sessionRequest.id, error: error)
            self.responder.client.respond(topic: sessionRequest.topic, response: .error(jsonrpcErrorResponse))
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testPairingPing() {
        let proposerReceivesPingResponseExpectation = expectation(description: "Proposer receives ping response")
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        
        _ = try! responder.client.pair(uri: uri)
        proposer.onPairingSettled = { [unowned self] pairing in
            proposer.client.ping(topic: pairing.topic) { response in
                XCTAssertTrue(response.isSuccess)
                proposerReceivesPingResponseExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    
    func testSessionPing() {
        let proposerReceivesPingResponseExpectation = expectation(description: "Proposer receives ping response")
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        try! responder.client.pair(uri: uri)
        responder.onSessionProposal = { [unowned self] proposal in
            self.responder.client.approve(proposal: proposal, accounts: [])
        }
        proposer.onSessionSettled = { [unowned self] sessionSettled in
            self.proposer.client.ping(topic: sessionSettled.topic) { response in
                XCTAssertTrue(response.isSuccess)
                proposerReceivesPingResponseExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testSuccessfulSessionUpgrade() {
        let proposerSessionUpgradeExpectation = expectation(description: "Proposer upgrades session on responder request")
        let responderSessionUpgradeExpectation = expectation(description: "Responder upgrades session on proposer response")
        let account = Account("eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdb")!
        let permissions = Session.Permissions.stub()
        let upgradePermissions = Session.Permissions(blockchains: ["eip155:42"], methods: ["eth_sendTransaction"])
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        try! responder.client.pair(uri: uri)
        responder.onSessionProposal = { [unowned self] proposal in
            self.responder.client.approve(proposal: proposal, accounts: [account])
        }
        responder.onSessionSettled = { [unowned self] sessionSettled in
            try? responder.client.upgrade(topic: sessionSettled.topic, permissions: upgradePermissions)
        }
        proposer.onSessionUpgrade = { topic, permissions in
            XCTAssertTrue(permissions.blockchains.isSuperset(of: upgradePermissions.blockchains))
            XCTAssertTrue(permissions.methods.isSuperset(of: upgradePermissions.methods))
            proposerSessionUpgradeExpectation.fulfill()
        }
        responder.onSessionUpgrade = { topic, permissions in
            XCTAssertTrue(permissions.blockchains.isSuperset(of: upgradePermissions.blockchains))
            XCTAssertTrue(permissions.methods.isSuperset(of: upgradePermissions.methods))
            responderSessionUpgradeExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testSuccessfulSessionUpdate() {
        let proposerSessionUpdateExpectation = expectation(description: "Proposer updates session on responder request")
        let responderSessionUpdateExpectation = expectation(description: "Responder updates session on proposer response")
        let account = Account("eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdb")!
        let updateAccounts: Set<Account> = [Account("eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdf")!]
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        try! responder.client.pair(uri: uri)
        responder.onSessionProposal = { [unowned self] proposal in
            self.responder.client.approve(proposal: proposal, accounts: [account])
        }
        responder.onSessionSettled = { [unowned self] sessionSettled in
            try? responder.client.update(topic: sessionSettled.topic, accounts: updateAccounts)
        }
        responder.onSessionUpdate = { _, accounts in
            XCTAssertEqual(accounts, updateAccounts)
            responderSessionUpdateExpectation.fulfill()
        }
        proposer.onSessionUpdate = { _, accounts in
            XCTAssertEqual(accounts, updateAccounts)
            proposerSessionUpdateExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testSessionNotificationSucceeds() {
        let proposerReceivesNotificationExpectation = expectation(description: "Proposer receives notification")
        let permissions = Session.Permissions.stub(notifications: ["type1"])
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        try! responder.client.pair(uri: uri)
        let notificationParams = Session.Notification(type: "type1", data: AnyCodable("notification_data"))
        responder.onSessionProposal = { [unowned self] proposal in
            self.responder.client.approve(proposal: proposal, accounts: [])
        }
        responder.onSessionSettled = { [unowned self] session in
            responder.client.notify(topic: session.topic, params: notificationParams, completion: nil)
        }
        proposer.onNotificationReceived = { notification, _ in
            XCTAssertEqual(notification, notificationParams)
            proposerReceivesNotificationExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testSessionNotificationFails() {
        let proposerReceivesNotificationExpectation = expectation(description: "Proposer receives notification")
        proposerReceivesNotificationExpectation.isInverted = true
        let permissions = Session.Permissions.stub(notifications: ["type1"])
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        try! responder.client.pair(uri: uri)
        let notificationParams = Session.Notification(type: "type2", data: AnyCodable("notification_data"))
        responder.onSessionProposal = { [unowned self] proposal in
            self.responder.client.approve(proposal: proposal, accounts: [])
        }
        proposer.onSessionSettled = { [unowned self] session in
            proposer.client.notify(topic: session.topic, params: notificationParams) { error in
                XCTAssertNotNil(error)
            }
        }
        responder.onNotificationReceived = { notification, _ in
            XCTFail()
            proposerReceivesNotificationExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testPairingUpdate() {
        let proposerReceivesPairingUpdateExpectation = expectation(description: "Proposer receives pairing update")
        let permissions = Session.Permissions.stub()
        let uri = try! proposer.client.connect(sessionPermissions: permissions)!
        _ = try! responder.client.pair(uri: uri)
        proposer.onPairingUpdate = { _, appMetadata in
            XCTAssertNotNil(appMetadata)
            proposerReceivesPairingUpdateExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
}

public struct EthSendTransaction: Codable, Equatable {
    public let from: String
    public let data: String
    public let value: String
    public let to: String
    public let gasPrice: String
    public let nonce: String
}


fileprivate let ethSendTransaction = """
   {
      "from":"0xb60e8dd61c5d32be8058bb8eb970870f07233155",
      "to":"0xd46e8dd67c5d32be8058bb8eb970870f07244567",
      "data":"0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675",
      "gas":"0x76c0",
      "gasPrice":"0x9184e72a000",
      "value":"0x9184e72a",
      "nonce":"0x117"
   }
"""
