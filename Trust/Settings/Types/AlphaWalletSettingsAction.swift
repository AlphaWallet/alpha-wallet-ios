// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

//Duplicated from SettingsAction.swift for easier upstream merging
enum AlphaWalletSettingsAction {
	case myWalletAddress
	case notificationsSettings
	case wallets
	case RPCServer
	case currency
	case DAppsBrowser
	case pushNotifications(enabled: Bool)
}
