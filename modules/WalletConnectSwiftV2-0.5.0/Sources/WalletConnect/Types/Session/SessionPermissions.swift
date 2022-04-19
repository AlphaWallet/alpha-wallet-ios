struct SessionPermissions: Codable, Equatable {
    
    struct Blockchain: Codable, Equatable {
        fileprivate(set) var chains: Set<String>
    }

    struct JSONRPC: Codable, Equatable {
        fileprivate(set) var methods: Set<String>
    }

    struct Notifications: Codable, Equatable {
        let types: [String]
    }
    
    private(set) var blockchain: Blockchain
    private(set) var jsonrpc: JSONRPC
    let notifications: Notifications?
    let controller: Controller?
    
    internal init(blockchain: Blockchain, jsonrpc: JSONRPC, notifications: Notifications? = nil, controller: Controller? = nil) {
        self.blockchain = blockchain
        self.jsonrpc = jsonrpc
        self.notifications = notifications
        self.controller = controller
    }
    
    public init(blockchain: Blockchain, jsonrpc: JSONRPC, notifications: Notifications) {
        self.blockchain = blockchain
        self.jsonrpc = jsonrpc
        self.notifications = notifications
        self.controller = nil
    }
    
    init(permissions: Session.Permissions) {
        self.blockchain = Blockchain(chains: permissions.blockchains)
        self.jsonrpc = JSONRPC(methods: permissions.methods)
        self.notifications = Notifications(types: permissions.notifications)
        self.controller = nil
    }
    
    mutating func upgrade(with permissions: SessionPermissions) {
        blockchain.chains.formUnion(permissions.blockchain.chains)
        jsonrpc.methods.formUnion(permissions.jsonrpc.methods)
    }
}
