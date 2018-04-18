// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct Constants {
    public static let coinbaseWidgetCode = "88d6141a-ff60-536c-841c-8f830adaacfd"
    public static let shapeShiftPublicKey = "c4097b033e02163da6114fbbc1bf15155e759ddfd8352c88c55e7fef162e901a800e7eaecf836062a0c075b2b881054e0b9aa2324be7bc3694578493faf59af4"
    public static let changellyRefferalID = "968d4f0f0bf9"
    public static let keychainKeyPrefix = "trustwallet"
    public static let gasLimit = BigInt(300000)

    // fee master
    public static let paymentServer = "http://feemaster.eastasia.cloudapp.azure.com:8080/api/claimToken"
    public static let getTicketInfoFromServer = "http://192.168.1.50:8080/api/ecrecoverAndGetTickets"
    //"http://feemaster.eastasia.cloudapp.azure.com:8080/api/ecrecoverAndGetTickets"


    // social
    public static let website = "https://www.awallet.io/"
    public static let twitterUsername = "Alpha_wallet"
    public static let redditGroupName = "r/AlphaWallet/"
    public static let facebookUsername = "AlphaWallet"

    // support
    public static let supportEmail = "support@awallet.io"
    public static let donationAddress = "0xFE6d4bC2De2D0b0E6FE47f08A28Ed52F9d052A02"
    public static let dappsBrowserURL = "https://dapps.trustwalletapp.com"

    // FIFA hardcoded FIFA token address. Look for "//FIFA" for relevant changes
    public static let fifaContractAddress = "0x6aE0e6D98955bA13Dacf654C4819e6A1886E978f"
    public static let nullTicket = "0x0000000000000000000000000000000000000000000000000000000000000000"
}

public struct UnitConfiguration {
    public static let gasPriceUnit: EthereumUnit = .gwei
    public static let gasFeeUnit: EthereumUnit = .ether
    public static let finneyUnit: EthereumUnit = .finney
}
