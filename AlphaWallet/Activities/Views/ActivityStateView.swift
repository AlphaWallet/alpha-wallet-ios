//
//  ActivityStateView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.03.2021.
//

import UIKit

class ActivityStateView: UIView {

    private let stateImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit

        return view
    }()
    private var pendingLoadingIndicatorView: ActivityLoadingIndicatorView?

    private func createPendingLoadingIndicatorView() -> ActivityLoadingIndicatorView {
        let control = ActivityLoadingIndicatorView()
        control.lineColor = R.color.azure()!
        control.backgroundLineColor = R.color.loadingBackground()!
        control.translatesAutoresizingMaskIntoConstraints = false
        control.duration = 1.1
        control.lineWidth = 3
        control.backgroundFillColor = .white
        control.translatesAutoresizingMaskIntoConstraints = false

        return control
    }

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(stateImageView)

        NSLayoutConstraint.activate(stateImageView.anchorsConstraint(to: self))
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func anchorConstraints(to view: UIView, size: CGSize = .init(width: 16, height: 16), bottomOffset: CGPoint = .init(x: -2, y: -2)) -> [NSLayoutConstraint] {
        return [
            heightAnchor.constraint(equalToConstant: size.height),
            widthAnchor.constraint(equalToConstant: size.width),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: bottomOffset.x),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: bottomOffset.y)
        ]
    }
    
    private func removePendingLoadingIndicatorView() {
        guard let view = pendingLoadingIndicatorView else { return }

        view.stopAnimating()
        view.removeFromSuperview()

        pendingLoadingIndicatorView = .none
    }

    func configure(viewModel: ActivityStateViewViewModel) {
        stateImageView.isHidden = viewModel.isInPendingState

        removePendingLoadingIndicatorView()

        if viewModel.isInPendingState {
            let view = createPendingLoadingIndicatorView()
            view.startAnimating()
            addSubview(view)
            
            pendingLoadingIndicatorView = view

            NSLayoutConstraint.activate(view.anchorsConstraint(to: self))
        }
        
        stateImageView.image = viewModel.stateImage
    }
}
