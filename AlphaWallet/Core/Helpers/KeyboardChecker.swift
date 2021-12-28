//
//  KeyboardChecker.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.07.2020.
//

import UIKit

extension UIApplication {
    var bottomSafeAreaHeight: CGFloat {

        let window = UIApplication.shared.windows[0]
        let safeFrame = window.safeAreaLayoutGuide.layoutFrame

        return window.frame.maxY - safeFrame.maxY
    }
}

class KeyboardChecker: NSObject {

    private weak var viewController: UIViewController?
    private let notificationCenter = NotificationCenter.default
    private let resetHeightDefaultValue: CGFloat
    var constraint: NSLayoutConstraint?
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

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let change = notification.keyboardInfo, let view = viewController?.view else {
            return
        }

        let keyboardEndFrame = view.convert(change.endFrame, to: view.window)
        let yKeyboardFrameOffset = keyboardEndFrame.origin.y - change.endFrame.origin.y

        let diff = keyboardEndFrame.height - yKeyboardFrameOffset
        if diff > yKeyboardFrameOffset {
            if let tabBar = tabBar, tabBar.isHidden {
                constraint?.constant = -keyboardEndFrame.height - buttonsBarHeight
            } else {
                constraint?.constant = -(keyboardEndFrame.height - tabBarHeight - buttonsBarHeight)
            }
        } else {
            if ignoreBottomSafeArea {
                constraint?.constant = -(keyboardEndFrame.height - tabBarHeight - buttonsBarHeight)
            } else {
                if UIApplication.shared.bottomSafeAreaHeight > 0.0 {
                    constraint?.constant = -(diff + UIApplication.shared.bottomSafeAreaHeight)
                } else {
                    constraint?.constant = -(keyboardEndFrame.height - tabBarHeight - buttonsBarHeight)
                }
            }
        }

        UIView.setAnimationCurve(change.curve)
        UIView.animate(withDuration: change.duration) {
            view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let change = notification.keyboardInfo, let view = viewController?.view else {
            return
        }

        let keyboardBeginFrame = view.convert(change.beginFrame, to: view.window)
        let keyboardEndFrame = view.convert(change.endFrame, to: view.window)

        //NOTE: we need to determine if keyboard hiding now or not. because there is cases when when we change keyboard, (software/external), and keyboardWillHide called all the time, and we dont know what height should set.
        if keyboardBeginFrame.height <= keyboardEndFrame.height {
            constraint?.constant = resetHeightDefaultValue
        } else {
            let keyboardEndFrame = view.convert(change.endFrame, to: view.window)
            let yKeyboardFrameOffset = keyboardEndFrame.origin.y - change.endFrame.origin.y
            let diff = keyboardEndFrame.height - yKeyboardFrameOffset

            if diff < 0 {
                constraint?.constant = resetHeightDefaultValue
            } else if diff > yKeyboardFrameOffset {
                constraint?.constant = -(keyboardEndFrame.height - abs(resetHeightDefaultValue))
            } else {
                constraint?.constant = -(diff + UIApplication.shared.bottomSafeAreaHeight)
            }
        }

        UIView.setAnimationCurve(change.curve)
        UIView.animate(withDuration: change.duration) {
            view.layoutIfNeeded()
        }
    }
}

extension Notification {

    struct Info {
        let beginFrame: CGRect
        let endFrame: CGRect
        let duration: Double
        let curve: UIView.AnimationCurve

        init?(_ notification: Notification) {
            guard let info = notification.userInfo else {
                return nil
            }

            beginFrame = (info[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
            endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
            duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
            curve = UIView.AnimationCurve(rawValue: (info[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber).intValue)!
        }
    }

    var keyboardInfo: Info? {
        return Info(self)
    }
}
