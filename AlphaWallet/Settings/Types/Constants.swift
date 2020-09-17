// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import web3swift

public struct Constants {
    public static let keychainKeyPrefix = "alphawallet"
    public static let xdaiDropPrefix = Data(bytes:
        [0x58, 0x44, 0x41, 0x49, 0x44, 0x52, 0x4F, 0x50]
    ).hex()

    public static let mainnetMagicLinkHost = "aw.app"
    public static let legacyMagicLinkHost = "app.awallet.io"
    public static let classicMagicLinkHost = "classic.aw.app"
    public static let callistoMagicLinkHost = "callisto.aw.app"
    public static let kovanMagicLinkHost = "kovan.aw.app"
    public static let ropstenMagicLinkHost = "ropsten.aw.app"
    public static let rinkebyMagicLinkHost = "rinkeby.aw.app"
    public static let poaMagicLinkHost = "poa.aw.app"
    public static let sokolMagicLinkHost = "sokol.aw.app"
    public static let xDaiMagicLinkHost = "xdai.aw.app"
    public static let goerliMagicLinkHost = "goerli.aw.app"
    public static let artisSigma1MagicLinkHost = "artis_sigma1.aw.app"
    public static let artisTau1MagicLinkHost = "artis_tau1.aw.app"
    public static let binanceMagicLinkHost = "binance.aw.app"
    public static let binanceTestMagicLinkHost = "test-binance.aw.app"
    public static let customMagicLinkHost = "custom.aw.app"

    public enum Currency {
        static let usd = "USD"
    }
    // Magic link networks
    public static let legacyMagicLinkPrefix = "https://app.awallet.io/"

    // fee master
    public static let paymentServer = "https://paymaster.stormbird.sg/api/claimToken"
    public static let paymentServerSpawnable = "https://paymaster.stormbird.sg/api/claimSpawnableToken"
    public static let paymentServerSupportsContractEndPoint = "https://paymaster.stormbird.sg/api/checkContractIsSupportedForFreeTransfers"
    public static let paymentServerClaimedToken = "https://paymaster.stormbird.sg/api/checkIfSignatureIsUsed"
    public static let currencyDropServer = "https://paymaster.stormbird.sg/api/claimFreeCurrency"

    // social
    public static let website = "https://alphawallet.com/"
    public static let twitterUsername = "AlphaWallet"
    public static let redditGroupName = "r/AlphaWallet/"
    public static let facebookUsername = "AlphaWallet"

    // support
    public static let supportEmail = "feedback+ios@alphawallet.com"
    public static let dappsBrowserURL = "http://aw.app"

    //Ethereum null variables
    public static let nullTokenId = "0x0000000000000000000000000000000000000000000000000000000000000000"
    public static let nullTokenIdBigUInt = BigUInt(0)
    public static let burnAddressString = "0x000000000000000000000000000000000000dEaD"
    static let nullAddress = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000000")!
    static let nativeCryptoAddressInDatabase = nullAddress

    // FIFA hardcoded FIFA token address
    static let ticketContractAddress = AlphaWallet.Address(string: "0xA66A3F08068174e8F005112A8b2c7A507a822335")!
    static let ticketContractAddressRopsten = AlphaWallet.Address(string: "0xD8e5F58DE3933E1E35f9c65eb72cb188674624F3")!

    // UEFA hardcoded addresses
    static let uefaMainnet = AlphaWallet.Address(string: "0x89D142Bef8605646881C68dcD48cDAF17FE597dC")!
    static let uefaRpcServer = RPCServer.main

    //UEFA 721 balances function hash
    static let balances165Hash721Ticket = "0xc84aae17"

    //etherscan-compatible APIs
    public static let mainnetEtherscanAPI = "https://api-cn.etherscan.com/api?module=account&action=txlist&address="
    public static let ropstenEtherscanAPI = "https://ropsten.etherscan.io/api?module=account&action=txlist&address="
    public static let kovanEtherscanAPI = "https://api-kovan.etherscan.io/api?module=account&action=txlist&address="
    public static let rinkebyEtherscanAPI = "https://rinkeby.etherscan.io/api?module=account&action=txlist&address="
    public static let classicEtherscanAPI = "https://blockscout.com/etc/mainnet/api?module=account&action=txlist&address="
    public static let xDaiAPI = "https://blockscout.com/poa/dai/api?module=account&action=txlist&address="
    public static let poaNetworkCoreAPI = "https://blockscout.com/poa/core/api?module=account&action=txlist&address="
    public static let goerliEtherscanAPI = "https://api-goerli.etherscan.io/api?module=account&action=txlist&address="
    public static let artisSigma1NetworkCoreAPI = "https://explorer.sigma1.artis.network/api?module=account&action=txlist&address="
    public static let artisTau1NetworkCoreAPI = "https://explorer.tau1.artis.network/api?module=account&action=txlist&address="

