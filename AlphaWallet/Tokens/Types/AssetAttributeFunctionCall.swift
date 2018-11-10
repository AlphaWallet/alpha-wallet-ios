// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct AssetAttributeFunctionCall: Equatable, Hashable {
    let server: RPCServer
    let contract: String
    let functionName: String
    let inputs: [CallForAssetAttribute.Argument]
    let output: CallForAssetAttribute.ReturnType
    let arguments: [AnyObject]
    //To avoid handling Equatable and Hashable, we'll just store the arguments' description
    private let argumentsDescription: String

    var hashValue: Int {
        return contract.hashValue ^ functionName.hashValue ^ inputs.count ^ output.type.rawValue.hashValue ^ argumentsDescription.hashValue ^ server.chainID
    }

    static func ==(lhs: AssetAttributeFunctionCall, rhs: AssetAttributeFunctionCall) -> Bool {
        return lhs.contract == rhs.contract && lhs.functionName == rhs.functionName && lhs.inputs == rhs.inputs && lhs.output.type == rhs.output.type && lhs.argumentsDescription == rhs.argumentsDescription && lhs.server.chainID == rhs.server.chainID
    }

    init(server: RPCServer, contract: String, functionName: String, inputs: [CallForAssetAttribute.Argument], output: CallForAssetAttribute.ReturnType, arguments: [AnyObject]) {
        self.server = server
        self.contract = contract
        self.functionName = functionName
        self.inputs = inputs
        self.output = output
        self.arguments = arguments
        self.argumentsDescription = arguments.description
    }
}
