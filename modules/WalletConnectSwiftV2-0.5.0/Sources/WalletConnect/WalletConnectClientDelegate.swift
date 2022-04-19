
import Foundation

/// A protocol that defines methods that WalletConnectClient instance call on it's delegate to handle sequences level events
public protocol WalletConnectClientDelegate: AnyObject {
    
    /// Tells the delegate that session proposal has been received.
    ///
    /// Function is executed on responder client only
    func didReceive(sessionProposal: Session.Proposal)
    
    /// Tells the delegate that session payload request has been received
    ///
    /// In most cases that function is supposed to be called on wallet client.
    /// - Parameters:
    ///     - sessionRequest: Object containing request received from peer client.
    func didReceive(sessionRequest: Request)
    
    /// Tells the delegate that session payload response has been received
    ///
    /// In most cases that function is supposed to be called on dApp client.
    /// - Parameters:
    ///     - sessionResponse: Object containing response received from peer client.
    func didReceive(sessionResponse: Response)
    
    /// Tells the delegate that the peer client has terminated the session.
    ///
    /// Function can be executed on any type of the client.
    func didDelete(sessionTopic: String, reason: Reason)
    
    /// Tells the delegate that session permissions has been upgraded.
    ///
    /// Function is executed on controller and non-controller client when both communicating peers have successfully upgraded permissions.
    func didUpgrade(sessionTopic: String, permissions: Session.Permissions)
    
    /// Tells the delegate that extra accounts has been included in session sequence
    ///
    /// Function is executed on controller and non-controller client when both communicating peers have successfully included new accounts requested by the controller client.
    func didUpdate(sessionTopic: String, accounts: Set<Account>)
    
    /// Tells the delegate that the client has settled a session.
    ///
    /// Function is executed on proposer and responder client when both communicating peers have successfully established a session.
    func didSettle(session: Session)
    
    /// Tells the delegate that the client has settled a pairing.
    ///
    /// Function is executed on proposer and responder client when both communicating peers have successfully established a pairing.
    func didSettle(pairing: Pairing)
    
    /// Tells the delegate that notification has been received.
    func didReceive(notification: Session.Notification, sessionTopic : String)
    
    /// Tells the delegate that peer client has rejected a session proposal.
    ///
    /// Function will be executed on proposer client only.
    func didReject(pendingSessionTopic: String, reason: Reason)
    
    /// Tells the delegate that peer has updated metadata for pairing.
    ///
    /// Function will be executed on proposer client only.
    func didUpdate(pairingTopic: String, appMetadata: AppMetadata)
}

public extension WalletConnectClientDelegate {
    func didSettle(pairing: Pairing) {}
    func didReceive(notification: Session.Notification, sessionTopic: String) {}
    func didReject(pendingSessionTopic: String, reason: Reason) {}
    func didUpdate(pairingTopic: String, appMetadata: AppMetadata) {}
    func didReceive(sessionRequest: Request) {}
    func didReceive(sessionProposal: Session.Proposal) {}
    func didReceive(sessionResponse: Response) {}
}
