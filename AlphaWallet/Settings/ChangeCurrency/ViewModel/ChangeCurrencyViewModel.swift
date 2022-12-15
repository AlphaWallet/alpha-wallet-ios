//
//  ChangeCurrencyViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.07.2022.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct ChangeCurrencyViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let selection: AnyPublisher<IndexPath, Never>
}

struct ChangeCurrencyViewModelOutput {
    let viewState: AnyPublisher<ChangeCurrencyViewModel.ViewState, Never>
    let selectedCurrency: AnyPublisher<Currency, Never>
}

class ChangeCurrencyViewModel {
    private let currencyService: CurrencyService
    private var cancelable = Set<AnyCancellable>()

    init(currencyService: CurrencyService) {
        self.currencyService = currencyService
    }

    func transform(input: ChangeCurrencyViewModelInput) -> ChangeCurrencyViewModelOutput {
        let selectedCurrency = input.selection
            .compactMap { [currencyService] in currencyService.availableCurrencies[$0.row] }
            .filter { [currencyService] in $0 != currencyService.currency }
            .handleEvents(receiveOutput: { [currencyService] in currencyService.set(currency: $0) })
            .prepend(currencyService.currency)
            .share()

        let availableCurrencies = input.willAppear
            .map { [currencyService] _ in currencyService.availableCurrencies }

        let snapshot = Publishers.CombineLatest(availableCurrencies, selectedCurrency)
            .map { currencies, selected in
                let views = currencies.map { CurrencyTableViewCellViewModel(currency: $0, isSelected: selected == $0) }

                return ChangeCurrencyViewModel.SectionViewModel(section: .currencies, views: views)
            }.map { self.buildSnapshot(for: [$0]) }

        let viewState = snapshot
            .map { ChangeCurrencyViewModel.ViewState(snapshot: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, selectedCurrency: selectedCurrency.delay(for: .milliseconds(5), scheduler: RunLoop.main).eraseToAnyPublisher())
    }

    private func buildSnapshot(for viewModels: [ChangeCurrencyViewModel.SectionViewModel]) -> ChangeCurrencyViewModel.Snapshot {
        var snapshot = ChangeCurrencyViewModel.Snapshot()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }

        return snapshot
    }
}

extension ChangeCurrencyViewModel {
    class DataSource: UITableViewDiffableDataSource<ChangeCurrencyViewModel.Section, CurrencyTableViewCellViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<ChangeCurrencyViewModel.Section, CurrencyTableViewCellViewModel>

    enum Section: Int, Hashable, CaseIterable {
        case currencies
    }

    struct ViewState {
        let snapshot: ChangeCurrencyViewModel.Snapshot
        let animatingDifferences: Bool = false
        let title: String = R.string.localizable.currencyNavigationTitle()
    }

    struct SectionViewModel {
        let section: ChangeCurrencyViewModel.Section
        let views: [CurrencyTableViewCellViewModel]
    }
}

extension Currency {
    var icon: UIImage? {
        switch self {
        case .USD:
            return R.image.usaFlag()
        case .GBP:
            return R.image.iconsFlagsUk()
        case .AUD:
            return R.image.iconsFlagsAustralia()
        case .NZD:
            return R.image.iconsFlagsNewzealand()
        case .EUR:
            return R.image.iconsFlagsEuro()
        case .UAH:
            return R.image.iconsFlagsUkraine()
        case .CNY:
            return R.image.iconsFlagsChina()
        case .JPY:
            return R.image.iconsFlagsJapan()
        case .TRY:
            return R.image.iconsFlagsTurkey()
        case .PLN:
            return R.image.iconsFlagsPoland()
        case .CAD:
            return R.image.iconsFlagsCanada()
        case .SGD:
            return R.image.iconsFlagsSingapore()
        case .TWD:
            return R.image.iconsFlagsTaiwan()
        }
    }
}
