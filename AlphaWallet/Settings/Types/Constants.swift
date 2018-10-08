// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct Constants {
    public static let coinbaseWidgetCode = "88d6141a-ff60-536c-841c-8f830adaacfd"
    public static let shapeShiftPublicKey = "c4097b033e02163da6114fbbc1bf15155e759ddfd8352c88c55e7fef162e901a800e7eaecf836062a0c075b2b881054e0b9aa2324be7bc3694578493faf59af4"
    public static let changellyRefferalID = "968d4f0f0bf9"
    public static let keychainKeyPrefix = "alphawallet"
    public static let gasLimit = BigInt(300000)
    public static let gasPriceDefaultERC875 = BigInt("22000000000")!
    
    //link formats
    public static let oldFormat: UInt8 = 0x00
    public static let notSpawnable: UInt8 = 0x01
    public static let spawnable: UInt8 = 0x02
    public static let customizable: UInt8 = 0x03

    // XML repo
    public static let repoServer = "https://repo.awallet.io"
    public static let repoClientName = "AlphaWallet"
    public static let repoPlatformName = "iOS"

    // fee master
    public static let paymentServer = "https://app.awallet.io:80/api/claimToken"
    public static let paymentServerSupportsContractEndPoint = "https://app.awallet.io:80/api/checkContractIsSupportedForFreeTransfers"
    public static let getTicketInfoFromServer = "https://app.awallet.io:80/api/ecrecoverAndGetTickets"

    // social
    public static let website = "https://community.awallet.io/c/alphawallet-app/ios-feedback"
    public static let twitterUsername = "Alpha_wallet"
    public static let redditGroupName = "r/AlphaWallet/"
    public static let facebookUsername = "AlphaWallet"
    public static let appstoreURL = "itms-apps://itunes.apple.com/app/id1358230430"

    // support
    public static let supportEmail = "support@awallet.io"
    public static let dappsBrowserURL = "https://www.stateofthedapps.com"

    public static let nullTokenId = "0x0000000000000000000000000000000000000000000000000000000000000000"
    public static let nullTokenIdBigUInt = BigUInt(0)
    public static let burnAddressString = "0x000000000000000000000000000000000000dEaD"
    public static let nullAddress = "0x0000000000000000000000000000000000000000"

    // FIFA hardcoded FIFA token address
    public static let ticketContractAddress = "0xA66A3F08068174e8F005112A8b2c7A507a822335"
    public static let ticketContractAddressRopsten = "0xD8e5F58DE3933E1E35f9c65eb72cb188674624F3"

    //etherscan APIs
    public static let mainnetEtherscanAPI = "https://api.etherscan.io/api?module=account&action=txlist&address="
    public static let ropstenEtherscanAPI = "https://ropsten.etherscan.io/api?module=account&action=txlist&address="
    public static let rinkebyEtherscanAPI = "https://rinkeby.etherscan.io/api?module=account&action=txlist&address="

    //etherscan contract details web page
    public static let mainnetEtherscanContractDetailsWebPageURL = "https://etherscan.io/address/"
    public static let ropstenEtherscanContractDetailsWebPageURL = "https://ropsten.etherscan.io/address/"
    public static let rinkebyEtherscanContractDetailsWebPageURL = "https://rinkeby.etherscan.io/address/"
    
    //ERC specs
    public static let erc721InterfaceHash = "0x80ac58cd"
    //CryptoKitties' ERC165 interface signature for ERC721 is wrong
    public static let erc721InterfaceHashOnlyForCryptoKitty = "0x9a20483d"

    //OpenSea links for erc721 assets
    public static let openseaAPI = "https://api.opensea.io/"
    public static let openseaAPIKEY = "11ba1b4f0c4246aeb07b1f8e5a20525f" // X-API-KEY

    public static let cryptoKittiesCooldowns = [
        "Fast",
        "Swift",
        "Swift",
        "Snappy",
        "Snappy",
        "Brisk",
        "Brisk",
        "Ploddy",
        "Ploddy",
        "Slow",
        "Slow",
        "Sluggish",
        "Sluggish",
        "Catatonic",
        "Catatonic"
    ]
    
    //contract addresses that are compatible with opensea
    //See comment in CryptoKittyHandling enum
    public static let cryptoKittiesContractAddress = "0x06012c8cf97bead5deae237070f9587f8e7a266d"

    public static let etherReceivedNotificationIdentifier = "etherReceivedNotificationIdentifier"
}

public struct UnitConfiguration {
    public static let gasPriceUnit: EthereumUnit = .gwei
    public static let gasFeeUnit: EthereumUnit = .ether
    public static let finneyUnit: EthereumUnit = .finney
}
