//
//  ReachabilityManager.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.03.2022.
//

import Alamofire
import Combine

public protocol ReachabilityManagerProtocol {
    var isReachable: Bool { get }
    var reachabilityObservable: AnyPublisher<Bool, Never> { get }
}

public class ReachabilityManager {
    private let manager: NetworkReachabilityManager?

    public var isReachable: Bool {
        return manager?.isReachable ?? false
    }

    private lazy var reachabilitySubject = CurrentValueSubject<Bool, Never>(isReachable)

    public init() {
        manager = NetworkReachabilityManager()

        manager?.listener = { [weak reachabilitySubject] state in
            switch state {
            case .notReachable, .unknown:
                reachabilitySubject?.send(false)
            case .reachable:
                reachabilitySubject?.send(true)
            }
        }

        manager?.startListening()
    }
}

extension ReachabilityManager: ReachabilityManagerProtocol {

    public var reachabilityObservable: AnyPublisher<Bool, Never> {
        reachabilitySubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

extension ReachabilityManager {

    public enum ReachabilityError: Error {
        case notReachable
    }

}
