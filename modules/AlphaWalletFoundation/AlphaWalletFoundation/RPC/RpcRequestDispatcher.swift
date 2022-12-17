//
//  RpcRequestDispatcher.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 15.01.2023.
//

import Foundation
import Combine
import AlphaWalletCore

public enum DispatchPolicy {
    case batch(Int)
    case noBatching

    var count: Int {
        switch self {
        case .batch(let int):
            return int
        case .noBatching:
            return 1
        }
    }
}

public protocol RpcRequestDispatcher {
    func send(request: RpcRequest, policy: DispatchPolicy?) -> AnyPublisher<RpcResponse, SessionTaskError>
}

extension RpcRequestDispatcher {
    public func send(request: RpcRequest) -> AnyPublisher<RpcResponse, SessionTaskError> {
        send(request: request, policy: nil)
    }
}

public final class BatchSupportableRpcRequestDispatcher: RpcRequestDispatcher {
    struct BatchError: Error, LocalizedError {
        let message: String

        public var localizedDescription: String {
            return message
        }
    }

    private let transporter: RpcRequestTransporter
    private let queue = DispatchQueue(label: "")
    private var batches: [BatchAsync] = []
    public var maxWaitTime: TimeInterval = 0.2
    public var policy: DispatchPolicy

    public init(transporter: RpcRequestTransporter, policy: DispatchPolicy) {
        self.transporter = transporter
        self.policy = policy
    }

