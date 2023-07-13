// Copyright © 2023 Stormbird PTE. LTD.

import UIKit
import AlphaWalletAttestation
import AlphaWalletFoundation

protocol AttestationViewControllerDelegate: AnyObject, CanOpenURL {
}

class AttestationViewController: UIViewController {
    private let containerView: ScrollableStackView = ScrollableStackView()
    private let attributesStackView = GridStackView(viewModel: .init(edgeInsets: .init(top: 0, left: 16, bottom: 15, right: 16)))
    private let attestation: Attestation

    weak var delegate: AttestationViewControllerDelegate?

    init(attestation: Attestation) {
        self.attestation = attestation

        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.attestationsEas()
        view.backgroundColor = Configuration.Color.Semantic.searchBarBackground

        var subviews: [UIView] = []

        let detailsHeader = TokenInfoHeaderView()
        detailsHeader.configure(viewModel: TokenInfoHeaderViewModel(title: R.string.localizable.semifungiblesDetails()))
        subviews.append(detailsHeader)

        let networkRow = functional.createDetailRow(title: R.string.localizable.transactionNetworkLabelTitle(), value: TokenAttributeViewModel.defaultValueAttributedString(attestation.server.name))
        subviews.append(networkRow)

        let contractAddressRow = functional.createDetailRow(title: R.string.localizable.contractAddress(), value: TokenAttributeViewModel.urlValueAttributedString(attestation.verifyingContract?.truncateMiddle ?? ""))
        subviews.append(contractAddressRow)
        contractAddressRow.delegate = self

        let attributesHeader = TokenInfoHeaderView()
        attributesHeader.configure(viewModel: TokenInfoHeaderViewModel(title: R.string.localizable.attestationsAttributes()))
        subviews.append(attributesHeader)

        var attributeViews: [NonFungibleTraitView] = []

        for each in attestation.data {
            let attributeView = functional.createAttributeView(name: each.type.name, value: each.value.stringValue)
            attributeViews.append(attributeView)
        }
        let dateFormatter = Date.formatter(with: "dd MMM yyyy h:mm:ss a")
        let validFromView = functional.createAttributeView(name: R.string.localizable.attestationsValidFrom(), value: dateFormatter.string(from: attestation.time))
        attributeViews.append(validFromView)
        let expirationTimeString: String
        if let expirationTime = attestation.expirationTime {
            expirationTimeString = dateFormatter.string(from: expirationTime)
        } else {
            expirationTimeString = "—"
        }
        let validUntilView = functional.createAttributeView(name: R.string.localizable.attestationsValidUntil(), value: expirationTimeString)
        attributeViews.append(validUntilView)

        attributesStackView.set(subviews: attributeViews)
        subviews.append(attributesStackView)

        containerView.stackView.addArrangedSubviews(subviews)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        showIssuerKeyVerificationButton()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func showIssuerKeyVerificationButton() {
        let issuerKeyVerificationButton = Self.functional.createIssuerKeyVerificationButton(isVerified: attestation.isValidAttestationIssuer)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: issuerKeyVerificationButton)
    }

    enum functional {}
}

fileprivate extension AttestationViewController.functional {
    static func createAttributeView(name: String, value: String) -> NonFungibleTraitView {
        //Looks like it doesn't matter
        let indexPath = IndexPath(row: 0, section: 0)

        let attributeView = NonFungibleTraitView(edgeInsets: .init(top: 10, left: 10, bottom: 10, right: 10), indexPath: indexPath)
        let attributeViewModel = NonFungibleTraitViewModel(title: name, attributedValue: TokenAttributeViewModel.defaultValueAttributedString(value, alignment: .center), attributedCountValue: nil)
        attributeView.configure(viewModel: attributeViewModel)
        return attributeView
    }

    static func createDetailRow(title: String, value: NSAttributedString) -> TokenAttributeView {
        //Looks like it doesn't matter
        let indexPath = IndexPath(row: 0, section: 0)

        let viewModel: TokenAttributeViewModel = TokenAttributeViewModel(title: title, attributedValue: value)
        let view = TokenAttributeView(indexPath: indexPath)
        view.configure(viewModel: viewModel)
        return view
    }

    static func createIssuerKeyVerificationButton(isVerified: Bool) -> UIButton {
        let title: String
        let image: UIImage?
        let tintColor: UIColor
        let button = UIButton(type: .system)
        if isVerified {
            //TODO localize
            title = "Trusted issuer"
            image = R.image.verified()
            tintColor = Configuration.Color.Semantic.textFieldContrastText
        } else {
            //TODO localize
            title = "Not trusted"
            image = R.image.unverified()
            tintColor = Configuration.Color.Semantic.defaultErrorText
        }
        button.setTitle(title, for: .normal)
        button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.imageView?.tintColor = tintColor
        button.titleLabel?.font = Fonts.regular(size: 11)
        button.setTitleColor(tintColor, for: .normal)
        //TODO hardcoded margins don't work well across languages, e.g. for Chinese
        button.imageEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 12)
        button.titleEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: -12)
        return button
    }
}

extension AttestationViewController: TokenAttributeViewDelegate {
    func didSelect(in view: TokenAttributeView) {
        guard let contract = attestation.verifyingContract else { return }
        delegate?.didPressViewContractWebPage(forContract: contract, server: attestation.server, in: self)
    }
}