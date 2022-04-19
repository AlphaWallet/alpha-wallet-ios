import Foundation
import Combine
import WalletConnectUtils
import WalletConnectKMS

final class SessionEngine {
    var onSessionPayloadRequest: ((Request)->())?
    var onSessionPayloadResponse: ((Response)->())?
    var onSessionApproved: ((Session)->())?
    var onApprovalAcknowledgement: ((Session) -> Void)?
    var onSessionRejected: ((String, SessionType.Reason)->())?
    var onSessionUpdate: ((String, Set<String>)->())?
    var onSessionUpgrade: ((String, SessionPermissions)->())?
    var onSessionDelete: ((String, SessionType.Reason)->())?
    var onNotificationReceived: ((String, Session.Notification)->())?
    
    private let sequencesStore: SessionSequenceStorage
    private let wcSubscriber: WCSubscribing
    private let relayer: WalletConnectRelaying
    private let kms: KeyManagementServiceProtocol
    private var metadata: AppMetadata
    private var publishers = [AnyCancellable]()
    private let logger: ConsoleLogging
    private let topicInitializer: () -> String?

    init(relay: WalletConnectRelaying,
         kms: KeyManagementServiceProtocol,
         subscriber: WCSubscribing,
         sequencesStore: SessionSequenceStorage,
         metadata: AppMetadata,
         logger: ConsoleLogging,
         topicGenerator: @escaping () -> String? = String.generateTopic) {
        self.relayer = relay
        self.kms = kms
        self.metadata = metadata
        self.wcSubscriber = subscriber
        self.sequencesStore = sequencesStore
        self.logger = logger
        self.topicInitializer = topicGenerator
        setUpWCRequestHandling()
        setupExpirationHandling()
        restoreSubscriptions()
        
        relayer.onResponse = { [weak self] in
            self?.handleResponse($0)
        }
    }
    
    func hasSession(for topic: String) -> Bool {
        return sequencesStore.hasSequence(forTopic: topic)
    }
    
    func getSettledSessions() -> [Session] {
        sequencesStore.getAll().compactMap {
            guard let settled = $0.settled else { return nil }
            let permissions = Session.Permissions(blockchains: settled.permissions.blockchain.chains, methods: settled.permissions.jsonrpc.methods)
            return Session(topic: $0.topic, peer: settled.peer.metadata!, permissions: permissions, accounts: settled.state.accounts)
        }
    }
    
    func proposeSession(settledPairing: Pairing, permissions: SessionPermissions, relay: RelayProtocolOptions) {
        guard let pendingSessionTopic = topicInitializer() else {
            logger.debug("Could not generate topic")
            return
        }
        logger.debug("Propose Session on topic: \(pendingSessionTopic)")
        
        let publicKey = try! kms.createX25519KeyPair()
        
        let proposal = SessionProposal(
            topic: pendingSessionTopic,
            relay: relay,
            proposer: SessionType.Proposer(publicKey: publicKey.hexRepresentation, controller: false, metadata: metadata),
            signal: SessionType.Signal(method: "pairing", params: SessionType.Signal.Params(topic: settledPairing.topic)),
            permissions: permissions,
            ttl: SessionSequence.timeToLivePending)
        
        let pendingSession = SessionSequence.buildProposed(proposal: proposal)
        
        sequencesStore.setSequence(pendingSession)
        wcSubscriber.setSubscription(topic: pendingSessionTopic)
        let pairingAgreementSecret = try! kms.getAgreementSecret(for: settledPairing.topic)!
        try! kms.setAgreementSecret(pairingAgreementSecret, topic: proposal.topic)
        
        let request = PairingType.PayloadParams.Request(method: .sessionPropose, params: proposal)
        let pairingPayloadParams = PairingType.PayloadParams(request: request)
        relayer.request(.wcPairingPayload(pairingPayloadParams), onTopic: settledPairing.topic) { [unowned self] result in
            switch result {
            case .success:
                logger.debug("Session Proposal response received")
            case .failure(let error):
                logger.debug("Could not send session proposal error: \(error)")
            }
        }
    }
    
