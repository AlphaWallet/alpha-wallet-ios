//
//  FakeEnsRecordsStorage.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 07.06.2022.
//

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

final class FakeEnsRecordsStorage: RealmStore {
    init() {
        super.init(config: fakeRealmConfiguration())
    }
}