    //NOTE: cancel request doens't work for batch requests, we actually can't cancel in when sending multiple requests at once, maybe just skip them on response
    public func send(request: RpcRequest, policy: DispatchPolicy?) -> AnyPublisher<RpcResponse, SessionTaskError> {
        Just(request)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { request -> AnyPublisher<RpcResponse, SessionTaskError> in
                self.dispatch(request: request, policy: policy ?? self.policy)
                    .flatMap { response -> AnyPublisher<RpcResponse, SessionTaskError> in
                        if let error = response.error {
                            return .fail(SessionTaskError(error: error))
                        } else {
                            return .just(response)
                        }
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    private func dispatch(request: RpcRequest, policy: DispatchPolicy) -> AnyPublisher<RpcResponse, SessionTaskError> {
        switch policy {
        case .noBatching:
            return transporter.dataTaskPublisher(request)
        case .batch(let count):
            guard let id = request.id else {
                return transporter.dataTaskPublisher(request)
            }

            let batch = getLatestBatchOrCreate(count: count)

//            do {
//                return try batch.add(request: request, id: id)
////                    .flatMap { Self.filter(responses: $0, looking: request) }
//                    .handleEvents(receiveOutput: { [weak self] _ in self?.batches.removeAll(where: { $0 == batch }) })
//                    .eraseToAnyPublisher()
//            } catch {
//                let batch = createBatch(count: count)
//                do {
//                    return try batch.add(request: request, id: id)
////                        .flatMap { Self.filter(responses: $0, looking: request) }
////                        .handleEvents(receiveOutput: { [weak self] _ in self?.batches.removeAll(where: { $0 == batch }) })
//                        .eraseToAnyPublisher()
//                } catch {
//                    return .fail(.responseError(error))
//                }
//            }

            return batch.add(request: request, id: id)
                .receive(on: queue)
                .handleEvents(receiveCompletion: { [weak self] _ in
                    print("xxx.batch.release")
                    self?.batches.removeAll(where: { $0 == batch })
                })
                .catch { [queue] error -> AnyPublisher<RpcResponse, SessionTaskError> in
                    guard let _ = error.unwrapped as? BatchError else { return .fail(error) }

                    let batch = self.createBatch(count: count)
                    return batch.add(request: request, id: id)
                        .receive(on: queue)
                        .handleEvents(receiveCompletion: { [weak self] _ in
                            print("xxx.batch.release")
                            self?.batches.removeAll(where: { $0 == batch })
                        }).eraseToAnyPublisher()
                }.print("xxx.batch.upstream")
                .eraseToAnyPublisher()
        }
    }

//    private static func filter(responses: [RpcResponse], looking request: RpcRequest) -> AnyPublisher<RpcResponse, SessionTaskError> {
//        if let error = responses.first?.error, responses.count == 1 {
//            let failureResponse = RpcResponse(id: request.id, error: error)
//            return .just(failureResponse)
//        }
//        guard let response = responses.first(where: { $0.id == request.id }) else {
//            return .fail(SessionTaskError(error: BatchError(message: "Response for \(request.id) not found")))
//        }
//        return .just(response)
//    }

    @discardableResult func createBatch(count: Int) -> BatchAsync {
        print("xxx.batch.build with capacity: \(count)")
        let batch = BatchAsync(capacity: count, maxWaitTime: maxWaitTime, transporter: transporter)

        batches.append(batch)

        return batch
    }

    private func getLatestBatchOrCreate(count: Int) -> BatchAsync {
        return batches.last ?? createBatch(count: count)
    }

//    public final class Batch {
//        private let uuid: UUID = UUID()
//        private let subject = PassthroughSubject<[RpcRequest], SessionTaskError>()
//        private let capacity: Int
//        private let requests: AtomicDictionary<RpcId, RpcRequest>
//        private let transporter: RpcRequestTransporter
//        private (set) var triggered: Bool = false
//        private var pendingTrigger: AnyCancellable?
//
//        let maxWaitTime: TimeInterval
//
//        public private (set) lazy var publisher: AnyPublisher<[RpcResponse], SessionTaskError> = {
//            subject
//                .breakpoint(receiveOutput: { r in
//                    print("xxx.batch.perform request: \(r.count)")
//                    return false
//                })
//                .flatMap { [transporter] in return Self.buildBatchOfRpcRequests(requests: $0, transporter: transporter) }
//                .share()
//                .eraseToAnyPublisher()
//        }()
//
//        private static func buildBatchOfRpcRequests(requests: [RpcRequest], transporter: RpcRequestTransporter) -> AnyPublisher<[RpcResponse], SessionTaskError> {
//            let request = RpcRequestBatch(requests: requests)
//            return transporter.dataTaskPublisher(request)
//                .map { $0.responses }
//                .eraseToAnyPublisher()
//        }
//
//        public func add(request: RpcRequest, id: RpcId) throws -> AnyPublisher<[RpcResponse], SessionTaskError> {
//            AnyPublisher<RpcResponse, SessionTaskError>.create { seal in
//                seal.send(<#T##input: RpcResponse##RpcResponse#>)
//                seal.send(completion: <#T##Subscribers.Completion<SessionTaskError>#>)
//
//                //seal: Publishers.Create<RpcResponse, SessionTaskError>.Subscriber
//                let cancellable = AnyCancellable {
//
//                }
//
//                return cancellable
//            }
//
//            guard !triggered else { throw SessionTaskError(error: BatchError(message: "Batch is already in flight")) }
//
//            if let value = requests[id] {
//                throw SessionTaskError(error: BatchError(message: "Request ID collision"))
//            } else {
//                requests[id] = request
//            }
//
//            if pendingTrigger == nil {
//                pendingTrigger = Timer.publish(every: maxWaitTime, on: RunLoop.main, in: .common)
//                    .autoconnect()
//                    .print("xxx.batch.trigger due to timeout")
//                    .sink { [weak self] _ in
//                        self?.trigger()
//                        self?.pendingTrigger?.cancel()
//                    }
//            }
//
//            if requests.count == capacity {
//                print("xxx.batch.trigger reach capacity")
//                trigger()
//            }
//
//            return publisher
//        }
//
//        func trigger() {
//            guard !triggered else { return }
//            triggered = true
//
//            subject.send(requests.values.map { $0.value })
//            subject.send(completion: .finished)
//        }
//
//        public init(capacity: Int, maxWaitTime: TimeInterval, transporter: RpcRequestTransporter) {
//            self.capacity = capacity
//            self.maxWaitTime = maxWaitTime
//            self.transporter = transporter
//            self.requests = .init(queue: DispatchQueue(label: "RealmStore.syncQueue", qos: .background))
//        }
//
//        static func == (lhs: Batch, rhs: Batch) -> Bool {
//            return lhs.uuid == rhs.uuid
//        }
//    }

    public final class BatchAsync {
        private let uuid: UUID = UUID()
        private let capacity: Int
        private let tasks: AtomicDictionary<RpcId, BatchTask>
        private let transporter: RpcRequestTransporter
        private var pendingTrigger: AnyCancellable?
        private var cancellable: AnyCancellable?

        let maxWaitTime: TimeInterval

        private let queue = DispatchQueue(label: "xxxx.")
        typealias BatchTask = (request: RpcRequest, seals: [Publishers.Create<RpcResponse, SessionTaskError>.Subscriber])

        private func add_xxx(request: RpcRequest, id: RpcId, seal: Publishers.Create<RpcResponse, SessionTaskError>.Subscriber) {
            guard cancellable == nil else {
                print("xxx.batch already on flight: \(id)")
                seal.send(completion: .failure(SessionTaskError(error: BatchError(message: "Batch is already in flight"))))
                return
            }

            if let task = tasks[id] {
                let seals = task.seals + [seal]
//                print("xxx.batch task already exists: \(id)")
//                seal.send(completion: .failure(SessionTaskError(error: BatchError(message: "Request ID collision"))))
//                return
                tasks[id] = (request: request, seals: seals)
            } else {
//                seals: [seal]
                tasks[id] = (request: request, seals: [seal])
            }

            if tasks.count == capacity {
                print("xxx.batch.trigger due to reach capacity")
                trigger()
            }

            if pendingTrigger == nil {
                pendingTrigger = Timer.publish(every: maxWaitTime, on: RunLoop.main, in: .common)
                    .autoconnect()
                    .receive(on: queue)
                    .print("xxx.batch.trigger due to timeout")
                    .sink { [weak self] _ in
                        self?.trigger()
                        self?.pendingTrigger?.cancel()
                    }
            }
        }

        static func == (lhs: BatchAsync, rhs: BatchAsync) -> Bool {
            return lhs.uuid == rhs.uuid
        }

        deinit {
            print("xxx.batch.\(self).deinit")
        }

        public func add(request: RpcRequest, id: RpcId) -> AnyPublisher<RpcResponse, SessionTaskError> {
            return AnyPublisher<RpcResponse, SessionTaskError>.create { [queue] seal in
                queue.sync {
                    self.add_xxx(request: request, id: id, seal: seal)
                }

                return AnyCancellable {
                    self.tasks[id] = nil
                    guard self.tasks.values.isEmpty else { return }
                    self.cancellable?.cancel()
                }
            }

//            guard !triggered else { throw SessionTaskError(error: BatchError(message: "Batch is already in flight")) }
//
//            if let value = requests[id] {
//                throw SessionTaskError(error: BatchError(message: "Request ID collision"))
//            } else {
//                requests[id] = request
//            }
//
//            if pendingTrigger == nil {
//                pendingTrigger = Timer.publish(every: maxWaitTime, on: RunLoop.main, in: .common)
//                    .autoconnect()
//                    .print("xxx.batch.trigger due to timeout")
//                    .sink { [weak self] _ in
//                        self?.trigger()
//                        self?.pendingTrigger?.cancel()
//                    }
//            }
//
//            if requests.count == capacity {
//                print("xxx.batch.trigger reach capacity")
//                trigger()
//            }
//
//            return publisher
        }

//        func add(request: RpcRequest, id: RpcId) async throws -> RpcResponse {
//                return try await withTaskCancellationHandler(operation: {
//                    try await withCheckedThrowingContinuation { continuation in
//                        do { try add(request: request, id: id, continuation: continuation) }
//                        catch { continuation.resume(throwing: error) }
//                    }
//                }, onCancel: {
//                    Task { continuations[id] = nil }
//                })
//            }
//
//            init(capacity: Int, maxWaitTime: TimeInterval, transporter: RpcRequestTransporter) {
//                self.capacity = capacity
//                self.transporter = transporter
//                self.maxWaitTime = maxWaitTime
//            }
//
//            private func add(request: RpcRequest, id: RpcId, continuation: CheckedContinuation<RpcResponse, Error>) throws {
//                guard cancellable == nil else { throw SessionTaskError(error: BatchError(message: "Batch is already in flight")) }
//
//                if let value = continuations[id] {
//                    throw SessionTaskError(error: BatchError(message: "Request ID collision"))
//                } else {
//                    continuations[id] = (continuation, request)
//                }
//
//                if pendingTrigger == nil {
//                    pendingTrigger = after(seconds: maxWaitTime).done { [weak self] in self?.trigger() }
//                }
//
//                if continuations.count == capacity {
//                    trigger()
//                }
//            }

        private func trigger() {
            guard cancellable == nil else { return }

            let requests = tasks.values.map { $0.value.request }
            print("xxx.batch.trigger with capacity: \(requests.count)")
            let request = RpcRequestBatch(requests: requests)
            cancellable = transporter.dataTaskPublisher(request)
                .map { $0.responses }
                .receive(on: queue)
                .breakpoint(receiveOutput: { _ in
                    print("xxx.batch.response")
                    return false
                })
                .sink(receiveCompletion: { result in
                    if self.tasks.contains(where: { $1.request.method == "eth_call_speacial" }) {
                        print("asdasd")
                    }
                    if case .failure(let error) = result {
                        self.tasks.forEach { $0.value.seals.forEach { $0.send(completion: .failure(error)) } }
                    }
                    self.tasks.removeAll()
                }, receiveValue: { responses in
                    if self.tasks.contains(where: { $1.request.method == "eth_call_speacial" }) {
                        print("asdasd")
                    }
                    if let error = responses.first?.error, responses.count == 1 {
                        for task in self.tasks.values {
                            let failureResponse = RpcResponse(id: task.key, error: error)
                            task.value.seals.forEach { $0.send(failureResponse) }
                            task.value.seals.forEach { $0.send(completion: .finished) }
                        }
                    } else {
                        for task in self.tasks.values {
                            if let response = responses.first(where: { $0.id == task.key }) {
                                task.value.seals.forEach { $0.send(response) }
                                task.value.seals.forEach { $0.send(completion: .finished) }
                            } else {
                                let error = BatchError(message: "Request not found")
                                task.value.seals.forEach { $0.send(completion: .failure(SessionTaskError(error: error))) }
                            }
                        }
                    }
                })
        }

        public init(capacity: Int, maxWaitTime: TimeInterval, transporter: RpcRequestTransporter) {
            self.capacity = capacity
            self.maxWaitTime = maxWaitTime
            self.transporter = transporter
            tasks = .init()
        }
    }

//    private class Store<T> {
//        private var values: [T] = []
//        private let queue: DispatchQueue
//
//        public init(queue: DispatchQueue = DispatchQueue(label: "RealmStore.syncQueue", qos: .background)) {
//            self.queue = queue
//        }
//
//        func append(_ element: T) {
//            dispatchPrecondition(condition: .notOnQueue(queue))
//            queue.sync { [weak self] in
//                self?.values.append(element)
//            }
//        }
//
//        func last() -> T? {
//            var element: T?
//            dispatchPrecondition(condition: .notOnQueue(queue))
//            queue.sync { [weak self] in
//                element = self?.values.last
//            }
//
//            return element
//        }
//
//        func count() -> Int {
//            var count: Int = 0
//            dispatchPrecondition(condition: .notOnQueue(queue))
//            queue.sync { [weak self] in
//                count = self?.values.count ?? 0
//            }
//            return count
//        }
//
//        func removeAll(where block: @escaping (T) -> Bool) {
//            dispatchPrecondition(condition: .notOnQueue(queue))
//            queue.sync { [weak self] in
//                self?.values.removeAll { block($0) }
//            }
//        }
//
//        func allValues() -> [T] {
//            var values: [T] = []
//            dispatchPrecondition(condition: .notOnQueue(queue))
//            queue.sync { [weak self] in
//                values = self?.values ?? []
//            }
//            return values
//        }
//    }
}
