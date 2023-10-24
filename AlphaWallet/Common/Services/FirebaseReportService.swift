//
//  FirebaseReportService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2021.
//
import FirebaseCore
import FirebaseCrashlytics
import func AlphaWalletCore.isRunningTests
import AlphaWalletFoundation
import AlphaWalletLogger

extension AlphaWallet {
    final class FirebaseCrashlyticsReporter: CrashlyticsReporter {
        private let crashlytics: Crashlytics = Crashlytics.crashlytics()

        //NOTE: to avoid warning `The default Firebase app has not yet been configured. FirebaseApp.configure()`, moving code to init method have no affect
        //@MainActor because crashlytics accesses the status bar (which is UI)
        @MainActor static var instance: FirebaseCrashlyticsReporter = {
            //TODO use a shared instance of `Config` instead, or does it not matter?
            var config = Config()
            if config.sendCrashReportingEnabled == nil {
                config.sendCrashReportingEnabled = true
            }

            let file = isRunningTests() ? R.file.googleServiceInfoTestsPlist() : R.file.googleServiceInfoPlist()
            if let options = file.flatMap({ FirebaseOptions(contentsOfFile: $0.path) }) {
                if isAlphaWallet() && config.isSendCrashReportingEnabled {
                    FirebaseApp.configure(options: options)
                }
            }

            return FirebaseCrashlyticsReporter()
        }()

        private init() { }

        func track(wallets: [Wallet]) {
            let wallets = wallets.map { $0.description }.joined(separator: ", ")
            let keysAndValues: [String: Any] = [
                ReportKey.walletAddresses.rawValue: wallets,
             ] as [String: Any]

            crashlytics.setCustomKeysAndValues(keysAndValues)
        }

        func trackActiveWallet(wallet: Wallet) {
            let keysAndValues: [String: Any] = [
                ReportKey.activeWalletAddress.rawValue: wallet.description,
             ] as [String: Any]

            crashlytics.setCustomKeysAndValues(keysAndValues)
        }

        func track(enabledServers: [RPCServer]) {
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
                case .deleteDeletedContracts, .addOrUpdateDeletedContracts, .addOrUpdateDelegateContracts:
                    break
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

    enum ReportKey: String {
        case walletAddresses
        case activeWalletAddress
        case activeServers
    }
}
