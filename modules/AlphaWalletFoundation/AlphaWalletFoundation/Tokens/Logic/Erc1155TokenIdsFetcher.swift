// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletWeb3
import BigInt

struct Erc1155TokenIds: Codable {
    typealias ContractsAndTokenIds = [AlphaWallet.Address: Set<BigUInt>]
    typealias BlockNumbersProcessed = [Range<UInt64>]

    let tokens: ContractsAndTokenIds
    let blockNumbersProcessed: BlockNumbersProcessed

    init(tokens: ContractsAndTokenIds, blockNumbersProcessed: BlockNumbersProcessed) {
        self.tokens = tokens
        self.blockNumbersProcessed = blockNumbersProcessed
    }

    init() {
        self.init(tokens: .init(), blockNumbersProcessed: .init())
    }
}

struct Erc1155TokenIdsV1: Codable {
    let tokens: Erc1155TokenIds.ContractsAndTokenIds
    let lastBlockNumber: BigUInt
}

internal struct Erc1155TransferEvent: Comparable {
    enum TransferType {
        case send
        case receive
    }
    let contract: AlphaWallet.Address
    let tokenId: BigUInt
    let value: BigUInt
    let from: AlphaWallet.Address
    let to: AlphaWallet.Address
    let transferType: TransferType
    let blockNumber: BigUInt
    let transactionIndex: BigUInt
    let logIndex: BigUInt

    static func < (lhs: Erc1155TransferEvent, rhs: Erc1155TransferEvent) -> Bool {
        if lhs.blockNumber == rhs.blockNumber {
            if lhs.transactionIndex == rhs.transactionIndex {
                return lhs.logIndex < rhs.logIndex
            } else {
                return lhs.transactionIndex < rhs.transactionIndex
            }
        } else {
            return lhs.blockNumber < rhs.blockNumber
        }
    }
}

