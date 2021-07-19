// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift
import BigInt

extension Activity {

    struct AssignedToken: Equatable, Hashable {

        struct TokenBalance {
            var balance = "0"
            var json: String = "{}"
        }

        enum Balance {
            case value(NSDecimalNumber?)
            case nftBalance(NSDecimalNumber)

            var isEmpty: Bool {
                switch self {
                case .nftBalance(let values):
                    return values == 0
                case .value(let value):
                    return value == 0
                }
            }

            var valueDecimal: NSDecimalNumber? {
                switch self {
                case .value(let value):
                    return value
                case .nftBalance(let value):
                    return value
                }
            }
        }

        let primaryKey: String
        let contractAddress: AlphaWallet.Address
        let symbol: String
        let decimals: Int
        let server: RPCServer
        let icon: Subscribable<TokenImage>
        let type: TokenType
        let name: String
        let balance: Balance
        let shouldDisplay: Bool
        let sortIndex: Int?
        var ticker: CoinTicker?

        var addressAndRPCServer: AddressAndRPCServer {
            return .init(address: contractAddress, server: server)
        }

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
                let fullValue = EtherNumberFormatter.plain.string(from: tokenObject.valueBigInt, decimals: decimals)
                balance = .value(fullValue.optionalDecimalValue)
            case .erc721, .erc721ForTickets, .erc875:
                balance = .nftBalance(.init(value: tokenObject.balance.count))
            }
        }

        var valueDecimal: NSDecimalNumber? {
            balance.valueDecimal
        }

        static func == (lhs: Activity.AssignedToken, rhs: Activity.AssignedToken) -> Bool {
            return lhs.name == rhs.name &&
                lhs.primaryKey == rhs.primaryKey &&
                lhs.server == rhs.server &&
                lhs.contractAddress == rhs.contractAddress &&
                lhs.symbol == rhs.symbol &&
                lhs.decimals == rhs.decimals &&
                lhs.icon.value?.image == rhs.icon.value?.image &&
                lhs.type == rhs.type
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(primaryKey)
            hasher.combine(server)
            hasher.combine(contractAddress)
            hasher.combine(symbol)
            hasher.combine(decimals)
            if let image = icon.value?.image {
                hasher.combine(image.hashValue)
            }
            hasher.combine(type.rawValue)
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
        return Array(balance.filter { isNonZeroBalance($0.balance, tokenType: self.type) })
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

func isNonZeroBalance(_ balance: String, tokenType: TokenType) -> Bool {
    return !isZeroBalance(balance, tokenType: tokenType)
}

func isZeroBalance(_ balance: String, tokenType: TokenType) -> Bool {
    //We don't care about fungibles here, but want to make sure that *only* ERC875 balances consider string of "0" as null token, because we mark tokens that are burnt as 0, whereas ERC721 can have token ID = 0, eg. https://bscscan.com/tx/0xf6f3ddbb6719d8e47a47cf8ec66853682c02f03626cc4c4f5ece9338a8f20aee
    switch tokenType {
    case .nativeCryptocurrency, .erc20, .erc875:
        if balance == Constants.nullTokenId || balance == "0" {
            return true
        }
        return false
    case .erc721, .erc721ForTickets:
        return balance.isEmpty
    }
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
