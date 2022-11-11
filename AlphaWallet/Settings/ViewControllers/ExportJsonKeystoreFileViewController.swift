//
//  ExportJsonKeystoreFileViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 1/12/21.
//

import UIKit
import Combine

@objc protocol ExportJsonKeystoreFileDelegate {
    func didExport(fileUrl: URL, in viewController: UIViewController)
}

class ExportJsonKeystoreFileViewController: UIViewController {
    private let viewModel: ExportJsonKeystoreFileViewModel

    private lazy var textView: TextView = {
        let textView = TextView.nonEditableTextView
        textView.label.text = R.string.localizable.settingsAdvancedExportJSONKeystoreFileLabel()

        return textView
    }()
    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()
    private let willAppear = PassthroughSubject<Void, Never>()
    private var cancelable = Set<AnyCancellable>()
    private var exportButton: UIButton { buttonsBar.buttons[0] }

    weak var delegate: ExportJsonKeystoreFileDelegate?

    init(viewModel: ExportJsonKeystoreFileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        let topInset = ScreenChecker.size(big: 34, medium: 34, small: 24)
        let textViewLayout = textView.defaultLayout(edgeInsets: .init(top: topInset, left: 16, bottom: 16, right: 16))
        view.addSubview(textViewLayout)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            textViewLayout.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textViewLayout.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textViewLayout.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

            footerBar.anchorsConstraint(to: view)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

    private func bind(viewModel: ExportJsonKeystoreFileViewModel) {

        let input = ExportJsonKeystoreFileViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            export: exportButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.error
            .sink { [weak self] in self?.displayError(message: $0) }
            .store(in: &cancelable)

        output.viewState
            .sink { [navigationItem, exportButton, textView] viewState in
                navigationItem.title = viewState.title
                exportButton.setTitle(viewState.buttonTitle, for: .normal)
                exportButton.isEnabled = viewState.isActionButtonEnabled
                textView.value = viewState.exportedJsonString
            }.store(in: &cancelable)

        output.fileUrl
            .sink { [weak self] url in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didExport(fileUrl: url, in: strongSelf)
            }.store(in: &cancelable)

        output.loadingState
            .sink { [weak self] state in
                switch state {
                case .beginLoading: self?.displayLoading()
                case .endLoading: self?.hideLoading()
                }
            }.store(in: &cancelable)
    }
}
