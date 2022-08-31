//
//  DummySearchView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.07.2022.
//

import UIKit

class DummySearchView: UIView {

    private let searchBar: UISearchBar = {
        let searchBar: UISearchBar = UISearchBar(frame: .init(x: 0, y: 0, width: 100, height: 50))
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.isUserInteractionEnabled = false
        UISearchBar.configure(searchBar: searchBar)

        return searchBar
    }()

    private var overlayView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    init(closure: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(searchBar)
        addSubview(overlayView)

        NSLayoutConstraint.activate(searchBar.anchorsConstraint(to: self) + overlayView.anchorsConstraint(to: self))

        UITapGestureRecognizer(addToView: overlayView, closure: closure)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