///Fetching ERC1155 tokens in 2 steps:
///
///A. Fetch known contracts and tokenIds owned (now or previously) for each, writing them to JSON. tokenIds are never removed (so we can easily discover their balance is 0 in the next step)
///B. Fetch balance for each tokenId owned (now or previously. For the latter value would be 0)
///
///This class performs (A)
public class Erc1155TokenIdsFetcher {
    private static let documentDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]).appendingPathComponent("erc1155TokenIds")

    //This is only for development purposes to keep the PromiseKit `Resolver`(s) from being deallocated when they aren't resolved so PromiseKit don't show a warning and create noise and confusion
    private static var fetchEventsPromiseKitResolversKeptForDevelopmentFeatureFlagOnly: [PassthroughSubject<[Erc1155TransferEvent], Erc1155TokenIdsFetcherError>] = .init()
    private let blockNumberProvider: BlockNumberProvider
    private let analytics: AnalyticsLogger
    private let wallet: Wallet
    private let server: RPCServer
    private let blockchainProvider: BlockchainProvider
    private var inFlightPromise: AnyPublisher<Erc1155TokenIds, Erc1155TokenIdsFetcherError>?
    private let config: Config

    public init(analytics: AnalyticsLogger, blockNumberProvider: BlockNumberProvider, blockchainProvider: BlockchainProvider, wallet: Wallet, server: RPCServer, config: Config) {
        self.config = config
        self.blockchainProvider = blockchainProvider
        self.analytics = analytics
        self.blockNumberProvider = blockNumberProvider
        self.server = server
        self.wallet = wallet
        try? FileManager.default.createDirectory(at: Self.documentDirectory, withIntermediateDirectories: true)
        migrateToStorageV2()
    }

    deinit {
        clear()
    }

    private func clear() {
        inFlightPromise = nil
    }

    //TODO debounce? Don't need too often? Or can be done from callers. Seems better to do it here
    //TODO Future PR to fix is so the lookups are combined if possible? Because it is sometimes 1 lookup for [0x0, token1], then [0x0] and another [token1]. While blocking it if inflight will work, we can actually coalesce the lookups by debouncing depending on how close they are (they can be just 1-4 seconds apart for Polygon)
    func detectContractsAndTokenIds() -> AnyPublisher<Erc1155TokenIds, Erc1155TokenIdsFetcherError> {
        if let inFlightPromise = inFlightPromise {
            return inFlightPromise
        }

        //don't use strong ref here as publisher stores as variable, causes ref cycle
        let promise = blockNumberProvider.latestBlockPublisher
            .receive(on: DispatchQueue.main)
            .setFailureType(to: Erc1155TokenIdsFetcherError.self)
            .compactMap { [weak self] blockNumber -> (Erc1155TokenIds, Int)? in
                guard let strongSelf = self else { return nil }
                let tokenIds: Erc1155TokenIds = strongSelf.readJson() ?? .init()
                return (tokenIds, blockNumber)
            }.flatMap { [weak self] (tokenIds: Erc1155TokenIds, currentBlockNumber: Int) -> AnyPublisher<Erc1155TokenIds, Erc1155TokenIdsFetcherError> in
                guard let strongSelf = self else { return .fail(.selfDellocated) }
                return asFutureThrowable {
                    return try await strongSelf.fetchTokenIdsWithLatestEvents(tokenIds: tokenIds, currentBlockNumber: currentBlockNumber)
                }.mapError { Erc1155TokenIdsFetcherError.internal(error: $0) }.eraseToAnyPublisher()
            }.flatMap { [weak self] (tokenIds: Erc1155TokenIds) -> AnyPublisher<Erc1155TokenIds, Erc1155TokenIdsFetcherError> in
                guard let strongSelf = self else { return .fail(.selfDellocated) }
                return asFutureThrowable {
                    return try await strongSelf.fetchTokenIdsByCatchingUpOlderEvents(tokenIds: tokenIds)
                }.mapError { Erc1155TokenIdsFetcherError.internal(error: $0) }.eraseToAnyPublisher()
            }.flatMap { [weak self] tokenIds -> AnyPublisher<Erc1155TokenIds, Erc1155TokenIdsFetcherError> in
                guard let strongSelf = self else { return .fail(.selfDellocated) }
                return strongSelf.writeJson(contractsAndTokenIds: tokenIds).map { tokenIds }.eraseToAnyPublisher()
            }.handleEvents(receiveCompletion: { [weak self] _ in self?.inFlightPromise = nil })
            .share()
            .eraseToAnyPublisher()

        inFlightPromise = promise

        return promise
    }

    private func knownErc1155Contracts() -> Set<AlphaWallet.Address>? {
        guard let contractsAndTokenIds = readJson() else { return nil }
        return Set(contractsAndTokenIds.tokens.keys)
    }

    public func filterAwayErc1155Tokens(contracts: [AlphaWallet.Address]) -> [AlphaWallet.Address] {
        if let erc1155Contracts = knownErc1155Contracts() {
            return contracts.filter { !erc1155Contracts.contains($0) }
        } else {
            return contracts
        }
    }

    // MARK: Serialization

    static private func fileUrl(forWallet address: AlphaWallet.Address, server: RPCServer) -> URL {
        return documentDirectory.appendingPathComponent("\(address.eip55String)-\(server.chainID)-v2.json")
    }

    private func readJson() -> Erc1155TokenIds? {
        guard let data = try? Data(contentsOf: Self.fileUrl(forWallet: wallet.address, server: server)) else { return nil }
        return try? JSONDecoder().decode(Erc1155TokenIds.self, from: data)
    }

    static private func fileUrlV1(forWallet address: AlphaWallet.Address, server: RPCServer) -> URL {
        return documentDirectory.appendingPathComponent("\(address.eip55String)-\(server.chainID).json")
    }

    private func readJsonV1() -> Erc1155TokenIdsV1? {
        guard let data = try? Data(contentsOf: Self.fileUrlV1(forWallet: wallet.address, server: server)) else { return nil }
        return try? JSONDecoder().decode(Erc1155TokenIdsV1.self, from: data)
    }

    enum Erc1155TokenIdsFetcherError: Error {
        case selfDellocated
        case writeFileFailure(error: Error)
        case fromAndToBlockNumberNotFound
        case `internal`(error: Error)
    }

    private func writeJson(contractsAndTokenIds: Erc1155TokenIds) -> AnyPublisher<Void, Erc1155TokenIdsFetcherError> {
        return Future<Void, Erc1155TokenIdsFetcherError> { [wallet, server] seal in
            do {
                let data = try JSONEncoder().encode(contractsAndTokenIds)
                try data.write(to: Self.fileUrl(forWallet: wallet.address, server: server), options: .atomicWrite)

                seal(.success(()))
            } catch {
                seal(.failure(.writeFileFailure(error: error)))
            }
        }.eraseToAnyPublisher()
    }

    public static func deleteForWallet(_ address: AlphaWallet.Address) {
        for each in RPCServer.availableServers {
            let file = fileUrl(forWallet: address, server: each)
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func migrateToStorageV2() {
        if let oldVersion = readJsonV1() {
            let tokenIds: Erc1155TokenIds = readJson() ?? .init()
            let updatedTokens = functional.computeUpdatedTokenIds(fromPreviousRead: oldVersion.tokens, newlyFetched: tokenIds.tokens)
            let updated = Erc1155TokenIds(tokens: updatedTokens, blockNumbersProcessed: tokenIds.blockNumbersProcessed)
            writeJson(contractsAndTokenIds: updated)
            try? FileManager.default.removeItem(at: Self.fileUrlV1(forWallet: wallet.address, server: server))
        }
    }

    private func fetchTokenIdsWithLatestEvents(tokenIds: Erc1155TokenIds, currentBlockNumber: Int) async throws -> Erc1155TokenIds {
        let maximumBlockRangeWindow: UInt64? = server.maximumBlockRangeForEvents
        //We must not use `.latest` because there is a chance it is slightly later than what we use to compute the block range for events
        guard let (fromBlockNumber, toBlockNumber) = Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: UInt64(currentBlockNumber), maximumWindow: maximumBlockRangeWindow, server: server, excludingRanges: tokenIds.blockNumbersProcessed) else {
            throw Erc1155TokenIdsFetcherError.fromAndToBlockNumberNotFound
        }
        return try await fetchTokenIdsWithEvents(fromBlockNumber: fromBlockNumber, toBlockNumber: toBlockNumber, previousTokenIds: tokenIds)
    }

    private func fetchTokenIdsByCatchingUpOlderEvents(tokenIds: Erc1155TokenIds) async throws -> Erc1155TokenIds {
        let maximumBlockRangeWindow: UInt64? = server.maximumBlockRangeForEvents
        //We must not use `.latest` because there is a chance it is slightly later than what we use to compute the block range for events
        if let range = Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: maximumBlockRangeWindow, server: server, excludingRanges: tokenIds.blockNumbersProcessed) {
            let (fromBlockNumber, toBlockNumber) = range
            return try await fetchTokenIdsWithEvents(fromBlockNumber: fromBlockNumber, toBlockNumber: toBlockNumber, previousTokenIds: tokenIds)
        } else {
            return tokenIds
        }
    }

    private func fetchTokenIdsWithEvents(fromBlockNumber: UInt64, toBlockNumber: UInt64, previousTokenIds: Erc1155TokenIds) async throws -> Erc1155TokenIds {
        let fromBlock = EventFilter.Block.blockNumber(fromBlockNumber)
        let toBlock = EventFilter.Block.blockNumber(toBlockNumber)
        let contractsAndTokenIds = try await fetchEvents(fromBlock: fromBlock, toBlock: toBlock)
        let updatedTokens = Erc1155TokenIdsFetcher.functional.computeUpdatedTokenIds(fromPreviousRead: previousTokenIds.tokens, newlyFetched: contractsAndTokenIds)
        let updatedBlockNumbersProcessed = Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: previousTokenIds.blockNumbersProcessed, newEntry: (fromBlockNumber, toBlockNumber))
        return Erc1155TokenIds(tokens: updatedTokens, blockNumbersProcessed: updatedBlockNumbersProcessed)
    }

    private func fetchEvents(fromBlock: EventFilter.Block, toBlock: EventFilter.Block) async throws -> Erc1155TokenIds.ContractsAndTokenIds {
        let recipientAddress = EthereumAddress(wallet.address.eip55String)!
        let nullFilter: [EventFilterable]? = nil
        let singleTransferEventName = "TransferSingle"
        let batchTransferEventName = "TransferBatch"
        let sendParameterFilters: [[EventFilterable]?] = [nullFilter, [recipientAddress], nullFilter]
        let receiveParameterFilters: [[EventFilterable]?] = [nullFilter, nullFilter, [recipientAddress]]
        let sendSingleEvents = try await fetchEvents(transferType: .send, eventName: singleTransferEventName, parameterFilters: sendParameterFilters, fromBlock: fromBlock, toBlock: toBlock)
        let receiveSingleEvents = try await fetchEvents(transferType: .receive, eventName: singleTransferEventName, parameterFilters: receiveParameterFilters, fromBlock: fromBlock, toBlock: toBlock)
        let sendBulkEvents = try await fetchEvents(transferType: .send, eventName: batchTransferEventName, parameterFilters: sendParameterFilters, fromBlock: fromBlock, toBlock: toBlock)
        let receiveBulkEvents = try await fetchEvents(transferType: .receive, eventName: batchTransferEventName, parameterFilters: receiveParameterFilters, fromBlock: fromBlock, toBlock: toBlock)

        let all: [Erc1155TransferEvent] = (sendSingleEvents + receiveSingleEvents + sendBulkEvents + receiveBulkEvents).sorted()
        let contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds = all.reduce(Erc1155TokenIds.ContractsAndTokenIds()) { result, each in
            var result = result
            var tokenIds = result[each.contract] ?? .init()
            tokenIds.insert(each.tokenId)
            result[each.contract] = tokenIds
            return result
        }
        let biggestBlockNumber: BigUInt
        if let blockNumber = all.last?.blockNumber {
            biggestBlockNumber = blockNumber
        } else {
            switch fromBlock {
            case .latest, .pending:
                //TODO should set to the latest blockNumber on the blockchain instead
                biggestBlockNumber = 0
            case .blockNumber(let blockNumber):
                biggestBlockNumber = BigUInt(blockNumber)
            }
        }
        return contractsAndTokenIds
    }

    fileprivate func fetchEvents(transferType: Erc1155TransferEvent.TransferType, eventName: String, parameterFilters: [[EventFilterable]?], fromBlock: EventFilter.Block, toBlock: EventFilter.Block) async throws -> [Erc1155TransferEvent] {
        if config.development.isAutoFetchingDisabled {
            return []
        }

        //We just need any contract for the Swift API to get events, it's not actually used
        let dummyContract = Constants.nullAddress
        let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: toBlock, addresses: nil, parameterFilters: parameterFilters)

        let events1 = try await blockchainProvider.eventLogs(contractAddress: dummyContract, eventName: eventName, abiString: AlphaWallet.Ethereum.ABI.erc1155, filter: eventFilter)
        let events = events1.filter { $0.eventLog != nil }
        let sortedEvents = events.sorted(by: { a, b in
            if a.eventLog!.blockNumber == b.eventLog!.blockNumber {
                return a.eventLog!.transactionIndex == b.eventLog!.transactionIndex
            } else {
                return a.eventLog!.blockNumber < b.eventLog!.blockNumber
            }
        })
        let results: [Erc1155TransferEvent] = sortedEvents.flatMap { each -> [Erc1155TransferEvent] in
            let contract = AlphaWallet.Address(address: each.eventLog!.address)
            guard let from = ((each.decodedResult["_from"] as? EthereumAddress).flatMap({ AlphaWallet.Address(address: $0) })) else { return [] }
            guard let to = ((each.decodedResult["_to"] as? EthereumAddress).flatMap({ AlphaWallet.Address(address: $0) })) else { return [] }
            let blockNumber = each.eventLog!.blockNumber
            let transactionIndex = each.eventLog!.transactionIndex
            let logIndex = each.eventLog!.logIndex
            if eventName == "TransferSingle" {
                guard let tokenId = each.decodedResult["_id"] as? BigUInt else { return [] }
                guard let value = each.decodedResult["_value"] as? BigUInt else { return [] }
                return [.init(contract: contract, tokenId: tokenId, value: value, from: from, to: to, transferType: transferType, blockNumber: blockNumber, transactionIndex: transactionIndex, logIndex: logIndex)]
            } else {
                guard let tokenIds = each.decodedResult["_ids"] as? [BigUInt] else { return [] }
                guard let values = each.decodedResult["_values"] as? [BigUInt] else { return [] }
                let results: [Erc1155TransferEvent] = zip(tokenIds, values).map { (tokenId, value) in
                    .init(contract: contract, tokenId: tokenId, value: value, from: from, to: to, transferType: transferType, blockNumber: blockNumber, transactionIndex: transactionIndex, logIndex: logIndex)
                }
                return results
            }
        }
        return results
    }
}

