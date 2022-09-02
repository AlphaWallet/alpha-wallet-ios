// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

class SuccessOverlayView: UIView {
    static func show() {
        let view = SuccessOverlayView(frame: UIScreen.main.bounds)
        view.show()
    }

    private let imageView = UIImageView(image: R.image.successOverlay()!)

    override init(frame: CGRect) {
        super.init(frame: frame)

        let blurEffect = UIBlurEffect(style: .extraLight)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        blurView.alpha = 0.3

        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hide))
        addGestureRecognizer(tapGestureRecognizer)

        NSLayoutConstraint.activate([
            blurView.anchorsConstraint(to: self),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func hide() {
        removeFromSuperview()
    }

    func show() {
        imageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIApplication.shared.firstKeyWindow?.addSubview(self)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 7, options: .curveEaseInOut, animations: {
            self.imageView.transform = .identity
        })

        UINotificationFeedbackGenerator.show(feedbackType: .success)

        hideAfterAWhile()
    }

    private func hideAfterAWhile() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.superview != nil else { return }
            UIView.animate(withDuration: 0.3, animations: {
                strongSelf.alpha = 0
            }, completion: { _ in
                strongSelf.hide()
            })
        }
    }
}
