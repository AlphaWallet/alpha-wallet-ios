// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

protocol AnalyticsNavigation {
    var rawValue: String { get }
}

protocol AnalyticsAction {
    var rawValue: String { get }
}

protocol AnalyticsError {
    var rawValue: String { get }
}

protocol AnalyticsUserProperty {
    var rawValue: String { get }
}

enum Analytics {
    enum Navigation: String, AnalyticsNavigation {
        case actionSheetForTransactionConfirmation = "Screen: Txn Confirmation"
        case actionSheetForTransactionConfirmationSuccessful = "Screen: Txn Confirmation Successful"
        case actionSheetForTransactionConfirmationFailed = "Screen: Txn Confirmation Failed"
        case scanQrCode = "Screen: QR Code Scanner"
        case onRamp = "Screen: Fiat On-Ramp"
        case tokenSwap = "Screen: Token Swap"
        case switchServers = "Screen: Switch Servers"
        case showDapps = "Screen: Dapps"
        case showHistory = "Screen: Dapp History"
        case tapBrowserMore = "Screen: Browser More Options"
        case signMessageRequest = "Screen: Sign Message Request"
        case walletConnect = "Screen: WalletConnect"
        case faq = "Screen: FAQ"
        case discord = "Screen: Discord"
        case telegramCustomerSupport = "Screen: Telegram: Customer Support"
        case twitter = "Screen: Twitter"
        case reddit = "Screen: Reddit"
        case facebook = "Screen: Facebook"
        case github = "Screen: Github"
        case explorer = "Screen: Explorer"
        case openShortcut = "Screen: Shortcut"
        case openHelpUrl = "Screen: Help URL"
    }

    enum Action: String, AnalyticsAction {
        case cancelsTransactionInActionSheet = "Txn Confirmation Cancelled"
        case cancelScanQrCode = "Scan QR Code Cancelled"
        case completeScanQrCode = "Scan QR Code Completed"
        case reloadBrowser = "Reload Browser"
        case shareUrl = "Share URL"
        case addDapp = "Add Dapp"
        case enterUrl = "Enter URL"
        case signMessageRequest = "Sign Message Request"
        case cancelSignMessageRequest = "Cancel Sign Message Request"
        case switchedServer = "Switch Server Completed"
        case cancelsSwitchServer = "Switch Server Cancelled"
        case walletConnectConnect = "WalletConnect Connect"
        case walletConnectCancel = "WalletConnect Cancel"
        case walletConnectDisconnect = "WalletConnect Disconnect"
        case walletConnectSwitchNetwork = "WalletConnect Switch Network"
        case walletConnectConnectionTimeout = "WalletConnect Connection Timeout"
        case walletConnectConnectionFailed = "WalletConnect Connection Failed"
        case clearBrowserCache = "Clear Browser Cache"
        case pingInfura = "Ping Infura"
        case rectifySendTransactionErrorInActionSheet = "Rectify Send Txn Error"
        case nameWallet = "Name Wallet"
        case firstWalletAction = "First Wallet Action"
        case addCustomChain = "Add Custom Chain"
        case editCustomChain = "Edit Custom Chain"
        case subscribeToEmailNewsletter = "Subscribe Email Newsletter"
        case tapSafariExtensionRewrittenUrl = "Tap Safari Extension Rewritten URL"
    }

    //Include "Error" at the end of the String value so it's easier to filter in analytics dashboard
    enum Error: String, AnalyticsError {
        case sendTransactionNonceTooLow = "Send Transaction Nonce Too Low Error"
    }

    enum Properties: String {
        case address
        case from
        case to
        case amount
        case source
        case resultType
        case speedType
        case chain
        case transactionType
        case name
        case messageType
        case isPrivateNetworkEnabled
        case sendPrivateTransactionsProvider
        case type
        case isAllFunds
        case addCustomChainType
        case isAccepted
        case reason
    }

    enum UserProperties: String, AnalyticsUserProperty {
        case transactionCount
        case testnetTransactionCount
        case enabledChains
        case walletsCount
        case hdWalletsCount
        case keystoreWalletsCount
        case watchedWalletsCount
        case dynamicTypeSetting
        case hasEnsAvatar
    }

    enum ScanQRCodeSource: String {
        case sendFungibleScreen
        case addressTextField
        case browserScreen
        case importWalletScreen
        case addCustomTokenScreen
        case walletScreen
        case quickAction
    }

    enum ScanQRCodeResultType: String {
        case value
        case walletConnect
        case other
        case url
        case privateKey
        case seedPhase
        case json
        case address
    }

    enum TransactionConfirmationSource: String {
        case walletConnect
        case sendFungible
        case tokenScript
        case sendNft
        case browser
        case claimPaidMagicLink
        case speedupTransaction
        case cancelTransaction
    }

    enum TransactionConfirmationSpeedType: String {
        case slow
        case standard
        case fast
        case rapid
        case custom
    }

    enum TransactionType: String {
        case erc20Transfer
        case erc20Approve
        case nativeCryptoTransfer
        case unknown
    }

    enum SignMessageRequestSource: String {
        case dappBrowser
        case tokenScript
        case walletConnect
    }

    enum SignMessageRequestType: String {
        case message
        case personalMessage
        case eip712
        case eip712v3And4
    }

    enum ExplorerType: String {
        case transaction
        case token
        case wallet
    }

    enum FirstWalletAction: String {
        case create
        case `import`
        case watch
    }

    enum WalletConnectAction: String {
        case bridgeUrl
    }

    enum ShortcutType: String {
        case walletQrCode
    }

    enum HelpUrl: String {
        case insufficientFunds
    }

    enum FiatOnRampSource: String {
        case token
        case transactionActionSheetInsufficientFunds
        case speedupTransactionInsufficientFunds
        case cancelTransactionInsufficientFunds
        case walletTab
    }
}