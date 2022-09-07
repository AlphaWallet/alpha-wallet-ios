// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

public struct CallForAssetAttribute {
    static private let abiTemplate: [String: Any] = [
        "type": "function",
        "name": "<to provide>",
        "inputs": "<to provide>",
        "outputs": "<to provide>",
        "payable": false,
        "stateMutability": "view",
        "constant": true
    ]

    public let abi: String
    public let name: String

    public init?(functionName: String, inputs: [AssetFunctionCall.Argument], output: AssetFunctionCall.ReturnType) {
        var abiDictionary = CallForAssetAttribute.abiTemplate
        abiDictionary["name" ] = functionName
        abiDictionary["inputs"] = inputs.map {
            [
                "name": "",
                "type": $0.type.rawValue,
            ]
        }
        abiDictionary["outputs"] = [
            [
                "name": "",
                "type": output.type.rawValue,
            ]
        ] as [[String: String]]
        name = functionName
        guard let data = try? JSONSerialization.data(withJSONObject: abiDictionary, options: .prettyPrinted), let abi = String(data: data, encoding: .utf8) else { return nil }
        self.abi = abi
    }
}
