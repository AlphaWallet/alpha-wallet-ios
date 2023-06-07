// Copyright © 2022 Stormbird PTE. LTD.

public enum CheckEIP681Error: Error, CustomStringConvertible {
    case configurationInvalid
    case contractInvalid
    case parameterInvalid
    case missingRpcServer
    case serverNotEnabled
    case tokenTypeNotSupported
    case notEIP681
    case embeded(error: Error)

    public var description: String {
        switch self {
        case .configurationInvalid:
            return "configurationInvalid"
        case .contractInvalid:
            return "contractInvalid"
        case .parameterInvalid:
            return "parameterInvalid"
        case .missingRpcServer:
            return "missingRpcServer"
        case .tokenTypeNotSupported:
            return "tokenTypeNotSupported"
        case .notEIP681:
            return "notEIP681"
        case .serverNotEnabled:
            return "serverNotEnabled"
        case .embeded(let error):
            return "embedded: \(error)"
        }
    }
}
