// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct Constants {
    public static let coinbaseWidgetCode = "88d6141a-ff60-536c-841c-8f830adaacfd"
    public static let shapeShiftPublicKey = "c4097b033e02163da6114fbbc1bf15155e759ddfd8352c88c55e7fef162e901a800e7eaecf836062a0c075b2b881054e0b9aa2324be7bc3694578493faf59af4"
    public static let changellyRefferalID = "968d4f0f0bf9"
    //
    public static let keychainKeyPrefix = "trustwallet"

    // social
    public static let website = "https://www.awallet.io/"
    public static let twitterUsername = "Alpha_wallet"
    public static let redditGroupName = "r/AlphaWallet/"
    public static let facebookUsername = "AlphaWallet"

    // support
    public static let supportEmail = "support@awallet.io"
    public static let donationAddress = "0xFE6d4bC2De2D0b0E6FE47f08A28Ed52F9d052A02"
    public static let dappsBrowserURL = "https://dapps.trustwalletapp.com"

    //FIFA hardcoded FIFA token address. Look for "//FIFA" for relevant changes
    public static let fifaContractAddress = "0xa9012Dc044B71EC2bA59903007d100b70AEf1a9a"
}

public struct UnitConfiguration {
    public static let gasPriceUnit: EthereumUnit = .gwei
    public static let gasFeeUnit: EthereumUnit = .ether
    public static let finneyUnit: EthereumUnit = .finney
}
