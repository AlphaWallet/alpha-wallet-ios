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
    private lazy var ens = ENS(delegate: ensDelegate, server: server)
    private let server: RPCServer
    private let ensReverseLookup: EnsReverseResolver
    private let ensDelegate: ENSDelegateImpl

    init(blockchainProvider: BlockchainProvider, storage: DomainNameRecordsStorage) {
        self.ensDelegate = ENSDelegateImpl(blockchainProvider: blockchainProvider)
        self.storage = storage
        self.server = blockchainProvider.server
        ensReverseLookup = EnsReverseResolver(storage: storage, blockchainProvider: blockchainProvider)
    }

    func getENSRecord(forAddress address: AlphaWallet.Address, record: EnsTextRecordKey) async throws -> String {
        let ens = try await ensReverseLookup.getENSNameFromResolver(for: address)
        return try await getENSRecord(forName: ens, record: record)
    }

    func getENSRecord(forName name: String, record: EnsTextRecordKey) async throws -> String {
        if let cachedResult = await cachedResult(forName: name, record: record) {
            return cachedResult
        }

        let value = try await ens.getTextRecord(forName: name, recordKey: record)
        let key = DomainNameLookupKey(nameOrAddress: name, server: server, record: record)
        await storage.addOrUpdate(record: .init(key: key, value: .record(value)))
        return value
    }

    private func cachedResult(forName name: String, record: EnsTextRecordKey) async -> String? {
        let key = DomainNameLookupKey(nameOrAddress: name, server: server, record: record)
        switch await storage.record(for: key, expirationTime: Constants.DomainName.recordExpiration)?.value {
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

    func getEnsAvatar(for address: AlphaWallet.Address, ens: String?) async throws -> Eip155URLOrWebImageURL {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        let _url: String
        if let ens = ens {
            _url = try await getENSRecord(forName: ens, record: .avatar)
        } else {
            _url = try await getENSRecord(forAddress: address, record: .avatar)
        }

        //NOTE: once open sea image url cached it will be here as `url`, so the next time we willn't decode it as eip155 and return it as it is
        guard let result = Eip155UrlCoder.decode(from: _url) else {
            guard let url = URL(string: _url) else {
                throw SmartContractError.embedded(AnyError.blockieCreateFailure)
            }
            //NOTE: fallback to URL in case if result isn't eip155
            return .image(image: .url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true), raw: _url)
        }

        return .eip155(url: result, raw: _url)
    }
}
