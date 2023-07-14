//
//  Web3+TransactionIntermediate.swift
//  web3swift-iOS
//
//  Created by Alexander Vlasov on 26.02.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt
import PromiseKit

extension Web3.Contract {
    struct EventParser: EventParserProtocol {

        let contract: ContractRepresentable
        let eventName: String
        let filter: EventFilter?
        private let web3: Web3

        init? (web3 web3Instance: Web3, eventName: String, contract: ContractRepresentable, filter: EventFilter? = nil) {
            guard let _ = contract.allEvents.index(of: eventName) else { return nil }
            self.eventName = eventName
            self.web3 = web3Instance
            self.contract = contract
            self.filter = filter
        }

        func parseBlockByNumber(_ blockNumber: UInt64) -> Swift.Result<[EventParserResultProtocol], Web3Error> {
            do {
                let result = try self.parseBlockByNumberPromise(blockNumber).wait()
                return .success(result)
            } catch {
                if let err = error as? Web3Error {
                    return .failure(err)
                }
                return .failure(Web3Error.generalError(error))
            }
        }

        func parseBlock(_ block: Block) -> Swift.Result<[EventParserResultProtocol], Web3Error> {
            do {
                let result = try self.parseBlockPromise(block).wait()
                return .success(result)
            } catch {
                if let err = error as? Web3Error {
                    return .failure(err)
                }
                return .failure(Web3Error.generalError(error))
            }
        }

        func parseTransactionByHash(_ hash: Data) -> Swift.Result<[EventParserResultProtocol], Web3Error> {
            do {
                let result = try self.parseTransactionByHashPromise(hash).wait()
                return .success(result)
            } catch {
                if let err = error as? Web3Error {
                    return .failure(err)
                }
                return .failure(Web3Error.generalError(error))
            }
        }

        func parseTransaction(_ transaction: Transaction) -> Swift.Result<[EventParserResultProtocol], Web3Error> {
            do {
                let result = try self.parseTransactionPromise(transaction).wait()
                return .success(result)
            } catch {
                if let err = error as? Web3Error {
                    return .failure(err)
                }
                return .failure(Web3Error.generalError(error))
            }
        }
    }
}

extension Web3.Contract.EventParser {
    func parseTransactionPromise(_ transaction: Transaction) -> Promise<[EventParserResultProtocol]> {
        let queue = self.web3.queue
        do {
            guard let hash = transaction.hash else {
                throw Web3Error.inputError("Failed to get transaction hash")}
            return self.parseTransactionByHashPromise(hash)
        } catch {
            let returnPromise = Promise<[EventParserResultProtocol]>.pending()
            queue.async {
                returnPromise.resolver.reject(error)
            }
            return returnPromise.promise
        }
    }

    func parseTransactionByHashPromise(_ hash: Data) -> Promise<[EventParserResultProtocol]> {
        let queue = self.web3.queue
        let eth = Web3.Eth(web3: self.web3)
        return eth.getTransactionReceiptPromise(hash).map(on: queue) { receipt throws -> [EventParserResultProtocol] in
            guard let results = parseReceiptForLogs(receipt: receipt, contract: self.contract, eventName: self.eventName, filter: self.filter) else {
                throw Web3Error.inputError("Failed to parse receipt for events")
            }
            return results
        }
    }

    func parseBlockByNumberPromise(_ blockNumber: UInt64) -> Promise<[EventParserResultProtocol]> {
        let queue = self.web3.queue
        let eth = Web3.Eth(web3: self.web3)
        do {
            if self.filter != nil && (self.filter?.fromBlock != nil || self.filter?.toBlock != nil) {
                throw Web3Error.inputError("Can not mix parsing specific block and using block range filter")
            }
            return eth.getBlockByNumberPromise(blockNumber).then(on: queue) {res in
                return self.parseBlockPromise(res)
            }
        } catch {
            let returnPromise = Promise<[EventParserResultProtocol]>.pending()
            queue.async {
                returnPromise.resolver.reject(error)
            }
            return returnPromise.promise
        }
    }

