//
//  FirebaseReportService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2021.
//

import Firebase

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

}

enum ReportKey: String {
    case walletAddresses
    case activeWalletAddress
}

let crashlytics = Crashlytics.crashlytics()

extension Crashlytics {

    func track(wallets: [Wallet]) {
        guard Features.default.isAvailable(.isFirebaseEnabled) else { return }

        let wallets = wallets.map { $0.description }.joined(separator: ", ")
        let keysAndValues: [String: Any] = [
            ReportKey.walletAddresses.rawValue: wallets,
         ] as [String: Any]

        setCustomKeysAndValues(keysAndValues)
    }

    func trackActiveWallet(wallet: Wallet) {
        guard Features.default.isAvailable(.isFirebaseEnabled) else { return }
        
        let keysAndValues: [String: Any] = [
            ReportKey.activeWalletAddress.rawValue: wallet.description,
         ] as [String: Any]

        setCustomKeysAndValues(keysAndValues)
    }
}
