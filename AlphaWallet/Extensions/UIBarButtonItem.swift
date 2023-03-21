//
//  UIBarButtonItem.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.08.2021.
//

import UIKit

enum GridOrListLayout: Int {
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

    var inverted: GridOrListLayout {
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
        guard var gridOrListLayout = gridOrListLayout else { return }
        gridOrListLayout.toggle()

        self.gridOrListLayout = gridOrListLayout
        image = self.gridOrListLayout?.image
    }

    static func switchGridToListViewBarButton(gridOrListLayout: GridOrListLayout = .grid, _ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        let sender = UIBarButtonItem(image: nil, style: .plain, target: target, action: selector)
        sender.gridOrListLayout = gridOrListLayout

        sender.image = sender.gridOrListLayout?.image
        sender.selectionClosure = { [weak target] sender in
            guard let target = target else { return }
            target.performSelector(onMainThread: selector, with: sender, waitUntilDone: false)
        }

        return sender
    }

    static func selectBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(title: R.string.localizable.aWalletTokenSelectTokens(), style: .plain, target: target, action: selector)
    }

    static func cancelBarButton(_ target: AnyObject?, selector: Selector?) -> UIBarButtonItem {
        return .init(barButtonSystemItem: .cancel, target: target, action: selector)
    }

    static func actionBarButton(_ target: AnyObject?, selector: Selector?) -> UIBarButtonItem {
        return .init(barButtonSystemItem: .action, target: target, action: selector)
    }

    static func doneBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(title: R.string.localizable.done(), style: .done, target: target, action: selector)
    }

    static func closeBarButton(_ target: AnyObject? = nil, selector: Selector? = nil) -> UIBarButtonItem {
        return .init(image: R.image.close(), style: .plain, target: target, action: selector)
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

    static func logoBarButton(image: UIImage? = R.image.awLogoSmall()) -> UIBarButtonItem {
        let imageView = ImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 30),
            imageView.heightAnchor.constraint(equalToConstant: 30)
        ])

        return .init(customView: imageView)
    }

    static func saveBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        .init(title: R.string.localizable.save(), style: .plain, target: target, action: selector)
    }

    static func settingsBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.tab_settings(), style: .plain, target: target, action: selector)
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

    var gridOrListLayout: GridOrListLayout? {
        get {
            return objc_getAssociatedObject(self, &AssociatedObject.selectionState) as? GridOrListLayout
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObject.selectionState, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc func didTapButton(_ sender: UIBarButtonItem) {
        selectionClosure?(sender)
    }
}