    func parseBlockPromise(_ block: Block) -> Promise<[EventParserResultProtocol]> {
        let queue = self.web3.queue
        do {
            guard let bloom = block.logsBloom else {
                throw Web3Error.inputError("Block doesn't have a bloom filter log")
            }
            if self.contract.address != nil {
                let addressPresent = block.logsBloom?.test(topic: self.contract.address!.addressData)
                if addressPresent != true {
                    let returnPromise = Promise<[EventParserResultProtocol]>.pending()
                    queue.async {
                        returnPromise.resolver.fulfill([EventParserResultProtocol]())
                    }
                    return returnPromise.promise
                }
            }
            guard let eventOfSuchTypeIsPresent = self.contract.testBloomForEventPrecence(eventName: self.eventName, bloom: bloom) else {
                throw Web3Error.inputError("Error processing bloom for events")
            }
            if !eventOfSuchTypeIsPresent {
                let returnPromise = Promise<[EventParserResultProtocol]>.pending()
                queue.async {
                    returnPromise.resolver.fulfill([EventParserResultProtocol]())
                }
                return returnPromise.promise
            }
            return Promise { seal in

                var pendingEvents: [Promise<[EventParserResultProtocol]>] = []
                for transaction in block.transactions {
                    switch transaction {
                    case .null:
                        seal.reject(Web3Error.inputError("No information about transactions in block"))
                        return
                    case .transaction(let tx):
                        guard let hash = tx.hash else {
                            seal.reject(Web3Error.inputError("Failed to get transaction hash"))
                            return
                        }
                        let subresultPromise = self.parseTransactionByHashPromise(hash)
                        pendingEvents.append(subresultPromise)
                    case .hash(let hash):
                        let subresultPromise = self.parseTransactionByHashPromise(hash)
                        pendingEvents.append(subresultPromise)
                    }
                }
                when(resolved: pendingEvents).done(on: queue) { (results: [Result<[EventParserResultProtocol]>]) throws in
                    var allResults = [EventParserResultProtocol]()
                    for res in results {
                        guard case .fulfilled(let subresult) = res else {
                            throw Web3Error.inputError("Failed to parse event for one transaction in block")
                        }
                        allResults.append(contentsOf: subresult)
                    }
                    seal.fulfill(allResults)
                }.catch(on: queue) {err in
                    seal.reject(err)
                }
            }
        } catch {
            let returnPromise = Promise<[EventParserResultProtocol]>.pending()
            queue.async {
                returnPromise.resolver.reject(error)
            }
            return returnPromise.promise
        }
    }

}

extension Web3.Contract {
    public func getIndexedEventsPromise(eventName: String, filter: EventFilter, joinWithReceipts: Bool = false) -> Promise<[EventParserResultProtocol]> {
        let queue = self.web3.queue
        do {
            guard let preEncoding = contract.encodeTopicToGetLogs(eventName: eventName, filter: filter) else {
                throw Web3Error.inputError("Failed to encode topic for request")
            }

            let request = JSONRPCrequest(method: .getLogs, params: JSONRPCparams(params: [preEncoding]))
            let fetchLogsPromise = self.web3.dispatch(request).map(on: queue) { response throws -> [EventParserResult] in
                guard let value: [EventLog] = response.getValue() else {
                    if response.error != nil {
                        throw Web3Error.nodeError(response.error!.message)
                    }
                    throw Web3Error.nodeError("Empty or malformed response")
                }
                let allLogs = value
                let decodedLogs = allLogs.compactMap({ (log) -> EventParserResult? in
                    guard let (evName, evData) = self.contract.parseEvent(log) else { return nil }
                    var res = EventParserResult(eventName: evName, transactionReceipt: nil, contractAddress: log.address, decodedResult: evData)
                    res.eventLog = log
                    return res
                }).filter { (res: EventParserResult?) -> Bool in
                    if eventName != nil {
                        if res != nil && res?.eventName == eventName && res!.eventLog != nil {
                            return true
                        }
                    } else {
                        if res != nil && res!.eventLog != nil {
                            return true
                        }
                    }
                    return false
                }
                return decodedLogs
            }
            if !joinWithReceipts {
                return fetchLogsPromise.mapValues(on: queue) { res -> EventParserResultProtocol in
                    return res as EventParserResultProtocol
                }
            }
            let eth = Web3.Eth(web3: self.web3)
            return fetchLogsPromise.thenMap(on: queue) { singleEvent in
                return eth.getTransactionReceiptPromise(singleEvent.eventLog!.transactionHash).map(on: queue) { receipt in
                    var joinedEvent = singleEvent
                    joinedEvent.transactionReceipt = receipt
                    return joinedEvent as EventParserResultProtocol
                }
            }
        } catch {
            let returnPromise = Promise<[EventParserResultProtocol]>.pending()
            queue.async {
                returnPromise.resolver.reject(error)
            }
            return returnPromise.promise
        }
    }
}
