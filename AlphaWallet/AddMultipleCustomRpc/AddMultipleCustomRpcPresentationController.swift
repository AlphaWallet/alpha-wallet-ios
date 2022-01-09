//
//  AddMultipleCustomRpcPresentationController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 31/12/21.
//

import UIKit

class AddMultipleCustomRpcPresentationController: UIPresentationController {

    // MARK: Properties

    override var shouldPresentInFullscreen: Bool {
        return false
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        var viewBounds = presentedViewController.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let requiredContainerWidth = containerView.bounds.width * 0.8
        viewBounds.width = requiredContainerWidth > viewBounds.width ? requiredContainerWidth : viewBounds.width
        viewBounds.width = viewBounds.width > containerView.bounds.width ? requiredContainerWidth : viewBounds.width
        var viewFrame = CGRect(origin: .zero, size: viewBounds)
        viewFrame.origin.x = (containerView.bounds.width - viewBounds.width) / 2.0
        viewFrame.origin.y = (containerView.bounds.height - viewBounds.height) / 2.0
        return viewFrame
    }

    // MARK: - Constructor

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

}
