// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

enum AlphaWalletSettingsAction {
	case myWalletAddress
	case notificationsSettings
	case wallets
	case RPCServer
	case currency
	case DAppsBrowser
	case pushNotifications(enabled: Bool)
	case language
}
