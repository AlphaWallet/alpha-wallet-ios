//
//  EventFiltering.swift
//  web3swift
//
//  Created by Alexander Vlasov on 11.05.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation

internal func filterLogs(decodedLogs: [EventParserResultProtocol], eventFilter: EventFilter) -> [EventParserResultProtocol] {
    let filteredLogs = decodedLogs.filter { (result) -> Bool in
        if eventFilter.addresses == nil {
            return true
        } else {
            if eventFilter.addresses!.contains(result.contractAddress) {
                return true
            } else {
                return false
            }
        }
    }.filter { (result) -> Bool in
        if eventFilter.parameterFilters == nil {
            return true
        } else {
            let keys = result.decodedResult.keys.filter({ (key) -> Bool in
                if let _ = UInt64(key) {
                    return true
                }
                return false
            })
            if keys.count < eventFilter.parameterFilters!.count {
                return false
            }
            for i in 0 ..< eventFilter.parameterFilters!.count {
                let allowedValues = eventFilter.parameterFilters![i]
                let actualValue = result.decodedResult["\(i)"]
                if actualValue == nil {
                    return false
                }
                if allowedValues == nil {
                    continue
                }
                var inAllowed = false
                for value in allowedValues! where value.isEqualTo(actualValue! as AnyObject) {
                    inAllowed = true
                    break
                }
                if !inAllowed {
                    return false
                }
            }
            return true
        }
    }
    return filteredLogs
}

internal func parseReceiptForLogs(receipt: TransactionReceipt, contract: ContractRepresentable, eventName: String, filter: EventFilter?) -> [EventParserResultProtocol]? {
    guard let bloom = receipt.logsBloom else { return nil }
    if contract.address != nil {
        let addressPresent = bloom.test(topic: contract.address!.addressData)
        if addressPresent != true {
            return [EventParserResultProtocol]()
        }
    }
    if filter != nil, let filterAddresses = filter?.addresses {
        var oneIsPresent = false
        for addr in filterAddresses {
            let addressPresent = bloom.test(topic: addr.addressData)
            if addressPresent == true {
                oneIsPresent = true
                break
            }
        }
        if oneIsPresent != true {
            return [EventParserResultProtocol]()
        }
    }
    guard let eventOfSuchTypeIsPresent = contract.testBloomForEventPrecence(eventName: eventName, bloom: bloom) else { return nil }
    if !eventOfSuchTypeIsPresent {
        return [EventParserResultProtocol]()
    }
    var allLogs = receipt.logs
    if contract.address != nil {
        allLogs = receipt.logs.filter({ (log) -> Bool in
            log.address == contract.address
        })
    }
    let decodedLogs = allLogs.compactMap({ (log) -> EventParserResultProtocol? in
        guard let (evName, evData) = contract.parseEvent(log) else { return nil }
        var result = EventParserResult(eventName: evName, transactionReceipt: receipt, contractAddress: log.address, decodedResult: evData)
        result.eventLog = log
        return result
    }).filter { (res: EventParserResultProtocol?) -> Bool in
        return res != nil && res?.eventName == eventName
    }
    var allResults = [EventParserResultProtocol]()
    if filter != nil {
        let eventFilter = filter!
        let filteredLogs = filterLogs(decodedLogs: decodedLogs, eventFilter: eventFilter)
        allResults = filteredLogs
    } else {
        allResults = decodedLogs
    }
    return allResults
}
