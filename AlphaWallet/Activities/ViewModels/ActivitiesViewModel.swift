// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

enum ActivityOrTransactionFilter {
    case keyword(_ value: String?)
}

struct ActivitiesViewModel {
    static var formatter: DateFormatter = Date.formatter(with: "dd MMM yyyy")
    struct ActivityDateKey: Hashable, Equatable {
        let date: Date
        let stringValue: String

        init(date: Date) {
            self.date = date

            stringValue = ActivitiesViewModel.formatter.string(from: date)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(stringValue)
        }

        static func == (_ lhs: ActivityDateKey, _ rhs: ActivityDateKey) -> Bool {
            return lhs.stringValue == rhs.stringValue
        }
    }

    typealias MappedToDateActivityOrTransaction = (date: ActivityDateKey, items: [ActivityRowModel])

    private var items: [MappedToDateActivityOrTransaction] = []
    private var filteredItems: [MappedToDateActivityOrTransaction] = []
    var itemsCount: Int {
        items.count
    }

    init(activities: [MappedToDateActivityOrTransaction] = []) {
        items = activities
    }

    static func sorted(activities: [ActivityRowModel]) -> [MappedToDateActivityOrTransaction] {
        //Uses NSMutableArray instead of Swift array for performance. Really slow when dealing with 10k events, which is hardly a big wallet
        var newItems: [ActivityDateKey: NSMutableArray] = [:]

        for each in activities {
            let key: ActivityDateKey = .init(date: each.date)
            let currentItems = newItems[key] ?? .init()
            currentItems.add(each)

            newItems[key] = currentItems
        }

        return newItems.map { each in
            (date: each.key, items: (each.value as! [ActivityRowModel]).sorted {
                //Show pending transactions at the top
                if $0.blockNumber == 0 && $1.blockNumber != 0 {
                    return true
                } else if $0.blockNumber != 0 && $1.blockNumber == 0 {
                    return false
                } else if $0.blockNumber > $1.blockNumber {
                    return true
                } else if $0.blockNumber < $1.blockNumber {
                    return false
                } else {
                    if $0.transactionIndex > $1.transactionIndex {
                        return true
                    } else if $0.transactionIndex < $1.transactionIndex {
                        return false
                    } else {
                        switch ($0, $1) {
                        case (.parentTransaction(transaction: let t0, _, _), .parentTransaction(transaction: let t1, _, _)):
                            return t0.blockNumber > t1.blockNumber
                        case (.parentTransaction, _):
                            return true
                        case (_, .parentTransaction):
                            return false
                        case let (.standaloneActivity(a0), .standaloneActivity(a1)):
                            return a0.logIndex > a1.logIndex
                        case let (.childTransaction(t0, _, _), .childTransaction(t1, _, _)):
                            if let n0 = Int(t0.nonce), let n1 = Int(t1.nonce) {
                                return n0 > n1
                            } else {
                                return false
                            }
                        case (.childTransaction, .standaloneActivity):
                            return false
                        case (.standaloneActivity, .childTransaction):
                            return true
                        case (.childTransaction, .standaloneTransaction):
                            return false
                        case (.standaloneTransaction, .childTransaction):
                            return true
                        case (.standaloneTransaction, .standaloneActivity):
                            return true
                        case (.standaloneActivity, .standaloneTransaction):
                            return false
                        case (.childActivity(transaction: let t0, activity: let a0), .childActivity(transaction: let t1, activity: let a1)):
                            if t0.blockNumber > t1.blockNumber {
                                return true
                            }
                            if t1.blockNumber > t0.blockNumber {
                                return false
                            }
                            return a0.logIndex > a1.logIndex
                        case (.childActivity(transaction: let t0, _), .childTransaction(transaction: let t1, _, _)):
                            if t0.blockNumber > t1.blockNumber {
                                return true
                            }
                            if t1.blockNumber > t0.blockNumber {
                                return false
                            }
                            return true
                        case (.childActivity(transaction: let t0, _), .standaloneTransaction(transaction: let t1, _)):
                            return t0.blockNumber > t1.blockNumber
                        case (.childActivity(transaction: let t0, _), .standaloneActivity(activity: let a1)):
                            return t0.blockNumber > a1.blockNumber
                        case (.standaloneTransaction(transaction: let t0, _), .childActivity(transaction: let t1, _)):
                            return t0.blockNumber > t1.blockNumber
                        case (.standaloneTransaction(transaction: let t0, _), .standaloneTransaction(transaction: let t1, _)):
                            return t0.blockNumber > t1.blockNumber
                        case (.childTransaction(transaction: let t0, _, _), .childActivity(transaction: let t1, _)):
                            if t0.blockNumber > t1.blockNumber {
                                return true
                            }
                            if t1.blockNumber > t0.blockNumber {
                                return false
                            }
                            return true
                        case (.standaloneActivity(activity: let a0), .childActivity(transaction: let transaction, _)):
                            return a0.blockNumber > transaction.blockNumber
                        }
                    }
                }
            })
        }
        .sorted { (object1, object2) -> Bool in
            return object1.date.date.timeIntervalSince1970 > object2.date.date.timeIntervalSince1970
        }
    }

