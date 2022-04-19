import UIKit
import WalletConnect
import WalletConnectUtils
import Web3
import CryptoSwift

final class ResponderViewController: UIViewController {

    let client: WalletConnectClient = {
        let metadata = AppMetadata(
            name: "Example Wallet",
            description: "wallet description",
            url: "example.wallet",
            icons: ["https://gblobscdn.gitbook.com/spaces%2F-LJJeCjcLrr53DcT1Ml7%2Favatar.png?alt=media"])
        return WalletConnectClient(
            metadata: metadata,
            projectId: "52af113ee0c1e1a20f4995730196c13e",
            relayHost: "relay.dev.walletconnect.com"
        )
    }()
    lazy  var account = Signer.privateKey.address.hex(eip55: true)
    var sessionItems: [ActiveSessionItem] = []
    var currentProposal: Session.Proposal?
    
    private let responderView: ResponderView = {
        ResponderView()
    }()
    
    override func loadView() {
        view = responderView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Wallet"
        responderView.scanButton.addTarget(self, action: #selector(showScanner), for: .touchUpInside)
        responderView.pasteButton.addTarget(self, action: #selector(showTextInput), for: .touchUpInside)
        
        responderView.tableView.dataSource = self
        responderView.tableView.delegate = self
        let settledSessions = client.getSettledSessions()
        sessionItems = getActiveSessionItem(for: settledSessions)
        client.delegate = self
        client.logger.setLogging(level: .debug)
    }
    
    @objc
    private func showScanner() {
        let scannerViewController = ScannerViewController()
        scannerViewController.delegate = self
        present(scannerViewController, animated: true)
    }
    
    @objc
    private func showTextInput() {
        let alert = UIAlertController.createInputAlert { [weak self] inputText in
            self?.pairClient(uri: inputText)
        }
        present(alert, animated: true)
    }
    
    private func showSessionProposal(_ info: SessionInfo) {
        let proposalViewController = SessionViewController()
        proposalViewController.delegate = self
        proposalViewController.show(info)
        present(proposalViewController, animated: true)
    }
    
    private func showSessionDetailsViewController(_ session: Session) {
        let vc = SessionDetailsViewController(session, client)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showSessionRequest(_ sessionRequest: Request) {
        let requestVC = RequestViewController(sessionRequest)
        requestVC.onSign = { [unowned self] in
            let result = Signer.signEth(request: sessionRequest)
            let response = JSONRPCResponse<AnyCodable>(id: sessionRequest.id, result: result)
            client.respond(topic: sessionRequest.topic, response: .response(response))
            reloadSessionDetailsIfNeeded()
        }
        requestVC.onReject = { [unowned self] in
            client.respond(topic: sessionRequest.topic, response: .error(JSONRPCErrorResponse(id: sessionRequest.id, error: JSONRPCErrorResponse.Error(code: 0, message: ""))))
            reloadSessionDetailsIfNeeded()
        }
        reloadSessionDetailsIfNeeded()
        present(requestVC, animated: true)
    }
    
    func reloadSessionDetailsIfNeeded() {
        if let sessionDetailsViewController = navigationController?.viewControllers.first(where: {$0 is SessionDetailsViewController}) as? SessionDetailsViewController {
            sessionDetailsViewController.reloadTable()
        }
    }
    
    private func pairClient(uri: String) {
        print("[RESPONDER] Pairing to: \(uri)")
        do {
            try client.pair(uri: uri)
        } catch {
            print("[PROPOSER] Pairing connect error: \(error)")
        }
    }
}

extension ResponderViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sessionItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sessionCell", for: indexPath) as! ActiveSessionCell
        cell.item = sessionItems[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let item = sessionItems[indexPath.row]
            client.disconnect(topic: item.topic, reason: Reason(code: 0, message: "disconnect"))
            sessionItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        "Disconnect"
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("did select row \(indexPath)")
        let itemTopic = sessionItems[indexPath.row].topic
        if let session = client.getSettledSessions().first{$0.topic == itemTopic} {
            showSessionDetailsViewController(session)
        }
    }
}

extension ResponderViewController: ScannerViewControllerDelegate {
    
    func didScan(_ code: String) {
        pairClient(uri: code)
    }
}

extension ResponderViewController: SessionViewControllerDelegate {
    
    func didApproveSession() {
        print("[RESPONDER] Approving session...")
        let proposal = currentProposal!
        currentProposal = nil
        let accounts = Set(proposal.permissions.blockchains.compactMap { Account($0+":\(account)") })
        client.approve(proposal: proposal, accounts: accounts)
    }
    
    func didRejectSession() {
        print("did reject session")
        let proposal = currentProposal!
        currentProposal = nil
        client.reject(proposal: proposal, reason: .disapprovedChains)
    }
}

extension ResponderViewController: WalletConnectClientDelegate {
    
    func didReceive(sessionProposal: Session.Proposal) {
        print("[RESPONDER] WC: Did receive session proposal")
        let appMetadata = sessionProposal.proposer
        let info = SessionInfo(
            name: appMetadata.name ?? "",
            descriptionText: appMetadata.description ?? "",
            dappURL: appMetadata.url ?? "",
            iconURL: appMetadata.icons?.first ?? "",
            chains: Array(sessionProposal.permissions.blockchains),
            methods: Array(sessionProposal.permissions.methods), pendingRequests: [])
        currentProposal = sessionProposal
        DispatchQueue.main.async { // FIXME: Delegate being called from background thread
            self.showSessionProposal(info)
        }
    }
    
    func didSettle(session: Session) {
        reloadActiveSessions()
    }
    
    func didReceive(sessionRequest: Request) {
        DispatchQueue.main.async { [weak self] in
            self?.showSessionRequest(sessionRequest)
        }
        print("[RESPONDER] WC: Did receive session request")
        
    }
    
    func didUpgrade(sessionTopic: String, permissions: Session.Permissions) {

    }

    func didUpdate(sessionTopic: String, accounts: Set<Account>) {

    }
    
    func didDelete(sessionTopic: String, reason: Reason) {
        reloadActiveSessions()
        DispatchQueue.main.async { [unowned self] in
            navigationController?.popToRootViewController(animated: true)
        }
    }
    
    private func getActiveSessionItem(for settledSessions: [Session]) -> [ActiveSessionItem] {
        return settledSessions.map { session -> ActiveSessionItem in
            let app = session.peer
            return ActiveSessionItem(
                dappName: app.name ?? "",
                dappURL: app.url ?? "",
                iconURL: app.icons?.first ?? "",
                topic: session.topic)
        }
    }
    
    private func reloadActiveSessions() {
        let settledSessions = client.getSettledSessions()
        let activeSessions = getActiveSessionItem(for: settledSessions)
        DispatchQueue.main.async { // FIXME: Delegate being called from background thread
            self.sessionItems = activeSessions
            self.responderView.tableView.reloadData()
        }
    }
}
