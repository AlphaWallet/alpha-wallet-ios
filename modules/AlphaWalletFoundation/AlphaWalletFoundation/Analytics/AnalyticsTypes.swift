// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public protocol AnalyticsNavigation {
    var rawValue: String { get }
}

public protocol AnalyticsAction {
    var rawValue: String { get }
}

public protocol AnalyticsStat {
    var rawValue: String { get }
}

public protocol AnalyticsError {
    var rawValue: String { get }
}

public protocol AnalyticsUserProperty {
    var rawValue: String { get }
}

public enum Analytics {
    public enum Navigation: String, AnalyticsNavigation {
        case actionSheetForTransactionConfirmation = "Screen: Txn Confirmation"
        case actionSheetForTransactionConfirmationSuccessful = "Screen: Txn Confirmation Successful"
        case actionSheetForTransactionConfirmationFailed = "Screen: Txn Confirmation Failed"
        case scanQrCode = "Screen: QR Code Scanner"
        case onRamp = "Screen: Fiat On-Ramp"
        case onUniswap = "Screen: Uniswap"
        case onxDaiBridge = "Screen: xDai Bridge"
        case onHoneyswap = "Screen: Honeyswap"
        case onOneinch = "Screen: Oneinch"
        case onCarthage = "Screen: Carthage"
        case onArbitrumBridge = "Screen: Arbitrum Bridge"
        case onQuickSwap = "Screen: QuickSwap"
        case fallback = "Screen: <Fallback>"
        case tokenSwap = "Screen: Token Swap"
        case switchServers = "Screen: Switch Servers"
        case showDapps = "Screen: Dapps"
        case showHistory = "Screen: Dapp History"
        case tapBrowserMore = "Screen: Browser More Options"
        case signMessageRequest = "Screen: Sign Message Request"
        case walletConnect = "Screen: WalletConnect"
        case deepLink = "Screen: DeepLink"
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
        case blockscanChat = "Screen: Blockscan Chat"
    }

    public enum Action: String, AnalyticsAction {
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
        case walletConnectAuthAccept = "WalletConnect Auth Accept"
        case walletConnectAuthCancel = "WalletConnect Auth Cancel"
        case clearBrowserCache = "Clear Browser Cache"
        case pingInfura = "Ping Infura"
        case rectifySendTransactionErrorInActionSheet = "Rectify Send Txn Error"
        case nameWallet = "Name Wallet"
        case firstWalletAction = "First Wallet Action"
        case addCustomChain = "Add Custom Chain"
        case editCustomChain = "Edit Custom Chain"
        case subscribeToEmailNewsletter = "Subscribe Email Newsletter"
        case sharedAppWhenPrompted = "Shared App When Prompted"
        case tapSafariExtensionRewrittenUrl = "Tap Safari Extension Rewritten URL"
        case deepLinkCancel = "DeepLink Cancel"
        case deeplinkVisited = "DeepLink Visit"
        case attestationMagicLink = "Attestation MagicLink Visit"
        case customUrlSchemeVisited = "Custom URL Scheme Visit"
        case deepLinkWalletApiCall = "Deep Link Wallet API Call"
    }

    //TODO re-evaluate if these should go into the main analytic engine
    public enum Stat: String, AnalyticsStat {
        case blockscanChatFetchUnread
    }

    //Include "Error" at the end of the String value so it's easier to filter in analytics dashboard
    public enum Error: String, AnalyticsError {
        case sendTransactionNonceTooLow = "Send Transaction Nonce Too Low Error"
    }

    public enum WebApiErrors: String, AnalyticsError {
        case openSeaRateLimited
        case openSeaInvalidApiKey
        case openSeaExpiredApiKey
        case rpcNodeRateLimited
        case rpcNodeInvalidApiKey
        case lifiFetchSupportedTokensError
        case lifiFetchSwapQuoteError
        case lifiFetchSwapRouteError
        case lifiFetchSupportedToolsError
        case lifiFetchSupportedChainsError
        case coinGeckoRateLimited
        case blockchainExplorerRateLimited
        case blockchainExplorerError
    }

    public enum Properties: String {
        case address
        case from
        case to
        case amount
        case source
        case resultType
        case speedType
        case chain
        case chains
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
        case domainName
        case scheme
        case code
        case message
    }

    public enum EmbeddedDeepLinkType: String {
        case eip681
        case walletConnect
        case others
    }

    public enum UserProperties: String, AnalyticsUserProperty {
        case transactionCount
        case testnetTransactionCount
        case enabledChains
        case walletsCount
        case hdWalletsCount
        case keystoreWalletsCount
        case watchedWalletsCount
        case dynamicTypeSetting
        case hasEnsAvatar
        case isAppPasscodeOrBiometricProtectionEnabled
    }

    public enum ScanQRCodeSource: String {
        case sendFungibleScreen
        case addressTextField
        case browserScreen
        case importWalletScreen
        case addCustomTokenScreen
        case walletScreen
        case quickAction
        case siriShortcut
    }

    public enum ScanQRCodeResultType: String {
        case addressOrEip681
        case attestation
        case walletConnect
        case string
        case url
        case privateKey
        case seedPhrase
        case json
        case address
    }

    public enum TransactionConfirmationSource: String {
        case walletConnect
        case sendFungible
        case tokenScript
        case sendNft
        case browser
        case claimPaidMagicLink
        case speedupTransaction
        case cancelTransaction
        case swapApproval
        case swap
    }

    public enum TransactionConfirmationSpeedType: String {
        case slow
        case standard
        case fast
        case rapid
        case custom
    }

    public enum TransactionType: String {
        case erc20Transfer
        case erc20Approve
        case erc721ApproveAll
        case nativeCryptoTransfer
        case swap
        case unknown
    }

    public enum WalletConnectVersion: String {
        case v1, v2
    }

    public enum SignMessageRequestSource: CustomStringConvertible {
        public var description: String {
            switch self {
            case .tokenScript: return "tokenScript"
            case .deepLink: return "deepLink"
            case .dappBrowser: return "dappBrowser"
            case .walletConnect(let version): return "walletConnect-\(version.rawValue)"
            }
        }

        case dappBrowser
        case deepLink
        case tokenScript
        case walletConnect(WalletConnectVersion)
    }

    public enum SignMessageRequestType: String {
        case message
        case personalMessage
        case eip712
        case eip712v3And4
    }

    public enum ExplorerType: String {
        case transaction
        case token
        case wallet
    }

    public enum FirstWalletAction: String {
        case create
        case `import`
        case watch
    }

    public enum WalletConnectAction: String {
       case bridgeUrl
       case connectionUrl
    }

    public enum ShortcutType: String {
        case walletQrCode
        case camera
    }

    public enum HelpUrl: String {
        case insufficientFunds
    }

    public enum BuyCryptoSource: String {
        case token
        case transactionActionSheetInsufficientFunds
        case speedupTransactionInsufficientFunds
        case cancelTransactionInsufficientFunds
        case walletTab
    }

    public enum BlockscanChatResultType: String {
        case nonZero
        case zero
        case error429
        case errorOthers
    }
}
