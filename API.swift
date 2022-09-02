// @generated
//  This file was automatically generated and should not be edited.

import Apollo
import Foundation

/// The supply models.
public enum TokenSupplyModel: RawRepresentable, Equatable, Hashable, CaseIterable, Apollo.JSONDecodable, Apollo.JSONEncodable {
  public typealias RawValue = String
  case fixed
  case settable
  case infinite
  case collapsing
  case annualValue
  case annualPercentage
  /// Auto generated constant for unknown enum values
  case __unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "FIXED": self = .fixed
      case "SETTABLE": self = .settable
      case "INFINITE": self = .infinite
      case "COLLAPSING": self = .collapsing
      case "ANNUAL_VALUE": self = .annualValue
      case "ANNUAL_PERCENTAGE": self = .annualPercentage
      default: self = .__unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .fixed: return "FIXED"
      case .settable: return "SETTABLE"
      case .infinite: return "INFINITE"
      case .collapsing: return "COLLAPSING"
      case .annualValue: return "ANNUAL_VALUE"
      case .annualPercentage: return "ANNUAL_PERCENTAGE"
      case .__unknown(let value): return value
    }
  }

  public static func == (lhs: TokenSupplyModel, rhs: TokenSupplyModel) -> Bool {
    switch (lhs, rhs) {
      case (.fixed, .fixed): return true
      case (.settable, .settable): return true
      case (.infinite, .infinite): return true
      case (.collapsing, .collapsing): return true
      case (.annualValue, .annualValue): return true
      case (.annualPercentage, .annualPercentage): return true
      case (.__unknown(let lhsValue), .__unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }

  public static var allCases: [TokenSupplyModel] {
    return [
      .fixed,
      .settable,
      .infinite,
      .collapsing,
      .annualValue,
      .annualPercentage,
    ]
  }
}

/// The transfer modes.
public enum TokenTransferable: RawRepresentable, Equatable, Hashable, CaseIterable, Apollo.JSONDecodable, Apollo.JSONEncodable {
  public typealias RawValue = String
  case permanent
  case temporary
  case bound
  /// Auto generated constant for unknown enum values
  case __unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "PERMANENT": self = .permanent
      case "TEMPORARY": self = .temporary
      case "BOUND": self = .bound
      default: self = .__unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .permanent: return "PERMANENT"
      case .temporary: return "TEMPORARY"
      case .bound: return "BOUND"
      case .__unknown(let value): return value
    }
  }

  public static func == (lhs: TokenTransferable, rhs: TokenTransferable) -> Bool {
    switch (lhs, rhs) {
      case (.permanent, .permanent): return true
      case (.temporary, .temporary): return true
      case (.bound, .bound): return true
      case (.__unknown(let lhsValue), .__unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }

  public static var allCases: [TokenTransferable] {
    return [
      .permanent,
      .temporary,
      .bound,
    ]
  }
}

/// The transfer fee types.
public enum AssetTransferFeeType: RawRepresentable, Equatable, Hashable, CaseIterable, Apollo.JSONDecodable, Apollo.JSONEncodable {
  public typealias RawValue = String
  case `none`
  case perTransfer
  case perCryptoItem
  case ratioCut
  case ratioExtra
  /// Auto generated constant for unknown enum values
  case __unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "NONE": self = .none
      case "PER_TRANSFER": self = .perTransfer
      case "PER_CRYPTO_ITEM": self = .perCryptoItem
      case "RATIO_CUT": self = .ratioCut
      case "RATIO_EXTRA": self = .ratioExtra
      default: self = .__unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .none: return "NONE"
      case .perTransfer: return "PER_TRANSFER"
      case .perCryptoItem: return "PER_CRYPTO_ITEM"
      case .ratioCut: return "RATIO_CUT"
      case .ratioExtra: return "RATIO_EXTRA"
      case .__unknown(let value): return value
    }
  }

  public static func == (lhs: AssetTransferFeeType, rhs: AssetTransferFeeType) -> Bool {
    switch (lhs, rhs) {
      case (.none, .none): return true
      case (.perTransfer, .perTransfer): return true
      case (.perCryptoItem, .perCryptoItem): return true
      case (.ratioCut, .ratioCut): return true
      case (.ratioExtra, .ratioExtra): return true
      case (.__unknown(let lhsValue), .__unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }

  public static var allCases: [AssetTransferFeeType] {
    return [
      .none,
      .perTransfer,
      .perCryptoItem,
      .ratioCut,
      .ratioExtra,
    ]
  }
}

public final class GetEnjinBalancesQuery: GraphQLQuery {
  /// The raw GraphQL definition of this operation.
  public let operationDefinition: String =
    """
    query GetEnjinBalances($ethAddress: String!, $page: Int!, $limit: Int!) {
      EnjinBalances(ethAddress: $ethAddress, pagination: {page: $page, limit: $limit}) {
        __typename
        token {
          __typename
          id
        }
        wallet {
          __typename
          ethAddress
        }
        value
      }
    }
    """

  public let operationName: String = "GetEnjinBalances"

  public var ethAddress: String
  public var page: Int
  public var limit: Int

  public init(ethAddress: String, page: Int, limit: Int) {
    self.ethAddress = ethAddress
    self.page = page
    self.limit = limit
  }

  public var variables: GraphQLMap? {
    return ["ethAddress": ethAddress, "page": page, "limit": limit]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes: [String] = ["Query"]

    public static var selections: [GraphQLSelection] {
      return [
        GraphQLField("EnjinBalances", arguments: ["ethAddress": GraphQLVariable("ethAddress"), "pagination": ["page": GraphQLVariable("page"), "limit": GraphQLVariable("limit")]], type: .list(.object(EnjinBalance.selections))),
      ]
    }

    public private(set) var resultMap: ResultMap

    public init(unsafeResultMap: ResultMap) {
      self.resultMap = unsafeResultMap
    }

    public init(enjinBalances: [EnjinBalance?]? = nil) {
      self.init(unsafeResultMap: ["__typename": "Query", "EnjinBalances": enjinBalances.flatMap { (value: [EnjinBalance?]) -> [ResultMap?] in value.map { (value: EnjinBalance?) -> ResultMap? in value.flatMap { (value: EnjinBalance) -> ResultMap in value.resultMap } } }])
    }

    /// Use this query to get information about balances stored on this Platform.
    public var enjinBalances: [EnjinBalance?]? {
      get {
        return (resultMap["EnjinBalances"] as? [ResultMap?]).flatMap { (value: [ResultMap?]) -> [EnjinBalance?] in value.map { (value: ResultMap?) -> EnjinBalance? in value.flatMap { (value: ResultMap) -> EnjinBalance in EnjinBalance(unsafeResultMap: value) } } }
      }
      set {
        resultMap.updateValue(newValue.flatMap { (value: [EnjinBalance?]) -> [ResultMap?] in value.map { (value: EnjinBalance?) -> ResultMap? in value.flatMap { (value: EnjinBalance) -> ResultMap in value.resultMap } } }, forKey: "EnjinBalances")
      }
    }

    public struct EnjinBalance: GraphQLSelectionSet {
      public static let possibleTypes: [String] = ["EnjinBalance"]

      public static var selections: [GraphQLSelection] {
        return [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("token", type: .object(Token.selections)),
          GraphQLField("wallet", type: .object(Wallet.selections)),
          GraphQLField("value", type: .scalar(Int.self)),
        ]
      }

      public private(set) var resultMap: ResultMap

      public init(unsafeResultMap: ResultMap) {
        self.resultMap = unsafeResultMap
      }

      public init(token: Token? = nil, wallet: Wallet? = nil, value: Int? = nil) {
        self.init(unsafeResultMap: ["__typename": "EnjinBalance", "token": token.flatMap { (value: Token) -> ResultMap in value.resultMap }, "wallet": wallet.flatMap { (value: Wallet) -> ResultMap in value.resultMap }, "value": value])
      }

      public var __typename: String {
        get {
          return resultMap["__typename"]! as! String
        }
        set {
          resultMap.updateValue(newValue, forKey: "__typename")
        }
      }

      /// The token for this balance.
      public var token: Token? {
        get {
          return (resultMap["token"] as? ResultMap).flatMap { Token(unsafeResultMap: $0) }
        }
        set {
          resultMap.updateValue(newValue?.resultMap, forKey: "token")
        }
      }

      /// The wallet for this balance.
      public var wallet: Wallet? {
        get {
          return (resultMap["wallet"] as? ResultMap).flatMap { Wallet(unsafeResultMap: $0) }
        }
        set {
          resultMap.updateValue(newValue?.resultMap, forKey: "wallet")
        }
      }

      /// The balance of this token.
      public var value: Int? {
        get {
          return resultMap["value"] as? Int
        }
        set {
          resultMap.updateValue(newValue, forKey: "value")
        }
      }

      public struct Token: GraphQLSelectionSet {
        public static let possibleTypes: [String] = ["EnjinToken"]

        public static var selections: [GraphQLSelection] {
          return [
            GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
            GraphQLField("id", type: .scalar(String.self)),
          ]
        }

        public private(set) var resultMap: ResultMap

        public init(unsafeResultMap: ResultMap) {
          self.resultMap = unsafeResultMap
        }

        public init(id: String? = nil) {
          self.init(unsafeResultMap: ["__typename": "EnjinToken", "id": id])
        }

        public var __typename: String {
          get {
            return resultMap["__typename"]! as! String
          }
          set {
            resultMap.updateValue(newValue, forKey: "__typename")
          }
        }

        /// The base id of the item.
        public var id: String? {
          get {
            return resultMap["id"] as? String
          }
          set {
            resultMap.updateValue(newValue, forKey: "id")
          }
        }
      }

      public struct Wallet: GraphQLSelectionSet {
        public static let possibleTypes: [String] = ["EnjinWallet"]

        public static var selections: [GraphQLSelection] {
          return [
            GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
            GraphQLField("ethAddress", type: .scalar(String.self)),
          ]
        }

        public private(set) var resultMap: ResultMap

        public init(unsafeResultMap: ResultMap) {
          self.resultMap = unsafeResultMap
        }

        public init(ethAddress: String? = nil) {
          self.init(unsafeResultMap: ["__typename": "EnjinWallet", "ethAddress": ethAddress])
        }

        public var __typename: String {
          get {
            return resultMap["__typename"]! as! String
          }
          set {
            resultMap.updateValue(newValue, forKey: "__typename")
          }
        }

        /// The Ethereum address of this wallet.
        public var ethAddress: String? {
          get {
            return resultMap["ethAddress"] as? String
          }
          set {
            resultMap.updateValue(newValue, forKey: "ethAddress")
          }
        }
      }
    }
  }
}

public final class EnjinOauthQuery: GraphQLQuery {
  /// The raw GraphQL definition of this operation.
  public let operationDefinition: String =
    """
    query EnjinOauth($email: String!, $password: String!) {
      EnjinOauth(email: $email, password: $password) {
        __typename
        id
        name
        accessTokens
      }
    }
    """

  public let operationName: String = "EnjinOauth"

  public var email: String
  public var password: String

  public init(email: String, password: String) {
    self.email = email
    self.password = password
  }

  public var variables: GraphQLMap? {
    return ["email": email, "password": password]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes: [String] = ["Query"]

    public static var selections: [GraphQLSelection] {
      return [
        GraphQLField("EnjinOauth", arguments: ["email": GraphQLVariable("email"), "password": GraphQLVariable("password")], type: .object(EnjinOauth.selections)),
      ]
    }

    public private(set) var resultMap: ResultMap

    public init(unsafeResultMap: ResultMap) {
      self.resultMap = unsafeResultMap
    }

    public init(enjinOauth: EnjinOauth? = nil) {
      self.init(unsafeResultMap: ["__typename": "Query", "EnjinOauth": enjinOauth.flatMap { (value: EnjinOauth) -> ResultMap in value.resultMap }])
    }

    /// Use this query to log users in and obtain an access token.
    public var enjinOauth: EnjinOauth? {
      get {
        return (resultMap["EnjinOauth"] as? ResultMap).flatMap { EnjinOauth(unsafeResultMap: $0) }
      }
      set {
        resultMap.updateValue(newValue?.resultMap, forKey: "EnjinOauth")
      }
    }

    public struct EnjinOauth: GraphQLSelectionSet {
      public static let possibleTypes: [String] = ["EnjinUser"]

      public static var selections: [GraphQLSelection] {
        return [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .scalar(Int.self)),
          GraphQLField("name", type: .scalar(String.self)),
          GraphQLField("accessTokens", type: .list(.scalar(String.self))),
        ]
      }

      public private(set) var resultMap: ResultMap

      public init(unsafeResultMap: ResultMap) {
        self.resultMap = unsafeResultMap
      }

      public init(id: Int? = nil, name: String? = nil, accessTokens: [String?]? = nil) {
        self.init(unsafeResultMap: ["__typename": "EnjinUser", "id": id, "name": name, "accessTokens": accessTokens])
      }

      public var __typename: String {
        get {
          return resultMap["__typename"]! as! String
        }
        set {
          resultMap.updateValue(newValue, forKey: "__typename")
        }
      }

      /// The id of the user.
      public var id: Int? {
        get {
          return resultMap["id"] as? Int
        }
        set {
          resultMap.updateValue(newValue, forKey: "id")
        }
      }

      /// The user's name.
      public var name: String? {
        get {
          return resultMap["name"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "name")
        }
      }

      /// The access tokens for this user.
      public var accessTokens: [String?]? {
        get {
          return resultMap["accessTokens"] as? [String?]
        }
        set {
          resultMap.updateValue(newValue, forKey: "accessTokens")
        }
      }
    }
  }
}