extension Erc1155TokenIdsFetcher {
    enum functional {}
}

//internal instead of fileprivate to expose to tests
extension Erc1155TokenIdsFetcher.functional {
    //Even if a tokenId now has a balance/value of 0, it will be included in the results
    static func computeUpdatedTokenIds(fromPreviousRead old: Erc1155TokenIds.ContractsAndTokenIds, newlyFetched: Erc1155TokenIds.ContractsAndTokenIds) -> Erc1155TokenIds.ContractsAndTokenIds {
        var updatedTokenIds: Erc1155TokenIds.ContractsAndTokenIds = old
        for (contract, newTokenIds) in newlyFetched {
            if let tokenIds = updatedTokenIds[contract] {
                updatedTokenIds[contract] = Set(Array(tokenIds) + Array(newTokenIds))
            } else {
                updatedTokenIds[contract] = newTokenIds
            }
        }
        return updatedTokenIds
    }

    static func combinedBlockNumbersProcessed(old: Erc1155TokenIds.BlockNumbersProcessed, newEntry: (UInt64, UInt64)) -> Erc1155TokenIds.BlockNumbersProcessed {
        var result: Erc1155TokenIds.BlockNumbersProcessed = old
        let tempNewRange = newEntry.0..<(newEntry.1+1)
        result.append(tempNewRange)
        result = coalesce(result)
        return result
    }

