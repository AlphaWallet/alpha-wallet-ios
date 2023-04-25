//
//  Duration.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 25/4/23.
//

import Foundation

enum Duration {
    static let dayInterval = 60 * 60 * 24
    static let hourInterval = 60 * 60
    static let minuteInterval = 60
    enum functional {
        static func timeInterval(days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> TimeInterval {
            return TimeInterval(seconds +
                                minutes * minuteInterval +
                                hours * hourInterval +
                                days * dayInterval)
        }
    }
}
