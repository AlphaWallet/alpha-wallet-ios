//
//  FirebaseReportService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2021.
//

import Firebase
import AlphaWalletFoundation

extension AlphaWallet {
    final class FirebaseReportService: ReportService {
        private let options: FirebaseOptions
        // NOTE: failable initializer allow us easily configure with different plist files for different configurations of project
        init?(contents: String? = Constants.googleServiceInfoPlistContent) {
            guard let contents = contents, let options = FirebaseOptions(contentsOfFile: contents) else {
                return nil
            }

            self.options = options
        }

        func configure() {
            FirebaseApp.configure(options: options)
        }
    }

    final class FirebaseCrashlyticsReporter: CrashlyticsReporter {
        private let crashlytics: Crashlytics = Crashlytics.crashlytics()

        func track(wallets: [Wallet]) {
            guard Features.default.isAvailable(.isFirebaseEnabled) else { return }

            let wallets = wallets.map { $0.description }.joined(separator: ", ")
            let keysAndValues: [String: Any] = [
                ReportKey.walletAddresses.rawValue: wallets,
             ] as [String: Any]

            crashlytics.setCustomKeysAndValues(keysAndValues)
        }

        func trackActiveWallet(wallet: Wallet) {
            guard Features.default.isAvailable(.isFirebaseEnabled) else { return }

            let keysAndValues: [String: Any] = [
                ReportKey.activeWalletAddress.rawValue: wallet.description,
             ] as [String: Any]

            crashlytics.setCustomKeysAndValues(keysAndValues)
        }

        func track(enabledServers: [RPCServer]) {
            guard Features.default.isAvailable(.isFirebaseEnabled) else { return }

            let chainIds = enabledServers
                .map(\.chainID)
                .sorted()
                .map(\.description)
                .joined(separator: ", ")
            let keysAndValues: [String: Any] = [
                ReportKey.activeServers.rawValue: chainIds,
            ] as [String: Any]

            crashlytics.setCustomKeysAndValues(keysAndValues)
        }

        /// Logs large nft asset jsons to Realm, that cause crashes
        /// - actions - update nft token balance operations
        /// - fileSizeThreshold - max json string size, that will trigger logging
        @discardableResult func logLargeNftJsonFiles(for actions: [AddOrUpdateTokenAction], fileSizeThreshold: Double = 10) -> Bool {
            func logNftJsonFileIfNeeded(address: AlphaWallet.Address, server: RPCServer, balance: NonFungibleBalance) -> Bool {
                switch balance {
                case .assets(let rawAssets):
                let result = rawAssets.filter { Double($0.json.count / 1048576) > fileSizeThreshold }
                    if result.isEmpty {
                        return false
                    } else {
                        for each in rawAssets {
                            let fileSizeInMb = Double(each.json.count / 1048576)
                            if !isRunningTests() {
                                logStoreLargeNonFungible(address: address, server: server, fileSize: fileSizeInMb, source: each.source)
                            } else {
                                infoLog("[Crashlytics] log large Nft asset json for address: \(address), server: \(server), fileSize: \(fileSizeInMb)MB, source: \(each.source.description)")
                            }
                        }

                        return true
                    }
                case .erc721ForTickets, .erc875, .balance:
                    return false
                }
            }

            var result: Bool?

            for action in actions {
                switch action {
                case .update(let token, let action):
                    guard case .nonFungibleBalance(let balance) = action else { continue }
                    let hasLargeFileSize = logNftJsonFileIfNeeded(address: token.contractAddress, server: token.server, balance: balance)
                    if result == nil && hasLargeFileSize {
                        result = hasLargeFileSize
                    }
                case .add(let token, _):
                    let hasLargeFileSize = logNftJsonFileIfNeeded(address: token.contract, server: token.server, balance: token.balance)
                    if result == nil && hasLargeFileSize {
                        result = hasLargeFileSize
                    }
                }
            }

            return result ?? false
        }

        private func logStoreLargeNonFungible(address: AlphaWallet.Address, server: RPCServer, fileSize: Double, source: NonFungibleBalance.Source) {
            let error = NSError(domain: "org.alphawallet.swift.nft", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Save NFT balance failure",
                NSLocalizedFailureReasonErrorKey: "Attempt to save String that is larger that 10 mb, to realm storage",
                NSLocalizedRecoverySuggestionErrorKey: "Unknown Error - Please try again",
                "address": address.eip55String,
                "chainId": String(server.chainID),
                "fileSize": "\(fileSize)MB",
                "source": source.description
            ])

            crashlytics.record(error: error)
        }
    }
}

extension Constants {
    public static let googleServiceInfoPlistContent: String? = {
        R.file.googleServiceInfoPlist()?.path
    }()
}