    static func coalesce(_ old: Erc1155TokenIds.BlockNumbersProcessed) -> Erc1155TokenIds.BlockNumbersProcessed {
        guard old.count > 1 else { return old }
        let e0 = old[old.count - 2]
        let e1 = old.last!
        if let unioned = union(e0, e1) {
            var result = old
            result = result.dropLast(2)
            result.append(unioned)
            return coalesce(result)
        } else {
            return old
        }
    }

    static func union(_ e0: Range<UInt64>, _ e1: Range<UInt64>) -> Range<UInt64>? {
        if e0.overlaps(e1) || e0.upperBound == e1.lowerBound || e1.upperBound == e0.lowerBound {
            return min(e0.lowerBound, e1.lowerBound)..<max(e0.upperBound, e1.upperBound)
        } else {
            return nil
        }
    }

    static func makeBlockRangeForEvents(toBlockNumber to: UInt64, maximumWindow: UInt64?, server: RPCServer = .main, excludingRanges: Erc1155TokenIds.BlockNumbersProcessed) -> (UInt64, UInt64)? {
        if let range = excludingRanges.last {
            if range.upperBound == to {
                return (to, to)
            } else if range.upperBound <= to {
                let from: UInt64 = {
                    if let maximumWindow = maximumWindow, to >= maximumWindow {
                        return to - maximumWindow + 1
                    } else {
                        return range.upperBound
                    }
                }()
                return (from, to)
            } else {
                //That `toBlockNumber` is always <= excludingRanges since we are looking for new events
                return nil
            }
        }

        if let maximumWindow = maximumWindow, to >= maximumWindow {
            return (to - maximumWindow + 1, to)
        } else {
            return (server.startBlock, to)
        }
    }

    //When we say "older events", we only look at the events processed and not the latest block in the blockchain
    static func makeBlockRangeToCatchUpForOlderEvents(maximumWindow: UInt64?, server: RPCServer = .main, excludingRanges: Erc1155TokenIds.BlockNumbersProcessed) -> (UInt64, UInt64)? {
        if let range = excludingRanges.last {
            guard range.lowerBound != 0 else { return nil }

            let to: UInt64 = range.lowerBound - 1
            let from: UInt64 = {
                let i = excludingRanges.count - 2
                if excludingRanges.indices.contains(i) {
                    let range = excludingRanges[i]
                    return range.upperBound
                } else {
                    return server.startBlock
                }
            }()
            if let maximumWindow = maximumWindow, to >= maximumWindow {
                return (max(from, to - maximumWindow + 1), to)
            } else {
                return (from, to)
            }
        } else {
            return nil
        }
    }
}
