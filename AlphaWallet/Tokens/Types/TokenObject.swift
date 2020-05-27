// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift
import BigInt

class TokenObject: Object {
    static func generatePrimaryKey(fromContract contract: AlphaWallet.Address, server: RPCServer) -> String {
        return "\(contract.eip55String)-\(server.chainID)"
    }

    @objc dynamic var primaryKey: String = ""
    @objc dynamic var chainId: Int = 0
    @objc dynamic var contract: String = Constants.nullAddress.eip55String
    @objc dynamic var name: String = ""
    @objc dynamic var symbol: String = ""
    @objc dynamic var decimals: Int = 0
    @objc dynamic var value: String = ""
    @objc dynamic var isDisabled: Bool = false
    @objc dynamic var rawType: String = TokenType.erc20.rawValue
    @objc dynamic var shouldDisplay: Bool = true
    var sortIndex = RealmOptional<Int>()
    let balance = List<TokenBalance>()

    var nonZeroBalance: [TokenBalance] {
        return Array(balance.filter { isNonZeroBalance($0.balance) })
    }

    var type: TokenType {
        get {
            return TokenType(rawValue: rawType)!
        }
        set {
            rawType = newValue.rawValue
        }
    }

    convenience init(
            contract: AlphaWallet.Address = Constants.nullAddress,
            server: RPCServer,
            name: String = "",
            symbol: String = "",
            decimals: Int = 0,
            value: String,
            isCustom: Bool = false,
            isDisabled: Bool = false,
            type: TokenType
    ) {
        self.init()
        self.primaryKey = TokenObject.generatePrimaryKey(fromContract: contract, server: server)
        self.contract = contract.eip55String
        self.chainId = server.chainID
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.value = value
        self.isDisabled = isDisabled
        self.type = type
    }

    var contractAddress: AlphaWallet.Address {
        get {
            return AlphaWallet.Address(uncheckedAgainstNullAddress: contract)!
        }
        set {
            contract = contractAddress.eip55String
        }
    }

    var valueBigInt: BigInt {
        return BigInt(value) ?? BigInt()
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

    override static func ignoredProperties() -> [String] {
        return ["type"]
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? TokenObject else { return false }
        return object.contractAddress.sameContract(as: contractAddress)
    }

    func title(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let localizedNameFromAssetDefinition = XMLHandler(contract: contractAddress, assetDefinitionStore: assetDefinitionStore).getName(fallback: name)
        return title(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
    }

    func titleInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let localizedNameFromAssetDefinition = XMLHandler(contract: contractAddress, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm(fallback: name)
        return title(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
    }

    private func title(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore, localizedNameFromAssetDefinition: String) -> String {
        let compositeName = compositeTokenName(forContract: contractAddress, fromContractName: name, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
        if compositeName.isEmpty {
            return symbol
        } else {
            let daiSymbol = "DAI\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
            //We could have just trimmed away all trailing \0, but this is faster and safer since only DAI seems to have this problem
            if daiSymbol == symbol {
                return "\(compositeName) (DAI)"
            } else {
                return "\(compositeName) (\(symbol))"
            }

        }
    }

    var isERC721AndNotForTickets: Bool {
        switch type {
        case .erc721:
            return true
        case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            return false
        }
    }

    var server: RPCServer {
        return .init(chainID: chainId)
    }
}

func isNonZeroBalance(_ balance: String) -> Bool {
    return !isZeroBalance(balance)
}

func isZeroBalance(_ balance: String) -> Bool {
    if balance == Constants.nullTokenId || balance == "0" {
        return true
    }
    return false
}

func compositeTokenName(forContract contract: AlphaWallet.Address, fromContractName contractName: String, localizedNameFromAssetDefinition: String) -> String {
    let compositeName: String
    //TODO improve and remove the check for "N/A". Maybe a constant
    //Special case for FIFA tickets, otherwise, we just show the name from the XML
    if contract.isFifaTicketcontract {
        if contractName.isEmpty {
            compositeName = localizedNameFromAssetDefinition
        } else {
            compositeName = "\(contractName) \(localizedNameFromAssetDefinition)"
        }
    } else {
        compositeName = localizedNameFromAssetDefinition
    }
    return compositeName
}
