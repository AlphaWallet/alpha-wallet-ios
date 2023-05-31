//
//  FakeEnsRecordsStorage.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 07.06.2022.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import Foundation

final class FakeEnsRecordsStorage: RealmStore {
    init() {
        super.init(realm: fakeRealm())
    }
}
