// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletABI
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletWeb3
import BigInt
import Kanna

public enum FunctionError: LocalizedError {
    case formPayload
    case formValue
    case postTransaction

    public var errorDescription: String? {
        switch self {
        case .formPayload:
            return "Impossible To Build Configuration! Form Payload missing"
        case .formValue:
            return "Impossible To Build Configuration! Form Value missing"
        case .postTransaction:
            return "Impossible To Build Configuration! Post Transaction"
        }
    }
}

// swiftlint:disable type_body_length
public struct FunctionOrigin {
    public enum FunctionType {
        case functionCall(functionName: String, inputs: [AssetFunctionCall.Argument], output: AssetFunctionCall.ReturnType)
        case functionTransaction(functionName: String, inputs: [AssetFunctionCall.Argument], inputValue: AssetFunctionCall.Argument?)
        case paymentTransaction(inputValue: AssetFunctionCall.Argument)
        //Not actually a function call/invocation. But it fits really well here
        case eventFiltering

        public var isCall: Bool {
            switch self {
            case .functionCall:
                return true
            case .functionTransaction, .paymentTransaction, .eventFiltering:
                return false
            }
        }
        public var isTransaction: Bool {
            switch self {
            case .functionCall, .eventFiltering:
                return false
            case .functionTransaction, .paymentTransaction:
                return true
            }
        }
        public var isFunctionTransaction: Bool {
            switch self {
            case .functionCall, .paymentTransaction, .eventFiltering:
                return false
            case .functionTransaction:
                return true
            }
        }
        public var functionName: String? {
            switch self {
            case .functionCall(let functionName, _, _), .functionTransaction(let functionName, _, _):
                return functionName
            case .paymentTransaction, .eventFiltering:
                return nil
            }
        }
        public var inputs: [AssetFunctionCall.Argument] {
            switch self {
            case .functionCall(_, let inputs, _), .functionTransaction(_, let inputs, _):
                return inputs
            case .paymentTransaction, .eventFiltering:
                return .init()
            }
        }
        public var output: AssetFunctionCall.ReturnType {
            switch self {
            case .functionCall(_, _, let output):
                return output
            case .functionTransaction, .paymentTransaction, .eventFiltering:
                return .init(type: .void)
            }
        }
        public var inputValue: AssetFunctionCall.Argument? {
            switch self {
            case .functionCall, .eventFiltering:
                return nil
            case .functionTransaction(_, _, let inputValue):
                return inputValue
            case .paymentTransaction(let inputValue):
                return inputValue
            }
        }
    }

    public let originContractOrRecipientAddress: AlphaWallet.Address
    private let functionType: FunctionType
    private let bitmask: BigUInt?
    private let bitShift: Int

    public let originElement: XMLElement
    public let xmlContext: XmlContext

    public var inputs: [AssetFunctionCall.Argument] {
        functionType.inputs
    }

    public var inputValue: AssetFunctionCall.Argument? {
        functionType.inputValue
    }

    public init?(forEthereumFunctionTransactionElement ethereumFunctionElement: XMLElement, root: XMLDocument, originContract: AlphaWallet.Address, xmlContext: XmlContext, bitmask: BigUInt?, bitShift: Int) {
        guard let functionName = ethereumFunctionElement["function"].nilIfEmpty else { return nil }
        let inputs: [AssetFunctionCall.Argument]
        if let dataElement = XMLHandler.getDataElement(fromFunctionElement: ethereumFunctionElement, xmlContext: xmlContext) {
            inputs = FunctionOrigin.extractInputs(fromDataElement: dataElement, root: root, xmlContext: xmlContext)
        } else {
            inputs = []
        }
        let value = XMLHandler.getValueElement(fromFunctionElement: ethereumFunctionElement, xmlContext: xmlContext).flatMap { FunctionOrigin.createInput(fromInputElement: $0, root: root, xmlContext: xmlContext, withInputType: .uint) }
        let functionType = FunctionType.functionTransaction(functionName: functionName, inputs: inputs, inputValue: value)
        self = .init(originElement: ethereumFunctionElement, xmlContext: xmlContext, originalContractOrRecipientAddress: originContract, functionType: functionType, bitmask: bitmask, bitShift: bitShift)
    }

