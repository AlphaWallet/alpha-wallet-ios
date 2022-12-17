//
//  BatchSupportableRpcRequestDispatcherTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation
import Combine

public class FakeRpcRequestTransporter: RpcRequestTransporter {
    public var delay: Int = 1
    public var queue: DispatchQueue = .main
    public var callbackClosure: (RpcRequest) -> AnyPublisher<RpcResponse, SessionTaskError> = { _ in
        return .empty()
    }

    public var callbackBatchClosure: (RpcRequestBatch) -> AnyPublisher<RpcResponseBatch, SessionTaskError> = { _ in
        return .empty()
    }

    public func dataTaskPublisher(_ request: RpcRequest) -> AnyPublisher<RpcResponse, SessionTaskError> {
        Just(request)
            .setFailureType(to: SessionTaskError.self)
            .delay(for: .seconds(delay), scheduler: queue)
            .flatMap { self.callbackClosure($0) }
            .eraseToAnyPublisher()
    }

    public func dataTaskPublisher(_ request: RpcRequestBatch) -> AnyPublisher<RpcResponseBatch, SessionTaskError> {
        Just(request)
            .setFailureType(to: SessionTaskError.self)
            .delay(for: .seconds(delay), scheduler: queue)
            .flatMap { self.callbackBatchClosure($0) }
            .eraseToAnyPublisher()
    }
}

final class BatchSupportableRpcRequestDispatcherTests: XCTestCase {
    private let transporter = FakeRpcRequestTransporter()
    private lazy var dispatcher = BatchSupportableRpcRequestDispatcher(transporter: transporter, policy: .batch(20))
    private var c1: AnyCancellable?
    private var c2: AnyCancellable?
    private var cancellable = Set<AnyCancellable>()

    enum Call: Equatable {
        case request
        case requestBatch(Int)
    }

    struct Response: Codable {
        let message: String
    }

    func testCancel() {
        transporter.callbackBatchClosure = { batch in
            let responses = batch.requests.map { r in
                return RpcResponse(id: r.id!, result: Response(message: "\(r) response index"))
            }

            return .just(RpcResponseBatch(responses: responses))
        }

        let e0_cancellation = self.expectation(description: "wait for r0 cancellation")
        let r0 = RpcRequest(method: "eth_call")

        c1 = dispatcher.send(request: r0)
            .print("xxx.eth_call.0")
            .handleEvents(receiveCancel: { e0_cancellation.fulfill() })
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        let e1_value = self.expectation(description: "wait for r1 value")
        let e1_completion = self.expectation(description: "wait for r1 completioins")

        c2 = dispatcher.send(request: r0)
            .print("xxx.eth_call.1")
            .sink(receiveCompletion: { _ in e1_completion.fulfill() }, receiveValue: { _ in e1_value.fulfill() })

        c1?.cancel()
        c1 = nil

        wait(for: [e0_cancellation, e1_value, e1_completion], timeout: 20)
    }

    func testCancel2() {
        var calls: Int = 0
        transporter.callbackBatchClosure = { batch in
            calls += 1
            let responses = batch.requests.map { r in
                return RpcResponse(id: r.id!, result: Response(message: "\(r) response index"))
            }

            return .just(RpcResponseBatch(responses: responses))
        }

        let e0_cancellation = self.expectation(description: "wait for r0 cancellation")
        let r0 = RpcRequest(method: "eth_call")

        c1 = dispatcher.send(request: r0, policy: .noBatching)
            .print("xxx.eth_call.0")
            .handleEvents(receiveCancel: { e0_cancellation.fulfill() })
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        let e1_cancellation = self.expectation(description: "wait for r1 cancellation")

        c2 = dispatcher.send(request: r0, policy: .noBatching)
            .print("xxx.eth_call.1")
            .handleEvents(receiveCancel: { e1_cancellation.fulfill() })
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        c1?.cancel()
        c1 = nil

        c2?.cancel()
        c2 = nil

        wait(for: [e0_cancellation, e1_cancellation], timeout: 20)
    }

