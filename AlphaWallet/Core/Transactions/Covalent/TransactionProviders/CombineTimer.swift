//
//  CombineTimer.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.05.2022.
//

import Foundation
import Combine

final class CombineTimer {

    private let intervalSubject: CurrentValueSubject<TimeInterval, Never>

    var interval: TimeInterval {
        get { intervalSubject.value }
        set { intervalSubject.send(newValue) }
    }

    var publisher: AnyPublisher<Void, Never> {
        intervalSubject
            .flatMapLatest { Timer.TimerPublisher(interval: $0, runLoop: .main, mode: .default).autoconnect() }
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    init(interval: TimeInterval = 1.0) {
        intervalSubject = CurrentValueSubject<TimeInterval, Never>(interval)
    }
}
