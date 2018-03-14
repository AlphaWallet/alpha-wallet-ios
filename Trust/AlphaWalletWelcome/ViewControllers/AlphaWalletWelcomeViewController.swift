// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AlphaWalletWelcomeViewControllerDelegate: class {
    func didPressCreateWallet(in viewController: AlphaWalletWelcomeViewController)
}

//Duplicated from WelcomeViewController.swift for easier upstream merging
class AlphaWalletWelcomeViewController: UIViewController {

    var viewModel = AlphaWalletWelcomeViewModel()
    weak var delegate: AlphaWalletWelcomeViewControllerDelegate?

    lazy var collectionViewController: AlphaWalletOnboardingCollectionViewController = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.scrollDirection = .horizontal
        let collectionViewController = AlphaWalletOnboardingCollectionViewController(collectionViewLayout: layout)
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
    let pages: [AlphaWalletOnboardingPageViewModel] = [

        AlphaWalletOnboardingPageViewModel(
            title: R.string.localizable.aWelcomeOnboarding1(),
            image: R.image.onboarding_1()!
        ),
        AlphaWalletOnboardingPageViewModel(
			title: R.string.localizable.aWelcomeOnboarding2(),
            image: R.image.onboarding_2()!
        ),
        AlphaWalletOnboardingPageViewModel(
			title: R.string.localizable.aWelcomeOnboarding3(),
            image: R.image.onboarding_3()!
        ),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.numberOfPages = pages.count
        view.addSubview(collectionViewController.view)

        view.addSubview(pageControl)
        view.addSubview(createWalletButton)

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
            createWalletButton.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        createWalletButton.addTarget(self, action: #selector(start), for: .touchUpInside)

        configure(viewModel: viewModel)
    }

    func configure(viewModel: AlphaWalletWelcomeViewModel) {
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
