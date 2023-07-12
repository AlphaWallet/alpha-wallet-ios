// Copyright © 2023 Stormbird PTE. LTD.

import XCTest
import AlphaWalletWeb3
@testable import AlphaWalletFoundation

class CallSmartContractFunctionTests: XCTestCase {
    //This is important to assert that the caching key is different event whe the event is the same, because we use the same ERC1155 transfer event for both checking send and receive events
    func testEventLogCachingKey() {
        let contractAddress = AlphaWallet.Address(string: "0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362")!
        let server = RPCServer.main
        let eventName = "TransferSingle"
        let abiString = AlphaWallet.Ethereum.ABI.erc1155
        let nullFilter: [EventFilterable]? = nil
        let recipientAddress = EthereumAddress(AlphaWallet.Address(string: "0x3EA245FC5909A55e426a2C044Aa4b48a143F9819")!.eip55String)!
        let sendParameterFilters: [[EventFilterable]?] = [nullFilter, [recipientAddress], nullFilter]
        let receiveParameterFilters: [[EventFilterable]?] = [nullFilter, nullFilter, [recipientAddress]]
        let sendFilter = EventFilter(fromBlock: .blockNumber(0), toBlock: .blockNumber(100), addresses: nil, parameterFilters: sendParameterFilters)
        let receiveFilter = EventFilter(fromBlock: .blockNumber(0), toBlock: .blockNumber(100), addresses: nil, parameterFilters: receiveParameterFilters)
        let sendCachingKey = GetEventLogs.generateEventLogCachingKey(contractAddress: contractAddress, server: server, eventName: eventName, abiString: abiString, filter: sendFilter)
        let receiveCachingKey = GetEventLogs.generateEventLogCachingKey(contractAddress: contractAddress, server: server, eventName: eventName, abiString: abiString, filter: receiveFilter)
        XCTAssertNotEqual(sendCachingKey, receiveCachingKey)
    }
}
