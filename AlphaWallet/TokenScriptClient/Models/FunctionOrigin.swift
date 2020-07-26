// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Kanna
import PromiseKit

enum FunctionError: LocalizedError {
    case formPayload
    case formValue
    case postTransaction
}

struct FunctionOrigin {
    enum FunctionType {
        case functionCall(functionName: String, inputs: [AssetFunctionCall.Argument], output: AssetFunctionCall.ReturnType)
        case functionTransaction(functionName: String, inputs: [AssetFunctionCall.Argument], inputValue: AssetFunctionCall.Argument?)
        case paymentTransaction(inputValue: AssetFunctionCall.Argument)
        //Not actually a function call/invocation. But it fits really well here
        case eventFiltering

        var isCall: Bool {
            switch self {
            case .functionCall:
                return true
            case .functionTransaction, .paymentTransaction, .eventFiltering:
                return false
            }
        }
        var isTransaction: Bool {
            switch self {
            case .functionCall, .eventFiltering:
                return false
            case .functionTransaction, .paymentTransaction:
                return true
            }
        }
        var isFunctionTransaction: Bool {
            switch self {
            case .functionCall, .paymentTransaction, .eventFiltering:
                return false
            case .functionTransaction:
                return true
            }
        }
        var functionName: String? {
            switch self {
            case .functionCall(let functionName, _, _), .functionTransaction(let functionName, _, _):
                return functionName
            case .paymentTransaction, .eventFiltering:
                return nil
            }
        }
        var inputs: [AssetFunctionCall.Argument] {
            switch self {
            case .functionCall(_, let inputs, _), .functionTransaction(_, let inputs, _):
                return inputs
            case .paymentTransaction, .eventFiltering:
                return .init()
            }
        }
        var output: AssetFunctionCall.ReturnType {
            switch self {
            case .functionCall(_, _, let output):
                return output
            case .functionTransaction, .paymentTransaction, .eventFiltering:
                return .init(type: .void)
            }
        }
        var inputValue: AssetFunctionCall.Argument? {
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

    private let attributeId: AttributeId
    private let functionType: FunctionType
    private let bitmask: BigUInt?
    private let bitShift: Int

    let originContractOrRecipientAddress: AlphaWallet.Address
    let originElement: XMLElement
    let xmlContext: XmlContext

    var inputs: [AssetFunctionCall.Argument] {
        functionType.inputs
    }

    var inputValue: AssetFunctionCall.Argument? {
        functionType.inputValue
    }

    init?(forEthereumFunctionTransactionElement ethereumFunctionElement: XMLElement, root: XMLDocument, attributeId: AttributeId, originContract: AlphaWallet.Address, xmlContext: XmlContext, bitmask: BigUInt?, bitShift: Int) {
        guard let functionName = ethereumFunctionElement["function"].nilIfEmpty else { return nil }
        let inputs: [AssetFunctionCall.Argument]
        if let dataElement = XMLHandler.getDataElement(fromFunctionElement: ethereumFunctionElement, xmlContext: xmlContext) {
            inputs = FunctionOrigin.extractInputs(fromDataElement: dataElement, root: root, xmlContext: xmlContext)
        } else {
            inputs = []
        }
        let value = XMLHandler.getValueElement(fromFunctionElement: ethereumFunctionElement, xmlContext: xmlContext).flatMap { FunctionOrigin.createInput(fromInputElement: $0, root: root, xmlContext: xmlContext, withInputType: .uint) }
        let functionType = FunctionType.functionTransaction(functionName: functionName, inputs: inputs, inputValue: value)
        self = .init(originElement: ethereumFunctionElement, xmlContext: xmlContext, originalContractOrRecipientAddress: originContract, attributeId: attributeId, functionType: functionType, bitmask: bitmask, bitShift: bitShift)
    }

    init?(forEthereumPaymentElement ethereumFunctionElement: XMLElement, root: XMLDocument, attributeId: AttributeId, recipientAddress: AlphaWallet.Address, xmlContext: XmlContext, bitmask: BigUInt?, bitShift: Int) {
        if let valueElement = XMLHandler.getValueElement(fromFunctionElement: ethereumFunctionElement, xmlContext: xmlContext), let value = FunctionOrigin.createInput(fromInputElement: valueElement, root: root, xmlContext: xmlContext, withInputType: .uint) {
            let functionType = FunctionType.paymentTransaction(inputValue: value)
            self = .init(originElement: ethereumFunctionElement, xmlContext: xmlContext, originalContractOrRecipientAddress: recipientAddress, attributeId: attributeId, functionType: functionType, bitmask: bitmask, bitShift: bitShift)
        } else {
            return nil
        }
    }

    init?(forEthereumFunctionCallElement ethereumFunctionElement: XMLElement, root: XMLDocument, attributeName: AttributeId, originContract: AlphaWallet.Address, xmlContext: XmlContext, bitmask: BigUInt?, bitShift: Int) {
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
        self = .init(originElement: ethereumFunctionElement, xmlContext: xmlContext, originalContractOrRecipientAddress: originContract, attributeId: attributeName, functionType: functionType, bitmask: bitmask, bitShift: bitShift)
    }

    init(originElement: XMLElement, xmlContext: XmlContext, originalContractOrRecipientAddress: AlphaWallet.Address, attributeId: AttributeId, functionType: FunctionType, bitmask: BigUInt?, bitShift: Int) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.originContractOrRecipientAddress = originalContractOrRecipientAddress
        self.attributeId = attributeId
        self.functionType = functionType
        self.bitmask = bitmask
        self.bitShift = bitShift
    }