    // TODO: Check matching controller
    func approve(proposal: SessionProposal, accounts: Set<String>) {
        logger.debug("Approve session")
        
        let selfPublicKey = try! kms.createX25519KeyPair()
        let agreementKeys = try! kms.performKeyAgreement(selfPublicKey: selfPublicKey, peerPublicKey: proposal.proposer.publicKey)
        
        let settledTopic = agreementKeys.derivedTopic()
        let pendingSession = SessionSequence.buildResponded(proposal: proposal, agreementKeys: agreementKeys, metadata: metadata)
        let settledSession = SessionSequence.buildPreSettled(proposal: proposal, agreementKeys: agreementKeys, metadata: metadata, accounts: accounts)
        
        let approval = SessionType.ApproveParams(
            relay: proposal.relay,
            responder: SessionParticipant(
                publicKey: selfPublicKey.hexRepresentation,
                metadata: metadata),
            expiry: Int(Date().timeIntervalSince1970) + proposal.ttl,
            state: SessionState(accounts: accounts))
        
        sequencesStore.setSequence(pendingSession)
        wcSubscriber.setSubscription(topic: proposal.topic)
        
        try! kms.setAgreementSecret(agreementKeys, topic: settledTopic)
        sequencesStore.setSequence(settledSession)
        wcSubscriber.setSubscription(topic: settledTopic)
        
        relayer.request(.wcSessionApprove(approval), onTopic: proposal.topic) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Success on wc_sessionApprove, published on topic: \(proposal.topic), settled topic: \(settledTopic)")
            case .failure(let error):
                self?.logger.error(error)
            }
        }
    }
    
    func reject(proposal: SessionProposal, reason: SessionType.Reason ) {
        let rejectParams = SessionType.RejectParams(reason: reason)
        relayer.request(.wcSessionReject(rejectParams), onTopic: proposal.topic) { [weak self] result in
            self?.logger.debug("Reject result: \(result)")
        }
    }
    
    func delete(topic: String, reason: Reason) {
        logger.debug("Will delete session for reason: message: \(reason.message) code: \(reason.code)")
        sequencesStore.delete(topic: topic)
        wcSubscriber.removeSubscription(topic: topic)
        relayer.request(.wcSessionDelete(SessionType.DeleteParams(reason: reason.toInternal())), onTopic: topic) { [weak self] result in
            self?.logger.debug("Session Delete result: \(result)")
        }
    }
    
    func ping(topic: String, completion: @escaping ((Result<Void, Error>) -> ())) {
        guard sequencesStore.hasSequence(forTopic: topic) else {
            logger.debug("Could not find session to ping for topic \(topic)")
            return
        }
        relayer.request(.wcSessionPing, onTopic: topic) { [unowned self] result in
            switch result {
            case .success(_):
                logger.debug("Did receive ping response")
                completion(.success(()))
            case .failure(let error):
                logger.debug("error: \(error)")
            }
        }
    }
    
    func request(params: Request) {
        guard sequencesStore.hasSequence(forTopic: params.topic) else {
            logger.debug("Could not find session for topic \(params.topic)")
            return
        }
        let request = SessionType.PayloadParams.Request(method: params.method, params: params.params)
        let sessionPayloadParams = SessionType.PayloadParams(request: request, chainId: params.chainId)
        let sessionPayloadRequest = WCRequest(id: params.id, method: .sessionPayload, params: .sessionPayload(sessionPayloadParams))
        relayer.request(topic: params.topic, payload: sessionPayloadRequest) { [weak self] result in
            switch result {
            case .success(_):
                self?.logger.debug("Did receive session payload response")
            case .failure(let error):
                self?.logger.debug("error: \(error)")
            }
        }
    }
    
    func respondSessionPayload(topic: String, response: JsonRpcResult) {
        guard sequencesStore.hasSequence(forTopic: topic) else {
            logger.debug("Could not find session for topic \(topic)")
            return
        }
        relayer.respond(topic: topic, response: response) { [weak self] error in
            if let error = error {
                self?.logger.debug("Could not send session payload, error: \(error.localizedDescription)")
            } else {
                self?.logger.debug("Sent Session Payload Response")
            }
        }
    }
    
    func update(topic: String, accounts: Set<String>) throws {
        guard var session = sequencesStore.getSequence(forTopic: topic) else {
            throw WalletConnectError.internal(.noSequenceForTopic)
        }
        for account in accounts {
            if !String.conformsToCAIP10(account) {
                throw WalletConnectError.internal(.notApproved) // TODO: Use a suitable error cases
            }
        }
        if !session.selfIsController || session.settled?.status != .acknowledged {
            throw WalletConnectError.unauthrorized(.unauthorizedUpdateRequest)
        }
        session.update(accounts)
        sequencesStore.setSequence(session)
        relayer.request(.wcSessionUpdate(SessionType.UpdateParams(accounts: accounts)), onTopic: topic)
    }
    
    func upgrade(topic: String, permissions: Session.Permissions) throws {
        let permissions = SessionPermissions(permissions: permissions)
        guard var session = sequencesStore.getSequence(forTopic: topic) else {
            throw WalletConnectError.noSessionMatchingTopic(topic)
        }
        guard session.isSettled else {
            throw WalletConnectError.sessionNotSettled(topic)
        }
        guard session.selfIsController else {
            throw WalletConnectError.unauthorizedNonControllerCall
        }
        guard validatePermissions(permissions) else {
            throw WalletConnectError.invalidPermissions
        }
        session.upgrade(permissions)
        let newPermissions = session.settled!.permissions // We know session is settled
        sequencesStore.setSequence(session)
        relayer.request(.wcSessionUpgrade(SessionType.UpgradeParams(permissions: newPermissions)), onTopic: topic)
    }
    
    func notify(topic: String, params: Session.Notification, completion: ((Error?)->())?) {
        guard let session = sequencesStore.getSequence(forTopic: topic), session.isSettled else {
            logger.debug("Could not find session for topic \(topic)")
            return
        }
        do {
            let params = SessionType.NotificationParams(type: params.type, data: params.data)
            try validateNotification(session: session, params: params)
            relayer.request(.wcSessionNotification(params), onTopic: topic) { result in
                switch result {
                case .success(_):
                    completion?(nil)
                case .failure(let error):
                    completion?(error)
                }
            }
        } catch let error as WalletConnectError {
            logger.error(error)
            completion?(error)
        } catch {}
    }

    //MARK: - Private
    
    private func setUpWCRequestHandling() {
        wcSubscriber.onReceivePayload = { [unowned self] subscriptionPayload in
            switch subscriptionPayload.wcRequest.params {
            case .sessionApprove(let approveParams):
                wcSessionApprove(subscriptionPayload, approveParams: approveParams)
            case .sessionReject(let rejectParams):
                wcSessionReject(subscriptionPayload, rejectParams: rejectParams)
            case .sessionUpdate(let updateParams):
                wcSessionUpdate(payload: subscriptionPayload, updateParams: updateParams)
            case .sessionUpgrade(let upgradeParams):
                wcSessionUpgrade(payload: subscriptionPayload, upgradeParams: upgradeParams)
            case .sessionDelete(let deleteParams):
                wcSessionDelete(subscriptionPayload, deleteParams: deleteParams)
            case .sessionPayload(let sessionPayloadParams):
                wcSessionPayload(subscriptionPayload, payloadParams: sessionPayloadParams)
            case .sessionPing(_):
                wcSessionPing(subscriptionPayload)
            case .sessionNotification(let notificationParams):
                wcSessionNotification(subscriptionPayload, notificationParams: notificationParams)
            default:
                logger.warn("Warning: Session Engine - Unexpected method type: \(subscriptionPayload.wcRequest.method) received from subscriber")
            }
        }
    }
    
    private func wcSessionApprove(_ payload: WCRequestSubscriptionPayload, approveParams: SessionType.ApproveParams) {
        let topic = payload.topic
        guard let session = sequencesStore.getSequence(forTopic: topic), let pendingSession = session.pending else {
            relayer.respondError(for: payload, reason: .noContextWithTopic(context: .session, topic: topic))
            return
        }
        guard !session.selfIsController else {
            // TODO: Replace generic reason with a valid code.
            relayer.respondError(for: payload, reason: .generic(message: "wcSessionApproval received by a controller"))
            return
        }
        
        let settledTopic: String
        let agreementKeys: AgreementSecret
        do {
            let publicKey = try session.getPublicKey()
            agreementKeys = try kms.performKeyAgreement(selfPublicKey: publicKey, peerPublicKey: approveParams.responder.publicKey)
            settledTopic = agreementKeys.derivedTopic()
            try kms.setAgreementSecret(agreementKeys, topic: settledTopic)
        } catch {
            relayer.respondError(for: payload, reason: .missingOrInvalid("agreement keys"))
            return
        }

        let proposal = pendingSession.proposal
        let settledSession = SessionSequence.buildAcknowledged(approval: approveParams, proposal: proposal, agreementKeys: agreementKeys, metadata: metadata)
        sequencesStore.delete(topic: proposal.topic)
        sequencesStore.setSequence(settledSession)
        wcSubscriber.setSubscription(topic: settledTopic)
        wcSubscriber.removeSubscription(topic: proposal.topic)
        
        let approvedSession = Session(
            topic: settledTopic,
            peer: approveParams.responder.metadata,
            permissions: Session.Permissions(
                blockchains: pendingSession.proposal.permissions.blockchain.chains,
                methods: pendingSession.proposal.permissions.jsonrpc.methods), accounts: settledSession.settled!.state.accounts)
        
        logger.debug("Responder Client approved session on topic: \(topic)")
        relayer.respondSuccess(for: payload)
        onSessionApproved?(approvedSession)
    }
    
    private func wcSessionReject(_ payload: WCRequestSubscriptionPayload, rejectParams: SessionType.RejectParams) {
        let topic = payload.topic
        guard sequencesStore.hasSequence(forTopic: topic) else {
            relayer.respondError(for: payload, reason: .noContextWithTopic(context: .session, topic: topic))
            return
        }
        sequencesStore.delete(topic: topic)
        wcSubscriber.removeSubscription(topic: topic)
        relayer.respondSuccess(for: payload)
        onSessionRejected?(topic, rejectParams.reason)
    }
    
    private func wcSessionUpdate(payload: WCRequestSubscriptionPayload, updateParams: SessionType.UpdateParams) {
        for account in updateParams.state.accounts {
            if !String.conformsToCAIP10(account) {
                relayer.respondError(for: payload, reason: .invalidUpdateRequest(context: .session))
                return
            }
        }
        let topic = payload.topic
        guard var session = sequencesStore.getSequence(forTopic: topic) else {
            relayer.respondError(for: payload, reason: .noContextWithTopic(context: .session, topic: topic))
            return
        }
        guard session.peerIsController else {
            relayer.respondError(for: payload, reason: .unauthorizedUpdateRequest(context: .session))
            return
        }
        session.settled?.state = updateParams.state
        sequencesStore.setSequence(session)
        relayer.respondSuccess(for: payload)
        onSessionUpdate?(topic, updateParams.state.accounts)
    }
    
    private func wcSessionUpgrade(payload: WCRequestSubscriptionPayload, upgradeParams: SessionType.UpgradeParams) {
        guard validatePermissions(upgradeParams.permissions) else {
            relayer.respondError(for: payload, reason: .invalidUpgradeRequest(context: .session))
            return
        }
        guard var session = sequencesStore.getSequence(forTopic: payload.topic) else {
            relayer.respondError(for: payload, reason: .noContextWithTopic(context: .session, topic: payload.topic))
            return
        }
        guard session.peerIsController else {
            relayer.respondError(for: payload, reason: .unauthorizedUpgradeRequest(context: .session))
            return
        }
        session.upgrade(upgradeParams.permissions)
        sequencesStore.setSequence(session)
        let newPermissions = session.settled!.permissions // We know session is settled
        relayer.respondSuccess(for: payload)
        onSessionUpgrade?(session.topic, newPermissions)
    }
    
    private func wcSessionDelete(_ payload: WCRequestSubscriptionPayload, deleteParams: SessionType.DeleteParams) {
        let topic = payload.topic
        guard sequencesStore.hasSequence(forTopic: topic) else {
            relayer.respondError(for: payload, reason: .noContextWithTopic(context: .session, topic: topic))
            return
        }
        sequencesStore.delete(topic: topic)
        wcSubscriber.removeSubscription(topic: topic)
        relayer.respondSuccess(for: payload)
        onSessionDelete?(topic, deleteParams.reason)
    }
    
    private func wcSessionPayload(_ payload: WCRequestSubscriptionPayload, payloadParams: SessionType.PayloadParams) {
        let topic = payload.topic
        let jsonRpcRequest = JSONRPCRequest<AnyCodable>(id: payload.wcRequest.id, method: payloadParams.request.method, params: payloadParams.request.params)
        let request = Request(
            id: jsonRpcRequest.id,
            topic: topic,
            method: jsonRpcRequest.method,
            params: jsonRpcRequest.params,
            chainId: payloadParams.chainId)
        
        guard let session = sequencesStore.getSequence(forTopic: topic) else {
            relayer.respondError(for: payload, reason: .noContextWithTopic(context: .session, topic: topic))
            return
        }
        if let chainId = request.chainId {
            guard session.hasPermission(forChain: chainId) else {
                relayer.respondError(for: payload, reason: .unauthorizedTargetChain(chainId))
                return
            }
        }
        guard session.hasPermission(forMethod: request.method) else {
            relayer.respondError(for: payload, reason: .unauthorizedRPCMethod(request.method))
            return
        }
        onSessionPayloadRequest?(request)
    }
    
    private func wcSessionPing(_ payload: WCRequestSubscriptionPayload) {
        relayer.respondSuccess(for: payload)
    }
    
    private func wcSessionNotification(_ payload: WCRequestSubscriptionPayload, notificationParams: SessionType.NotificationParams) {
        let topic = payload.topic
        guard let session = sequencesStore.getSequence(forTopic: topic), session.isSettled else {
            relayer.respondError(for: payload, reason: .noContextWithTopic(context: .session, topic: payload.topic))
            return
        }
        if session.selfIsController {
            guard session.hasPermission(forNotification: notificationParams.type) else {
                relayer.respondError(for: payload, reason: .unauthorizedNotificationType(notificationParams.type))
                return
            }
        }
        let notification = Session.Notification(type: notificationParams.type, data: notificationParams.data)
        relayer.respondSuccess(for: payload)
        onNotificationReceived?(topic, notification)
    }
    
    private func validateNotification(session: SessionSequence, params: SessionType.NotificationParams) throws {
        if session.selfIsController {
            return
        } else {
            guard let notifications = session.settled?.permissions.notifications,
                  notifications.types.contains(params.type) else {
                throw WalletConnectError.unauthrorized(.unauthorizedNotificationType)
            }
        }
    }
    
    private func setupExpirationHandling() {
        sequencesStore.onSequenceExpiration = { [weak self] topic, publicKey in
            self?.kms.deletePrivateKey(for: publicKey)
            self?.kms.deleteAgreementSecret(for: topic)
        }
    }
    
    private func restoreSubscriptions() {
        relayer.transportConnectionPublisher
            .sink { [unowned self] (_) in
                let topics = sequencesStore.getAll().map{$0.topic}
                topics.forEach{self.wcSubscriber.setSubscription(topic: $0)}
            }.store(in: &publishers)
    }
    
    private func handleResponse(_ response: WCResponse) {
        switch response.requestParams {
        case .pairingPayload(let payloadParams):
            let proposeParams = payloadParams.request.params
            handleProposeResponse(topic: response.topic, proposeParams: proposeParams, result: response.result)
        case .sessionApprove(_):
            handleApproveResponse(topic: response.topic, result: response.result)
        case .sessionUpdate:
            handleUpdateResponse(topic: response.topic, result: response.result)
        case .sessionUpgrade:
            handleUpgradeResponse(topic: response.topic, result: response.result)
        case .sessionPayload(_):
            let response = Response(topic: response.topic, chainId: response.chainId, result: response.result)
            onSessionPayloadResponse?(response)
        default:
            break
        }
    }
    
    private func handleProposeResponse(topic: String, proposeParams: SessionProposal, result: JsonRpcResult) {
        switch result {
        case .response:
            break
        case .error:
            wcSubscriber.removeSubscription(topic: proposeParams.topic)
            kms.deletePrivateKey(for: proposeParams.proposer.publicKey)
            kms.deleteAgreementSecret(for: topic)
            sequencesStore.delete(topic: proposeParams.topic)
        }
    }
    
    private func handleApproveResponse(topic: String, result: JsonRpcResult) {
        guard
            let pendingSession = sequencesStore.getSequence(forTopic: topic),
            let settledTopic = pendingSession.pending?.outcomeTopic,
            let proposal = pendingSession.pending?.proposal
        else {
            return
        }
        switch result {
        case .response:
            guard let settledSession = sequencesStore.getSequence(forTopic: settledTopic) else {return}
            kms.deleteAgreementSecret(for: topic)
            wcSubscriber.removeSubscription(topic: topic)
            sequencesStore.delete(topic: topic)
            let sessionSuccess = Session(
                topic: settledTopic,
                peer: proposal.proposer.metadata,
                permissions: Session.Permissions(
                    blockchains: proposal.permissions.blockchain.chains,
                    methods: proposal.permissions.jsonrpc.methods), accounts: settledSession.settled!.state.accounts)
            onApprovalAcknowledgement?(sessionSuccess)
        case .error:
            wcSubscriber.removeSubscription(topic: topic)
            wcSubscriber.removeSubscription(topic: settledTopic)
            sequencesStore.delete(topic: topic)
            sequencesStore.delete(topic: settledTopic)
            kms.deleteAgreementSecret(for: topic)
            kms.deleteAgreementSecret(for: settledTopic)
            kms.deletePrivateKey(for: pendingSession.publicKey)
        }
    }
    
    private func handleUpdateResponse(topic: String, result: JsonRpcResult) {
        guard let session = sequencesStore.getSequence(forTopic: topic), let accounts = session.settled?.state.accounts else {
            return
        }
        switch result {
        case .response:
            onSessionUpdate?(topic, accounts)
        case .error:
            logger.error("Peer failed to update state.")
        }
    }
    
    private func handleUpgradeResponse(topic: String, result: JsonRpcResult) {
        guard let session = sequencesStore.getSequence(forTopic: topic), let permissions = session.settled?.permissions else {
            return
        }
        switch result {
        case .response:
            onSessionUpgrade?(session.topic, permissions)
        case .error:
            logger.error("Peer failed to upgrade permissions.")
        }
    }
    
    private func validatePermissions(_ permissions: SessionPermissions) -> Bool {
        for chainId in permissions.blockchain.chains {
            if !String.conformsToCAIP2(chainId) {
                return false
            }
        }
        for method in permissions.jsonrpc.methods {
            if method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }
        if let notificationTypes = permissions.notifications?.types {
            for notification in notificationTypes {
                if notification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return false
                }
            }
        }
        return true
    }
}
