// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct CallForAssetAttribute {
    enum SolidityType: String {
        //TODO do we need to support the "odd" ones like uint24 in all steps of 8?
        //TODO support address, enums, etc?
        case bool
        case int
        case int8
        case int16
        case int32
        case int64
        case int128
        case int256
        case uint
        case uint8
        case uint16
        case uint32
        case uint64
        case uint128
        case uint256
        case string
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