    mutating func filter(_ filter: ActivityOrTransactionFilter) {
        var newFilteredItems = items

        switch filter {
        case .keyword(let keyword):
            if let valueToSearch = keyword?.trimmed.lowercased(), valueToSearch.nonEmpty {
                let twoKeywords = splitIntoExactlyTwoKeywords(valueToSearch)
                let results = newFilteredItems.compactMap { date, content -> MappedToDateActivityOrTransaction? in
                    let data: [ActivityRowModel]
                    if let twoKeywords = twoKeywords {
                        //Special case to support keywords like "Sent CoFi"
                        data = content.filter { data -> Bool in
                            (data.activityName?.lowercased().contains(twoKeywords.0) ?? false) &&
                                    (data.getTokenSymbol()?.lowercased().contains(twoKeywords.1) ?? false)
                        }
                    } else {
                        data = content.filter { data -> Bool in
                            (data.activityName?.lowercased().contains(valueToSearch) ?? false) ||
                                    (data.getTokenSymbol()?.lowercased().contains(valueToSearch) ?? false)
                        }
                    }

                    if data.isEmpty {
                        return nil
                    } else {
                        return (date: date, items: data)
                    }
                }

                newFilteredItems = results
            }
        }

        filteredItems = newFilteredItems
    }

    var backgroundColor: UIColor {
        Colors.appWhite
    }

    var headerBackgroundColor: UIColor {
        GroupedTable.Color.background
    }

    var headerTitleTextColor: UIColor {
        GroupedTable.Color.title
    }

    var headerTitleFont: UIFont {
        Fonts.tableHeader
    }

    var numberOfSections: Int {
        filteredItems.count
    }

    func numberOfItems(for section: Int) -> Int {
        filteredItems[section].items.count
    }

    func item(for row: Int, section: Int) -> ActivityRowModel {
        filteredItems[section].items[row]
    }

    func titleForHeader(in section: Int) -> String {
        let date = filteredItems[section].date.date
        if NSCalendar.current.isDateInToday(date) {
            return R.string.localizable.today().localizedUppercase
        }
        if NSCalendar.current.isDateInYesterday(date) {
            return R.string.localizable.yesterday().localizedUppercase
        }

        return filteredItems[section].date.stringValue.localizedUppercase
    }

    private func splitIntoExactlyTwoKeywords(_ string: String) -> (String, String)? {
        let components = string.split(separator: " ")
        guard components.count == 2 else { return nil }
        return (String(components[0]), String(components[1]))
    }
}

extension String {
    var nonEmpty: Bool {
        return !self.trimmed.isEmpty
    }
}

extension ActivitiesViewModel {
    class functional {}
}

extension ActivitiesViewModel.functional {

