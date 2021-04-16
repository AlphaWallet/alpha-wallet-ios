// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

protocol PromptViewControllerDelegate: class {
    func actionButtonTapped(inController controller: PromptViewController)
    func controllerDismiss(_ controller: PromptViewController)
}

class PromptViewController: UIViewController {
    private var viewModel = PromptViewModel(title: "", description: "", buttonTitle: "")
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: "", isMinimalMode: true))
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))

    private var titleLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.black()
        v.font = Fonts.regular(size: 28)
        return v
    }()

    private var descriptionLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.mine()
        v.font = Fonts.regular(size: 17)
        return v
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        return scrollView
    }()

    private var contentSizeObservation: NSKeyValueObservation?

    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = viewModel.footerBackgroundColor
        view.addSubview(buttonsBar)

        return view
    }()

    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissViewController))
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(tap)

        return view
    }()

    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.cornerRadius = 12

        view.addSubview(scrollView)
        view.addSubview(footerBar)
        view.addSubview(headerView)

        return view
    }()

    private lazy var heightConstraint: NSLayoutConstraint = {
        return containerView.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()

    private lazy var bottomConstraint: NSLayoutConstraint = {
        containerView.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }()

    private var allowPresentationAnimation: Bool = true
    private var allowDismissalAnimation: Bool = true

    weak var delegate: PromptViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)

        view.addSubview(backgroundView)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            backgroundView.bottomAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            heightConstraint,
            bottomConstraint,
            containerView.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 26),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -26),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            footerBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor),

            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
        ])
        headerView.closeButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .initial]) { [weak self] scrollView, _ in
            guard let strongSelf = self, strongSelf.allowDismissalAnimation else { return }

            let statusBarHeight = UIApplication.shared.statusBarFrame.height
            let contentHeight = scrollView.contentSize.height + DataEntry.Metric.TransactionConfirmation.footerHeight + DataEntry.Metric.TransactionConfirmation.headerHeight + UIApplication.shared.bottomSafeAreaHeight
            let newHeight = min(UIScreen.main.bounds.height - statusBarHeight, contentHeight)

            let fillScreenPercentage = strongSelf.heightConstraint.constant / strongSelf.view.bounds.height

            if fillScreenPercentage >= 0.9 {
                strongSelf.heightConstraint.constant = strongSelf.containerView.bounds.height
            } else {
                strongSelf.heightConstraint.constant = newHeight
            }
        }

        generateSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)

        //NOTE: to display animation correctly we can take 'view.frame.height' and bottom view will smoothly slide up from button ;)
        bottomConstraint.constant = view.frame.height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(true, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presentViewAnimated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(false, animated: false)
        }
    }

    private func presentViewAnimated() {
        guard allowPresentationAnimation else { return }
        allowPresentationAnimation = false

        bottomConstraint.constant = 0

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    func dismissViewAnimated(with completion: @escaping () -> Void) {
        guard allowDismissalAnimation else { return }
        allowDismissalAnimation = false

        bottomConstraint.constant = heightConstraint.constant

        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            completion()
        })
    }

    @objc private func dismissViewController() {
        delegate?.controllerDismiss(self)
    }

    func configure(viewModel: PromptViewModel) {
        self.viewModel = viewModel

        scrollView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor

        titleLabel.text = viewModel.title

        descriptionLabel.text = viewModel.description

        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.shrinkBorderColor = Colors.loadingIndicatorBorder
        button.setTitle(viewModel.buttonTitle, for: .normal)
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        buttonsBar.isHidden = false
    }

    @objc private func actionButtonTapped() {
        delegate?.actionButtonTapped(inController: self)
    }

    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()
        let views: [UIView] = [
            titleLabel,
            .spacer(height: 20),
            descriptionLabel,
        ]
        stackView.addArrangedSubviews(views)
    }
}