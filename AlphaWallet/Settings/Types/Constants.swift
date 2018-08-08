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

    // XML repo
    public static let repoServer = "https://repo.awallet.io"
    public static let repoClientName = "AlphaWallet"
    public static let repoPlatformName = "iOS"

    // fee master
    public static let paymentServer = "https://app.awallet.io:80/api/claimToken"
    public static let getTicketInfoFromServer = "https://app.awallet.io:80/api/ecrecoverAndGetTickets"

    // social
    public static let website = "https://community.awallet.io/c/alphawallet-app/ios-feedback"
    public static let twitterUsername = "Alpha_wallet"
    public static let redditGroupName = "r/AlphaWallet/"
    public static let facebookUsername = "AlphaWallet"
    public static let appstoreURL = "itms-apps://itunes.apple.com/app/id1358230430"

    // support
    public static let supportEmail = "support@awallet.io"
    public static let donationAddress = "0xFE6d4bC2De2D0b0E6FE47f08A28Ed52F9d052A02"
    public static let dappsBrowserURL = "https://dapps.trustwalletapp.com"

    // FIFA hardcoded FIFA token address. Look for "//FIFA" for relevant changes
    public static let ticketContractAddress = "0xA66A3F08068174e8F005112A8b2c7A507a822335"
    public static let ticketContractAddressRopsten = "0xD8e5F58DE3933E1E35f9c65eb72cb188674624F3"
    public static let nullTicket = "0x0000000000000000000000000000000000000000000000000000000000000000"
    public static let burnAddressString = "0x000000000000000000000000000000000000dEaD"
    public static let event = "FIFA WC2018"

    //kkk remove
    public static let cryptoKittyContractAddress = "0x06012c8cf97BEaD5deAe237070F9587f8E7A266d"
    public static let hardcodedKittyId = 857895
    public static let kittyGenes = [
        800058: "689278284593481476509607714409998114129040247814513095176469160709554223",
        800059: "678778009017880207790542205580649507656770004622593132176275284610754689",
        800060: "511552204362739273568891924113783434309291544878210549804816287661068453",
        800061: "848288247037508737253900465939616209479991340231947699967362172752101872",
        800064: "463030671847361009623655041980105839559505707889683150053505526906666733",
        857895: "511233108311607355399004664888628607974771859309555250866227390356885633"
    ]

    //etherscan APIs
    public static let mainnetEtherscanAPI = "https://api.etherscan.io/api?module=account&action=txlist&address="
    public static let ropstenEtherscanAPI = "https://ropsten.etherscan.io/api?module=account&action=txlist&address="
    public static let rinkebyEtherscanAPI = "https://rinkeby.etherscan.io/api?module=account&action=txlist&address="

    //etherscan contract details web page
    public static let mainnetEtherscanContractDetailsWebPageURL = "https://etherscan.io/address/"
    public static let ropstenEtherscanContractDetailsWebPageURL = "https://ropsten.etherscan.io/address/"
    public static let rinkebyEtherscanContractDetailsWebPageURL = "https://rinkeby.etherscan.io/address/"
    
    //ERC specs
    public static let erc721InterfaceHash = "0x9a20483d"
}

public struct UnitConfiguration {
    public static let gasPriceUnit: EthereumUnit = .gwei
    public static let gasFeeUnit: EthereumUnit = .ether
    public static let finneyUnit: EthereumUnit = .finney
}
