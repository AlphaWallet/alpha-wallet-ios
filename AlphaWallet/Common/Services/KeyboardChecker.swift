//
//  KeyboardChecker.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.07.2020.
//

import UIKit
import AlphaWalletFoundation

class KeyboardChecker: NSObject {

    private weak var viewController: UIViewController?
    private let notificationCenter = NotificationCenter.default
    private let resetHeightDefaultValue: CGFloat
    var constraints: [NSLayoutConstraint] = []
    //NOTE: for views with input view 'date picker', we need to ignore bottom safe area
    private let ignoreBottomSafeArea: Bool
    private let buttonsBarHeight: CGFloat
    
    init(_ viewController: UIViewController, resetHeightDefaultValue: CGFloat = -UIApplication.shared.bottomSafeAreaHeight, ignoreBottomSafeArea: Bool = false, buttonsBarHeight: CGFloat = 0) {
        self.viewController = viewController
        self.resetHeightDefaultValue = resetHeightDefaultValue
        self.ignoreBottomSafeArea = ignoreBottomSafeArea
        self.buttonsBarHeight = buttonsBarHeight
        super.init()

        //NOTE: while protection has turned on, we want to subscribe/unsubscribe from handling keyboard appearence, to prevent bottom inset
        notificationCenter.addObserver(self, selector: #selector(viewWillDisappear), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(viewWillAppear), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func viewWillAppear() {
        notificationCenter.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func viewWillDisappear() {
        notificationCenter.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private var tabBarHeight: CGFloat {
        return tabBar?.frame.size.height ?? 0.0
    }

    private var tabBar: UITabBar? {
        viewController?.tabBarController?.tabBar
    }

    private func updateContraints(value: CGFloat) {
        for each in constraints {
            each.constant = value
        }
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let change = notification.keyboardInfo, let view = viewController?.view else {
            return
        }

        let keyboardEndFrame = view.convert(change.endFrame, to: view.window)
        let yKeyboardFrameOffset = keyboardEndFrame.origin.y - change.endFrame.origin.y

        let diff = keyboardEndFrame.height - yKeyboardFrameOffset
        if diff > yKeyboardFrameOffset {
            if let tabBar = tabBar, tabBar.isHidden {
                updateContraints(value: -keyboardEndFrame.height - buttonsBarHeight)
            } else {
                updateContraints(value: -(keyboardEndFrame.height - tabBarHeight - buttonsBarHeight))
            }
        } else {
            if ignoreBottomSafeArea {
                updateContraints(value: -(keyboardEndFrame.height - tabBarHeight - buttonsBarHeight))
            } else {
                if UIApplication.shared.bottomSafeAreaHeight > 0.0 {
                    updateContraints(value: -(diff + UIApplication.shared.bottomSafeAreaHeight))
                } else {
                    updateContraints(value: -(keyboardEndFrame.height - tabBarHeight - buttonsBarHeight))
                }
            }
        }

        UIView.animate(withDuration: change.duration, delay: 0, options: [change.curve], animations: {
            view.layoutIfNeeded()
        }, completion: { _ in

        })
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let change = notification.keyboardInfo, let view = viewController?.view else {
            return
        }

        let keyboardBeginFrame = view.convert(change.beginFrame, to: view.window)
        let keyboardEndFrame = view.convert(change.endFrame, to: view.window)

        //NOTE: we need to determine if keyboard hiding now or not. because there is cases when when we change keyboard, (software/external), and keyboardWillHide called all the time, and we dont know what height should set.
        if keyboardBeginFrame.height <= keyboardEndFrame.height {
            updateContraints(value: resetHeightDefaultValue)
        } else {
            let keyboardEndFrame = view.convert(change.endFrame, to: view.window)
            let yKeyboardFrameOffset = keyboardEndFrame.origin.y - change.endFrame.origin.y
            let diff = keyboardEndFrame.height - yKeyboardFrameOffset

            if diff < 0 {
                updateContraints(value: resetHeightDefaultValue)
            } else if diff > yKeyboardFrameOffset {
                updateContraints(value: -(keyboardEndFrame.height - abs(resetHeightDefaultValue)))
            } else {
                updateContraints(value: -(diff + UIApplication.shared.bottomSafeAreaHeight))
            }
        }

        UIView.animate(withDuration: change.duration, delay: 0, options: [change.curve], animations: {
            view.layoutIfNeeded()
        }, completion: { _ in

        })
    }
}

extension Notification {

    struct Info {
        let beginFrame: CGRect
        let endFrame: CGRect
        let duration: Double
        let curve: UIView.AnimationOptions

        init?(_ notification: Notification) {
            guard let info = notification.userInfo else {
                return nil
            }

            beginFrame = (info[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
            endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
            duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
            curve = UIView.AnimationOptions(rawValue: UInt((info[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber).intValue))
        }
    }

    var keyboardInfo: Info? {
        return Info(self)
    }
}
