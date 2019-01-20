// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol EditMyDappViewControllerDelegate: class {
    func didTapSave(dapp: Bookmark, withTitle title: String, url: String, inViewController viewController: EditMyDappViewController)
    func didTapCancel(inViewController viewController: EditMyDappViewController)
}

class EditMyDappViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private let screenTitleLabel = UILabel()
    private let iconImageView = UIImageView()
    lazy private var imageHolder = ContainerViewWithShadow(aroundView: iconImageView)
    private let titleLabel = UILabel()
    private let titleTextField = UITextField()
    private let urlLabel = UILabel()
    private let urlTextField = UITextField()
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private var viewModel: EditMyDappViewControllerViewModel?

    weak var delegate: EditMyDappViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        titleTextField.delegate = self

        urlTextField.delegate = self

        let stackView = [
            UIView.spacer(height: 34),
            screenTitleLabel,
            UIView.spacer(height: 28),
            imageHolder,
            UIView.spacer(height: 28),
            titleLabel,
            UIView.spacer(height: 7),
            titleTextField,
            UIView.spacer(height: 18),
            urlLabel,
            UIView.spacer(height: 7),
            urlTextField
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = Metrics.greenButtonHeight
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        saveButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        footerBar.addSubview(saveButton)

        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        let marginToHideBottomRoundedCorners = CGFloat(30)
        NSLayoutConstraint.activate([
            imageHolder.widthAnchor.constraint(equalToConstant: 80),
            imageHolder.widthAnchor.constraint(equalTo: imageHolder.heightAnchor),

            titleLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            urlLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            titleTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            urlTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            //Additional allowance so there's a margin below the buttons for non-iPhone X devices
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -buttonsHeight - 3),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            saveButton.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 15),
            saveButton.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor, constant: -15),
            saveButton.topAnchor.constraint(equalTo: footerBar.topAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: buttonsHeight),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 37),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -37),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            cancelButton.topAnchor.constraint(equalTo: view.layoutGuide.topAnchor),

            //We don't use createConstraintsWithContainer() because the top rounded corners need to be lower
            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 10),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: EditMyDappViewControllerViewModel) {
        self.viewModel = viewModel

        view.backgroundColor = viewModel.backgroundColor

        imageHolder.configureShadow(color: viewModel.imageShadowColor, offset: viewModel.imageShadowOffset, opacity: viewModel.imageShadowOpacity, radius: viewModel.imageShadowRadius)

        iconImageView.backgroundColor = viewModel.imageBackgroundColor
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.kf.setImage(with: viewModel.imageUrl, placeholder: viewModel.imagePlaceholder)

        screenTitleLabel.text = viewModel.screenTitle
        screenTitleLabel.textAlignment = .center
        screenTitleLabel.font = viewModel.screenFont

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.titleText

        urlLabel.textColor = viewModel.urlColor
        urlLabel.font = viewModel.urlFont
        urlLabel.text = viewModel.urlText

        titleTextField.borderStyle = viewModel.titleTextFieldBorderStyle
        titleTextField.borderWidth = viewModel.titleTextFieldBorderWidth
        titleTextField.borderColor = viewModel.titleTextFieldBorderColor
        titleTextField.cornerRadius = viewModel.titleTextFieldCornerRadius
        titleTextField.font = viewModel.titleTextFieldFont
        titleTextField.returnKeyType = .next
        titleTextField.text = viewModel.titleTextFieldText

        urlTextField.borderStyle = viewModel.urlTextFieldBorderStyle
        urlTextField.borderWidth = viewModel.urlTextFieldBorderWidth
        urlTextField.borderColor = viewModel.urlTextFieldBorderColor
        urlTextField.cornerRadius = viewModel.urlTextFieldCornerRadius
        urlTextField.font = viewModel.urlTextFieldFont
        urlTextField.returnKeyType = .done
        urlTextField.text = viewModel.urlTextFieldText

        saveButton.setTitleColor(viewModel.saveButtonTitleColor, for: .normal)
        saveButton.backgroundColor = viewModel.saveButtonBackgroundColor
        saveButton.titleLabel?.font = viewModel.saveButtonFont
        saveButton.setTitle(viewModel.saveButtonTitle, for: .normal)
        saveButton.cornerRadius = viewModel.saveButtonCornerRadius

        cancelButton.setTitleColor(viewModel.cancelButtonTitleColor, for: .normal)
        cancelButton.titleLabel?.font = viewModel.cancelButtonFont
        cancelButton.setTitle(viewModel.cancelButtonTitle, for: .normal)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        iconImageView.layer.cornerRadius = iconImageView.frame.size.width / 2

        imageHolder.layer.cornerRadius = imageHolder.frame.size.width / 2
        if let viewModel = viewModel {
            imageHolder.configureShadow(color: viewModel.imageShadowColor, offset: viewModel.imageShadowOffset, opacity: viewModel.imageShadowOpacity, radius: viewModel.imageShadowRadius)
        }
    }

    @objc private func save() {
        guard let dapp = viewModel?.dapp else { return }
        guard let url = urlTextField.text?.trimmed else { return }
        guard !url.isEmpty else { return }
        let title = titleTextField.text?.trimmed ?? ""
        delegate?.didTapSave(dapp: dapp, withTitle: title, url: url, inViewController: self)
    }

    @objc private func cancel() {
        delegate?.didTapCancel(inViewController: self)
    }
}

extension EditMyDappViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case titleTextField:
            urlTextField.becomeFirstResponder()
        case urlTextField:
            urlTextField.endEditing(true)
        default:
            break
        }
        return true
    }
}
