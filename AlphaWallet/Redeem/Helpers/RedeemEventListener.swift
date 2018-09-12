//
//  RedeemEventListener.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/12/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import TrustKeystore

class RedeemEventListener {

    var shouldListen = false

    func start(for address: Address,
               completion: @escaping () -> Void) {
        if !shouldListen {
            return
        }
        EventsRest().getEvents(for: address, completion: { [weak self] result in
            guard let strongSelf = self else { return }
            print(result)
            switch result {
            case .success(let events):
                print(events)
                completion()
            case .failure(let error):
                print(error)
                strongSelf.start(for: address, completion: completion)
            }
        })
    }

    func stop() {
        shouldListen = false
        RestClient.cancel()
    }
}
