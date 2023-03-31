//
//  CAIP10AccountProvidable.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.01.2023.
//

import Foundation
import Combine
import AlphaWalletFoundation
import WalletConnectSign

protocol CAIP10AccountProvidable {
    var accounts: AnyPublisher<Set<CAIP10Account>, Never> { get }

    func set(activeWallet: Wallet?)
    func namespaces(proposalOrServer: ProposalOrServer) throws -> [String: SessionNamespace]
}

extension CAIP10AccountProvidable {
    func namespaces(for server: RPCServer) throws -> (accounts: [String], server: RPCServer, namespaces: [String: SessionNamespace]) {
        let namespaces = try namespaces(proposalOrServer: .server(server))

        guard let namespace = namespaces[SupportedSessionNamespace.eip155.rawValue] else { throw AnyCAIP10AccountProvidable.CAIP10AccountProvidableError.eip155NotFound }
        let accounts = namespace.accounts.map { $0.address }

        return (accounts: accounts, server: server, namespaces: namespaces)
    }
}

enum SupportedSessionNamespace: String {
    case eip155
}

class AnyCAIP10AccountProvidable: CAIP10AccountProvidable {
    enum CAIP10AccountProvidableError: Error {
        case unavailableToBuildBlockchain
        case chainNotSupportedOrNotEnabled
        case emptyNamespaces
        case eip155NotFound
    }

    private let accountsSubject: CurrentValueSubject<Set<CAIP10Account>?, Never> = .init(nil)
    private let activeWalletSubject: CurrentValueSubject<Wallet?, Never> = .init(nil)
    private let keystore: Keystore
    private var cancellable = Set<AnyCancellable>()
    
    var accounts: AnyPublisher<Set<CAIP10Account>, Never> {
        accountsSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    public init(keystore: Keystore, serversProvidable: ServersProvidable) {
        self.keystore = keystore

        let wallets = keystore.walletsPublisher.filter { !$0.isEmpty }

        let servers = serversProvidable.enabledServersPublisher
            .filter { !$0.isEmpty }
            .map { $0.sorted(by: { $0.displayOrderPriority < $1.displayOrderPriority }) }

        let activeWallet = activeWalletSubject.compactMap { $0 }

        Publishers.CombineLatest3(wallets, servers, activeWallet)
            .map { wallets, servers, activeWallet -> Set<CAIP10Account> in
                let blockchains = servers.compactMap { Blockchain($0.eip155) }
                var accounts: Set<CAIP10Account> = .init()

                //NOTE: for now support only active wallets, will be updated to being able to use any available wallet, non watch
                let wallets = wallets.filter { $0 == activeWallet }

                for wallet in wallets {
                    for blockchain in blockchains {
                        guard let account = CAIP10Account(blockchain: blockchain, address: wallet.address.eip55String) else { continue }
                        accounts.insert(account)
                    }
                }

                return accounts
            }.removeDuplicates()
            .assign(to: \.value, on: accountsSubject)
            .store(in: &cancellable)
    }

    func set(activeWallet: Wallet?) {
        activeWalletSubject.send(activeWallet)
    }

    func namespaces(proposalOrServer: ProposalOrServer) throws -> [String: SessionNamespace] {
        switch proposalOrServer {
        case .server(let server):
            guard let blockchain = Blockchain(server.eip155) else { throw CAIP10AccountProvidableError.unavailableToBuildBlockchain }
            let accounts = accountsForSupportedBlockchains(for: [blockchain])
            guard !accounts.isEmpty else { throw CAIP10AccountProvidableError.chainNotSupportedOrNotEnabled }

            return [SupportedSessionNamespace.eip155.rawValue: SessionNamespace(accounts: accounts, methods: [], events: [])]
        case .proposal(let proposal):
            var sessionNamespaces: [String: SessionNamespace] = [:]
            buildResponseNamespaces(&sessionNamespaces, namespaces: proposal.requiredNamespaces)
            buildResponseNamespaces(&sessionNamespaces, namespaces: proposal.optionalNamespaces ?? [:])

            if sessionNamespaces.isEmpty {
                throw CAIP10AccountProvidableError.emptyNamespaces
            }

            return sessionNamespaces
        }
    }

    private func buildResponseNamespaces(_ responseNamespaces: inout [String: SessionNamespace], namespaces: [String: ProposalNamespace]) {
        for each in namespaces {
            let proposalNamespace = each.value

            let accounts: Set<CAIP10Account>
            let key: String
            if let namespace = SupportedSessionNamespace(rawValue: each.key) {
                key = namespace.rawValue
                accounts = accountsForSupportedBlockchains(for: proposalNamespace.chains ?? [])
            } else if let blockchain = Blockchain(each.key) {
                key = blockchain.absoluteString
                accounts = accountsForSupportedBlockchains(for: [blockchain])
            } else {
                continue
            }

            if accounts.isEmpty { continue }
            if let existedNamespace = responseNamespaces[key] {
                responseNamespaces[key] = SessionNamespace(
                    accounts: existedNamespace.accounts.union(accounts),
                    methods: existedNamespace.methods.union(proposalNamespace.methods),
                    events: existedNamespace.events.union(proposalNamespace.events))
            } else {
                let sessionNamespace = SessionNamespace(
                    accounts: accounts,
                    methods: proposalNamespace.methods,
                    events: proposalNamespace.events)

                responseNamespaces[key] = sessionNamespace
            }
        }
    }

    private func accountsForSupportedBlockchains(for blockchains: Set<Blockchain>) -> Set<CAIP10Account> {
        var accounts = Set<CAIP10Account>()

        for blockchain in blockchains {
            let filtered = (accountsSubject.value ?? .init()).filter { $0.blockchain == blockchain }
            accounts = accounts.union(filtered)
        }

        return accounts
    }
}
