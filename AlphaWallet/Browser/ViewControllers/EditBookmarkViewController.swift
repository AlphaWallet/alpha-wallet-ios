// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

protocol EditBookmarkViewControllerDelegate: AnyObject {
    func didSave(in viewController: EditBookmarkViewController)
    func didClose(in viewController: EditBookmarkViewController)
}

class EditBookmarkViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private lazy var screenTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = viewModel.screenTitle
        label.textAlignment = .center
        label.font = viewModel.screenFont

        return label
    }()
    private lazy var iconImageView: UIImageView = {
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.backgroundColor = viewModel.imageBackgroundColor
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true

        return iconImageView
    }()
    private lazy var imageHolder = ContainerViewWithShadow(aroundView: iconImageView)
    private lazy var titleTextField: TextField = {
        let textField = TextField.textField
        textField.delegate = self
        textField.label.text = viewModel.titleText
        textField.returnKeyType = .next

        return textField
    }()
    private lazy var urlTextField: TextField = {
        let textField = TextField.textField
        textField.delegate = self
        textField.label.text = viewModel.urlText
        textField.returnKeyType = .done

        return textField
    }()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private let viewModel: EditBookmarkViewModel

    weak var delegate: EditBookmarkViewControllerDelegate?

    init(viewModel: EditBookmarkViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        let stackView = [
            UIView.spacer(height: 34),
            screenTitleLabel,
            UIView.spacer(height: 28),
            imageHolder,
            UIView.spacer(height: 28),

            titleTextField.label,
            UIView.spacer(height: 4),
            titleTextField,
            UIView.spacer(height: 18),

            urlTextField.label,
            UIView.spacer(height: 7),
            urlTextField
        ].asStackView(axis: .vertical, alignment: .center)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        let marginToHideBottomRoundedCorners = CGFloat(30)
        NSLayoutConstraint.activate([
            imageHolder.widthAnchor.constraint(equalToConstant: 80),
            imageHolder.widthAnchor.constraint(equalTo: imageHolder.heightAnchor),

            titleTextField.label.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            titleTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            urlTextField.label.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            urlTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -HorizontalButtonsBar.buttonsHeight - HorizontalButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: HorizontalButtonsBar.buttonsHeight),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 37),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -37),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            //We don't use createConstraintsWithContainer() because the top rounded corners need to be lower
            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bind(viewModel: viewModel)

        buttonsBar.configure()
        let saveButton = buttonsBar.buttons[0]
        saveButton.setTitle(viewModel.saveButtonTitle, for: .normal)
    }

    private var cancelable = Set<AnyCancellable>()
    private let deleteBookmark = PassthroughSubject<IndexPath, Never>()

    private func bind(viewModel: EditBookmarkViewModel) {
        view.backgroundColor = viewModel.backgroundColor

        let save = buttonsBar.buttons[0]
            .publisher(forEvent: .touchUpInside)
            .map { [urlTextField, titleTextField] _ in
                return (title: titleTextField.value.trimmed, url: urlTextField.value.trimmed)
            }.eraseToAnyPublisher()

        let input = EditBookmarkViewModelInput(save: save)
        let output = viewModel.transform(input: input)
        
        output.viwState.sink { [imageHolder, iconImageView, titleTextField, urlTextField] viewState in
            iconImageView.kf.setImage(with: viewState.imageUrl, placeholder: viewModel.imagePlaceholder)
            titleTextField.value = viewState.title
            urlTextField.value = viewState.url
            imageHolder.configureShadow(color: viewModel.imageShadowColor, offset: viewModel.imageShadowOffset, opacity: viewModel.imageShadowOpacity, radius: viewModel.imageShadowRadius, cornerRadius: imageHolder.frame.size.width / 2)
        }.store(in: &cancelable)

        output.didSave
            .sink { _ in self.delegate?.didSave(in: self) }
            .store(in: &cancelable)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageHolder.configureShadow(color: viewModel.imageShadowColor, offset: viewModel.imageShadowOffset, opacity: viewModel.imageShadowOpacity, radius: viewModel.imageShadowRadius, cornerRadius: imageHolder.frame.size.width / 2)
    }
}

extension EditBookmarkViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension EditBookmarkViewController: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
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

    func doneButtonTapped(for textField: TextField) {
        //no-op
    }

    func nextButtonTapped(for textField: TextField) {
        //no-op
    }
}
