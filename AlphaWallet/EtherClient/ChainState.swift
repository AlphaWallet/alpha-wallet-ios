// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import JSONRPCKit
import APIKit
import PromiseKit

class ChainState {

    struct Keys {
        static let latestBlock = "chainID"
    }

    private let server: RPCServer

    private var latestBlockKey: String {
        return "\(server.chainID)-" + Keys.latestBlock
    }

    var latestBlock: Int {
        get {
            return defaults.integer(forKey: latestBlockKey)
        }
        set {
            defaults.set(newValue, forKey: latestBlockKey)
        }
    }
    let defaults: UserDefaults

    var updateLatestBlock: Timer?

    init(config: Config, server: RPCServer) {
        self.server = server
        self.defaults = config.defaults
        if config.development.isAutoFetchingDisabled {
            //No-op
        } else {
            self.updateLatestBlock = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.fetch()
            }
        }
    }

    func start() {
        fetch()
    }

    func stop() {
        updateLatestBlock?.invalidate()
        updateLatestBlock = nil
    }

    @objc func fetch() {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BlockNumberRequest()))
        firstly {
            Session.send(request)
        }.done { [weak self] in
            self?.latestBlock = $0
        }.catch { error in
            //We need to catch (and since we can make a good guess what it might be, capture it below) it instead of `.cauterize()` because the latter would log a scary message about malformed JSON in the console.
            if case SendTransactionRetryableError.possibleBinanceTestnetTimeout = error {
                //TODO log
            }
        }
    }

    func confirmations(fromBlock: Int) -> Int? {
        guard fromBlock > 0 else { return nil }
        let block = latestBlock - fromBlock
        guard latestBlock != 0, block > 0 else { return nil }
        return max(0, block)
    }

}
