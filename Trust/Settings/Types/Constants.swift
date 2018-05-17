// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct Constants {
    public static let coinbaseWidgetCode = "88d6141a-ff60-536c-841c-8f830adaacfd"
    public static let shapeShiftPublicKey = "c4097b033e02163da6114fbbc1bf15155e759ddfd8352c88c55e7fef162e901a800e7eaecf836062a0c075b2b881054e0b9aa2324be7bc3694578493faf59af4"
    public static let changellyRefferalID = "968d4f0f0bf9"
    public static let keychainKeyPrefix = "alphawallet"
    public static let gasLimit = BigInt(300000)
    public static let gasPriceDefaultStormbird = BigInt("22000000000")!

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
}

public struct UnitConfiguration {
    public static let gasPriceUnit: EthereumUnit = .gwei
    public static let gasFeeUnit: EthereumUnit = .ether
    public static let finneyUnit: EthereumUnit = .finney
}
