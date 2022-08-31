//
//  ActivityStateViewViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.03.2021.
//

import UIKit
import AlphaWalletFoundation

struct ActivityStateViewViewModel {
    var stateImage: UIImage? {
        switch state {
        case .completed:
            return nil
        case .pending:
            return R.image.activityPending()
        case .failed:
            return R.image.activityFailed()
        }
    }

    var isInPendingState: Bool {
        switch state {
        case .completed, .failed:
            return false
        case .pending:
            return true
        }
    }

    private let state: Activity.State
    private let nativeViewType: Activity.NativeViewType

    init(activity: Activity) {
        state = activity.state
        nativeViewType = activity.nativeViewType
    }

}
