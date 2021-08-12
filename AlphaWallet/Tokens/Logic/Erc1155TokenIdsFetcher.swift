// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

struct Erc1155TokenIds: Codable {
    typealias ContractsTokenIdsAndValues = [AlphaWallet.Address: [BigUInt: BigInt]]

    let tokens: ContractsTokenIdsAndValues
    let lastBlockNumber: BigUInt
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

    static func <(lhs: Erc1155TransferEvent, rhs: Erc1155TransferEvent) -> Bool {
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

class Erc1155TokenIdsFetcher {
    static let documentDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]).appendingPathComponent("erc1155TokenIds")

    private let address: AlphaWallet.Address
    private let server: RPCServer

    init(address: AlphaWallet.Address, server: RPCServer) {
        self.address = address
        self.server = server
        try? FileManager.default.createDirectory(at: Self.documentDirectory, withIntermediateDirectories: true)
    }

    func refreshBalance() -> Promise<Void> {
        let fromBlockNumber: BigUInt
        let old: Erc1155TokenIds
        if let lastFetched: Erc1155TokenIds = readJson() {
            old = lastFetched
        } else {
            //Should really be -1 instead 0, but so we don't fight with the type system (negative) and doesn't matter in practice being off by 1 at the start
            old = .init(tokens: .init(), lastBlockNumber: 0)
        }
        fromBlockNumber = old.lastBlockNumber + 1

        let toBlock: EventFilter.Block
        if server == .binance_smart_chain || server == .binance_smart_chain_testnet || server == .heco {
            //NOTE: binance_smart_chain does not allow range more than 5000
            toBlock = .blockNumber(UInt64(fromBlockNumber) + 4000)
        } else {
            toBlock = .latest
        }

        return firstly {
            functional.fetchEvents(forAddress: address, server: server, fromBlock: .blockNumber(UInt64(fromBlockNumber)), toBlock: toBlock)
        }.map { fetched -> Erc1155TokenIds in
            let tokens = fetched.tokens
            switch toBlock {
            case .latest, .pending:
                //TODO even better if we set the latest block number in the blockchain
                return fetched
            case .blockNumber(let num):
                let lastBlockNumber = BigUInt(num)
                return Erc1155TokenIds(tokens: tokens, lastBlockNumber: lastBlockNumber)
            }
        }.get {
            let tokens = $0.tokens
        }.map { delta in
            let updatedTokens = self.computeUpdatedBalance(fromOld: old.tokens, delta: delta.tokens)
            return Erc1155TokenIds(tokens: updatedTokens, lastBlockNumber: delta.lastBlockNumber)
        }.then {
            self.writeJson(contractsTokenIdsAndValue: $0)
        }
    }

    private func computeUpdatedBalance(fromOld old: Erc1155TokenIds.ContractsTokenIdsAndValues, delta: Erc1155TokenIds.ContractsTokenIdsAndValues) -> Erc1155TokenIds.ContractsTokenIdsAndValues {
        var updatedTokens: Erc1155TokenIds.ContractsTokenIdsAndValues = old
        for (contract, deltaTokenIdsAndValue) in delta {
            if var updateTokenIdsAndValue = updatedTokens[contract] {
                for (tokenId, deltaValue) in deltaTokenIdsAndValue {
                    let oldValue = updateTokenIdsAndValue[tokenId] ?? 0
                    updateTokenIdsAndValue[tokenId] = oldValue + deltaValue
                }
                updatedTokens[contract] = updateTokenIdsAndValue
            } else {
                updatedTokens[contract] = deltaTokenIdsAndValue
            }
        }
        return updatedTokens
    }

    //MARK: Serialization

    static private func fileUrl(forWallet address: AlphaWallet.Address, server: RPCServer) -> URL {
        return documentDirectory.appendingPathComponent("\(address.eip55String)-\(server.chainID).json")
    }

    func readJson() -> Erc1155TokenIds? {
        guard let data = try? Data(contentsOf: Self.fileUrl(forWallet: address, server: server)) else { return nil }
        return try? JSONDecoder().decode(Erc1155TokenIds.self, from: data)
    }

