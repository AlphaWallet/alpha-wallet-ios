//
//  FeedbackGenerator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import UIKit
import PromiseKit

public enum NotificationFeedbackType {
    case success
    case warning
    case error

    public var feedbackType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}

extension UINotificationFeedbackGenerator {

    public static func show(feedbackType result: NotificationFeedbackType, completion: @escaping () -> Void = {}) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            feedbackGenerator.notificationOccurred(result.feedbackType)
            completion()
        }
    }
    
    public static func showFeedbackPromise<T>(value: T, feedbackType: NotificationFeedbackType) -> Promise<T> {
        return Promise { seal in
            UINotificationFeedbackGenerator.show(feedbackType: feedbackType) {
                seal.fulfill(value)
            }
        }
    }
}
