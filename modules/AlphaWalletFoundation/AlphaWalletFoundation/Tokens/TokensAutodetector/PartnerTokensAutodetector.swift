//
//  PartnerTokensAutodetector.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 14.04.2023.
//

import Foundation
import AlphaWalletCore
import Combine

class PartnerTokensAutodetector: TokensAutodetector {
    private let subject = PassthroughSubject<[TokenOrContract], Never>()
    private let contractToImportStorage: ContractToImportStorage
    private let tokensDataStore: TokensDataStore
    private let importToken: TokenImportable & TokenOrContractFetchable
    private let queue = DispatchQueue(label: "org.alphawallet.swift.partnerTokensAutodetector")
    private var cancellable = Set<AnyCancellable>()
    private let server: RPCServer

    var detectedTokensOrContracts: AnyPublisher<[TokenOrContract], Never> {
        subject.eraseToAnyPublisher()
    }

    init(contractToImportStorage: ContractToImportStorage,
         tokensDataStore: TokensDataStore,
         importToken: TokenImportable & TokenOrContractFetchable,
         server: RPCServer) {

        self.server = server
        self.importToken = importToken
        self.tokensDataStore = tokensDataStore
        self.contractToImportStorage = contractToImportStorage
    }

    func start() {
        Just(contractToImportStorage.contractsToDetect)
            .subscribe(on: queue)
            .map { self.filter(contractsToDetect: $0) }
            .flatMap { [importToken] contracts in
                let publishers = contracts.map {
                    return importToken.fetchTokenOrContract(
                        for: $0.contract,
                        onlyIfThereIsABalance: $0.onlyIfThereIsABalance).mapToResult()
                }
                return Publishers.MergeMany(publishers).collect()
            }.receive(on: queue)
            .map { $0.compactMap { try? $0.get() } }
            .filter { !$0.isEmpty }
            .multicast(subject: subject)
            .connect()
            .store(in: &cancellable)
    }

    func stop() {
        //no-op
    }

    func resume() {
        //no-op
    }

    private func filter(contractsToDetect: [ContractToImport]) -> [ContractToImport] {
        return contractsToDetect.filter { $0.server == server }.filter {
            !tokensDataStore.tokens(for: [$0.server]).map { $0.contractAddress }.contains($0.contract) &&
            !tokensDataStore.deletedContracts(forServer: $0.server).map { $0.contractAddress }.contains($0.contract) &&
            !tokensDataStore.hiddenContracts(forServer: $0.server).map { $0.contractAddress }.contains($0.contract)
        }
    }
}
