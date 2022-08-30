//
//  SelfSizingPanelLayout.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.03.2022.
//

import FloatingPanel
import UIKit

typealias FloatingPanelController = FloatingPanel.FloatingPanelController
typealias FloatingPanelControllerDelegate = FloatingPanel.FloatingPanelControllerDelegate
typealias FloatingPanelLayout = FloatingPanel.FloatingPanelLayout

// MARK: - Layouts
class SelfSizingPanelLayout: FloatingPanelBottomLayout {

    let referenceGuide: FloatingPanelLayoutReferenceGuide

    init(referenceGuide: FloatingPanelLayoutReferenceGuide = .safeArea) {
        self.referenceGuide = referenceGuide
    }

    override var initialState: FloatingPanelState {
        .full
    }

    override var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        [.full: FloatingPanelIntrinsicLayoutAnchor(fractionalOffset: 0, referenceGuide: referenceGuide),
         .half: FloatingPanelIntrinsicLayoutAnchor(fractionalOffset: 0, referenceGuide: referenceGuide),
         .tip: FloatingPanelIntrinsicLayoutAnchor(fractionalOffset: 0, referenceGuide: referenceGuide)]
    }

    override func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        0.4
    }

}

class FixedSizePanelLayout: FloatingPanelBottomLayout {

    let panelHeight: CGFloat
    let referenceGuide: FloatingPanelLayoutReferenceGuide

    init(panelHeight: CGFloat, referenceGuide: FloatingPanelLayoutReferenceGuide = .safeArea) {
        self.panelHeight = panelHeight
        self.referenceGuide = referenceGuide
    }

    override var initialState: FloatingPanelState {
        .full
    }

    override var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        [.full: FloatingPanelIntrinsicLayoutAnchor(absoluteOffset: -panelHeight, referenceGuide: referenceGuide),
         .half: FloatingPanelIntrinsicLayoutAnchor(absoluteOffset: -panelHeight, referenceGuide: referenceGuide),
         .tip: FloatingPanelIntrinsicLayoutAnchor(absoluteOffset: -panelHeight, referenceGuide: referenceGuide)]
    }

    override func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        0.4
    }

}

class ScrollableFloatingPanelLayout: FloatingPanelBottomLayout {

    override init() {
        super.init()
    }

    override var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        return [
            .full: FloatingPanelLayoutAnchor(absoluteInset: 18.0, edge: .top, referenceGuide: .safeArea),
            .half: FloatingPanelLayoutAnchor(fractionalInset: 0.5, edge: .bottom, referenceGuide: .safeArea)
        ]
    }

    override func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        0.4
    }
}

class FullScreenScrollableFloatingPanelLayout: FloatingPanelBottomLayout {

    override init() {
        super.init()
    }

    override var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        return [
            .full: FloatingPanelLayoutAnchor(absoluteInset: 18.0, edge: .top, referenceGuide: .safeArea),
            .half: FloatingPanelLayoutAnchor(absoluteInset: 18.0, edge: .top, referenceGuide: .safeArea)
        ]
    }

    override func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        0.4
    }
}

extension FloatingPanelController {

    convenience init(shadowColor: UIColor = Configuration.Color.Semantic.shadow, shadowOpacity: Float = 0.1, isPanEnabled: Bool) {
        self.init()
        
        let appearance = SurfaceAppearance()
        appearance.cornerRadius = 16
        appearance.backgroundColor = Colors.appBackground

        let shadow = SurfaceAppearance.Shadow()
        shadow.opacity = shadowOpacity
        shadow.color = shadowColor
        shadow.offset = .init(width: 0, height: -4)
        shadow.radius = 5
        shadow.spread = 0

        appearance.shadows = [shadow]

        isRemovalInteractionEnabled = true

        surfaceView.grabberHandle.isHidden = isPanEnabled
        surfaceView.appearance = appearance
    }

    var shouldDismissOnBackdrop: Bool {
        get { return surfaceView.grabberHandle.isHidden }
        set {
            guard newValue else { return }
            backdropView.gestureRecognizers?.forEach { [weak self] in self?.backdropView.removeGestureRecognizer($0) }
            let backdropTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackdrop(tapGesture:)))
            backdropView.addGestureRecognizer(backdropTapGesture)
        }
    } 

    @objc private func handleBackdrop(tapGesture: UITapGestureRecognizer) {
        guard let viewController = tapGesture.view?.parentFloatingPanelController else { return }

        delegate?.floatingPanelWillRemove?(self)
        viewController.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.floatingPanelDidRemove?(self)
        }
    }

}
