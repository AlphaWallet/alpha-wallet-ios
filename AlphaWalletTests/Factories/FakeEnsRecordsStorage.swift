//
//  FakeEnsRecordsStorage.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 07.06.2022.
//

import Foundation
@testable import AlphaWallet

final class FakeEnsRecordsStorage: RealmStore {
    init() {
        super.init(realm: fakeRealm())
    }
}
