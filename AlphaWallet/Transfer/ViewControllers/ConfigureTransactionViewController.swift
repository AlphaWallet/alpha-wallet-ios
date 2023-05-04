// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import AlphaWalletFoundation
import Combine

protocol ConfigureTransactionViewControllerDelegate: AnyObject {
    func didSaved(in viewController: ConfigureTransactionViewController)
}

class ConfigureTransactionViewController: UIViewController {
    private var cancellable = Set<AnyCancellable>()
    private let viewModel: ConfigureTransactionViewModel
    private lazy var stateView: UpdateInView = {
        let view = UpdateInView(viewModel: viewModel.updateInViewModel)
        return view
    }()
    private lazy var containerView: ScrollableStackView = {
        return ScrollableStackView()
    }()
    private var footerContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()
    private var gasSpeedViews: [GasSpeed: (view: GasSpeedView, seperator: UIView)] = [:]
    private var editTransactionContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()
    private lazy var editTransactionViewController = EditTransactionViewController(viewModel: viewModel.editTransactionViewModel)
    private let saveSubject = PassthroughSubject<Void, Never>()

    weak var delegate: ConfigureTransactionViewControllerDelegate?

    init(viewModel: ConfigureTransactionViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        containerView.configure(viewModel: .init(backgroundColor: Configuration.Color.Semantic.defaultViewBackground))
        navigationItem.leftBarButtonItem = UIBarButtonItem.saveBarButton(self, selector: #selector(saveButtonSelected))

        let stackView = [
            containerView,
            stateView
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsIgnoringBottomSafeArea(to: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(editTransactionViewController)
        editTransactionContainerView.addSubview(editTransactionViewController.view)
        editTransactionViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(editTransactionViewController.view.anchorsConstraint(to: editTransactionContainerView))
        editTransactionViewController.didMove(toParent: self)

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        generateViews()
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: ConfigureTransactionViewModel) {
        let input = ConfigureTransactionViewModelInput(saveSelected: saveSubject.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self] viewState in
                for each in viewState.gasSpeedViewModels {
                    guard let subview = self?.gasSpeedViews[each.gasSpeed] else { continue }

                    subview.view.configure(viewModel: each)
                    
                    subview.view.isHidden = each.isHidden
                    subview.seperator.isHidden = each.isHidden
                }
                self?.editTransactionContainerView.isHidden = viewState.isEditTransactionHidden
                self?.navigationItem.title = viewState.title
            }.store(in: &cancellable)

        output.gasPriceWarning
            .sink { [weak self] in self?.showFooterWarning(gasPriceWarning: $0) }
            .store(in: &cancellable)

        output.didSave
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didSaved(in: strongSelf)
            }.store(in: &cancellable)
    }

    private func showFooterWarning(gasPriceWarning: TransactionConfigurator.GasPriceWarning?) {
        let view: UIView
        if let gasPriceWarning = gasPriceWarning {
            view = createTableFooterForGasPriceWarning(gasPriceWarning)
        } else {
            view = createTableFooterForGasInformation(server: viewModel.server)
        }

        for each in footerContainerView.subviews {
            each.removeFromSuperview()
        }

        footerContainerView.addSubview(view)
        NSLayoutConstraint.activate(view.anchorsConstraint(to: footerContainerView, margin: 30))
    }

    private func createTableFooterForGasInformation(server: RPCServer) -> UIView {
        let footer = UIView(frame: .init(x: 0, y: 0, width: 0, height: 100))
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = Fonts.regular(size: 15)
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.text = R.string.localizable.transactionConfirmationFeeFooterText(server.blockChainName)

        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(label)

        NSLayoutConstraint.activate([
            label.anchorsConstraint(to: footer),
        ])

        return footer
    }

    private func createTableFooterForGasPriceWarning(_ gasPriceWarning: TransactionConfigurator.GasPriceWarning) -> UIView {
        let background = UIView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = Configuration.Color.Semantic.configureTransactionBackground
        background.borderColor = Configuration.Color.Semantic.configureTransactionBorder
        background.cornerRadius = 8
        background.borderWidth = 1

        let warningIcon = UIImageView(image: R.image.gasWarning())
        warningIcon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.textAlignment = .center
        titleLabel.font = Fonts.semibold(size: 20)
        titleLabel.textColor = Configuration.Color.Semantic.defaultErrorText
        titleLabel.text = gasPriceWarning.longTitle

        let descriptionLabel = UITextView()
        descriptionLabel.backgroundColor = .clear
        descriptionLabel.textColor = Configuration.Color.Semantic.defaultSubtitleText
        descriptionLabel.textAlignment = .center
        descriptionLabel.isEditable = false
        descriptionLabel.isSelectable = true
        descriptionLabel.isUserInteractionEnabled = true
        descriptionLabel.isScrollEnabled = false
        descriptionLabel.dataDetectorTypes = .link
        descriptionLabel.font = Fonts.regular(size: 15)
        descriptionLabel.text = gasPriceWarning.localizedDescription

        let row0 = [warningIcon, titleLabel].asStackView(axis: .horizontal, spacing: 6)
        let row1 = descriptionLabel

        let stackView = [
            row0,
            row1,
        ].asStackView(axis: .vertical, spacing: 6, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: background, edgeInsets: UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 16)),

            warningIcon.widthAnchor.constraint(equalToConstant: 24),
            warningIcon.widthAnchor.constraint(equalTo: warningIcon.heightAnchor),

            descriptionLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -50)
        ])

        return background
    }

    @objc private func saveButtonSelected(_ sender: UIBarButtonItem) {
        saveSubject.send(())
    }
}

extension ConfigureTransactionViewController {

    private func buildGasSpeedView(gasSpeed: GasSpeed) -> GasSpeedView {
        if let view = gasSpeedViews[gasSpeed] {
            return view.view
        } else {
            let subview = GasSpeedView()
            subview.isUserInteractionEnabled = true

            UITapGestureRecognizer.init(addToView: subview) { [weak viewModel] in
                viewModel?.select(gasSpeed: gasSpeed)
            }
            gasSpeedViews[gasSpeed] = (subview, UIView.separator())

            return subview
        }
    }

    private func generateViews() {
        var views: [UIView] = []
        for gasSpeed in viewModel.allGasSpeeds {
            let subview: GasSpeedView = buildGasSpeedView(gasSpeed: gasSpeed)

            views += [subview, gasSpeedViews[gasSpeed]!.seperator]
        }

        views += [editTransactionContainerView]
        views += [footerContainerView]

        containerView.stackView.removeAllArrangedSubviews()
        containerView.stackView.addArrangedSubviews(views)
    }
}
