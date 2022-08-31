// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

protocol PromptViewControllerDelegate: AnyObject {
    func actionButtonTapped(inController controller: PromptViewController)
    func controllerDismiss(_ controller: PromptViewController)
}

class PromptViewController: ModalViewController {

    weak var _delegate: PromptViewControllerDelegate?

    private var titleLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = Configuration.Color.Semantic.popupPrimaryFont
        v.font = Fonts.bold(size: 24)

        return v
    }()

    private var descriptionLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = Configuration.Color.Semantic.popupSecondaryFont
        v.font = Fonts.regular(size: 17)

        return v
    }()

    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        return buttonsBar
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        let footerView = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        UIKitFactory.decorateAsDefaultView(footerView)
        footerStackView.addArrangedSubview(footerView)
        generateSubviews()
        presentationDelegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: PromptViewModel) {
        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(viewModel.buttonTitle, for: .normal)
        buttonsBar.buttons[0].addTarget(self, action: #selector(actionButtonSelected), for: .touchUpInside)

        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.description 
    }

    @objc private func actionButtonSelected(_ sender: UIButton) {
        dismissViewAnimated(with: {
            self._delegate?.actionButtonTapped(inController: self)
            self.dismiss(animated: false)
        })
    }
}

extension PromptViewController: ModalViewControllerDelegate {

    func didDismiss(_ controller: ModalViewController) {
        _delegate?.controllerDismiss(self)
        dismiss(animated: false)
    }

    func didClose(_ controller: ModalViewController) {
        dismissViewAnimated(with: {
            self._delegate?.controllerDismiss(self)
            self.dismiss(animated: false)
        })
    }

    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()

        let views: [UIView] = [
            [.spacerWidth(16), titleLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            [.spacerWidth(16), descriptionLabel, .spacerWidth(16)].asStackView(axis: .horizontal)
        ]

        stackView.addArrangedSubviews(views)
    }
}
