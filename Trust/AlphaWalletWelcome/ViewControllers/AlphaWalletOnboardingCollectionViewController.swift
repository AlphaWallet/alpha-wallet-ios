// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

//Duplicated from OnboardingCollectionViewController.swift for easier upstream merging
class AlphaWalletOnboardingCollectionViewController: UICollectionViewController {
    var pages = [AlphaWalletOnboardingPageViewModel]()
    weak var pageControl: UIPageControl?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        collectionView?.register(AlphaWalletOnboardingPage.self, forCellWithReuseIdentifier: AlphaWalletOnboardingPage.identifier)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.itemSize = view.bounds.size
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pages.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AlphaWalletOnboardingPage.identifier, for: indexPath) as! AlphaWalletOnboardingPage
        cell.model = pages[indexPath.row]
        return cell
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        pageControl?.currentPage = Int(round(scrollView.contentOffset.x / flowLayout.itemSize.width - 0.5))
    }
}