public final class GetEnjinTokenQuery: GraphQLQuery {
  /// The raw GraphQL definition of this operation.
  public let operationDefinition: String =
    """
    query GetEnjinToken($id: String!) {
      EnjinToken(id: $id) {
        __typename
        id
        name
        creator
        meltValue
        meltFeeRatio
        meltFeeMaxRatio
        supplyModel
        totalSupply
        circulatingSupply
        reserve
        transferable
        nonFungible
        blockHeight
        markedForDelete
        createdAt
        updatedAt
        mintableSupply
        itemURI
        transferFeeSettings {
          __typename
          type
        }
        wallet {
          __typename
          ethAddress
        }
      }
    }
    """

  public let operationName: String = "GetEnjinToken"

  public var id: String

  public init(id: String) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes: [String] = ["Query"]

    public static var selections: [GraphQLSelection] {
      return [
        GraphQLField("EnjinToken", arguments: ["id": GraphQLVariable("id")], type: .object(EnjinToken.selections)),
      ]
    }

    public private(set) var resultMap: ResultMap

    public init(unsafeResultMap: ResultMap) {
      self.resultMap = unsafeResultMap
    }

    public init(enjinToken: EnjinToken? = nil) {
      self.init(unsafeResultMap: ["__typename": "Query", "EnjinToken": enjinToken.flatMap { (value: EnjinToken) -> ResultMap in value.resultMap }])
    }

