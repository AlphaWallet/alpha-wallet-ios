//
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.09.2021.
//

import Foundation
import AlphaWalletENS
import Combine

/// https://eips.ethereum.org/EIPS/eip-634
final class GetEnsTextRecord {
    private let storage: DomainNameRecordsStorage
    private lazy var ens = ENS(delegate: ensDelegate, chainId: server.chainID)
    private let server: RPCServer
    private let ensReverseLookup: EnsReverseResolver
    private let ensDelegate: ENSDelegateImpl

    init(blockchainProvider: BlockchainProvider, storage: DomainNameRecordsStorage) {
        self.ensDelegate = ENSDelegateImpl(blockchainProvider: blockchainProvider)
        self.storage = storage
        self.server = blockchainProvider.server
        ensReverseLookup = EnsReverseResolver(storage: storage, blockchainProvider: blockchainProvider)
    }

    func getENSRecord(forAddress address: AlphaWallet.Address, record: EnsTextRecordKey) -> AnyPublisher<String, SmartContractError> {
        ensReverseLookup.getENSNameFromResolver(for: address)
            .flatMap { ens in
                self.getENSRecord(forName: ens, record: record)
            }.eraseToAnyPublisher()
    }

    func getENSRecord(forName name: String, record: EnsTextRecordKey) -> AnyPublisher<String, SmartContractError> {
        if let cachedResult = cachedResult(forName: name, record: record) {
            return .just(cachedResult)
        }

        return ens.getTextRecord(forName: name, recordKey: record)
            .handleEvents(receiveOutput: { [storage, server] value in
                let key = DomainNameLookupKey(nameOrAddress: name, server: server, record: record)
                storage.addOrUpdate(record: .init(key: key, value: .record(value)))
            }).eraseToAnyPublisher()
    }

    private func cachedResult(forName name: String, record: EnsTextRecordKey) -> String? {
        let key = DomainNameLookupKey(nameOrAddress: name, server: server, record: record)
        switch storage.record(for: key, expirationTime: Constants.DomainName.recordExpiration)?.value {
        case .record(let record):
            return record
        case .domainName, .address, .none:
            return nil
        }
    }
}

extension GetEnsTextRecord {

    enum Eip155URLOrWebImageURL {
        case image(image: BlockiesImage, raw: String)
        case eip155(url: Eip155URL, raw: String)
    }

    func getEnsAvatar(for address: AlphaWallet.Address, ens: String?) -> AnyPublisher<Eip155URLOrWebImageURL, SmartContractError> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        let publisher: AnyPublisher<String, SmartContractError>
        if let ens = ens {
            publisher = getENSRecord(forName: ens, record: .avatar)
        } else {
            publisher = getENSRecord(forAddress: address, record: .avatar)
        }

        return publisher.flatMap { _url -> AnyPublisher<Eip155URLOrWebImageURL, SmartContractError> in
            //NOTE: once open sea image url cached it will be here as `url`, so the next time we willn't decode it as eip155 and return it as it is
            guard let result = Eip155UrlCoder.decode(from: _url) else {
                guard let url = URL(string: _url) else {
                    return .fail(.embedded(AnyError.blockieCreateFailure))
                }
                //NOTE: fallback to URL in case if result isn't eip155
                return .just(.image(image: .url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true), raw: _url))
            }

            return .just(.eip155(url: result, raw: _url))
        }.eraseToAnyPublisher()
    }
}
