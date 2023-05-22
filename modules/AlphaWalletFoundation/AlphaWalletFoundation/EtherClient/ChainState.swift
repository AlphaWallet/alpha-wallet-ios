// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore
import Combine

public protocol BlockNumberStorage {
    func latestBlock(server: RPCServer) -> BlockNumber
    func set(latestBlock: BlockNumber, for server: RPCServer)
}

public final class BlockNumberProvider {
    private let provider: BlockNumberSchedulerProvider
    private let scheduler: Scheduler
    private var storage: BlockNumberStorage
    private let server: RPCServer
    public var latestBlock: Int {
        get { return storage.latestBlock(server: server) }
        set {
            storage.set(latestBlock: newValue, for: server)
            subject.send(newValue)
        }
    }

    public var latestBlockPublisher: AnyPublisher<Int, Never> {
        subject.eraseToAnyPublisher()
    }
    private var cancellable = Set<AnyCancellable>()
    private lazy var subject: CurrentValueSubject<Int, Never> = .init(latestBlock)

    public init(storage: BlockNumberStorage, blockchainProvider: BlockchainProvider) {
        self.storage = storage
        self.server = blockchainProvider.server
        self.provider = BlockNumberSchedulerProvider(blockchainProvider: blockchainProvider)
        self.scheduler = Scheduler(provider: provider)
    }

    deinit {
        scheduler.cancel()
    }

    public func start() {
        scheduler.start()
        provider.publisher
            .sink { [weak self] result in
                switch result {
                case .success(let blockNumber):
                    self?.latestBlock = blockNumber
                case .failure(let error):
                    //We need to catch (and since we can make a good guess what it might be, capture it below) it instead of `.cauterize()` because the latter would log a scary message about malformed JSON in the console.
                    guard case .some(let error) = error else { return }
                    if case RpcNodeRetryableRequestError.possibleBinanceTestnetTimeout = error {
                        //TODO log
                    }
                }
            }.store(in: &cancellable)
    }

    public func restart() {
        scheduler.restart(force: true)
    }

    public func cancel() {
        scheduler.cancel()
    }

    public func confirmations(fromBlock: Int) -> Int? {
        guard fromBlock > 0 else { return nil }
        let block = latestBlock - fromBlock
        guard latestBlock != 0, block > 0 else { return nil }
        return max(0, block)
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

