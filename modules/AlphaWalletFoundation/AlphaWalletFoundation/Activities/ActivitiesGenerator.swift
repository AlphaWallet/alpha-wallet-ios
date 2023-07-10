//
//  ActivitiesGenerator.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.03.2023.
//

import Foundation
import CoreFoundation
import Combine
import AlphaWalletCore
import AlphaWalletTokenScript
import CombineExt

class ActivitiesGenerator {
    private let sessionsProvider: SessionsProvider
    private let transactionsFilterStrategy: TransactionsFilterStrategy
    private let tokensService: TokensService
    private let activitiesFilterStrategy: ActivitiesFilterStrategy
    private let eventsActivityDataStore: EventsActivityDataStoreProtocol

    var tokensAndTokenHolders: AtomicDictionary<AddressAndRPCServer, [TokenHolder]> = .init()

    init(sessionsProvider: SessionsProvider,
         transactionsFilterStrategy: TransactionsFilterStrategy,
         activitiesFilterStrategy: ActivitiesFilterStrategy,
         tokensService: TokensService,
         eventsActivityDataStore: EventsActivityDataStoreProtocol) {

        self.eventsActivityDataStore = eventsActivityDataStore
        self.tokensService = tokensService
        self.sessionsProvider = sessionsProvider
        self.transactionsFilterStrategy = transactionsFilterStrategy
        self.activitiesFilterStrategy = activitiesFilterStrategy
    }

    func generateActivities() -> AnyPublisher<[ActivityTokenObjectTokenHolder], Never> {
        let tokens = sessionsProvider.sessions
            .receive(on: DispatchQueue.main)
            .map { self.getTokensForActivities(servers: Array($0.keys)) }

        let eventsForActivities = sessionsProvider.sessions
            .receive(on: DispatchQueue.main)
            .map { Array($0.keys) }
            .flatMapLatest { [eventsActivityDataStore] in eventsActivityDataStore.recentEventsChangeset(servers: $0) }

        return Publishers.CombineLatest(tokens, eventsForActivities)
            .map { self.getTokensAndXmlHandlers(tokens: $0.0) }
            .map { self.getContractsAndCards(contractServerXmlHandlers: $0) }
            .map { self.getActivitiesAndTokens(contractsAndCards: $0) }
            .eraseToAnyPublisher()
    }

    private func getTokensForActivities(servers: [RPCServer]) -> [Token] {
        switch transactionsFilterStrategy {
        case .all:
            return tokensService.tokens(for: servers)
        case .filter(_, let token):
            precondition(servers.contains(token.server), "fatal error, no session for server: \(token.server)")
            return [token]
        case .predicate:
            //NOTE: not supported here
            return []
        }
    }

    private func getTokensAndXmlHandlers(tokens: [Token]) -> TokenObjectsAndXMLHandlers {
        return tokens.compactMap { token -> (contract: AlphaWallet.Address, server: RPCServer, xmlHandler: XMLHandler)? in
            guard let session = sessionsProvider.session(for: token.server) else { return nil }

            let xmlHandler = session.tokenAdaptor.xmlHandler(token: token)
            guard xmlHandler.hasAssetDefinition else { return nil }
            guard xmlHandler.server?.matches(server: token.server) ?? false else { return nil }

            return (contract: token.contractAddress, server: token.server, xmlHandler: xmlHandler)
        }
    }

    private func getContractsAndCards(contractServerXmlHandlers: TokenObjectsAndXMLHandlers) -> ContractsAndCards {
        let contractsAndCardsOptional: [ContractsAndCards] = contractServerXmlHandlers.compactMap { contract, _, xmlHandler in
            var contractAndCard: ContractsAndCards = .init()
            for card in xmlHandler.activityCards {
                let (filterName, filterValue) = card.eventOrigin.eventFilter
                let interpolatedFilter: String
                if let implicitAttribute = EventSource.functional.convertToImplicitAttribute(string: filterValue) {
                    switch implicitAttribute {
                    case .tokenId:
                        continue
                    case .ownerAddress:
                        let wallet = sessionsProvider.activeSessions.anyValue.account
                        interpolatedFilter = "\(filterName)=\(wallet.address.eip55String)"
                    case .label, .contractAddress, .symbol:
                        //TODO support more?
                        continue
                    }
                } else {
                    //TODO support things like "$prefix-{tokenId}"
                    continue
                }

                guard let server = xmlHandler.server else { continue }
                switch server {
                case .any:
                    for server in sessionsProvider.activeSessions.keys {
                        contractAndCard.append((contract: contract, server: server, card: card, interpolatedFilter: interpolatedFilter))
                    }
                case .server(let server):
                    contractAndCard.append((contract: contract, server: server, card: card, interpolatedFilter: interpolatedFilter))
                }
            }
            return contractAndCard
        }
        return contractsAndCardsOptional.flatMap { $0 }
    }

    private func getActivitiesAndTokens(contractsAndCards: ContractsAndCards) -> [ActivityTokenObjectTokenHolder] {
        var activitiesAndTokens: [ActivityTokenObjectTokenHolder] = .init()
        //NOTE: here is a lot of calculations, `contractsAndCards` could reach up of 1000 items, as well as recentEvents could reach 1000.Simply it call inner function 1 000 000 times
        for (contract, server, card, interpolatedFilter) in contractsAndCards {
            let activities = getActivities(contract: contract, server: server, card: card, interpolatedFilter: interpolatedFilter)
            //NOTE: filter activities to avoid: `Fatal error: Duplicate values for key: '<id>'`
            let filteredActivities = activities.filter { data in !activitiesAndTokens.contains(where: { $0.activity.id == data.activity.id }) }
            activitiesAndTokens.append(contentsOf: filteredActivities)
        }

        return Self.filter(activities: activitiesAndTokens, strategy: activitiesFilterStrategy)
    }

