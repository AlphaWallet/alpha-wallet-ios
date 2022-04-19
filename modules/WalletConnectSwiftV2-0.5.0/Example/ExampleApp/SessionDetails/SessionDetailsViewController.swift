import UIKit
import WalletConnect
import WalletConnectUtils

final class SessionDetailsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let sessiondetailsView = {
        SessionDetailsView()
    }()
    private var sessionInfo: SessionInfo
    private let client: WalletConnectClient
    private let session: Session
    init(_ session: Session, _ client: WalletConnectClient) {
        let pendingRequests = client.getPendingRequests(topic: session.topic).map{$0.method}
        self.sessionInfo = SessionInfo(name: session.peer.name ?? "",
                                       descriptionText: session.peer.description ?? "",
                                       dappURL: session.peer.description ?? "",
                                       iconURL: session.peer.icons?.first ?? "",
                                       chains: Array(session.permissions.blockchains),
                                       methods: Array(session.permissions.methods),
                                       pendingRequests: pendingRequests)
        self.client = client
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        show(sessionInfo)
        super.viewDidLoad()
        sessiondetailsView.pingButton.addTarget(self, action: #selector(ping), for: .touchUpInside)
        sessiondetailsView.tableView.delegate = self
        sessiondetailsView.tableView.dataSource = self
        sessiondetailsView.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    override func loadView() {
        view = sessiondetailsView
    }

    private func show(_ sessionInfo: SessionInfo) {
        sessiondetailsView.nameLabel.text = sessionInfo.name
        sessiondetailsView.descriptionLabel.text = sessionInfo.descriptionText
        sessiondetailsView.urlLabel.text = sessionInfo.dappURL
        sessiondetailsView.loadImage(at: sessionInfo.iconURL)
    }
    
    @objc
    private func ping() {
        client.ping(topic: session.topic) { result in
            switch result {
            case .success():
                print("received ping response")
            case .failure(let error):
                print(error)
            }
        }
    }
    
    //MARK: - Table View
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return sessionInfo.chains.count
        } else if section == 1 {
            return sessionInfo.methods.count
        } else {
            return sessionInfo.pendingRequests.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if indexPath.section == 0 {
            cell.textLabel?.text = sessionInfo.chains[indexPath.row]
        } else if indexPath.section == 1 {
            cell.textLabel?.text = sessionInfo.methods[indexPath.row]
        } else {
            cell.textLabel?.text = sessionInfo.pendingRequests[indexPath.row]
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Chains"
        } else if section == 1 {
            return "Methods"
        } else {
            return "Pending Requests"
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2 {
            let pendingRequests = client.getPendingRequests(topic: session.topic)
            showSessionRequest(pendingRequests[indexPath.row])
        }
    }
    
    private func showSessionRequest(_ sessionRequest: Request) {
        let requestVC = RequestViewController(sessionRequest)
        requestVC.onSign = { [unowned self] in
            let result = Signer.signEth(request: sessionRequest)
            let response = JSONRPCResponse<AnyCodable>(id: sessionRequest.id, result: result)
            client.respond(topic: sessionRequest.topic, response: .response(response))
            reloadTable()
        }
        requestVC.onReject = { [unowned self] in
            client.respond(topic: sessionRequest.topic, response: .error(JSONRPCErrorResponse(id: sessionRequest.id, error: JSONRPCErrorResponse.Error(code: 0, message: ""))))
            reloadTable()
        }
        present(requestVC, animated: true)
    }
    
    func reloadTable() {
        let pendingRequests = client.getPendingRequests(topic: session.topic).map{$0.method}
        self.sessionInfo = SessionInfo(name: session.peer.name ?? "",
                                       descriptionText: session.peer.description ?? "",
                                       dappURL: session.peer.description ?? "",
                                       iconURL: session.peer.icons?.first ?? "",
                                       chains: Array(session.permissions.blockchains),
                                       methods: Array(session.permissions.methods),
                                       pendingRequests: pendingRequests)
        sessiondetailsView.tableView.reloadData()
    }
}
