// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public class Features {
    public static let `default`: Features = Features()!

    private let encoder: JSONEncoder = JSONEncoder()
    private let fileUrl: URL

    private var isMutationAvailable: Bool {
        return (Environment.isTestFlight || Environment.isDebug)
    }
    private var featuresDictionary: [FeaturesAvailable: Bool] = [FeaturesAvailable: Bool]()

    public init?(fileName: String = "Features.json") {
        do {
            var url: URL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            url.appendPathComponent(fileName)
            self.fileUrl = url
            self.readFromFileUrl()
        } catch {
            verboseLog("[Features] init Exception: \(error)")
            return nil
        }
    }

    private func readFromFileUrl() {
        do {
            let decoder = JSONDecoder()
            let data = try Data(contentsOf: fileUrl)
            let jsonData = try decoder.decode([FeaturesAvailable: Bool].self, from: data)
            featuresDictionary = jsonData
        } catch {
            verboseLog("[Features] readFromFileUrl error: \(error)")
            featuresDictionary = [FeaturesAvailable: Bool]()
        }
    }

    private func writeToFileUrl() {
        do {
            let data = try encoder.encode(featuresDictionary)
            if let jsonString = String(data: data, encoding: .utf8) {
                try jsonString.write(to: fileUrl, atomically: true, encoding: .utf8)
            }
        } catch {
            verboseLog("[Features] writeToFileUrl error: \(error)")
        }
    }

    public func isAvailable(_ item: FeaturesAvailable) -> Bool {
        if isMutationAvailable, let value = featuresDictionary[item] {
            return value
        }
        return item.defaultValue
    }

    public func setAvailable(_ item: FeaturesAvailable, _ value: Bool) {
        guard isMutationAvailable else { return }
        featuresDictionary[item] = value
        writeToFileUrl()
    }

    public func invert(_ item: FeaturesAvailable) {
        let value = !isAvailable(item)
        setAvailable(item, value)
    }

    public func reset() {
        FeaturesAvailable.allCases.forEach { key in
            setAvailable(key, key.defaultValue)
        }
    }

}

public enum FeaturesAvailable: String, CaseIterable, Codable {
    case isActivityEnabled
    case isSendAllFundsFungibleEnabled
    case isSpeedupAndCancelEnabled
    case isLanguageSwitcherDisabled
    case shouldLoadTokenScriptWithFailedSignatures
    case isRenameWalletEnabledWhileLongPress
    case shouldPrintCURLForOutgoingRequest
    case isEip3085AddEthereumChainEnabled
    case isEip3326SwitchEthereumChainEnabled
    case isPromptForEmailListSubscriptionEnabled
    case isAlertsEnabled
    case isErc1155Enabled
    case isUsingPrivateNetwork
    case isUsingAppEnforcedTimeoutForMakingWalletConnectConnections
    case isAttachingLogFilesToSupportEmailEnabled
    case isPalmEnabled
    case isExportJsonKeystoreEnabled
    case is24SeedWordPhraseAllowed
    case isAnalyticsUIEnabled
    case isJsonFileBasedStorageForWalletAddressesEnabled
    case isBlockscanChatEnabled
    case isTokenScriptSignatureStatusEnabled
    case isFirebaseEnabled
    case isSwapEnabled
    case isCoinbasePayEnabled
    case isLoggingEnabledForTickerMatches

    public var defaultValue: Bool {
        switch self {
        case .isActivityEnabled:
            return true
        case .isSendAllFundsFungibleEnabled:
            return true
        case .isSpeedupAndCancelEnabled:
            return true
        case .isLanguageSwitcherDisabled:
            return true
        case .shouldLoadTokenScriptWithFailedSignatures:
            return true
        case .isRenameWalletEnabledWhileLongPress:
            return true
        case .shouldPrintCURLForOutgoingRequest:
            return false
        case .isEip3085AddEthereumChainEnabled:
            return true
        case .isEip3326SwitchEthereumChainEnabled:
            return true
        case .isPromptForEmailListSubscriptionEnabled:
            return true
        case .isAlertsEnabled:
            return false
        case .isErc1155Enabled:
            return true
        case .isUsingPrivateNetwork:
            return true
        case .isUsingAppEnforcedTimeoutForMakingWalletConnectConnections:
            return true
        case .isAttachingLogFilesToSupportEmailEnabled:
            return false
        case .isPalmEnabled:
            return true
        case .isExportJsonKeystoreEnabled:
            return true
        case .is24SeedWordPhraseAllowed:
            return true
        case .isAnalyticsUIEnabled:
            return true
        case .isJsonFileBasedStorageForWalletAddressesEnabled:
            return true
        case .isBlockscanChatEnabled:
            return true
        case .isTokenScriptSignatureStatusEnabled:
            return false
        case .isFirebaseEnabled:
            return true
        case .isSwapEnabled:
            return false
        case .isCoinbasePayEnabled:
            return false
        case .isLoggingEnabledForTickerMatches:
            return false
        }
    }

    public var descriptionLabel: String {
        return self.rawValue.insertSpaceBeforeCapitals()
    }
}
