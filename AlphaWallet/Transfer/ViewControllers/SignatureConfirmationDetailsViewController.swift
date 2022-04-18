//
//  SignatureConfirmationDetailsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.03.2021.
//

import UIKit

class SignatureConfirmationDetailsViewController: UIViewController {

    private let singleMessageTextView: SelfResizedTextView = {
        let textView = SelfResizedTextView()
        textView.isEditable = false
        return textView
    }()

    private var viewModel: SignatureConfirmationDetailsViewModel 

    lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    init(viewModel: SignatureConfirmationDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([

            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            singleMessageTextView.heightConstraint,
        ])
    }

    private func generateView(viewModel: SignatureConfirmationDetailsViewModel) {
        containerView.stackView.removeAllArrangedSubviews()

        var subviews: [UIView]

        switch viewModel {
        case .rawValue(let viewModel):
            configureMessageTextView(attributedText: viewModel.messageAttributedString, backgroundColor: viewModel.backgroundColor)

            subviews = [singleMessageTextView]
        case .typedMessageValue(let viewModel):
            let view = TypedDataView()
            view.delegate = self
            view.configure(viewModel: viewModel.typedDataViewModel)

            subviews = [view]
        case .eip712v3And4(let viewModel):
            switch viewModel.presentationType {
            case .complexObject(let attributedText):
                let view = TypedDataView()
                view.delegate = self
                view.configure(viewModel: .init(name: viewModel.key, value: ""))

                configureMessageTextView(attributedText: attributedText, backgroundColor: viewModel.backgroundColor)

                subviews = [view, singleMessageTextView]
            case .single(let value):
                let view = TypedDataView()
                view.delegate = self
                view.configure(viewModel: .init(name: viewModel.key, value: value, isCopyAllowed: true))

                subviews = [view]
            }
        }

        containerView.stackView.addArrangedSubviews(subviews)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configureMessageTextView(attributedText: NSAttributedString, backgroundColor: UIColor) {
        singleMessageTextView.attributedText = attributedText
        singleMessageTextView.backgroundColor = backgroundColor
    }

    func configure(viewModel: SignatureConfirmationDetailsViewModel) {
        self.viewModel = viewModel
        
        navigationItem.title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor

        generateView(viewModel: viewModel)
    }
}

extension SignatureConfirmationDetailsViewController: TypedDataViewDelegate {
    func copySelected(in view: TypedDataView) {
        UIPasteboard.general.string = viewModel.valueToCopy

        self.view.showCopiedToClipboard(title: R.string.localizable.copiedToClipboard())
    }
}
