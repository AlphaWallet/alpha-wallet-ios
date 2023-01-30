// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore
import Combine

public protocol BlockNumberStorage {
    func latestBlock(server: RPCServer) -> BlockNumber
    func set(latestBlock: BlockNumber, for server: RPCServer)
}

public final class BlockNumberProvider {

    private lazy var provider: BlockNumberSchedulerProvider = {
        let provider = BlockNumberSchedulerProvider(blockchainProvider: blockchainProvider)
        provider.delegate = self

        return provider
    }()
    private let blockchainProvider: BlockchainProvider
    private lazy var scheduler = Scheduler(provider: provider)
    private var storage: BlockNumberStorage
    public var latestBlock: Int {
        get { return storage.latestBlock(server: blockchainProvider.server) }
        set {
            storage.set(latestBlock: newValue, for: blockchainProvider.server)
            latestBlockSubject.send(newValue)
        }
    }

    public var latestBlockPublisher: AnyPublisher<Int, Never> {
        latestBlockSubject.eraseToAnyPublisher()
    }

    private lazy var latestBlockSubject: CurrentValueSubject<Int, Never> = .init(latestBlock)

    public init(storage: BlockNumberStorage, blockchainProvider: BlockchainProvider) {
        self.storage = storage
        self.blockchainProvider = blockchainProvider
    }

    deinit {
        scheduler.cancel()
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

extension BlockNumberProvider: BlockNumberSchedulerProviderDelegate {
    public func didReceive(result: Result<BlockNumber, PromiseError>) {
        switch result {
        case .success(let blockNumber):
            latestBlock = blockNumber
        case .failure(let error):
            //We need to catch (and since we can make a good guess what it might be, capture it below) it instead of `.cauterize()` because the latter would log a scary message about malformed JSON in the console.
            guard case .some(let error) = error else { return }
            if case RpcNodeRetryableRequestError.possibleBinanceTestnetTimeout = error {
                //TODO log
            }
        }
    }
}

extension Config: BlockNumberStorage {
    private static func chainStateKey(server: RPCServer) -> String {
        return "\(server.chainID)-" + "chainID"
    }

    public func latestBlock(server: RPCServer) -> BlockNumber {
        let latestBlockKey = Config.chainStateKey(server: server)
        return defaults.integer(forKey: latestBlockKey)
    }

    public func set(latestBlock: BlockNumber, for server: RPCServer) {
        let latestBlockKey = Config.chainStateKey(server: server)
        defaults.set(latestBlock, forKey: latestBlockKey)
    }
}

