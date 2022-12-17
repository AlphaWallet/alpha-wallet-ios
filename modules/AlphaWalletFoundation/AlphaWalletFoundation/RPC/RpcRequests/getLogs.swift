//
//  getLogs.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletWeb3

extension RpcRequest {
    static func getLogs(params: EventFilterParameters) -> RpcRequest {
        RpcRequest(method: "eth_getLogs", params: [params])
    }
}

struct EventLogsDecoder {
    enum DecoderError: Error {
        case nonJsonResponse
    }
    private let contract: Contract
    private let eventName: String

    init(contract: Contract, eventName: String) {
        self.eventName = eventName
        self.contract = contract
    }

    func decode(value: RpcResponse) throws -> [EventParserResultProtocol] {
        switch value.outcome {
        case .response(let value):
            guard let json = value.stringRepresentation.data(using: .utf8) else {
                throw DecoderError.nonJsonResponse
            }
            let logs = try JSONDecoder().decode([EventLog].self, from: json)

            return logs.compactMap { log -> EventParserResult? in
                guard let (evName, evData) = self.contract.parseEvent(log) else { return nil }
                var res = EventParserResult(eventName: evName, transactionReceipt: nil, contractAddress: log.address, decodedResult: evData)
                res.eventLog = log
                return res
            }.filter { (res: EventParserResult?) -> Bool in
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
        case .error(let error):
            throw error
        }
    }
}
