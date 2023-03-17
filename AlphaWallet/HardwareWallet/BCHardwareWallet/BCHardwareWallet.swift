// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletFoundation
import AlphaWalletHardwareWallet

class BCHardwareWalletCreator: HardwareWalletFactory {
    func createWallet() -> HardwareWallet {
        _fail()
    }
}

class BCHardwareWallet {
    static let isEnabled: Bool = false
    static let name = "Hardware Wallet"

    required init(
        signatureObtainedMessage: HardwareWalletSuccessMessages,
        publicKeyObtainedMessage: HardwareWalletSuccessMessages,
        importedSeedMessage: HardwareWalletSuccessMessages
    ) {
        _fail()
    }
}

extension BCHardwareWallet: HardwareWallet {
    func signHash(_ hash: Data) async throws -> Data {
        _fail()
    }

    func getAddress() async throws -> AlphaWallet.Address {
        _fail()
    }
}

extension BCHardwareWallet {
    //This is just for development
    func wipe() async throws {
        _fail()
    }

    //This is just for development
    func importSeed(mnemonic: String) async throws -> AlphaWallet.Address {
        _fail()
    }
}

fileprivate func _fail(file: StaticString = #file, line: UInt = #line) -> Never {
    preconditionFailure("Should not call this since this is disabled with `isEnabled = false`", file: file, line: line)
}