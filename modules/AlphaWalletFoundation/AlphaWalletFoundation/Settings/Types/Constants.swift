// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct Constants {
    static let mainnetMagicLinkHost = "aw.app"
    static let legacyMagicLinkHost = "app.awallet.io"
    static let classicMagicLinkHost = "classic.aw.app"
    static let callistoMagicLinkHost = "callisto.aw.app"
    static let kovanMagicLinkHost = "kovan.aw.app"
    static let ropstenMagicLinkHost = "ropsten.aw.app"
    static let rinkebyMagicLinkHost = "rinkeby.aw.app"
    static let poaMagicLinkHost = "poa.aw.app"
    static let sokolMagicLinkHost = "sokol.aw.app"
    static let xDaiMagicLinkHost = "xdai.aw.app"
    static let goerliMagicLinkHost = "goerli.aw.app"
    static let artisSigma1MagicLinkHost = "artis_sigma1.aw.app"
    static let artisTau1MagicLinkHost = "artis_tau1.aw.app"
    static let binanceMagicLinkHost = "binance.aw.app"
    static let binanceTestMagicLinkHost = "test-binance.aw.app"
    static let hecoMagicLinkHost = "heco.aw.app"
    static let hecoTestMagicLinkHost = "test-heco.aw.app"
    static let customMagicLinkHost = "custom.aw.app"
    static let fantomMagicLinkHost = "fantom.aw.app"
    static let fantomTestMagicLinkHost = "test-fantom.aw.app"
    static let avalancheMagicLinkHost = "avalanche.aw.app"
    static let avalancheTestMagicLinkHost = "test-avalanche.aw.app"
    static let maticMagicLinkHost = "polygon.aw.app"
    static let mumbaiTestMagicLinkHost = "test-polygon.aw.app"
    static let optimisticMagicLinkHost = "optimistic.aw.app"
    static let optimisticTestMagicLinkHost = "optimistic-kovan.aw.app"
    static let cronosTestMagicLinkHost = "test-cronos.aw.app"
    static let arbitrumMagicLinkHost = "arbitrum.aw.app"
    static let arbitrumRinkebyMagicLinkHost = "arbitrum-rinkeby.aw.app"
    static let palmMagicLinkHost = "palm.aw.app"
    static let palmTestnetMagicLinkHost = "palmTestnet.aw.app"
    static let klaytnCypressMagicLinkHost = "klaytnCypress.aw.app"
    static let klaytnBaobabTestnetMagicLinkHost = "klaytnBaobabTestnet.aw.app"
    static let phiMagicLinkHost = "phi.aw.app"
    static let ioTeXMagicLinkHost = "ioTeX.aw.app"
    static let ioTeXTestnetMagicLinkHost = "ioTeXTestnet.aw.app"
    static let candleMagicLinkHost = "candle.aw.app"

    // Magic link networks
    public static let legacyMagicLinkPrefix = "https://app.awallet.io/"

    // fee master
    public static let paymentServer = "https://paymaster.stormbird.sg/api/claimToken"
    public static let paymentServerSpawnable = "https://paymaster.stormbird.sg/api/claimSpawnableToken"
    public static let paymentServerSupportsContractEndPoint = "https://paymaster.stormbird.sg/api/checkContractIsSupportedForFreeTransfers"
    public static let paymentServerClaimedToken = "https://paymaster.stormbird.sg/api/checkIfSignatureIsUsed"
    public static let currencyDropServer = "https://paymaster.stormbird.sg/api/claimFreeCurrency"

    //Ethereum null variables
    public static let nullTokenId = "0x0000000000000000000000000000000000000000000000000000000000000000"
    public static let nullTokenIdBigUInt = BigUInt(0)
    public static let burnAddressString = "0x000000000000000000000000000000000000dEaD"
    public static let nullAddress = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000000")!
    public static let nativeCryptoAddressInDatabase = nullAddress

    // FIFA hardcoded FIFA token address
    public static let ticketContractAddress = AlphaWallet.Address(string: "0xA66A3F08068174e8F005112A8b2c7A507a822335")!
    static let ticketContractAddressRopsten = AlphaWallet.Address(string: "0xD8e5F58DE3933E1E35f9c65eb72cb188674624F3")!

    // UEFA hardcoded addresses
    static let uefaMainnet = AlphaWallet.Address(string: "0x89D142Bef8605646881C68dcD48cDAF17FE597dC")!
    static let uefaRpcServer = RPCServer.main

    static let gnoGnosis = (address: AlphaWallet.Address(string: "0x9c58bacc331c9aa871afd802db6379a98e80cedb")!, server: RPCServer.xDai)

    //UEFA 721 balances function hash
    static let balances165Hash721Ticket = "0xc84aae17"

    static let unstoppableDomainsV2API = "https://unstoppabledomains.g.alchemy.com"
    static let unstoppableDomainsRecordKeys = ["crypto.MATIC.version.MATIC.address", "crypto.ETH.address", "crypto.MATIC.version.ERC20.address"]
    //Using "kat" instead of "cryptokitties" to avoid being mistakenly detected by app review as supporting CryptoKitties
    static let katContractAddress = "0x06012c8cf97bead5deae237070f9587f8e7a266d"
    public static let katNameFallback = "AlphaWallet.katNameFallback"

    //xDai dapps
    static let xDaiBridge = URL(string: "https://bridge.xdaichain.com/")!
    static let arbitrumBridge = URL(string: "https://bridge.arbitrum.io/")!

    static func buyWithRampUrl(asset: String, wallet: Wallet) -> String? {
        guard Constants.Credentials.rampApiKey.nonEmpty else { return nil }
        return "https://buy.ramp.network/?hostApiKey=\(Constants.Credentials.rampApiKey)&hostLogoUrl=https%3A%2F%2Falphawallet.com%2Fwp-content%2Fthemes%2Falphawallet%2Fimg%2Falphawallet-logo.svg&hostAppName=AlphaWallet&swapAsset=\(asset)&userAddress=\(wallet.address.eip55String)"
    }

    static func buyWithCoinbaseUrl(blockchain: String, wallet: Wallet) -> String? {
        guard Features.default.isAvailable(.isCoinbasePayEnabled) else { return nil }
        guard Constants.Credentials.coinbaseAppId.nonEmpty else { return nil }
        let base = "https://pay.coinbase.com/buy/select-asset?appId=\(Constants.Credentials.coinbaseAppId)"
        return base + ("&destinationWallets=[{\"address\": \"\(wallet.address.eip55String)\",\"blockchains\":[\"\(blockchain)\"]}]".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")
    }

    static let highStandardEthereumMainnetGasThresholdGwei = BigInt(130)

    static let legacy875Addresses = [AlphaWallet.Address(string: "0x830e1650a87a754e37ca7ed76b700395a7c61614")!,
                                            AlphaWallet.Address(string: "0xa66a3f08068174e8f005112a8b2c7a507a822335")!]
    static let legacy721Addresses = [
        AlphaWallet.Address(string: "0x06012c8cf97bead5deae237070f9587f8e7a266d")!,
        AlphaWallet.Address(string: "0xabc7e6c01237e8eef355bba2bf925a730b714d5f")!,
        AlphaWallet.Address(string: "0x71c118b00759b0851785642541ceb0f4ceea0bd5")!,
        AlphaWallet.Address(string: "0x7fdcd2a1e52f10c28cb7732f46393e297ecadda1")!
    ]

    static let ethDenverXDaiPartnerContracts = [
        (name: "DEN", contract: AlphaWallet.Address(string: "0x6a814843de5967cf94d7720ce15cba8b0da81967")!),
        (name: "BURN", contract: AlphaWallet.Address(string: "0x94819805310cf736198df0de856b0ff5584f0903")!),
        (name: "BURN", contract: AlphaWallet.Address(string: "0xdec31651bec1fbbff392aa7de956d6ee4559498b")!),
        (name: "BURN", contract: AlphaWallet.Address(string: "0xa95d505e6933cb790ed3431805871efe4e6bbafd")!),
        (name: "DEN", contract: AlphaWallet.Address(string: "0xbdc3df563a3959a373916b724c683d69ba4097f7")!),
        (name: "DEN", contract: AlphaWallet.Address(string: "0x6e251ee9cadf0145babfd3b64664a9d7f941fcc3")!),
        (name: "BUFF", contract: AlphaWallet.Address(string: "0x3e50bf6703fc132a94e4baff068db2055655f11b")!),
        (name: "ETHD2019", contract: AlphaWallet.Address(string: "0xa16b70E8fAd839E62aBBa2d962E4ca5a28aF9e76")!)
    ]

    static let partnerContracts = [
        (name: "DAI", contract: AlphaWallet.Address(string: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359")!),
        (name: "GUSD", contract: AlphaWallet.Address(string: "0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd")!),
        (name: "PAX", contract: AlphaWallet.Address(string: "0x8e870d67f660d95d5be530380d0ec0bd388289e1")!),
        (name: "TUSD", contract: AlphaWallet.Address(string: "0x8dd5fbce2f6a956c3022ba3663759011dd51e73e")!),
        (name: "USDC", contract: AlphaWallet.Address(string: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")!),
        (name: "USDO", contract: AlphaWallet.Address(string: "0x98f2ab72198f2e64527bdb28931f60c0f77ac2fc")!),
        (name: "SHANKAI", contract: Self.ticketContractAddress),

        //fTokens
        (name: "fETH", contract: AlphaWallet.Address(string: "0x5993233d88B4424D9c12e468A39736D5948c2835")!),
        (name: "fHBTC", contract: AlphaWallet.Address(string: "0x3CE92b88DEAec1037335E614Eb6409C95edcAC76")!),
        (name: "fWBTC", contract: AlphaWallet.Address(string: "0x93B9B852FcD2f964Faa7E50EC1374e016260718c")!),
        (name: "fUSDT", contract: AlphaWallet.Address(string: "0x51da0A7340874674C488b67200D007E422667650")!),
        (name: "fUSDC", contract: AlphaWallet.Address(string: "0xfDD543Ed2701dEB2a172Df4876E60918E28Ba217")!),
        (name: "fBUSD", contract: AlphaWallet.Address(string: "0x556be90ea81e8abceEc2737cf6AE0a6cfEe58b40")!),
        (name: "fHUSD", contract: AlphaWallet.Address(string: "0x52d61a0AA88170b6EbDEA25Be1561E5665e6481B")!),
        (name: "fDAI", contract: AlphaWallet.Address(string: "0xfF5cDA31926CA2Ed79533D6B95Fc6ADbDE0f1015")!),
        (name: "fFOR", contract: AlphaWallet.Address(string: "0x84ff569ee2E8b9A2C22E79af431fD248fb41D87b")!),
        (name: "fBNB", contract: AlphaWallet.Address(string: "0x92563b3b8c92B22e37aC956a2B19c40988D25933")!),
        (name: "fHT", contract: AlphaWallet.Address(string: "0x39527B067B04D43c627FB741848ef2c3f8ead3FE")!),
        (name: "fOKB", contract: AlphaWallet.Address(string: "0x4316AAa55ab3BD3a7ee3fbC83580521801210225")!),
        (name: "fyUSD", contract: AlphaWallet.Address(string: "0x66142B3c234C054bA91374732C10cEA0f72390fE")!),
        (name: "fQC", contract: AlphaWallet.Address(string: "0x161190d29cC015EaEFD6c4ad0AA7519B6b75b9c0")!),
        (name: "fyWETH", contract: AlphaWallet.Address(string: "0xd136b32330E539aa9411c4e8968eB26b35c5917B")!),
        (name: "fYFII", contract: AlphaWallet.Address(string: "0x4Ffc92ddD9439c93fc79dD5560e06026A445037D")!),
        (name: "fNEST", contract: AlphaWallet.Address(string: "0xbd3df917A7E69fBa3e1d912577Be7eCC01bE1d12")!),
        (name: "fARPA", contract: AlphaWallet.Address(string: "0x0486B8d96789C6938361Ab776D6b27b6FC03C471")!),
        (name: "fYFI", contract: AlphaWallet.Address(string: "0x8a06bbA4219C3f1Ca705318f5848E62f3beF33d0")!),
        (name: "fMKR", contract: AlphaWallet.Address(string: "0x9FC5d71FC9b14630a2f198F188450D26Fa5788f7")!),
        (name: "fLINK", contract: AlphaWallet.Address(string: "0x29B22BeFe0F5362986152a5430d03B446b8e27fB")!),
        (name: "fUNI", contract: AlphaWallet.Address(string: "0xDb694CB2B58F66C5E79fF272dF37ECb46Dc31ADD")!),
        (name: "fLRC", contract: AlphaWallet.Address(string: "0x6c2e2cEc8De4A6a071065D4BD5c496636570fDC2")!),
        (name: "fLEND", contract: AlphaWallet.Address(string: "0x45b4E177B17e2d50dB6D547015A6f9723FF9c1a0")!),
        (name: "fSNX", contract: AlphaWallet.Address(string: "0x8B2ef6d7d4Cc334D003398007722FdF8ca3f5E55")!),
    ]

    static let rinkebyPartnerContracts = [
        (name: "HKS", contract: AlphaWallet.Address(string: "0x75cB2Cc380d1387a79eE64b1b7C9Fa051139a319")!),
    ]

    static let ensContractOnMainnet = AlphaWallet.Address.ethereumAddress(eip55String: "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85")

    public static let defaultEnabledServers: [RPCServer] = [.main, .xDai, .polygon]
    public static let defaultEnabledTestnetServers: [RPCServer] = [.goerli]

    enum TokenScript {
        static let urlSchemeForResources = "tokenscript-resource:///"
        static let validatorAPI = "https://aw.app/api/v1/verifyXMLDSig"
    }

    enum Enjin {
        static let apiUrl = URL(string: "https://cloud.enjin.io/graphql/default")!
    }

    enum BlockscanChat {
        static let blockscanChatWebUrl = URL(string: "https://chat.blockscan.com/login")!
        static let unreadCountEndpoint = URL(string: "https://blockscan-chat-proxy.herokuapp.com/blockscanchat/unreadcount")!
    }

    enum Coingecko {
        static let baseUrl = URL(string: "https://api.coingecko.com")!
    }

    enum OneInch {
        static let exchangeUrl = URL(string: "https://api.1inch.exchange")!
    }

    enum HoneySwap {
        static let exchangeUrl = URL(string: "https://tokens.honeyswap.org/")!
    }

    enum Ramp {
        static let exchangeUrl = URL(string: "https://api-instant.ramp.network")!
    }

    enum Covalent {
        static let apiBaseUrl = URL(string: "https://api.covalenthq.com")!
        static let newlyAddedTransactionUpdateInterval: TimeInterval = 15
        static let newlyAddedTransactionsPerPage = 100
        static let oldestTransactionUpdateInterval: TimeInterval = 25
        static let oldestAddedTransactionsPerPage = 500
        static let pendingTransactionUpdateInterval: TimeInterval = 5
    }

    enum ChainState {
        static let getChainStateInterval: TimeInterval = 6
    }

    enum Ens {
        static let recordExpiration: TimeInterval = -(2 * 24 * 60 * 60)
    }

    enum Image {
        static let numberOfCharactersOfSymbolToShowInIcon = 4
    }

    enum Phi {
        static let baseUrl = URL(string: "https://price.phi.network")!
    }

    //CurrencyFormatter
    static let formatterFractionDigits = 2

    //EtherNumberFormatter
    static let etherFormatterFractionDigits = 4

    public static let defaultSortTokensParams: [SortTokensParam] =  [
        .byField(field: .name, direction: .ascending),
        .byField(field: .name, direction: .descending),
        .byField(field: .value, direction: .ascending),
        .byField(field: .value, direction: .descending)
    ]
}
