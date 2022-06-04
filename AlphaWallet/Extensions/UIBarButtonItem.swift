//
//  UIBarButtonItem.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.08.2021.
//

import UIKit

enum GridOrListSelectionState: Int {
    case grid
    case list

    mutating func toggle() {
        switch self {
        case .grid:
            self = .list
        case .list:
            self = .grid
        }
    }

    var inverted: GridOrListSelectionState {
        switch self {
        case .list:
            return .grid
        case .grid:
            return .list
        }
    }

    var image: UIImage? {
        switch self {
        case .grid:
            return R.image.iconsSystemGrid()
        case .list:
            return R.image.iconsSystemList()
        }
    }
}

extension UIBarButtonItem {

    func toggleSelection() {
        guard var selection = selection else { return }
        selection.toggle()

        self.selection = selection
        image = self.selection?.image
    }

    static func switchGridToListViewBarButton(selection: GridOrListSelectionState = .grid, _ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        let sender = UIBarButtonItem(image: nil, style: .plain, target: target, action: selector)
        sender.selection = selection

        sender.image = sender.selection?.image
        sender.selectionClosure = { [weak target] sender in
            guard let target = target else { return }
            target.performSelector(onMainThread: selector, with: sender, waitUntilDone: false)
        }

        return sender
    }

    static func selectBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(title: R.string.localizable.aWalletTokenSelectTokens(), style: .plain, target: target, action: selector)
    }

    static func cancelBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(barButtonSystemItem: .cancel, target: target, action: selector)
    }

    static func closeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.close(), style: .plain, target: target, action: selector)
    }

    static func backBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.backWhite(), style: .plain, target: target, action: selector)
    }

    static func addButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.iconsSystemPlus(), style: .plain, target: target, action: selector)
    }

    static func qrCodeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.qr_code_icon(), style: .plain, target: target, action: selector)
    }

    static func myqrCodeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.qrRounded(), style: .plain, target: target, action: selector)
    }

    static func moreBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.toolbarMenu(), style: .plain, target: target, action: selector)
    }

    static func addBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.add_hide_tokens(), style: .plain, target: target, action: selector)
    }

    static func saveBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        .init(title: R.string.localizable.save(), style: .plain, target: target, action: selector)
    }

    static func settingsBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.tab_settings(), style: .plain, target: target, action: selector)
    }

    static func backBarButton(selectionClosure: @escaping (UIBarButtonItem) -> Void) -> UIBarButtonItem {
        let barButton = UIBarButtonItem(image: R.image.backWhite(), style: .plain, target: nil, action: nil)
        barButton.selectionClosure = selectionClosure

        return barButton
    }

    private struct AssociatedObject {
        static var key = "action_closure_key"
        static var selectionState = "is_selected_state_key"
    }

    var selectionClosure: ((UIBarButtonItem) -> Void)? {
        get {
            return objc_getAssociatedObject(self, &AssociatedObject.key) as? (UIBarButtonItem) -> Void
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObject.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            target = self
            action = #selector(didTapButton)
        }
    }

    var selection: GridOrListSelectionState? {
        get {
            return objc_getAssociatedObject(self, &AssociatedObject.selectionState) as? GridOrListSelectionState
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObject.selectionState, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc func didTapButton(_ sender: UIBarButtonItem) {
        selectionClosure?(sender)
    }
}