    func testBatch() {
        struct BatchError: Error {
            let message: String
        }
        let batch = BatchSupportableRpcRequestDispatcher.BatchAsync(capacity: 5, maxWaitTime: 0.2, transporter: transporter)

        transporter.callbackBatchClosure = { batch in
            let responses = batch.requests.map { r in
                return RpcResponse(id: r.id!, result: Response(message: "\(r) response"))
            }

            print("xxx.eth_call.perform request batch of \(batch.requests)")

            return .just(RpcResponseBatch(responses: responses))
        }
        let e0_value = self.expectation(description: "wait for r0 value")
        let e0_completion = self.expectation(description: "wait for r0 completioins")
        let r0 = RpcRequest(method: "eth_call", id: 0)
        batch.add(request: r0, id: r0.id!)
            .print("xxx.r0")
            .sink(receiveCompletion: { _ in e0_completion.fulfill() }, receiveValue: { _ in e0_value.fulfill() })
            .store(in: &cancellable)

        let e1_value = self.expectation(description: "wait for r1 value")
        let e1_completion = self.expectation(description: "wait for r1 completioins")
        let r1 = RpcRequest(method: "eth_call", id: 1)
        batch.add(request: r1, id: r1.id!)
            .print("xxx.r1")
            .sink(receiveCompletion: { _ in e1_completion.fulfill() }, receiveValue: { _ in e1_value.fulfill() })
            .store(in: &cancellable)

        let e2_value = self.expectation(description: "wait for r2 value")
        let e2_completion = self.expectation(description: "wait for r2 completioins")
        let r2 = RpcRequest(method: "eth_call", id: 2)

        batch.add(request: r2, id: r2.id!)
            .print("xxx.r2")
            .sink(receiveCompletion: { _ in e2_completion.fulfill() }, receiveValue: { _ in e2_value.fulfill() })
            .store(in: &cancellable)

        let e3_value = self.expectation(description: "wait for r3 value")
        let e3_completion = self.expectation(description: "wait for r3 completioins")
        let r3 = RpcRequest(method: "eth_call")

        DispatchQueue.main.async {
            batch.add(request: r3, id: r3.id!)
                .sink(receiveCompletion: { _ in e3_completion.fulfill() }, receiveValue: { _ in e3_value.fulfill() })
                .store(in: &self.cancellable)
        }

        let r4 = RpcRequest(method: "eth_call")
        let e4_failure = self.expectation(description: "wait for r4 value")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            batch.add(request: r4, id: r4.id!)
                .sink(receiveCompletion: { result in
                    guard case .failure = result else { return }
                    e4_failure.fulfill()
                }, receiveValue: { _ in })
                .store(in: &self.cancellable)
        }

