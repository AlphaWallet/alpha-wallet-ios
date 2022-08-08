// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

extension Constants {
    enum Credentials {
        private static func env(_ name: String) -> String? {
            return ProcessInfo.processInfo.environment[name]
        }

        static let infuraKey = env("INFURAKEY") ?? "ad6d834b7a1e4d03a7fde92020616149"
        static let etherscanKey = env("ETHERSCANKEY") ?? "1PX7RG8H4HTDY8X55YRMCAKPZK476M23ZR"
        static let binanceSmartChainExplorerApiKey: String? = env("BINANCESMARTCHAINEXPLORERAPIKEY")
        static let polygonScanExplorerApiKey: String? = env("POLYGONSCANEXPLORERAPIKEY")
        static let analyticsKey = ""
        static let paperTrail = (host: "", port: UInt(0))
        static let mailChimpListSpecificKey = ""
        static let openseaKey = env("OPENSEAKEY") ?? "11ba1b4f0c4246aeb07b1f8e5a20525f"
        static let rampApiKey = "j5wr7oqktym7z69yyf84bb8a6cqb7qfu5ynmeyvn"
        static let enjinUserName = "vlad_shepitko@outlook.com"
        static let enjinUserPassword: String = "wf@qJPz75CL9Tw$"
        static let walletConnectProjectId = "8ba9ee138960775e5231b70cc5ef1c3a"
        static let unstoppableDomainsV2ApiKey = "Bearer rLuujk_dLBN-JDE6Xl8QSCg-FeIouRKM"
        static let blockscanChatProxyKey = ""
        static let covalentApiKey = env("COVALENTAPIKEY") ?? "ckey_7ee61be7f8364ba784f697510bd"
        //Without the "Basic " prefix
        static let klaytnRpcNodeKeyBasicAuth = env("KLAYTNRPCNODEKEYBASICAUTH") ?? ""
    }
}
