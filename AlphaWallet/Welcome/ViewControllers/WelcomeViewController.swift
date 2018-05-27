// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol WelcomeViewControllerDelegate: class {
    func didPressCreateWallet(in viewController: WelcomeViewController)
}

class WelcomeViewController: UIViewController {

    var viewModel = WelcomeViewModel()
    weak var delegate: WelcomeViewControllerDelegate?

    lazy var collectionViewController: OnboardingCollectionViewController = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.scrollDirection = .horizontal
        let collectionViewController = OnboardingCollectionViewController(collectionViewLayout: layout)
        collectionViewController.pages = pages
        collectionViewController.pageControl = pageControl
        collectionViewController.collectionView?.isPagingEnabled = true
        collectionViewController.collectionView?.showsHorizontalScrollIndicator = false
        collectionViewController.collectionView?.backgroundColor = viewModel.backgroundColor
        return collectionViewController
    }()
    let pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        return pageControl
    }()
    let createWalletButton: UIButton = {
        let button = Button(size: .large, style: .squared)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.aWelcomeOnboardingCreatewalletButtonTitle(), for: .normal)
        button.titleLabel?.font = Fonts.semibold(size: 16)
        button.backgroundColor = Colors.appBackground
        button.setTitleColor(Colors.appWhite, for: .normal)
        return button
    }()
    let pages: [OnboardingPageViewModel] = [

        OnboardingPageViewModel(
            title: R.string.localizable.aWelcomeOnboarding1(),
            image: R.image.onboarding_1()!
        ),
        OnboardingPageViewModel(
			title: R.string.localizable.aWelcomeOnboarding2(),
            image: R.image.onboarding_2()!
        ),
        OnboardingPageViewModel(
			title: R.string.localizable.aWelcomeOnboarding3(),
            image: R.image.onboarding_3()!
        ),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.numberOfPages = pages.count
        view.addSubview(collectionViewController.view)

        view.addSubview(pageControl)

        let footerBar = UIView()
        footerBar.backgroundColor = Colors.appBackground
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerBar)

        let walletButtonHeight = CGFloat(50)
        footerBar.addSubview(createWalletButton)

        collectionViewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            collectionViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            collectionViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            pageControl.centerYAnchor.constraint(equalTo: collectionViewController.view.centerYAnchor, constant: -120),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.heightAnchor.constraint(equalToConstant: 20),

            createWalletButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -10),
            createWalletButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 10),
            createWalletButton.topAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: walletButtonHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        createWalletButton.addTarget(self, action: #selector(start), for: .touchUpInside)

        configure(viewModel: viewModel)
    }

    func configure(viewModel: WelcomeViewModel) {
        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor
        pageControl.currentPageIndicatorTintColor = viewModel.currentPageIndicatorTintColor
        pageControl.pageIndicatorTintColor = viewModel.pageIndicatorTintColor
        pageControl.numberOfPages = viewModel.numberOfPages
        pageControl.currentPage = viewModel.currentPage
    }

    @IBAction func start() {
        delegate?.didPressCreateWallet(in: self)
    }
}