        wait(for: [e0_value, e0_completion, e1_value, e1_completion, e2_value, e2_completion, e3_value, e3_completion, e4_failure], timeout: 20)
    }

    func testExample() {
        ///                              success                              failure                           failure                                 success
        let _: [Call] = [.requestBatch(4), .requestBatch(1), .requestBatch(1), .requestBatch(1)]
        var performed: [Call] = []
        var index: Int = 0

        transporter.callbackClosure = { r in
            let response = RpcResponse(id: r.id!, result: Response(message: "\(r) response index: \(index)"))
            index += 1
            performed.append(.request)
            print("xxx.eth_call.perform request")

            return .just(response)
        }

        var indexBatch: Int = 0
        transporter.callbackBatchClosure = { batch in
            let responses = batch.requests.map { r in
                switch indexBatch {
                case 0:
                    return RpcResponse(id: r.id!, result: Response(message: "\(r) response index: \(indexBatch)"))
                case 1:
                    return RpcResponse(id: r.id!, error: JSONRPCError(code: 10000, message: "rate limitted", data: AnyCodable(RateLimitedResponse(rate: .init(allowed_rps: 1, backoff_seconds: 1, current_rps: 36.6), see: "hello"))))
                case 2:
                    return RpcResponse(id: r.id!, error: JSONRPCError(code: 10000, message: "rate limitted", data: AnyCodable(RateLimitedResponse(rate: .init(allowed_rps: 1, backoff_seconds: 1, current_rps: 36.6), see: "hello"))))
                case 3:
                    return RpcResponse(id: r.id!, result: Response(message: "\(r) response index: \(indexBatch)"))
                default:
                    return RpcResponse(id: r.id!, result: Response(message: "\(r) response index: \(indexBatch)"))
                }
            }
            performed.append(.requestBatch(batch.requests.count))
            print("xxx.eth_call.perform request batch of \(batch.requests)")
            indexBatch += 1

            return .just(RpcResponseBatch(responses: responses))
        }

        let e0_value = self.expectation(description: "wait for r0 value")
        let e0_completion = self.expectation(description: "wait for r0 completioins")
        let r0 = RpcRequest(method: "eth_call")

        dispatcher.send(request: r0)
            .print("xxx.eth_call.0")
            .sink(receiveCompletion: { _ in e0_completion.fulfill() }, receiveValue: { _ in e0_value.fulfill() })
            .store(in: &cancellable)

        let e1_value = self.expectation(description: "wait for r1 value")
        let e1_completion = self.expectation(description: "wait for r1 completioins")

        dispatcher.send(request: r0)
            .print("xxx.eth_call.1")
            .sink(receiveCompletion: { _ in e1_completion.fulfill() }, receiveValue: { _ in e1_value.fulfill() })
            .store(in: &cancellable)

        let e2_value = self.expectation(description: "wait for r2 value")
        let e2_completion = self.expectation(description: "wait for r2 completioins")
        let r2 = RpcRequest(method: "eth_call")

        dispatcher.send(request: r2)
            .print("xxx.eth_call.2")
            .sink(receiveCompletion: { _ in e2_completion.fulfill() }, receiveValue: { _ in e2_value.fulfill() })
            .store(in: &cancellable)

        let e3_value = self.expectation(description: "wait for r3 value")
        let e3_completion = self.expectation(description: "wait for r3 completioins")
        DispatchQueue.main.async {
            let r3 = RpcRequest(method: "eth_call")
            self.dispatcher.send(request: r3)
                .print("xxx.eth_call.3")
                .sink(receiveCompletion: { _ in e3_completion.fulfill() }, receiveValue: { _ in e3_value.fulfill() })
                .store(in: &self.cancellable)
        }

        let e4_value = self.expectation(description: "wait for r4 value")
        let e4_completion = self.expectation(description: "wait for r4 completioins")
        let r4 = RpcRequest(method: "eth_call")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.dispatcher.send(request: r4)
                .print("xxx.eth_call.4")
                .sink(receiveCompletion: { _ in e4_completion.fulfill() }, receiveValue: { _ in e4_value.fulfill() })
                .store(in: &self.cancellable)
        }

        let e5_value = self.expectation(description: "wait for r5 value")
        let e5_completion = self.expectation(description: "wait for r5 completioins")

        let e6_value = self.expectation(description: "wait for r5 value")
        let e6_completion = self.expectation(description: "wait for r5 completioins")

        let r5 = RpcRequest(method: "eth_call_speacial", id: 444)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.dispatcher.send(request: r5)
                .print("xxx.eth_call.5")
                .sink(receiveCompletion: { _ in e5_completion.fulfill() }, receiveValue: { _ in e5_value.fulfill() })
                .store(in: &self.cancellable)

            DispatchQueue.main.async {
                self.dispatcher.send(request: r5)
                    .print("xxx.eth_call.6")
                    .sink(receiveCompletion: { _ in e6_completion.fulfill() }, receiveValue: { _ in e6_value.fulfill() })
                    .store(in: &self.cancellable)
            }

        }

        let e_completion = self.expectation(description: "wait for r5 completioins")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