    private func writeJson(contractsTokenIdsAndValue: Erc1155TokenIds) -> Promise<Void> {
        Promise { seal in
            if let data = try? JSONEncoder().encode(contractsTokenIdsAndValue) {
                do {
                    try data.write(to: Self.fileUrl(forWallet: address, server: server), options: .atomicWrite)
                    seal.fulfill(())
                } catch {
                    seal.reject(error)
                }
            } else {
                struct E: Error {}
                seal.reject(E())
            }
        }
    }

    static func deleteForWallet(_ address: AlphaWallet.Address) {
        for each in RPCServer.allCases {
            let file = fileUrl(forWallet: address, server: each)
            try? FileManager.default.removeItem(at: file)
        }
    }
}

extension Erc1155TokenIdsFetcher {
    class functional {}
}

extension Erc1155TokenIdsFetcher.functional {
    static func fetchEvents(forAddress address: AlphaWallet.Address, server: RPCServer, fromBlock: EventFilter.Block, toBlock: EventFilter.Block) -> Promise<Erc1155TokenIds> {
        let recipientAddress = EthereumAddress(address.eip55String)!
        let nullFilter: [EventFilterable]? = nil
        let singleTransferEventName = "TransferSingle"
        let batchTransferEventName = "TransferBatch"

        let sendParameterFilters: [[EventFilterable]?] = [nullFilter, [recipientAddress], nullFilter]
        let receiveParameterFilters: [[EventFilterable]?] = [nullFilter, nullFilter, [recipientAddress]]
        let sendSinglePromise = firstly {
            fetchEvents(server: server, transferType: .send, eventName: singleTransferEventName, parameterFilters: sendParameterFilters, fromBlock: fromBlock, toBlock: toBlock)
        }
        let receiveSinglePromise = firstly {
            fetchEvents(server: server, transferType: .receive, eventName: singleTransferEventName, parameterFilters: receiveParameterFilters, fromBlock: fromBlock, toBlock: toBlock)
        }

        let sendBulkPromise = firstly {
            fetchEvents(server: server, transferType: .send, eventName: batchTransferEventName, parameterFilters: sendParameterFilters, fromBlock: fromBlock, toBlock: toBlock)
        }
        let receiveBulkPromise = firstly {
            fetchEvents(server: server, transferType: .receive, eventName: batchTransferEventName, parameterFilters: receiveParameterFilters, fromBlock: fromBlock, toBlock: toBlock)
        }
        return firstly {
            when(fulfilled: sendSinglePromise, receiveSinglePromise, sendBulkPromise, receiveBulkPromise)
        }.map { a, b, c, d -> Erc1155TokenIds in
            let all: [Erc1155TransferEvent] = (a + b + c + d).sorted()
            var contractsTokenIdsAndValue: Erc1155TokenIds.ContractsTokenIdsAndValues = .init()
            for each in all {
                let tokenId = each.tokenId
                let value = BigInt(each.value)
                var tokenIdsAndValue = contractsTokenIdsAndValue[each.contract] ?? .init()
                let oldValue = tokenIdsAndValue[tokenId] ?? 0
                switch each.transferType {
                case .send:
                    //We need to track negatives even if old value is 0 because we are computing the deltas since the last fetch
                    tokenIdsAndValue[tokenId] = oldValue - value
                case .receive:
                    tokenIdsAndValue[tokenId] = oldValue + value
                }
                contractsTokenIdsAndValue[each.contract] = tokenIdsAndValue
            }
            let biggestBlockNumber: BigUInt = all.last?.blockNumber ?? 0
            return Erc1155TokenIds(tokens: contractsTokenIdsAndValue, lastBlockNumber: biggestBlockNumber)
        }
    }

    fileprivate static func fetchEvents(server: RPCServer, transferType: Erc1155TransferEvent.TransferType, eventName: String, parameterFilters: [[EventFilterable]?], fromBlock: EventFilter.Block, toBlock: EventFilter.Block) -> Promise<[Erc1155TransferEvent]> {
        Promise { seal in
            //We just need any contract for the Swift API to get events, it's not actually used
            let dummyContract = Constants.nullAddress

            let queue: DispatchQueue = .main

            let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: toBlock, addresses: nil, parameterFilters: parameterFilters)
            firstly {
                getEventLogs(withServer: server, contract: dummyContract, eventName: eventName, abiString: AlphaWallet.Ethereum.ABI.erc1155String, filter: eventFilter, queue: queue)
            }.done(on: queue, { events in
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
                seal.fulfill(results)
            }).catch { error in
                //TODO should log remotely
            }
        }
    }
}