    func extractValue(withTokenId tokenId: TokenId, account: Wallet, server: RPCServer, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator) -> AssetInternalValue? {
        guard let functionName = functionType.functionName else { return nil }
        guard let subscribable = callSmartContractFunction(
                forAttributeId: attributeId,
                tokenId: tokenId,
                attributeAndValues: attributeAndValues,
                localRefs: localRefs,
                account: account,
                server: server,
                originContract: originContractOrRecipientAddress,
                functionName: functionName,
                output: functionType.output,
                callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) else { return nil }
        let resultSubscribable = Subscribable<AssetInternalValue>(nil)
        subscribable.subscribe { value in
            guard let value = value else { return }
            if let bitmask = self.bitmask {
                resultSubscribable.value = self.castReturnValue(value: value, bitmask: bitmask)
            } else {
                resultSubscribable.value = value
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

    private func postTransaction(withPayload payload: Data, value: BigUInt, server: RPCServer, session: WalletSession, keystore: Keystore) -> Promise<SentTransaction> {
        let account = try! EtherKeystore().getAccount(for: session.account.address)!
        return Promise { seal in
            TransactionConfigurator.estimateGasPrice(server: server).done { gasPrice in
                //Note: since we have the data payload, it is unnecessary to load an UnconfirmedTransaction struct
                let transactionToSign = UnsignedTransaction(
                        value: BigInt(value),
                        account: account,
                        to: self.originContractOrRecipientAddress,
                        nonce: -1,
                        data: payload,
                        gasPrice: gasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        server: server
                )
                let sendTransactionCoordinator = SendTransactionCoordinator(
                        session: session,
                        keystore: keystore,
                        confirmType: .signThenSend
                )
                sendTransactionCoordinator.send(transaction: transactionToSign) { result in
                    switch result {
                    case .success(let confirmResult):
                        switch confirmResult {
                        case .signedTransaction:
                            //Impossible to reach here
                            seal.reject(FunctionError.postTransaction)
                        case .sentTransaction(let transaction):
                            seal.fulfill(transaction)
                        }
                    case .failure:
                        seal.reject(FunctionError.postTransaction)
                    }
                }
            }.cauterize()
        }
    }

    //We encode slightly differently depending on whether the function is a call or a transaction. Specifically addresses should be a string (actually EthereumAddress would do too, but we don't it so we don't have to import the framework here) for calls, which uses Web3Swift, and Address for calls (which uses vendored TrustCore)
    private func formArguments(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], account: Wallet) -> [AnyObject]? {
        let arguments: [AnyObject] = functionType.inputs.compactMap {
            switch $0 {
            case .ref(let ref, let solidityType), .cardRef(let ref, let solidityType):
                let ref = AssetFunctionCall.ArgumentReferences(string: ref)
                switch ref {
                case .ownerAddress:
                    return AssetAttributeValueUsableAsFunctionArguments.address(account.address).coerce(toArgumentType: solidityType, forFunctionType: functionType)
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

    private func formTransactionPayload(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, account: Wallet) -> Data? {
        assert(functionType.isFunctionTransaction)
        guard let functionName = functionType.functionName else { return nil }
        guard let arguments = formArguments(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, account: account) else { return nil }
        let parameters = functionType.inputs.map { $0.abiType }
        let functionEncoder = Function(name: functionName, parameters: parameters)
        let encoder = ABIEncoder()
        do {
            try encoder.encode(function: functionEncoder, arguments: arguments)
            let data = encoder.data
            return data
        } catch {
            return nil
        }
    }

    private func formValue(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, account: Wallet) -> BigUInt? {
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

    //TODO duplicated from InCoordinator.importPaidSignedOrder. Extract
    func postTransaction(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore) -> Promise<SentTransaction> {
        assert(functionType.isTransaction)
        let payload: Data
        let value: BigUInt
        switch functionType {
        case .functionCall, .eventFiltering:
            return .init(error: FunctionError.postTransaction)
        case .paymentTransaction:
            payload = .init()
            guard let val = formValue(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server, account: session.account) else { return .init(error: FunctionError.formValue) }
            value = val
        case .functionTransaction:
            guard let data = formTransactionPayload(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server, account: session.account) else { return .init(error: FunctionError.formPayload) }
            payload = data
            value = formValue(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server, account: session.account) ?? 0
        }
        return postTransaction(withPayload: payload, value: value, server: server, session: session, keystore: keystore)
    }

    func generateDataAndValue(withTokenId tokenId: TokenId, attributeAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore) -> (Data?, BigUInt)? {
        assert(functionType.isTransaction)
        let payload: Data?
        let value: BigUInt
        switch functionType {
        case .functionCall, .eventFiltering:
            return nil
        case .paymentTransaction:
            payload = nil
            guard let val = formValue(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server, account: session.account) else { return nil }
            value = val
        case .functionTransaction:
            guard let data = formTransactionPayload(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server, account: session.account) else { return nil }
            payload = data
            value = formValue(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, server: server, account: session.account) ?? 0
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
            forAttributeId attributeId: AttributeId,
            tokenId: TokenId,
            attributeAndValues: [AttributeId: AssetInternalValue],
            localRefs: [AttributeId: AssetInternalValue],
            account: Wallet,
            server: RPCServer,
            originContract: AlphaWallet.Address,
            functionName: String,
            output: AssetFunctionCall.ReturnType,
            callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator
    ) -> Subscribable<AssetInternalValue>? {
        assert(functionType.isCall)
        guard let arguments = formArguments(withTokenId: tokenId, attributeAndValues: attributeAndValues, localRefs: localRefs, account: account) else { return nil }
        guard let functionName = functionType.functionName else { return nil }
        let functionCall = AssetFunctionCall(server: server, contract: originContract, functionName: functionName, inputs: functionType.inputs, output: output, arguments: arguments)
        return callForAssetAttributeCoordinator.getValue(forAttributeId: attributeId, tokenId: tokenId, functionCall: functionCall)
    }
}