//            for (index, each) in expectedCalls.enumerated() {
//                XCTAssertEqual(performed[index], each, "exact as expectes calls count for index: \(index)")
//            }

            e_completion.fulfill()
        }

        wait(for: [e0_value, e0_completion, e1_value, e1_completion, e2_value, e2_completion, e3_value, e3_completion, e4_value, e4_completion, e5_value, e5_completion, e6_value, e6_completion, e_completion], timeout: 20)
    }

    func testExample_2() {
        var index: Int = 0

        transporter.callbackClosure = { r in
            let response = RpcResponse(id: r.id!, result: Response(message: "\(r) response index: \(index)"))
            index += 1
            print("xxx.eth_call.perform request")

            return .just(response)
        }

        var indexBatch: Int = 0
        transporter.callbackBatchClosure = { batch in
            print("xxx.indexBatch: \(indexBatch)")
            
            let response: RpcResponseBatch
            switch indexBatch {
            case 0:
                XCTAssertEqual(batch.requests.count, 2)
                response = RpcResponseBatch(responses: [
                    RpcResponse(id: batch.requests[0].id!, result: Response(message: "success response index: \(indexBatch)")),
                    RpcResponse(id: batch.requests[1].id!, error: JSONRPCError(code: 10000, message: "rate limitted", data: AnyCodable(RateLimitedResponse(rate: .init(allowed_rps: 1, backoff_seconds: 1, current_rps: 36.6), see: "hello"))))
                ])
            case 1:
                XCTAssertEqual(batch.requests.count, 1)
                response = RpcResponseBatch(responses: [
                    RpcResponse(id: batch.requests[0].id!, error: JSONRPCError(code: 10000, message: "rate limitted", data: AnyCodable(RateLimitedResponse(rate: .init(allowed_rps: 1, backoff_seconds: 1, current_rps: 36.6), see: "hello"))))
                ])
            case 2:
                XCTAssertEqual(batch.requests.count, 1)
                response = RpcResponseBatch(responses: [
//                    RpcResponse(id: batch.requests[0].id!, result: Response(message: "success response index: \(indexBatch)")),
                    RpcResponse(id: batch.requests[0].id!, error: JSONRPCError(code: 10000, message: "rate limitted", data: AnyCodable(RateLimitedResponse(rate: .init(allowed_rps: 1, backoff_seconds: 1, current_rps: 36.6), see: "hello"))))
                ])
            case 3:
                XCTAssertEqual(batch.requests.count, 1)
                response = RpcResponseBatch(responses: [
                    RpcResponse(id: batch.requests[0].id!, error: JSONRPCError(code: 10000, message: "rate limitted", data: AnyCodable(RateLimitedResponse(rate: .init(allowed_rps: 1, backoff_seconds: 1, current_rps: 36.6), see: "hello"))))
                ])
            default:
                fatalError()
            }

            indexBatch += 1
            return .just(response)
        }

        let e0_value = self.expectation(description: "wait for r0 value")
        let e0_completion = self.expectation(description: "wait for r0 completioins")
        let r0 = RpcRequest(method: "eth_call", id: 0)

        dispatcher.send(request: r0)
//            .print("xxx.eth_call.0")
            .sink(receiveCompletion: { _ in e0_completion.fulfill() }, receiveValue: { _ in e0_value.fulfill() })
            .store(in: &cancellable)

//        let e1_value = self.expectation(description: "wait for r1 value")
        let e1_completion = self.expectation(description: "wait for r1 completioins")

        let r1 = RpcRequest(method: "eth_call", id: 1)
        dispatcher.send(request: r1)
            .print("xxx.eth_call.1")
            .sink(receiveCompletion: { _ in e1_completion.fulfill() }, receiveValue: { _ in })
            .store(in: &cancellable)

        wait(for: [e0_value, e0_completion, e1_completion], timeout: 20)
    }
}
