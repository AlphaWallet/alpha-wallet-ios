// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift
import BigInt

extension Activity {

    struct AssignedToken: Equatable {

        struct TokenBalance {
            var balance = "0"
            var json: String = "{}"
        }

        enum Balance {
            case value(BigInt)
            case balance([TokenBalance])
            case none

            var isEmpty: Bool {
                switch self {
                case .balance(let values):
                    return values.isEmpty
                case .value(let value):
                    return value.isZero
                case .none:
                    return true
                }
            }
        }

        var primaryKey: String
        var contractAddress: AlphaWallet.Address
        var symbol: String
        var decimals: Int
        var server: RPCServer
        var icon: Subscribable<TokenImage>
        var type: TokenType
        var name: String
        var balance: Balance
        var shouldDisplay: Bool
        var sortIndex: Int?

        init(tokenObject: TokenObject) {
            name = tokenObject.name
            primaryKey = tokenObject.primaryKey
            server = tokenObject.server
            contractAddress = tokenObject.contractAddress
            symbol = tokenObject.symbol
            decimals = tokenObject.decimals
            icon = tokenObject.icon
            type = tokenObject.type
            shouldDisplay = tokenObject.shouldDisplay
            sortIndex = tokenObject.sortIndex.value

            switch type {
            case .erc20, .nativeCryptocurrency:
                self.balance = .value(tokenObject.valueBigInt)
            case .erc721, .erc721ForTickets, .erc875:
                let balance = tokenObject.balance.map { TokenBalance(balance: $0.balance, json: $0.json) }
                self.balance = .balance(Array(balance))
            }
        }

        static func == (lhs: Activity.AssignedToken, rhs: Activity.AssignedToken) -> Bool {
            return lhs.primaryKey == rhs.primaryKey
        }

    }
}

extension Activity.AssignedToken {

    func title(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let handler = XMLHandler(contract: contractAddress, tokenType: type, assetDefinitionStore: assetDefinitionStore)
        let localizedNameFromAssetDefinition = handler.getLabel(fallback: name)
        return title(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
    }

    func titleInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let handler = XMLHandler(contract: contractAddress, tokenType: type, assetDefinitionStore: assetDefinitionStore)
        let localizedNameFromAssetDefinition = handler.getNameInPluralForm(fallback: name)
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

    func symbolInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let handler = XMLHandler(contract: contractAddress, tokenType: type, assetDefinitionStore: assetDefinitionStore)
        let localizedNameFromAssetDefinition = handler.getNameInPluralForm(fallback: name)
        return symbol(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
    }

    private func symbol(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore, localizedNameFromAssetDefinition: String) -> String {
        let compositeName = compositeTokenName(forContract: contractAddress, fromContractName: name, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
        if compositeName.isEmpty {
            return symbol
        } else {
            let daiSymbol = "DAI\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
            //We could have just trimmed away all trailing \0, but this is faster and safer since only DAI seems to have this problem
            if daiSymbol == symbol {
                return "DAI"
            } else {
                return symbol
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
}

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

    var optionalDecimalValue: NSDecimalNumber? {
        return EtherNumberFormatter.plain.string(from: valueBigInt, decimals: decimals).optionalDecimalValue
    }

    var contractAddress: AlphaWallet.Address {
        return AlphaWallet.Address(uncheckedAgainstNullAddress: contract)!
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
        //NOTE: to improve perfomance seems like we can use check for primary key instead of checking contracts
        return object.contractAddress.sameContract(as: contractAddress)
    }

    func title(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let localizedNameFromAssetDefinition = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore).getLabel(fallback: name)
        return title(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
    }

    func titleInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let localizedNameFromAssetDefinition = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm(fallback: name)
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

    func symbolInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let localizedNameFromAssetDefinition = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm(fallback: name)
        return symbol(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
    }

    private func symbol(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore, localizedNameFromAssetDefinition: String) -> String {
        let compositeName = compositeTokenName(forContract: contractAddress, fromContractName: name, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
        if compositeName.isEmpty {
            return symbol
        } else {
            let daiSymbol = "DAI\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
            //We could have just trimmed away all trailing \0, but this is faster and safer since only DAI seems to have this problem
            if daiSymbol == symbol {
                return "DAI"
            } else {
                return symbol
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
    if contract.isFifaTicketContract {
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
