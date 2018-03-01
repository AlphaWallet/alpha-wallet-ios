import Foundation

struct ContractStormBirdTransfer: Web3Request {
    
    typealias Response = String
    let address: String
    let indices: [UInt16]
    
    var type: Web3RequestType {
        let abi = "{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"ticketIndices\",\"type\":\"uint16[]\"}],\"name\":\"transfer\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"} , [\"\(address)\", \(indices)]"
        let run = "web3.eth.abi.encodeFunctionCall(" + abi + ")"
        return .script(command: run)
    }
}
