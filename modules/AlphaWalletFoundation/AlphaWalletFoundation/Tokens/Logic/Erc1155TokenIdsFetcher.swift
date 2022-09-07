// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

public struct Erc1155TokenIds: Codable {
    public typealias ContractsAndTokenIds = [AlphaWallet.Address: Set<BigUInt>]

    public let tokens: ContractsAndTokenIds
    public let lastBlockNumber: BigUInt
}

fileprivate struct Erc1155TransferEvent: Comparable {
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
    static let documentDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]).appendingPathComponent("erc1155TokenIds")

    private let address: AlphaWallet.Address
    private let server: RPCServer
    private let config: Config
    private let queue: DispatchQueue

    public init(address: AlphaWallet.Address, server: RPCServer, config: Config, queue: DispatchQueue) {
        self.address = address
        self.server = server
        self.config = config
        self.queue = queue
        try? FileManager.default.createDirectory(at: Self.documentDirectory, withIntermediateDirectories: true)
    }

    public func detectContractsAndTokenIds() -> Promise<Erc1155TokenIds> {
        let address = self.address
        let server = self.server
        //Should really be -1 instead 0, but so we don't fight with the type system (negative) and doesn't matter in practice being off by 1 at the start
        let fromPreviousRead: Erc1155TokenIds = readJson() ?? .init(tokens: .init(), lastBlockNumber: 0)
        let fromBlockNumber = fromPreviousRead.lastBlockNumber + 1
        let toBlock = server.makeMaximumToBlockForEvents(fromBlockNumber: UInt64(fromBlockNumber))
        return firstly {
            functional.fetchEvents(config: config, forAddress: address, server: server, fromBlock: .blockNumber(UInt64(fromBlockNumber)), toBlock: toBlock, queue: queue)
        }.map(on: queue, { fetched -> Erc1155TokenIds in
            let tokens = fetched.tokens
            let deltaSinceLastCheck: Erc1155TokenIds
            switch toBlock {
            case .latest, .pending:
                //TODO even better if we set the latest block number in the blockchain
                deltaSinceLastCheck = fetched
            case .blockNumber(let num):
                let lastBlockNumber = BigUInt(num)
                deltaSinceLastCheck = Erc1155TokenIds(tokens: tokens, lastBlockNumber: lastBlockNumber)
            }
            let updatedTokens = functional.computeUpdatedTokenIds(fromPreviousRead: fromPreviousRead.tokens, deltaSinceLastCheck: deltaSinceLastCheck.tokens)
            let contractsAndTokenIds = Erc1155TokenIds(tokens: updatedTokens, lastBlockNumber: deltaSinceLastCheck.lastBlockNumber)
            return contractsAndTokenIds
        }).then(on: .main, { contractsAndTokenIds -> Promise<Erc1155TokenIds> in
            return Erc1155TokenIdsFetcher
                .writeJson(contractsAndTokenIds: contractsAndTokenIds, address: address, server: server)
                .map { contractsAndTokenIds }
        })
    }

    public func knownErc1155Contracts() -> Set<AlphaWallet.Address>? {
        guard let contractsAndTokenIds = readJson() else { return nil }
        return Set(contractsAndTokenIds.tokens.keys)
    }

    // MARK: Serialization

    static private func fileUrl(forWallet address: AlphaWallet.Address, server: RPCServer) -> URL {
        return documentDirectory.appendingPathComponent("\(address.eip55String)-\(server.chainID).json")
    }

    private func readJson() -> Erc1155TokenIds? {
        guard let data = try? Data(contentsOf: Self.fileUrl(forWallet: address, server: server)) else { return nil }
        return try? JSONDecoder().decode(Erc1155TokenIds.self, from: data)
    }

    private static func writeJson(contractsAndTokenIds: Erc1155TokenIds, address: AlphaWallet.Address, server: RPCServer) -> Promise<Void> {
        Promise { seal in
            if let data = try? JSONEncoder().encode(contractsAndTokenIds) {
                try data.write(to: Self.fileUrl(forWallet: address, server: server), options: .atomicWrite)
                seal.fulfill(())
            } else {
                struct E: Error {}
                seal.reject(E())
            }
        }
    }

    public static func deleteForWallet(_ address: AlphaWallet.Address) {
        for each in RPCServer.availableServers {
            let file = fileUrl(forWallet: address, server: each)
            try? FileManager.default.removeItem(at: file)
        }
    }
}

