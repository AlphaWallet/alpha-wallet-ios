// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct AssetFunctionCall: Equatable, Hashable {
    enum ArgumentReferences {
        case ownerAddress
        case tokenId
        //TODO might be good to remove TokenID to be stricter?
        case tokenID
        case attribute(AttributeId)

        init(string: AttributeId) {
            switch string {
            case "ownerAddress":
                self = .ownerAddress
            case "tokenId":
                self = .tokenId
            case "tokenID":
                self = .tokenID
            default:
                self = .attribute(string)
            }
        }
    }

    enum Argument: Equatable {
        case ref(ref: String, type: SolidityType)
        case value(value: String, type: SolidityType)

        var type: SolidityType {
            switch self {
            case .ref(_, let type), .value(_, let type):
                return type
            }
        }

        var abiType: ABIType {
            switch type {
            case .address:
                return .address
            case .bool:
                return .bool
            case .int:
                return .int(bits: 256)
            case .int8:
                return .int(bits: 8)
            case .int16:
                return .int(bits: 16)
            case .int24:
                return .int(bits: 24)
            case .int32:
                return .int(bits: 32)
            case .int40:
                return .int(bits: 40)
            case .int48:
                return .int(bits: 48)
            case .int56:
                return .int(bits: 56)
            case .int64:
                return .int(bits: 64)
            case .int72:
                return .int(bits: 72)
            case .int80:
                return .int(bits: 80)
            case .int88:
                return .int(bits: 88)
            case .int96:
                return .int(bits: 96)
            case .int104:
                return .int(bits: 104)
            case .int112:
                return .int(bits: 112)
            case .int120:
                return .int(bits: 120)
            case .int128:
                return .int(bits: 128)
            case .int136:
                return .int(bits: 136)
            case .int144:
                return .int(bits: 144)
            case .int152:
                return .int(bits: 152)
            case .int160:
                return .int(bits: 160)
            case .int168:
                return .int(bits: 168)
            case .int176:
                return .int(bits: 176)
            case .int184:
                return .int(bits: 184)
            case .int192:
                return .int(bits: 192)
            case .int200:
                return .int(bits: 200)
            case .int208:
                return .int(bits: 208)
            case .int216:
                return .int(bits: 216)
            case .int224:
                return .int(bits: 224)
            case .int232:
                return .int(bits: 232)
            case .int240:
                return .int(bits: 240)
            case .int248:
                return .int(bits: 248)
            case .int256:
                return .int(bits: 256)
            case .string:
                return .string
            case .uint:
                return .uint(bits: 256)
            case .uint8:
                return .uint(bits: 8)
            case .uint16:
                return .uint(bits: 16)
            case .uint24:
                return .uint(bits: 24)
            case .uint32:
                return .uint(bits: 32)
            case .uint40:
                return .uint(bits: 40)
            case .uint48:
                return .uint(bits: 48)
            case .uint56:
                return .uint(bits: 56)
            case .uint64:
                return .uint(bits: 64)
            case .uint72:
                return .uint(bits: 72)
            case .uint80:
                return .uint(bits: 80)
            case .uint88:
                return .uint(bits: 88)
            case .uint96:
                return .uint(bits: 96)
            case .uint104:
                return .uint(bits: 104)
            case .uint112:
                return .uint(bits: 112)
            case .uint120:
                return .uint(bits: 120)
            case .uint128:
                return .uint(bits: 128)
            case .uint136:
                return .uint(bits: 136)
            case .uint144:
                return .uint(bits: 144)
            case .uint152:
                return .uint(bits: 152)
            case .uint160:
                return .uint(bits: 160)
            case .uint168:
                return .uint(bits: 168)
            case .uint176:
                return .uint(bits: 176)
            case .uint184:
                return .uint(bits: 184)
            case .uint192:
                return .uint(bits: 192)
            case .uint200:
                return .uint(bits: 200)
            case .uint208:
                return .uint(bits: 208)
            case .uint216:
                return .uint(bits: 216)
            case .uint224:
                return .uint(bits: 224)
            case .uint232:
                return .uint(bits: 232)
            case .uint240:
                return .uint(bits: 240)
            case .uint248:
                return .uint(bits: 248)
            case .uint256:
                return .uint(bits: 256)
            case .void:
                //Should be impossible
                return .bool
            }
        }
    }

    struct ReturnType {
        let type: SolidityType
    }

    let server: RPCServer
    let contract: AlphaWallet.Address
    let functionName: String
    let inputs: [Argument]
    let output: ReturnType
    let arguments: [AnyObject]
    //To avoid handling Equatable and Hashable, we'll just store the arguments' description
    private let argumentsDescription: String

    var hashValue: Int {
        return contract.eip55String.hashValue ^ functionName.hashValue ^ inputs.count ^ output.type.rawValue.hashValue ^ argumentsDescription.hashValue ^ server.chainID
    }

    static func == (lhs: AssetFunctionCall, rhs: AssetFunctionCall) -> Bool {
        return lhs.contract == rhs.contract && lhs.functionName == rhs.functionName && lhs.inputs == rhs.inputs && lhs.output.type == rhs.output.type && lhs.argumentsDescription == rhs.argumentsDescription && lhs.server.chainID == rhs.server.chainID
    }

    init(server: RPCServer, contract: AlphaWallet.Address, functionName: String, inputs: [Argument], output: ReturnType, arguments: [AnyObject]) {
        self.server = server
        self.contract = contract
        self.functionName = functionName
        self.inputs = inputs
        self.output = output
        self.arguments = arguments
        self.argumentsDescription = arguments.description
    }
}