    static func extractTokenAndActivityName(fromTransactionRow transactionRow: TransactionRow, tokensDataStore: TokensDataStore, wallet: AlphaWallet.Address) -> (token: TokenObject, activityName: String)? {
        enum TokenOperation {
            case nativeCryptoTransfer(TokenObject)
            case completedTransfer(TokenObject)
            case pendingTransfer(TokenObject)
            case completedErc20Approval(TokenObject)
            case pendingErc20Approval(TokenObject)

            var token: TokenObject {
                switch self {
                case .nativeCryptoTransfer(let token):
                    return token
                case .completedTransfer(let token):
                    return token
                case .pendingTransfer(let token):
                    return token
                case .completedErc20Approval(let token):
                    return token
                case .pendingErc20Approval(let token):
                    return token
                }
            }
        }

        let erc20TokenOperation: TokenOperation?
        if transactionRow.operation == nil {
            erc20TokenOperation = .nativeCryptoTransfer(MultipleChainsTokensDataStore.functional.etherToken(forServer: transactionRow.server))
        } else {
            //Explicitly listing out combinations so future changes to enums will be caught by compiler
            switch (transactionRow.state, transactionRow.operation?.operationType) {
            case (.pending, .nativeCurrencyTokenTransfer), (.pending, .erc20TokenTransfer), (.pending, .erc721TokenTransfer), (.pending, .erc875TokenTransfer), (.pending, .erc1155TokenTransfer):
                erc20TokenOperation = transactionRow.operation?.contractAddress.flatMap { tokensDataStore.token(forContract: $0, server: transactionRow.server) }.flatMap { TokenOperation.pendingTransfer($0) }
            case (.completed, .nativeCurrencyTokenTransfer), (.completed, .erc20TokenTransfer), (.completed, .erc721TokenTransfer), (.completed, .erc875TokenTransfer), (.completed, .erc1155TokenTransfer):
                erc20TokenOperation = transactionRow.operation?.contractAddress.flatMap { tokensDataStore.token(forContract: $0, server: transactionRow.server) }.flatMap { TokenOperation.completedTransfer($0) }
            case (.pending, .erc20TokenApprove):
                erc20TokenOperation = transactionRow.operation?.contractAddress.flatMap { tokensDataStore.token(forContract: $0, server: transactionRow.server) }.flatMap { TokenOperation.pendingErc20Approval($0) }
            case (.completed, .erc20TokenApprove):
                erc20TokenOperation = transactionRow.operation?.contractAddress.flatMap { tokensDataStore.token(forContract: $0, server: transactionRow.server) }.flatMap { TokenOperation.completedErc20Approval($0) }
            case (.unknown, _), (.error, _), (.failed, _), (_, .unknown), (.completed, .none), (.pending, nil):
                erc20TokenOperation = .none
            }
        }
        guard let token = erc20TokenOperation?.token else { return nil }
        let activityName: String
        switch erc20TokenOperation {
        case .nativeCryptoTransfer, .completedTransfer, .pendingTransfer, .none:
            if wallet.sameContract(as: transactionRow.from) {
                activityName = "sent"
            } else {
                activityName = "received"
            }
        case .completedErc20Approval, .pendingErc20Approval:
            activityName = "ownerApproved"
        }
        return (token: token, activityName: activityName)
    }

    static func createPseudoActivity(fromTransactionRow transactionRow: TransactionRow, tokensDataStore: TokensDataStore, wallet: AlphaWallet.Address) -> Activity? {
        guard let (token, activityName) = extractTokenAndActivityName(fromTransactionRow: transactionRow, tokensDataStore: tokensDataStore, wallet: wallet) else { return nil }

        var cardAttributes = [AttributeId: AssetInternalValue]()
        cardAttributes.setSymbol(string: transactionRow.server.symbol)

        if let operation = transactionRow.operation, operation.symbol != nil, let value = BigUInt(operation.value) {
            cardAttributes.setAmount(uint: value)
        } else {
            if let value = BigUInt(transactionRow.value) {
                cardAttributes.setAmount(uint: value)
            }
        }

        if let value = AlphaWallet.Address(string: transactionRow.from) {
            cardAttributes.setFrom(address: value)
        }

        if let toString = transactionRow.operation?.to, let to = AlphaWallet.Address(string: toString) {
            cardAttributes.setTo(address: to)
        } else {
            if let value = AlphaWallet.Address(string: transactionRow.to) {
                cardAttributes.setTo(address: value)
            }
        }

        var timestamp: GeneralisedTime = .init()
        timestamp.date = transactionRow.date
        cardAttributes.setTimestamp(generalisedTime: timestamp)
        let state: Activity.State
        switch transactionRow.state {
        case .pending:
            state = .pending
        case .completed:
            state = .completed
        case .error, .failed:
            state = .failed
        //TODO we don't need the other states at the moment
        case .unknown:
            state = .completed
        }
        let rowType: ActivityRowType
        switch transactionRow {
        case .standalone:
            rowType = .standalone
        case .group:
            rowType = .group
        case .item:
            rowType = .item
        }
        return .init(
                //We only use this ID for refreshing the display of specific activity, since the display for ETH send/receives don't ever need to be refreshed, just need a number that don't clash with other activities
                id: transactionRow.blockNumber + 10000000,
                rowType: rowType,
                tokenObject: Activity.AssignedToken(tokenObject: token),
                server: transactionRow.server,
                name: activityName,
                eventName: activityName,
                blockNumber: transactionRow.blockNumber,
                transactionId: transactionRow.id,
                transactionIndex: transactionRow.transactionIndex,
                //We don't use this for transactions, so it's ok
                logIndex: 0,
                date: transactionRow.date,
                values: (token: .init(), card: cardAttributes),
                view: (html: "", style: ""),
                itemView: (html: "", style: ""),
                isBaseCard: true,
                state: state
        )
    }
}

