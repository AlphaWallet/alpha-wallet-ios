// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct CallForAssetAttribute {
    enum SolidityType: String {
        case bool
        case int
        case string
        case uint256
    }

    struct Argument: Equatable {
        let name: String
        let type: SolidityType
    }

    struct ReturnType {
        let type: SolidityType
    }

    static private let abiTemplate: [String: Any] = [
        "type" : "function",
        "name" : "<to provide>",
        "inputs" : "<to provide>",
        "outputs" : "<to provide>",
        "payable" : false,
        "stateMutability" : "view",
        "constant" : true
    ]

    let abi: String
    let name: String

    init?(functionName: String, inputs: [Argument], output: ReturnType) {
        var abiDictionary = CallForAssetAttribute.abiTemplate
        abiDictionary["name" ] = functionName
        abiDictionary["inputs"] = inputs.map {
            [
                "name": $0.name,
                "type": $0.type.rawValue,
            ]
        }
        abiDictionary["outputs"] = [
            [
                "name": "",
                "type": output.type.rawValue,
            ]
        ] as Array<[String: String]>
        name = functionName
        guard let data = try? JSONSerialization.data(withJSONObject: abiDictionary, options: .prettyPrinted), let abi = String(data: data, encoding: .utf8) else { return nil}
        self.abi = abi
    }
}