    //etherscan-compatible erc20 transaction event APIs
    //The fetch ERC20 transactions endpoint from Etherscan returns only ERC20 token transactions but the Blockscout version also includes ERC721 transactions too (so it's likely other types that it can detect will be returned too); thus we check the token type rather than assume that they are all ERC20
    public static let mainnetEtherscanAPIErc20Events = "https://api-cn.etherscan.com/api?module=account&action=tokentx&address="
    public static let ropstenEtherscanAPIErc20Events = "https://ropsten.etherscan.io/api?module=account&action=tokentx&address="
    public static let kovanEtherscanAPIErc20Events = "https://api-kovan.etherscan.io/api?module=account&action=tokentx&address="
    public static let rinkebyEtherscanAPIErc20Events = "https://rinkeby.etherscan.io/api?module=account&action=tokentx&address="
    public static let classicAPIErc20Events = "https://blockscout.com/etc/mainnet/api?module=account&action=tokentx&address="
    public static let xDaiAPIErc20Events = "https://blockscout.com/poa/dai/api?module=account&action=tokentx&address="
    public static let poaNetworkCoreAPIErc20Events = "https://blockscout.com/poa/core/api?module=account&action=tokentx&address="
    public static let goerliEtherscanAPIErc20Events = "https://api-goerli.etherscan.io/api?module=account&action=tokentx&address="
    public static let artisSigma1NetworkCoreAPIErc20Events = "https://explorer.sigma1.artis.network/api?module=account&action=tokentx&address="
    public static let artisTau1NetworkCoreAPIErc20Events = "https://explorer.tau1.artis.network/api?module=account&action=tokentx&address="

    //etherscan-compatible contract details web page
    public static let mainnetEtherscanContractDetailsWebPageURL = "https://cn.etherscan.com/address/"
    public static let kovanEtherscanContractDetailsWebPageURL = "https://kovan.etherscan.io/address/"
    public static let rinkebyEtherscanContractDetailsWebPageURL = "https://rinkeby.etherscan.io/address/"
    public static let ropstenEtherscanContractDetailsWebPageURL = "https://ropsten.etherscan.io/address/"
    //Can't use https://blockscout.com/poa/dai/address/ even though it ultimately redirects there because blockscout (tested on 20190620), blockscout.com is only able to show that URL after the address has been searched (with the ?q= URL)
    public static let xDaiContractPage = "https://blockscout.com/poa/dai/search?q="
    public static let poaContractPage = "https://blockscout.com/poa/core/search?q="
    public static let goerliContractPage = "https://goerli.etherscan.io/address/"
    public static let sokolContractPage = "https://blockscout.com/poa/sokol/search?q="
    public static let etcContractPage = "https://blockscout.com/etc/mainnet/search?q="
    public static let callistoContractPage = "https://blockscout.com/callisto/mainnet/search?q="
    public static let artisSigma1ContractPage = "https://explorer.sigma1.artis.network/search?q="
    public static let artisTau1ContractPage = "https://explorer.tau1.artis.network/search?q="
    public static let binanceContractPage = "https://explorer.binance.org/smart/search?q="
    public static let binanceTestnetContractPage = "https://explorer.binance.org/smart-testnet/search?q="

    //OpenSea links for erc721 assets
    public static let openseaAPI = "https://api.opensea.io/"
    public static let openseaRinkebyAPI = "https://rinkeby-api.opensea.io/"
    public static let openseaAPIKEY = "11ba1b4f0c4246aeb07b1f8e5a20525f" // X-API-KEY
    //Using "kat" instead of "cryptokitties" to avoid being mistakenly detected by app review as supporting CryptoKitties
    public static let katContractAddress = "0x06012c8cf97bead5deae237070f9587f8e7a266d"

    //ENS
    static let ENSRegistrarAddress = AlphaWallet.Address(string: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e")!
    static let ENSRegistrarRopsten = ENSRegistrarAddress
    static let ENSRegistrarRinkeby = ENSRegistrarAddress
    static let ENSRegistrarGoerli = ENSRegistrarAddress

    //Misc
    public static let etherReceivedNotificationIdentifier = "etherReceivedNotificationIdentifier"
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
    ]

    static let rinkebyPartnerContracts = [
        (name: "HKS", contract: AlphaWallet.Address(string: "0x75cB2Cc380d1387a79eE64b1b7C9Fa051139a319")!),
    ]

    static let defaultEnabledServers: [RPCServer] = [.main, .xDai]

    static let tokenScriptUrlSchemeForResources = "tokenscript-resource:///"

    //validator API
    static let tokenScriptValidatorAPI = "https://aw.app/api/v1/verifyXMLDSig"

    //CurrencyFormatter
    static let formatterFractionDigits = 2

    //EtherNumberFormatter
    static let etherFormatterFractionDigits = 4
}

public struct UnitConfiguration {
    public static let gasPriceUnit: EthereumUnit = .gwei
    public static let gasFeeUnit: EthereumUnit = .ether
    public static let finneyUnit: EthereumUnit = .finney
}
