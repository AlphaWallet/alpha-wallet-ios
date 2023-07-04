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
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        view.stackView.alignment = .center
        return view
    }()
    private lazy var imageHolder = ContainerViewWithShadow(aroundView: iconImageView)
    private lazy var titleTextField: TextField = {
        let textField = TextField.buildTextField()
        textField.delegate = self
        textField.label.text = viewModel.titleText
        textField.returnKeyType = .next
        textField.inputAccessoryButtonType = .next

        return textField
    }()
    private lazy var urlTextField: TextField = {
        let textField = TextField.buildTextField()
        textField.delegate = self
        textField.label.text = viewModel.urlText
        textField.returnKeyType = .done
        textField.inputAccessoryButtonType = .done

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

    weak var delegate: EditBookmarkViewControllerDelegate?

    init(viewModel: EditBookmarkViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let titleTextFieldLayout = titleTextField.defaultLayout()
        let urlTextFieldLayout = urlTextField.defaultLayout()

        let xOffset: CGFloat = 16

        containerView.stackView.addArrangedSubviews([
            .spacer(height: 16), //NOTE: use spacer to avoid cropping shadow
            imageHolder,
            UIView.spacer(height: ScreenChecker.size(big: 28, medium: 28, small: 20)),
            titleTextFieldLayout,
            UIView.spacer(height: 18),
            urlTextFieldLayout,
        ])

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0.0)
        view.addSubview(containerView)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            imageHolder.widthAnchor.constraint(equalToConstant: 80),
            imageHolder.widthAnchor.constraint(equalTo: imageHolder.heightAnchor),

            titleTextFieldLayout.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            urlTextFieldLayout.widthAnchor.constraint(equalTo: containerView.widthAnchor),

            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: xOffset),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -xOffset),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        buttonsBar.buttons[0].setTitle(R.string.localizable.save(), for: .normal)
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: EditBookmarkViewModel) {
        let saveSelected = buttonsBar.buttons[0]
            .publisher(forEvent: .touchUpInside)
            .map { [urlTextField, titleTextField] _ in
                return (title: titleTextField.value.trimmed, url: urlTextField.value.trimmed)
            }.eraseToAnyPublisher()

        let input = EditBookmarkViewModelInput(saveSelected: saveSelected)
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [imageHolder, iconImageView, titleTextField, urlTextField, navigationItem] viewState in
                navigationItem.title = viewState.title
                iconImageView.setImage(url: viewState.imageUrl, placeholder: viewModel.imagePlaceholder)
                titleTextField.value = viewState.bookmarkTitle
                urlTextField.value = viewState.bookmarkUrl
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

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: TextField) {
        urlTextField.becomeFirstResponder()
    }

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
}