extension Erc1155TokenIdsFetcher {
    class functional {}
}

extension Erc1155TokenIdsFetcher.functional {
    //This is only for development purposes to keep the PromiseKit `Resolver`(s) from being deallocated when they aren't resolved so PromiseKit don't show a warning and create noise and confusion
    private static var fetchEventsPromiseKitResolversKeptForDevelopmentFeatureFlagOnly: [Resolver<[Erc1155TransferEvent]>] = .init()

    static func fetchEvents(config: Config, forAddress address: AlphaWallet.Address, server: RPCServer, fromBlock: EventFilter.Block, toBlock: EventFilter.Block, queue: DispatchQueue) -> Promise<Erc1155TokenIds> {
        let recipientAddress = EthereumAddress(address.eip55String)!
        let nullFilter: [EventFilterable]? = nil
        let singleTransferEventName = "TransferSingle"
        let batchTransferEventName = "TransferBatch"
        let sendParameterFilters: [[EventFilterable]?] = [nullFilter, [recipientAddress], nullFilter]
        let receiveParameterFilters: [[EventFilterable]?] = [nullFilter, nullFilter, [recipientAddress]]
        let sendSinglePromise = fetchEvents(config: config, server: server, transferType: .send, eventName: singleTransferEventName, parameterFilters: sendParameterFilters, fromBlock: fromBlock, toBlock: toBlock, queue: queue)
        let receiveSinglePromise = fetchEvents(config: config, server: server, transferType: .receive, eventName: singleTransferEventName, parameterFilters: receiveParameterFilters, fromBlock: fromBlock, toBlock: toBlock, queue: queue)
        let sendBulkPromise = fetchEvents(config: config, server: server, transferType: .send, eventName: batchTransferEventName, parameterFilters: sendParameterFilters, fromBlock: fromBlock, toBlock: toBlock, queue: queue)
        let receiveBulkPromise = fetchEvents(config: config, server: server, transferType: .receive, eventName: batchTransferEventName, parameterFilters: receiveParameterFilters, fromBlock: fromBlock, toBlock: toBlock, queue: queue)
        return firstly {
            when(fulfilled: sendSinglePromise, receiveSinglePromise, sendBulkPromise, receiveBulkPromise)
        }.map(on: queue, { a, b, c, d -> Erc1155TokenIds in
            let all: [Erc1155TransferEvent] = (a + b + c + d).sorted()
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
            return Erc1155TokenIds(tokens: contractsAndTokenIds, lastBlockNumber: biggestBlockNumber)
        })
    }

    fileprivate static func fetchEvents(config: Config, server: RPCServer, transferType: Erc1155TransferEvent.TransferType, eventName: String, parameterFilters: [[EventFilterable]?], fromBlock: EventFilter.Block, toBlock: EventFilter.Block, queue: DispatchQueue) -> Promise<[Erc1155TransferEvent]> {
        if config.development.isAutoFetchingDisabled {
            return Promise<[Erc1155TransferEvent]> { seal in
                fetchEventsPromiseKitResolversKeptForDevelopmentFeatureFlagOnly.append(seal)
            }
        }

        //We just need any contract for the Swift API to get events, it's not actually used
        let dummyContract = Constants.nullAddress
        let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: toBlock, addresses: nil, parameterFilters: parameterFilters)
        return firstly {
            getEventLogs(withServer: server, contract: dummyContract, eventName: eventName, abiString: AlphaWallet.Ethereum.ABI.erc1155String, filter: eventFilter, queue: queue)
        }.map(on: queue, { events -> [Erc1155TransferEvent] in
            let events = events.filter { $0.eventLog != nil }
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
        })
    }

    //Even if a tokenId now has a balance/value of 0, it will be included in the results
    static func computeUpdatedTokenIds(fromPreviousRead old: Erc1155TokenIds.ContractsAndTokenIds, deltaSinceLastCheck delta: Erc1155TokenIds.ContractsAndTokenIds) -> Erc1155TokenIds.ContractsAndTokenIds {
        var updatedTokenIds: Erc1155TokenIds.ContractsAndTokenIds = old
        for (contract, newTokenIds) in delta {
            if let tokenIds = updatedTokenIds[contract] {
                updatedTokenIds[contract] = Set(Array(tokenIds) + Array(newTokenIds))
            } else {
                updatedTokenIds[contract] = newTokenIds
            }
        }
        return updatedTokenIds
    }
}
