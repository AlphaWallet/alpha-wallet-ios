//
//  Web3+Protocols.swift
//  web3swift-iOS
//
//  Created by Alexander Vlasov on 26.02.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt
import PromiseKit

public protocol EventParserResultProtocol {
    var eventName: String { get }
    var decodedResult: [String: Any] { get }
    var contractAddress: EthereumAddress { get }
    var transactionReceipt: TransactionReceipt? { get }
    var eventLog: EventLog? { get }
}

protocol EventParserProtocol {
    func parseTransaction(_ transaction: Transaction) -> Swift.Result<[EventParserResultProtocol], Web3Error>
    func parseTransactionByHash(_ hash: Data) -> Swift.Result<[EventParserResultProtocol], Web3Error>
    func parseBlock(_ block: Block) -> Swift.Result<[EventParserResultProtocol], Web3Error>
    func parseBlockByNumber(_ blockNumber: UInt64) -> Swift.Result<[EventParserResultProtocol], Web3Error>
    func parseTransactionPromise(_ transaction: Transaction) -> Promise<[EventParserResultProtocol]>
    func parseTransactionByHashPromise(_ hash: Data) -> Promise<[EventParserResultProtocol]>
    func parseBlockByNumberPromise(_ blockNumber: UInt64) -> Promise<[EventParserResultProtocol]>
    func parseBlockPromise(_ block: Block) -> Promise<[EventParserResultProtocol]>
}
