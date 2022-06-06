//
//  FakeEnsRecordsStorage.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 07.06.2022.
//

import Foundation
import RealmSwift
@testable import AlphaWallet

final class FakeEnsRecordsStorage: RealmStore {
    init() {
        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryEnsRecordsRealm"))
        super.init(realm: realm)
    }
}