    /// Use this query to get token data.
    public var enjinToken: EnjinToken? {
      get {
        return (resultMap["EnjinToken"] as? ResultMap).flatMap { EnjinToken(unsafeResultMap: $0) }
      }
      set {
        resultMap.updateValue(newValue?.resultMap, forKey: "EnjinToken")
      }
    }

    public struct EnjinToken: GraphQLSelectionSet {
      public static let possibleTypes: [String] = ["EnjinToken"]

      public static var selections: [GraphQLSelection] {
        return [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .scalar(String.self)),
          GraphQLField("name", type: .scalar(String.self)),
          GraphQLField("creator", type: .scalar(String.self)),
          GraphQLField("meltValue", type: .scalar(String.self)),
          GraphQLField("meltFeeRatio", type: .scalar(Int.self)),
          GraphQLField("meltFeeMaxRatio", type: .scalar(Int.self)),
          GraphQLField("supplyModel", type: .scalar(TokenSupplyModel.self)),
          GraphQLField("totalSupply", type: .scalar(String.self)),
          GraphQLField("circulatingSupply", type: .scalar(String.self)),
          GraphQLField("reserve", type: .scalar(String.self)),
          GraphQLField("transferable", type: .scalar(TokenTransferable.self)),
          GraphQLField("nonFungible", type: .scalar(Bool.self)),
          GraphQLField("blockHeight", type: .scalar(Int.self)),
          GraphQLField("markedForDelete", type: .scalar(Bool.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
          GraphQLField("mintableSupply", type: .scalar(Double.self)),
          GraphQLField("itemURI", type: .scalar(String.self)),
          GraphQLField("transferFeeSettings", type: .object(TransferFeeSetting.selections)),
          GraphQLField("wallet", type: .object(Wallet.selections)),
        ]
      }

      public private(set) var resultMap: ResultMap

      public init(unsafeResultMap: ResultMap) {
        self.resultMap = unsafeResultMap
      }

      public init(id: String? = nil, name: String? = nil, creator: String? = nil, meltValue: String? = nil, meltFeeRatio: Int? = nil, meltFeeMaxRatio: Int? = nil, supplyModel: TokenSupplyModel? = nil, totalSupply: String? = nil, circulatingSupply: String? = nil, reserve: String? = nil, transferable: TokenTransferable? = nil, nonFungible: Bool? = nil, blockHeight: Int? = nil, markedForDelete: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil, mintableSupply: Double? = nil, itemUri: String? = nil, transferFeeSettings: TransferFeeSetting? = nil, wallet: Wallet? = nil) {
        self.init(unsafeResultMap: ["__typename": "EnjinToken", "id": id, "name": name, "creator": creator, "meltValue": meltValue, "meltFeeRatio": meltFeeRatio, "meltFeeMaxRatio": meltFeeMaxRatio, "supplyModel": supplyModel, "totalSupply": totalSupply, "circulatingSupply": circulatingSupply, "reserve": reserve, "transferable": transferable, "nonFungible": nonFungible, "blockHeight": blockHeight, "markedForDelete": markedForDelete, "createdAt": createdAt, "updatedAt": updatedAt, "mintableSupply": mintableSupply, "itemURI": itemUri, "transferFeeSettings": transferFeeSettings.flatMap { (value: TransferFeeSetting) -> ResultMap in value.resultMap }, "wallet": wallet.flatMap { (value: Wallet) -> ResultMap in value.resultMap }])
      }

      public var __typename: String {
        get {
          return resultMap["__typename"]! as! String
        }
        set {
          resultMap.updateValue(newValue, forKey: "__typename")
        }
      }

      /// The base id of the item.
      public var id: String? {
        get {
          return resultMap["id"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "id")
        }
      }

      /// The item name.
      public var name: String? {
        get {
          return resultMap["name"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "name")
        }
      }

      /// The user who created the item.
      public var creator: String? {
        get {
          return resultMap["creator"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "creator")
        }
      }

      /// The the melt value (and therefore exchange rate) for this item.
      public var meltValue: String? {
        get {
          return resultMap["meltValue"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "meltValue")
        }
      }

      /// The the melt fee ratio for this item in the range 0-10000 to allow fractional ratios, e,g, 1 = 0.01%,  10000 = 100%, 250 = 2.5% and so on.
      public var meltFeeRatio: Int? {
        get {
          return resultMap["meltFeeRatio"] as? Int
        }
        set {
          resultMap.updateValue(newValue, forKey: "meltFeeRatio")
        }
      }

      /// The the max melt fee ratio for this item in the range 0-10000 to allow fractional ratios, e,g, 1 = 0.01%,  10000 = 100%, 250 = 2.5% and so on.
      public var meltFeeMaxRatio: Int? {
        get {
          return resultMap["meltFeeMaxRatio"] as? Int
        }
        set {
          resultMap.updateValue(newValue, forKey: "meltFeeMaxRatio")
        }
      }

      /// The item's supply model.
      public var supplyModel: TokenSupplyModel? {
        get {
          return resultMap["supplyModel"] as? TokenSupplyModel
        }
        set {
          resultMap.updateValue(newValue, forKey: "supplyModel")
        }
      }

      /// The total supply of the item.
      public var totalSupply: String? {
        get {
          return resultMap["totalSupply"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "totalSupply")
        }
      }

      /// The circulating supply of the item.
      public var circulatingSupply: String? {
        get {
          return resultMap["circulatingSupply"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "circulatingSupply")
        }
      }

      /// The initial reserve of the item.
      public var reserve: String? {
        get {
          return resultMap["reserve"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "reserve")
        }
      }

      /// The transferable type.
      public var transferable: TokenTransferable? {
        get {
          return resultMap["transferable"] as? TokenTransferable
        }
        set {
          resultMap.updateValue(newValue, forKey: "transferable")
        }
      }

      /// If this is this a non fungible item.
      public var nonFungible: Bool? {
        get {
          return resultMap["nonFungible"] as? Bool
        }
        set {
          resultMap.updateValue(newValue, forKey: "nonFungible")
        }
      }

      /// The block number of the last update.
      public var blockHeight: Int? {
        get {
          return resultMap["blockHeight"] as? Int
        }
        set {
          resultMap.updateValue(newValue, forKey: "blockHeight")
        }
      }

      /// Has this item been marked for delete?
      @available(*, deprecated, message: "Deprecated")
      public var markedForDelete: Bool? {
        get {
          return resultMap["markedForDelete"] as? Bool
        }
        set {
          resultMap.updateValue(newValue, forKey: "markedForDelete")
        }
      }

      /// The ISO 8601 datetime when this resource was created.
      public var createdAt: String? {
        get {
          return resultMap["createdAt"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "createdAt")
        }
      }

      /// The ISO 8601 datetime when this resource was last updated.
      public var updatedAt: String? {
        get {
          return resultMap["updatedAt"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "updatedAt")
        }
      }

      /// The number of items currently available to mint.
      public var mintableSupply: Double? {
        get {
          return resultMap["mintableSupply"] as? Double
        }
        set {
          resultMap.updateValue(newValue, forKey: "mintableSupply")
        }
      }

      /// The URI for this item (if set).
      @available(*, deprecated, message: "Renamed to metadataURI")
      public var itemUri: String? {
        get {
          return resultMap["itemURI"] as? String
        }
        set {
          resultMap.updateValue(newValue, forKey: "itemURI")
        }
      }

      /// The fee settings for this item.
      public var transferFeeSettings: TransferFeeSetting? {
        get {
          return (resultMap["transferFeeSettings"] as? ResultMap).flatMap { TransferFeeSetting(unsafeResultMap: $0) }
        }
        set {
          resultMap.updateValue(newValue?.resultMap, forKey: "transferFeeSettings")
        }
      }

      /// The wallet for this balance.
      public var wallet: Wallet? {
        get {
          return (resultMap["wallet"] as? ResultMap).flatMap { Wallet(unsafeResultMap: $0) }
        }
        set {
          resultMap.updateValue(newValue?.resultMap, forKey: "wallet")
        }
      }

      public struct TransferFeeSetting: GraphQLSelectionSet {
        public static let possibleTypes: [String] = ["EnjinTokenTransferFeeSettings"]

        public static var selections: [GraphQLSelection] {
          return [
            GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
            GraphQLField("type", type: .scalar(AssetTransferFeeType.self)),
          ]
        }

        public private(set) var resultMap: ResultMap

        public init(unsafeResultMap: ResultMap) {
          self.resultMap = unsafeResultMap
        }

        public init(type: AssetTransferFeeType? = nil) {
          self.init(unsafeResultMap: ["__typename": "EnjinTokenTransferFeeSettings", "type": type])
        }

        public var __typename: String {
          get {
            return resultMap["__typename"]! as! String
          }
          set {
            resultMap.updateValue(newValue, forKey: "__typename")
          }
        }

        /// The type of transfer (None, Per Item, Per Transfer).
        public var type: AssetTransferFeeType? {
          get {
            return resultMap["type"] as? AssetTransferFeeType
          }
          set {
            resultMap.updateValue(newValue, forKey: "type")
          }
        }
      }

      public struct Wallet: GraphQLSelectionSet {
        public static let possibleTypes: [String] = ["EnjinWallet"]

        public static var selections: [GraphQLSelection] {
          return [
            GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
            GraphQLField("ethAddress", type: .scalar(String.self)),
          ]
        }

        public private(set) var resultMap: ResultMap

        public init(unsafeResultMap: ResultMap) {
          self.resultMap = unsafeResultMap
        }

        public init(ethAddress: String? = nil) {
          self.init(unsafeResultMap: ["__typename": "EnjinWallet", "ethAddress": ethAddress])
        }

        public var __typename: String {
          get {
            return resultMap["__typename"]! as! String
          }
          set {
            resultMap.updateValue(newValue, forKey: "__typename")
          }
        }

        /// The Ethereum address of this wallet.
        public var ethAddress: String? {
          get {
            return resultMap["ethAddress"] as? String
          }
          set {
            resultMap.updateValue(newValue, forKey: "ethAddress")
          }
        }
      }
    }
  }
}
