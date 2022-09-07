// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore

public final class ChainState {
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private lazy var provider: ChainStateSchedulerProvider = {
        let provider = ChainStateSchedulerProvider(server: server, analytics: analytics)
        provider.delegate = self

        return provider
    }()
    private lazy var scheduler = Scheduler(provider: provider)
    private var config: Config

    public var latestBlock: Int {
        get { return config.latestBlock(server: server) }
        set { config.set(latestBlock: newValue, for: server) }
    }

    public init(config: Config, server: RPCServer, analytics: AnalyticsLogger) {
        self.config = config
        self.server = server
        self.analytics = analytics
    }

    public func start() {
        scheduler.start()
    }

    public func stop() {
        scheduler.cancel()
    }

    public func confirmations(fromBlock: Int) -> Int? {
        guard fromBlock > 0 else { return nil }
        let block = latestBlock - fromBlock
        guard latestBlock != 0, block > 0 else { return nil }
        return max(0, block)
    }
}

extension ChainState: ChainStateSchedulerProviderDelegate {
    public func didReceive(result: Result<Int, PromiseError>) {
        switch result {
        case .success(let block):
            latestBlock = block
        case .failure(let error):
            //We need to catch (and since we can make a good guess what it might be, capture it below) it instead of `.cauterize()` because the latter would log a scary message about malformed JSON in the console.
            guard case .some(let error) = error else { return }
            if case RpcNodeRetryableRequestError.possibleBinanceTestnetTimeout = error {
                //TODO log
            }
        }
    }
}

fileprivate extension Config {
    private static func chainStateKey(server: RPCServer) -> String {
        return "\(server.chainID)-" + "chainID"
    }

    func latestBlock(server: RPCServer) -> Int {
        let latestBlockKey = Config.chainStateKey(server: server)
        return defaults.integer(forKey: latestBlockKey)
    }

    func set(latestBlock: Int, for server: RPCServer) {
        let latestBlockKey = Config.chainStateKey(server: server)
        defaults.set(latestBlock, forKey: latestBlockKey)
    }
}
