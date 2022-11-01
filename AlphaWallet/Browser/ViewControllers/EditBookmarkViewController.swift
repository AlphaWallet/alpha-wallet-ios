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
    private let buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()
    private let viewModel: EditBookmarkViewModel
    private var cancelable = Set<AnyCancellable>()
    private let deleteBookmark = PassthroughSubject<IndexPath, Never>()
    private lazy var keyboardChecker = KeyboardChecker(self)
    private var footerBottomConstraint: NSLayoutConstraint!

    weak var delegate: EditBookmarkViewControllerDelegate?

    init(viewModel: EditBookmarkViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let stackView = [
            imageHolder,
            UIView.spacer(height: ScreenChecker.size(big: 28, medium: 28, small: 20)),
            titleTextField.label,
            UIView.spacer(height: 7),
            titleTextField,
            UIView.spacer(height: 18),
            urlTextField.label,
            UIView.spacer(height: 7),
            urlTextField
        ].asStackView(axis: .vertical, alignment: .center)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: .zero, separatorHeight: 0.0)
        view.addSubview(footerBar)

        footerBottomConstraint = footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        footerBottomConstraint.constant = -UIApplication.shared.bottomSafeAreaHeight
        keyboardChecker.constraints = [footerBottomConstraint]
        
        NSLayoutConstraint.activate([
            imageHolder.widthAnchor.constraint(equalToConstant: 80),
            imageHolder.widthAnchor.constraint(equalTo: imageHolder.heightAnchor),

            titleTextField.label.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            titleTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            urlTextField.label.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            urlTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: footerBar.topAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBottomConstraint,
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardChecker.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    private func bind(viewModel: EditBookmarkViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.screenTitle
        buttonsBar.buttons[0].setTitle(viewModel.saveButtonTitle, for: .normal)

        let saveSelected = buttonsBar.buttons[0]
            .publisher(forEvent: .touchUpInside)
            .map { [urlTextField, titleTextField] _ in
                return (title: titleTextField.value.trimmed, url: urlTextField.value.trimmed)
            }.eraseToAnyPublisher()

        let input = EditBookmarkViewModelInput(saveSelected: saveSelected)
        let output = viewModel.transform(input: input)
        
        output.viewState.sink { [imageHolder, iconImageView, titleTextField, urlTextField] viewState in
            iconImageView.kf.setImage(with: viewState.imageUrl, placeholder: viewModel.imagePlaceholder)
            titleTextField.value = viewState.title
            urlTextField.value = viewState.url
            imageHolder.configureShadow(color: viewModel.imageShadowColor, offset: viewModel.imageShadowOffset, opacity: viewModel.imageShadowOpacity, radius: viewModel.imageShadowRadius, cornerRadius: imageHolder.frame.size.width / 2)
        }.store(in: &cancelable)

        output.bookmarkSaved
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