    public init?(forEthereumPaymentElement ethereumFunctionElement: XMLElement, root: XMLDocument, recipientAddress: AlphaWallet.Address, xmlContext: XmlContext, bitmask: BigUInt?, bitShift: Int) {
        if let valueElement = XMLHandler.getValueElement(fromFunctionElement: ethereumFunctionElement, xmlContext: xmlContext), let value = FunctionOrigin.createInput(fromInputElement: valueElement, root: root, xmlContext: xmlContext, withInputType: .uint) {
            let functionType = FunctionType.paymentTransaction(inputValue: value)
            self = .init(originElement: ethereumFunctionElement, xmlContext: xmlContext, originalContractOrRecipientAddress: recipientAddress, functionType: functionType, bitmask: bitmask, bitShift: bitShift)
        } else {
            return nil
        }
    }

    public init?(forEthereumFunctionCallElement ethereumFunctionElement: XMLElement, root: XMLDocument, originContract: AlphaWallet.Address, xmlContext: XmlContext, bitmask: BigUInt?, bitShift: Int) {
        guard let functionName = ethereumFunctionElement["function"].nilIfEmpty else { return nil }
        guard let asType: OriginAsType = ethereumFunctionElement["as"].flatMap({ OriginAsType(rawValue: $0) }) else { return nil }
        let inputs: [AssetFunctionCall.Argument]
        let output = AssetFunctionCall.ReturnType(type: asType.solidityReturnType)
        if let dataElement = XMLHandler.getDataElement(fromFunctionElement: ethereumFunctionElement, xmlContext: xmlContext) {
            inputs = FunctionOrigin.extractInputs(fromDataElement: dataElement, root: root, xmlContext: xmlContext)
        } else {
            inputs = []
        }
        let functionType = FunctionType.functionCall(functionName: functionName, inputs: inputs, output: output)
        self = .init(originElement: ethereumFunctionElement, xmlContext: xmlContext, originalContractOrRecipientAddress: originContract, functionType: functionType, bitmask: bitmask, bitShift: bitShift)
    }

