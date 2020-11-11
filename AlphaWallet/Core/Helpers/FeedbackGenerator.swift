//
//  FeedbackGenerator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import UIKit

enum NotificationFeedbackType {
    case success
    case warning
    case error

    var feedbackType: UINotificationFeedbackGenerator.FeedbackType {
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

    static func show(feedbackType result: NotificationFeedbackType) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            feedbackGenerator.notificationOccurred(result.feedbackType)
        }
    }
}