    private static func filter(activities: [ActivityTokenObjectTokenHolder],
                               strategy: ActivitiesFilterStrategy) -> [ActivityTokenObjectTokenHolder] {

        switch strategy {
        case .none:
            return activities
        case .contract(let contract), .operationTypes(_, let contract):
            return activities.filter { $0.tokenObject.contractAddress == contract }
        case .nativeCryptocurrency(let primaryKey):
            return activities.filter { $0.tokenObject.primaryKey == primaryKey }
        }
    }

    private func getActivities(contract: AlphaWallet.Address,
                               server: RPCServer,
                               card: TokenScriptCard,
                               interpolatedFilter: String) -> [ActivityTokenObjectTokenHolder] {

        //NOTE: eventsActivityDataStore. getRecentEvents() returns only 100 events, that could cause error with creating activities (missing events)
        //replace with fetching only filtered event instances,
        let events = eventsActivityDataStore.getRecentEventsSortedByBlockNumber(for: card.eventOrigin.contract, server: server, eventName: card.eventOrigin.eventName, interpolatedFilter: interpolatedFilter)

        let activitiesForThisCard: [ActivityTokenObjectTokenHolder] = events.compactMap { eachEvent -> ActivityTokenObjectTokenHolder? in
            guard let token = tokensService.token(for: contract, server: server) else { return nil }
            guard let session = sessionsProvider.session(for: token.server) else { return nil }

            let implicitAttributes = generateImplicitAttributesForToken(contract: contract, server: server, symbol: token.symbol)
            let tokenAttributes = implicitAttributes
            var cardAttributes = ActivitiesService.functional
                .generateImplicitAttributesForCard(forContract: contract, server: server, event: eachEvent)

            cardAttributes.merge(eachEvent.data) { _, new in new }

            for parameter in card.eventOrigin.parameters {
                guard let originalValue = cardAttributes[parameter.name] else { continue }
                guard let type = SolidityType(rawValue: parameter.type) else { continue }
                let translatedValue = type.coerce(value: originalValue)
                cardAttributes[parameter.name] = translatedValue
            }

            let tokenHolders: [TokenHolder]

            if let h = tokensAndTokenHolders[token.addressAndRPCServer] {
                tokenHolders = h
            } else {
                if token.contractAddress == Constants.nativeCryptoAddressInDatabase {
                    let tokenScriptToken = TokenScript.Token(
                        tokenIdOrEvent: .tokenId(tokenId: .init(1)),
                        tokenType: .nativeCryptocurrency,
                        index: 0,
                        name: "",
                        symbol: "",
                        status: .available,
                        values: .init())

                    tokenHolders = [TokenHolder(tokens: [tokenScriptToken], contractAddress: token.contractAddress, hasAssetDefinition: true)]
                } else {
                    tokenHolders = session.tokenAdaptor.getTokenHolders(token: token)
                }
                tokensAndTokenHolders[token.addressAndRPCServer] = tokenHolders
            }
            //NOTE: using `tokenHolders[0]` i received crash with out of range exception
            guard let tokenHolder = tokenHolders.first else { return nil }
            //TODO fix for activities: special fix to filter out the event we don't want - need to doc this and have to handle with TokenScript design
            let isNativeCryptoAddress = token.contractAddress == Constants.nativeCryptoAddressInDatabase
            if card.name == "aETHMinted" && isNativeCryptoAddress && cardAttributes["amount"]?.uintValue == 0 {
                return nil
            } else {
                //no-op
            }

            let activity = Activity(id: Int.random(in: 0..<Int.max), rowType: .standalone, token: token, server: eachEvent.server, name: card.name, eventName: eachEvent.eventName, blockNumber: eachEvent.blockNumber, transactionId: eachEvent.transactionId, transactionIndex: eachEvent.transactionIndex, logIndex: eachEvent.logIndex, date: eachEvent.date, values: (token: tokenAttributes, card: cardAttributes), view: card.view, itemView: card.itemView, isBaseCard: card.isBase, state: .completed)

            return (activity: activity, tokenObject: token, tokenHolder: tokenHolder)
        }

        return activitiesForThisCard
    }

    private func generateImplicitAttributesForToken(contract: AlphaWallet.Address, server: RPCServer, symbol: String) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        for each in AssetImplicitAttributes.allCases {
            //TODO ERC721s aren't fungible, but doesn't matter here
            guard each.shouldInclude(forAddress: contract, isFungible: true) else { continue }
            switch each {
            case .ownerAddress:
                guard let session = sessionsProvider.session(for: server) else { continue }
                results[each.javaScriptName] = .address(session.account.address)
            case .tokenId:
                //We aren't going to add `tokenId` as an implicit attribute even for ERC721s, because we don't know it
                break
            case .label:
                break
            case .symbol:
                results[each.javaScriptName] = .string(symbol)
            case .contractAddress:
                results[each.javaScriptName] = .address(contract)
            }
        }
        return results
    }
}
