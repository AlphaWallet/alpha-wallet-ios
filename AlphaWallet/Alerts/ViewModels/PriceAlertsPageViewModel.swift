//
//  PriceAlertsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct PriceAlertsViewModelInput {
    let updateAlert: AnyPublisher<(value: Bool, indexPath: IndexPath), Never>
    let removeAlert: AnyPublisher<IndexPath, Never>
}

struct PriceAlertsViewModelOutput {
    let viewState: AnyPublisher<PriceAlertsViewModel.ViewState, Never>
}

class PriceAlertsViewModel {
    private let alertService: PriceAlertServiceType
    private let token: Token
    private var cancelable = Set<AnyCancellable>()
    
    init(alertService: PriceAlertServiceType, token: Token) {
        self.alertService = alertService
        self.token = token
    }

    func transform(input: PriceAlertsViewModelInput) -> PriceAlertsViewModelOutput {
        input.removeAlert
            .sink { [alertService] in alertService.remove(indexPath: $0) }
            .store(in: &cancelable)

        input.updateAlert
            .sink { [alertService] in alertService.update(indexPath: $0.indexPath, update: .enabled($0.value)) }
            .store(in: &cancelable)

        let viewState = alertService.alertsPublisher(forStrategy: .token(token))
            .map { $0.map { PriceAlertTableViewCellViewModel(alert: $0) } }
            .map { [SectionViewModel(section: .alerts, views: $0)] }
            .map { ViewState(snapshot: self.buildSnapshot(for: $0)) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [SectionViewModel]) -> PriceAlertsViewModel.Snapshot {
        var snapshot = PriceAlertsViewModel.Snapshot()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }

        return snapshot
    }
}

extension PriceAlertsViewModel {
    class DataSource: UITableViewDiffableDataSource<PriceAlertsViewModel.Section, PriceAlertTableViewCellViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<PriceAlertsViewModel.Section, PriceAlertTableViewCellViewModel>

    enum Section: Int, Hashable, CaseIterable {
        case alerts
    }

    struct SectionViewModel {
        let section: Section
        let views: [PriceAlertTableViewCellViewModel]
    }

    struct ViewState {
        let animatingDifferences: Bool = false
        let snapshot: Snapshot
        let addNewAlertViewModel = ShowAddHideTokensViewModel(
            addHideTokensIcon: R.image.add_hide_tokens(),
            addHideTokensTitle: R.string.localizable.priceAlertNewAlert(),
            backgroundColor: Configuration.Color.Semantic.tableViewHeaderBackground,
            badgeText: nil)
    }
}

extension AlertType {
    var icon: UIImage? {
        switch self {
        case .price(let priceTarget, _):
            switch priceTarget {
            case .above:
                return R.image.iconsSystemUp()
            case .below:
                return R.image.iconsSystemDown()
            }
        }
    }

    var title: String {
        switch self {
        case .price(let priceTarget, let value):
            //FIXME: replace alert rate(double) with CurrencyRateSupportable
            let result = NumberFormatter.fiatShort(currency: CurrencyService(storage: Config()).currency).string(double: value) ?? "-"
            return "\(priceTarget.title) \(result)"
        }
    }
}

extension PriceAlert {
    var description: String { return type.title }
    var icon: UIImage? { return type.icon }
    var title: String { return type.title }
}

extension PriceTarget {
    var title: String {
        switch self {
        case .above: return R.string.localizable.priceAlertAbove()
        case .below: return R.string.localizable.priceAlertBelow()
        }
    }
}