    public init(originElement: XMLElement, xmlContext: XmlContext, originalContractOrRecipientAddress: AlphaWallet.Address, functionType: FunctionType, bitmask: BigUInt?, bitShift: Int) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.originContractOrRecipientAddress = originalContractOrRecipientAddress
        self.functionType = functionType
        self.bitmask = bitmask
        self.bitShift = bitShift
    }

    public func extractValue(withTokenId tokenId: TokenId, account: AlphaWallet.Address, server: RPCServer, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], assetAttributeProvider: CallForAssetAttributeProvider) -> AssetInternalValue? {
        guard let functionName = functionType.functionName else { return nil }
        guard let subscribable = callSmartContractFunction(
                tokenId: tokenId,
                attributeAndValues: attributeAndValues,
                localRefs: localRefs,
                account: account,
                server: server,
                originContract: originContractOrRecipientAddress,
                functionName: functionName,
                output: functionType.output,
                assetAttributeProvider: assetAttributeProvider) else { return nil }
        //NOTE: updated with storing cancellable in chainld subscribable to avoid ref cycles, looks like syncAsync might cause it.
        //be careful with cancellables
        let resultSubscribable: Subscribable<AssetInternalValue> = subscribable.mapFirst { value in
            guard let value = value else { return nil }
            if let bitmask = self.bitmask {
                return self.castReturnValue(value: value, bitmask: bitmask)
            } else {
                return value
            }
        }

        return .subscribable(resultSubscribable)
    }

    private func castReturnValue(value: AssetInternalValue, bitmask: BigUInt) -> AssetInternalValue {
        switch value {
        case .uint(let value):
            return .uint(BigUInt((bitmask & value) >> bitShift))
        case .int(let value):
            return .int(BigInt((bitmask & BigUInt(value)) >> bitShift))
        case .bytes(let value):
            let shiftedValue = BigUInt((bitmask & BigUInt(value)) >> bitShift)
            return .bytes(shiftedValue.serialize())
        case .address, .string, .subscribable, .bool, .generalisedTime, .openSeaNonFungibleTraits:
            return value
        }
    }

    //We encode slightly differently depending on whether the function is a call or a transaction. Specifically addresses should be a string (actually EthereumAddress would do too, but we don't it so we don't have to import the framework here) for calls, which uses Web3Swift, and Address for calls (which uses vendored TrustCore)
    private func formArguments(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], account: AlphaWallet.Address) -> [AnyObject]? {
        let arguments: [AnyObject] = functionType.inputs.compactMap {
            switch $0 {
            case .ref(let ref, let solidityType), .cardRef(let ref, let solidityType):
                let ref = AssetFunctionCall.ArgumentReferences(string: ref)
                switch ref {
                case .ownerAddress:
                    return AssetAttributeValueUsableAsFunctionArguments.address(account).coerce(toArgumentType: solidityType, forFunctionType: functionType)
                case .tokenId, .tokenID:
                    return AssetAttributeValueUsableAsFunctionArguments.uint(tokenId).coerce(toArgumentType: solidityType, forFunctionType: functionType)
                case .attribute(let attributeId):
                    let availableAttributes = AssetAttributeValueUsableAsFunctionArguments.dictionary(fromAssetAttributeKeyValues: attributeAndValues)
                    guard let value = availableAttributes[attributeId] else { return nil }
                    return value.coerce(toArgumentType: solidityType, forFunctionType: functionType)
                }
            case .prop(let ref, let solidityType):
                let availableAttributes = AssetAttributeValueUsableAsFunctionArguments.dictionary(fromAssetAttributeKeyValues: localRefs)
                guard let value = availableAttributes[ref] else { return nil }
                return value.coerce(toArgumentType: solidityType, forFunctionType: functionType)
            case .value(let value, let solidityType):
                return AssetAttributeValueUsableAsFunctionArguments.string(value).coerce(toArgumentType: solidityType, forFunctionType: functionType)
            }
        }
        guard arguments.count == functionType.inputs.count else { return nil }
        return arguments
    }

    private func formTransactionPayload(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, account: AlphaWallet.Address) -> (data: Data, function: DecodedFunctionCall)? {
        assert(functionType.isFunctionTransaction)
        guard let functionName = functionType.functionName else { return nil }
        guard let arguments = formArguments(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, account: account) else { return nil }
        let parameters = functionType.inputs.map { $0.abiType }
        let functionEncoder = Function(name: functionName, parameters: parameters)
        let encoder = ABIEncoder()
        do {
            try encoder.encode(function: functionEncoder, arguments: arguments)
            let data = encoder.data
            let argumentsMetaData: [FunctionCall.Argument] = Array(zip(parameters, arguments)).map { .init(type: $0, value: $1) }
            let functionCallMetaData: DecodedFunctionCall = .init(name: functionName, arguments: argumentsMetaData)
            return (data: data, function: functionCallMetaData)
        } catch {
            return nil
        }
    }

    private func formValue(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer) -> BigUInt? {
        guard let value = functionType.inputValue else { return nil }
        switch value {
        case .ref(let ref, let solidityType), .cardRef(let ref, let solidityType):
            let ref = AssetFunctionCall.ArgumentReferences(string: ref)
            switch ref {
            case .ownerAddress:
                return nil
            case .tokenId, .tokenID:
                return nil
            case .attribute(let attributeId):
                let availableAttributes = AssetAttributeValueUsableAsFunctionArguments.dictionary(fromAssetAttributeKeyValues: attributeAndValues)
                guard let value = availableAttributes[attributeId] else { return nil }
                return (value.coerce(toArgumentType: solidityType, forFunctionType: functionType) as? BigUInt)
            }
        case .prop(let ref, let solidityType):
            let availableAttributes = AssetAttributeValueUsableAsFunctionArguments.dictionary(fromAssetAttributeKeyValues: localRefs)
            guard let value = availableAttributes[ref] else { return nil }
            return (value.coerce(toArgumentType: solidityType, forFunctionType: functionType) as? BigUInt)
        case .value(let value, let solidityType):
            return (AssetAttributeValueUsableAsFunctionArguments.string(value).coerce(toArgumentType: solidityType, forFunctionType: functionType) as? BigUInt)
        }
    }

    //TODO check tokenServer and server are the same
    public func makeUnConfirmedTransaction(tokenServer: RPCServer, tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, wallet: AlphaWallet.Address) throws -> TokenScriptUnconfirmedTransaction {
        assert(functionType.isTransaction)
        let payload: Data
        let value: BigUInt
        let functionCallMetaData: DecodedFunctionCall
        switch functionType {
        case .functionCall, .eventFiltering:
            throw FunctionError.postTransaction
        case .paymentTransaction:
            payload = .init()
            guard let val = formValue(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server) else {
                throw FunctionError.formValue
            }
            functionCallMetaData = .nativeCryptoTransfer(value: val)
            value = val
        case .functionTransaction:
            guard let (data, metadata) = formTransactionPayload(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server, account: wallet) else {
                throw FunctionError.formPayload
            }
            payload = data
            functionCallMetaData = metadata
            value = formValue(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server) ?? 0
        }
        return TokenScriptUnconfirmedTransaction(server: tokenServer, value: value, recipient: nil, contract: originContractOrRecipientAddress, data: payload, decodedFunctionCall: functionCallMetaData)
    }

    public func generateDataAndValue(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, wallet: AlphaWallet.Address) -> (Data?, BigUInt)? {
        assert(functionType.isTransaction)
        let payload: Data?
        let value: BigUInt
        switch functionType {
        case .functionCall, .eventFiltering:
            return nil
        case .paymentTransaction:
            payload = nil
            guard let val = formValue(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server) else { return nil }
            value = val
        case .functionTransaction:
            guard let (data, _) = formTransactionPayload(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server, account: wallet) else { return nil }
            payload = data
            value = formValue(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server) ?? 0
        }
        return (payload, value)
    }

    fileprivate static func extractInputs(fromDataElement dataElement: XMLElement, root: XMLDocument, xmlContext: XmlContext) -> [AssetFunctionCall.Argument] {
        return XMLHandler.getInputs(fromDataElement: dataElement).compactMap {
            guard let inputType = $0.tagName.nilIfEmpty.flatMap({ SolidityType(rawValue: $0) }) else { return nil }
            return createInput(fromInputElement: $0, root: root, xmlContext: xmlContext, withInputType: inputType)
        }
    }

    fileprivate static func createInput(fromInputElement inputElement: XMLElement, root: XMLDocument, xmlContext: XmlContext, withInputType inputType: SolidityType) -> AssetFunctionCall.Argument? {
        if let inputName = inputElement["ref"].nilIfEmpty {
            return .ref(ref: inputName, type: inputType)
        } else if let inputName = inputElement["local-ref"].nilIfEmpty {
            let attributes = XMLHandler.getActionCardAttributeElements(fromRoot: root, xmlContext: xmlContext)
            let attributeNames = attributes.compactMap { $0["name"] }
            if attributeNames.contains(inputName) {
                return .cardRef(ref: inputName, type: inputType)
            } else {
                return .prop(ref: inputName, type: inputType)
            }
        } else if let value = inputElement.text.nilIfEmpty {
            return .value(value: value, type: inputType)
        } else {
            return nil
        }
    }

    private func callSmartContractFunction(
            tokenId: TokenId,
            attributeAndValues: [AttributeId: AssetInternalValue],
            localRefs: [AttributeId: AssetInternalValue],
            account: AlphaWallet.Address,
            server: RPCServer,
            originContract: AlphaWallet.Address,
            functionName: String,
            output: AssetFunctionCall.ReturnType,
            assetAttributeProvider: CallForAssetAttributeProvider
    ) -> Subscribable<AssetInternalValue>? {
        assert(functionType.isCall)
        guard let arguments = formArguments(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, account: account) else { return nil }
        guard let functionName = functionType.functionName else { return nil }
        let functionCall = AssetFunctionCall(server: server, contract: originContract, functionName: functionName, inputs: functionType.inputs, output: output, arguments: arguments)

        //ENS token is treated as ERC721 because it is picked up from OpenSea. But it doesn't respond to `name` and `symbol`. Calling them is harmless but causes node errors that can be confusing "execution reverted" when looking at logs
        if ["name", "symbol"].contains(functionCall.functionName) && functionCall.contract == Constants.ensContractOnMainnet {
            return Subscribable<AssetInternalValue>(value: nil)
        }

        return assetAttributeProvider.getValue(functionCall: functionCall)
    }
}
// swiftlint:enable type_body_length
