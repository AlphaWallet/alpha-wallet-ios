import Foundation
import WalletConnectKMS

struct SessionSequence: ExpirableSequence {
    
    let topic: String
    let relay: RelayProtocolOptions
    let selfParticipant: Participant
    let expiryDate: Date
    private var sequenceState: Either<Pending, Settled>
    
    var publicKey: String {
        selfParticipant.publicKey
    }
    
    func getPublicKey() throws -> AgreementPublicKey {
        try AgreementPublicKey(rawRepresentation: Data(hex: selfParticipant.publicKey))
    }
    
    var pending: Pending? {
        get {
            sequenceState.left
        }
        set {
            if let pending = newValue {
                sequenceState = .left(pending)
            }
        }
    }
    
    var settled: Settled? {
        get {
            sequenceState.right
        }
        set {
            if let settled = newValue {
                sequenceState = .right(settled)
            }
        }
    }
    
    var isSettled: Bool {
        settled?.status == .acknowledged
    }
    
    var selfIsController: Bool {
        guard let controller = settled?.permissions.controller else { return false }
        return selfParticipant.publicKey == controller.publicKey
    }
    
    var peerIsController: Bool {
        isSettled && settled?.peer.publicKey == settled?.permissions.controller?.publicKey
    }
    
    static var timeToLiveProposed: Int {
        Time.hour
    }
    
    static var timeToLivePending: Int {
        Time.day
    }
    
    static var timeToLiveSettled: Int {
        Time.day * 7
    }
    
    func hasPermission(forChain chainId: String) -> Bool {
        guard let settled = settled else { return false }
        return settled.permissions.blockchain.chains.contains(chainId)
    }
    
    func hasPermission(forMethod method: String) -> Bool {
        guard let settled = settled else { return false }
        return settled.permissions.jsonrpc.methods.contains(method)
    }
    
    func hasPermission(forNotification type: String) -> Bool {
        guard let notificationPermissions = settled?.permissions.notifications else { return false }
        return notificationPermissions.types.contains(type)
    }
    
    mutating func upgrade(_ permissions: SessionPermissions) {
        settled?.permissions.upgrade(with: permissions)
    }
    
    mutating func update(_ accounts: Set<String>) {
        settled?.state.accounts = accounts
    }
}

extension SessionSequence {
    
    struct Pending: Codable {
        let status: Status
        let proposal: SessionProposal
        let outcomeTopic: String?
        
        enum Status: Codable {
            case proposed
            case responded
        }
    }
    
    struct Settled: Codable {
        let peer: Participant
        var permissions: SessionPermissions
        var state: SessionState
        var status: Status
        
        enum Status: Codable {
            case preSettled
            case acknowledged
        }
    }
}

// MARK: - Initialization

extension SessionSequence {
    
    init(topic: String, relay: RelayProtocolOptions, selfParticipant: Participant, expiryDate: Date, pendingState: Pending) {
        self.init(topic: topic, relay: relay, selfParticipant: selfParticipant, expiryDate: expiryDate, sequenceState: .left(pendingState))
    }
    
    init(topic: String, relay: RelayProtocolOptions, selfParticipant: Participant, expiryDate: Date, settledState: Settled) {
        self.init(topic: topic, relay: relay, selfParticipant: selfParticipant, expiryDate: expiryDate, sequenceState: .right(settledState))
    }
    
    static func buildProposed(proposal: SessionProposal) -> SessionSequence {
        SessionSequence(
            topic: proposal.topic,
            relay: proposal.relay,
            selfParticipant: Participant(publicKey: proposal.proposer.publicKey, metadata: proposal.proposer.metadata),
            expiryDate: Date(timeIntervalSinceNow: TimeInterval(timeToLiveProposed)),
            pendingState: Pending(
                status: .proposed,
                proposal: proposal,
                outcomeTopic: nil
            )
        )
    }
    
    static func buildResponded(proposal: SessionProposal, agreementKeys: AgreementSecret, metadata: AppMetadata) -> SessionSequence {
        SessionSequence(
            topic: proposal.topic,
            relay: proposal.relay,
            selfParticipant: Participant(publicKey: agreementKeys.publicKey.hexRepresentation, metadata: metadata),
            expiryDate: Date(timeIntervalSinceNow: TimeInterval(Time.day)),
            pendingState: Pending(
                status: .responded,
                proposal: proposal,
                outcomeTopic: agreementKeys.derivedTopic()
            )
        )
    }
    
    static func buildPreSettled(proposal: SessionProposal, agreementKeys: AgreementSecret, metadata: AppMetadata, accounts: Set<String>) -> SessionSequence {
        let controllerKey = proposal.proposer.controller ? proposal.proposer.publicKey : agreementKeys.publicKey.hexRepresentation
        return SessionSequence(
            topic: agreementKeys.derivedTopic(),
            relay: proposal.relay,
            selfParticipant: Participant(publicKey: agreementKeys.publicKey.hexRepresentation, metadata: metadata),
            expiryDate: Date(timeIntervalSinceNow: TimeInterval(proposal.ttl)),
            settledState: Settled(
                peer: Participant(publicKey: proposal.proposer.publicKey, metadata: proposal.proposer.metadata),
                permissions: SessionPermissions(
                    blockchain: proposal.permissions.blockchain,
                    jsonrpc: proposal.permissions.jsonrpc,
                    notifications: proposal.permissions.notifications,
                    controller: Controller(publicKey: controllerKey)),
                state: SessionState(accounts: accounts),
                status: .acknowledged
            )
        )
    }
    
    static func buildAcknowledged(approval approveParams: SessionType.ApproveParams, proposal: SessionProposal, agreementKeys: AgreementSecret, metadata: AppMetadata) -> SessionSequence {
        let controllerKey = proposal.proposer.controller ? proposal.proposer.publicKey : approveParams.responder.publicKey
        return SessionSequence(
            topic: agreementKeys.derivedTopic(),
            relay: approveParams.relay,
            selfParticipant: Participant(publicKey: agreementKeys.publicKey.hexRepresentation, metadata: metadata),
            expiryDate: Date(timeIntervalSince1970: TimeInterval(approveParams.expiry)),
            settledState: Settled(
                peer: Participant(publicKey: approveParams.responder.publicKey, metadata: approveParams.responder.metadata),
                permissions: SessionPermissions(
                    blockchain: proposal.permissions.blockchain,
                    jsonrpc: proposal.permissions.jsonrpc,
                    notifications: proposal.permissions.notifications,
                    controller: Controller(publicKey: controllerKey)),
                state: approveParams.state,
                status: .acknowledged
            )
        )
    }
}
