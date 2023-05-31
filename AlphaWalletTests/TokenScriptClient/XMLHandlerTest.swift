//
//  XMLHandlerTest.swift
//  AlphaWalletTests
//
//  Created by James Sangalli on 11/4/18.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import BigInt
import Foundation
import XCTest
// swiftlint:disable type_body_length
class XMLHandlerTest: XCTestCase {
    let tokenHex = "0x00000000000000000000000000000000fefe5ae99a3000000000000000010001".substring(from: 2)

    func testParser() {
        let assetDefinitionStore = AssetDefinitionStore.make()
        let token = XMLHandler(contract: Constants.nullAddress, tokenType: .erc20, assetDefinitionStore: assetDefinitionStore).getToken(
            name: "",
            symbol: "",
            fromTokenIdOrEvent: .tokenId(tokenId: BigUInt(tokenHex, radix: 16)!),
            index: UInt16(1),
            inWallet: .make(),
            server: .main,
            tokenType: TokenType.erc875,
            assetDefinitionStore: assetDefinitionStore
        )
        XCTAssertNotNil(token)
    }

    //TODO fix test
//    func testHasAssetDefinition() {
//        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
//        let address1 = AlphaWallet.Address.ethereumAddress(eip55String: "0x0000000000000000000000000000000000000001")
//        let address2 = AlphaWallet.Address.ethereumAddress(eip55String: "0x0000000000000000000000000000000000000002")
//        store[address1] = ""
//        XCTAssertTrue(XMLHandler(contract: address1.eip55String, assetDefinitionStore: store).hasAssetDefinition)
//        XCTAssertFalse(XMLHandler(contract: address2.eip55String, assetDefinitionStore: store).hasAssetDefinition)
//    }

    // swiftlint:disable function_body_length
    func testExtractingAttributesWithNamespaceInXML() {
        // swiftlint:disable line_length
        let xml = """
                <ts:token xmlns:ethereum="urn:ethereum:constantinople" xmlns:ts="http://tokenscript.org/2020/06/tokenscript" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" custodian="false" xsi:schemaLocation="http://tokenscript.org/2020/06/tokenscript http://tokenscript.org/2020/06/tokenscript.xsd">
                    <ts:label>
                        <ts:plurals xml:lang="en">
                            <ts:string quantity="one">Ticket</ts:string>
                            <ts:string quantity="other">Tickets</ts:string>
                        </ts:plurals>
                        <ts:plurals xml:lang="es">
                            <ts:string quantity="one">Boleto de admisión</ts:string>
                            <ts:string quantity="other">Boleto de admisiónes</ts:string>
                        </ts:plurals>
                        <ts:plurals xml:lang="zh">
                            <ts:string quantity="one">入場券</ts:string>
                            <ts:string quantity="other">入場券</ts:string>
                        </ts:plurals>
                    </ts:label>

                    <ts:contract interface="erc875" name="FIFA">
                        <ts:address network="1">0xA66A3F08068174e8F005112A8b2c7A507a822335</ts:address>
                    </ts:contract>

                    <ts:origins>
                        <!-- Define the contract which holds the token that the user will use -->
                        <ts:ethereum contract="FIFA"></ts:ethereum>
                    </ts:origins>

                    <ts:cards>
                        <ts:card type="token">
                            <ts:item-view xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
                                <xhtml:style type="text/css">.tbml-count {
                  font-family: "SourceSansPro";
                  font-weight: bolder;
                  font-size: x-large;
                  color: white;
                }
                .tbml-country{
                  font-family: "SourceSansPro";
                  font-weight: bolder;
                  font-size: x-large;
                  color: white;
                }
                .tbml-date {
                  font-family: "SourceSansPro";
                  font-size: small;
                  color: white;
                }
                .tbml-time {
                  font-family: "SourceSansPro";
                  font-size: small;
                  color: white;
                }
                .tbml-venue {
                  font-family: "SourceSansPro";
                  font-size: small;
                  color: white;
                }
                .tbml-category {
                  font-family: "SourceSansPro";
                  font-size: small;
                  color: white;
                }

                .country_container{
                  padding-bottom: 1.6em;
                }
                .datetime_container{
                  padding-bottom: 0.5em;
                }
                .venue_container{
                  padding-bottom: 0.5em;
                }
                .category_container{
                  padding-bottom: 0.5em;
                }

                html {
                }
                body {
                  padding: 0px;
                  margin: 0px;
                }
                div {
                  margin: 0px;
                  padding: 0px;
                }
                .data-icon {
                  height:16px;
                  vertical-align: middle
                }

                .ticket{
                  background-image: url(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB2aWV3Qm94PSIwIDAgMzQ0IDE5MCI+PGRlZnM+PHN0eWxlPi5he2ZpbGw6bm9uZTt9LmIsLmd7ZmlsbC1ydWxlOmV2ZW5vZGQ7fS5ie2ZpbGw6dXJsKCNhKTt9LmN7ZmlsbDojZTBjMzhhO30uZHtmaWxsOiMyMzFmMjA7fS5le2ZpbGw6IzAwNmNhMzt9LmZ7ZmlsbDojZDAxYTIxO30uZywuaHtmaWxsOiNmZmY7fS5pe2NsaXAtcGF0aDp1cmwoI2IpO30uantjbGlwLXBhdGg6dXJsKCNjKTt9Lmt7Y2xpcC1wYXRoOnVybCgjZCk7fS5se2NsaXAtcGF0aDp1cmwoI2UpO30ubXtjbGlwLXBhdGg6dXJsKCNmKTt9Lm57Y2xpcC1wYXRoOnVybCgjZyk7fS5ve2NsaXAtcGF0aDp1cmwoI2kpO30ucHtjbGlwLXBhdGg6dXJsKCNrKTt9LnF7Y2xpcC1wYXRoOnVybCgjbSk7fS5ye2NsaXAtcGF0aDp1cmwoI28pO30uc3tjbGlwLXBhdGg6dXJsKCNxKTt9LnR7Y2xpcC1wYXRoOnVybCgjcyk7fS51e2NsaXAtcGF0aDp1cmwoI3UpO30udntjbGlwLXBhdGg6dXJsKCN3KTt9Lnd7Y2xpcC1wYXRoOnVybCgjeSk7fS54e2NsaXAtcGF0aDp1cmwoI2FhKTt9Lnl7Y2xpcC1wYXRoOnVybCgjYWMpO30uentjbGlwLXBhdGg6dXJsKCNhZSk7fS5hYXtjbGlwLXBhdGg6dXJsKCNhZyk7fS5hYntjbGlwLXBhdGg6dXJsKCNhaSk7fS5hY3tjbGlwLXBhdGg6dXJsKCNhayk7fS5hZHtjbGlwLXBhdGg6dXJsKCNhbSk7fS5hZXtjbGlwLXBhdGg6dXJsKCNhbyk7fS5hZntjbGlwLXBhdGg6dXJsKCNhcSk7fS5hZ3tjbGlwLXBhdGg6dXJsKCNhcyk7fS5haHtjbGlwLXBhdGg6dXJsKCNhdSk7fS5haXtjbGlwLXBhdGg6dXJsKCNhdyk7fS5hantjbGlwLXBhdGg6dXJsKCNheSk7fS5ha3tjbGlwLXBhdGg6dXJsKCNiYSk7fS5hbHtjbGlwLXBhdGg6dXJsKCNiYyk7fS5hbXtjbGlwLXBhdGg6dXJsKCNiZSk7fS5hbntjbGlwLXBhdGg6dXJsKCNiZyk7fS5hb3tjbGlwLXBhdGg6dXJsKCNiaSk7fS5hcHtjbGlwLXBhdGg6dXJsKCNiayk7fS5hcXtjbGlwLXBhdGg6dXJsKCNibSk7fS5hcntjbGlwLXBhdGg6dXJsKCNibyk7fS5hc3tjbGlwLXBhdGg6dXJsKCNicSk7fS5hdHtjbGlwLXBhdGg6dXJsKCNicyk7fS5hdXtjbGlwLXBhdGg6dXJsKCNidSk7fS5hdntjbGlwLXBhdGg6dXJsKCNidyk7fS5hd3tjbGlwLXBhdGg6dXJsKCNieSk7fS5heHtjbGlwLXBhdGg6dXJsKCNjYSk7fS5heXtjbGlwLXBhdGg6dXJsKCNjYyk7fS5hentjbGlwLXBhdGg6dXJsKCNjZSk7fS5iYXtjbGlwLXBhdGg6dXJsKCNjZyk7fS5iYntjbGlwLXBhdGg6dXJsKCNjaSk7fS5iY3tjbGlwLXBhdGg6dXJsKCNjayk7fS5iZHtjbGlwLXBhdGg6dXJsKCNjbSk7fS5iZXtjbGlwLXBhdGg6dXJsKCNjbyk7fS5iZntjbGlwLXBhdGg6dXJsKCNjcSk7fS5iZ3tjbGlwLXBhdGg6dXJsKCNjcyk7fS5iaHtjbGlwLXBhdGg6dXJsKCNjdSk7fS5iaXtjbGlwLXBhdGg6dXJsKCNjdyk7fS5iantjbGlwLXBhdGg6dXJsKCNjeSk7fS5ia3tjbGlwLXBhdGg6dXJsKCNkYSk7fS5ibHtjbGlwLXBhdGg6dXJsKCNkYyk7fTwvc3R5bGU+PGxpbmVhckdyYWRpZW50IGlkPSJhIiB4MT0iNDkuOTciIHkxPSItMzAuMDMiIHgyPSIyODcuNDIiIHkyPSIyMDcuNDIiIGdyYWRpZW50VHJhbnNmb3JtPSJtYXRyaXgoMSwgMCwgMCwgLTEsIDAsIDE4NCkiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj48c3RvcCBvZmZzZXQ9IjAiIHN0b3AtY29sb3I9IiMwMDJjNmQiLz48c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiMwMDY4YjIiLz48L2xpbmVhckdyYWRpZW50PjxjbGlwUGF0aCBpZD0iYiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PHBhdGggY2xhc3M9ImEiIGQ9Ik01NS42LDU1LjkxYS43LjcsMCwwLDEsLjctLjcxLjY4LjY4LDAsMCwxLC43LjcuNjcuNjcsMCwwLDEtLjY5LjcuODUuODUsMCwwLDEtLjcxLS42OSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48cGF0aCBjbGFzcz0iYSIgZD0iTTcwLjMyLDQ4LjQ3YS41Ni41NiwwLDAsMSwuMjEtLjU0LjUzLjUzLDAsMCwxLC41NC4yLjU0LjU0LDAsMCwxLS4yLjU1LjM1LjM1LDAsMCwxLS41NS0uMjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iZCIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PHBhdGggY2xhc3M9ImEiIGQ9Ik03MS4wOSw1MS41MmMtLjEsMCwwLS4yMi4xNC0uNDhhLjY3LjY3LDAsMCwxLS4yNS0uNTkuODEuODEsMCwwLDEsLjg2LS43OWwuMjkuMDhhMS4zNSwxLjM1LDAsMCwxLC4yNy0uMjNjLjEsMCwwLC4yMi0uMTEuMzlhLjY1LjY1LDAsMCwxLC4yNC41OS43OS43OSwwLDAsMS0uODUuNzlsLS4yOS0uMDhjLS4wOC4yOC0uMjEuMzUtLjMuMzIiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iZSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMyIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJmIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48cmVjdCBjbGFzcz0iYSIgeD0iMTI4LjMiIHk9Ii0yIiB3aWR0aD0iMiIgaGVpZ2h0PSIxODQiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iZyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNi41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImkiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjEwIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImsiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjEzLjUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0ibSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTciIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0ibyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMjAuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJxIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIyNCIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJzIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIyNy41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9InUiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjMxIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9InciIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjM0LjUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0ieSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMzgiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYWEiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjQ1IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImFjIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI0MS41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImFlIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI0OCIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJhZyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNTEuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJhaSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNTUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYWsiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjU4LjUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYW0iIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjYyIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImFvIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI2NS41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImFxIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI2OSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJhcyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNzIuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJhdSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNzYiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYXciIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9Ijc5LjUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYXkiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjgzIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJhIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI5MCIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJiYyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iODYuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJiZSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTM5IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJnIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNDIuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJiaSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTQ2IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJrIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNDkuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJibSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTUzIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJvIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNTYuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJicSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTYwIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJzIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNjMuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJidSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTY3IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJ3IiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNzAuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJieSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTc0IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNhIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxODEiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iY2MiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjE3Ny41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNlIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI5NCIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjZyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iOTcuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjaSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTAxIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNrIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMDQuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjbSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTA4IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNvIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMTEuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjcSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTE1IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNzIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMTguNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjdSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTIyIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImN3IiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMjUuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjeSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTI5IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImRhIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMzYiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iZGMiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjEzMi41IiByPSIxIi8+PC9jbGlwUGF0aD48L2RlZnM+PHRpdGxlPmJhY2tncm91bmRfcmVkZWVtZWRfZW1wdHk8L3RpdGxlPjxwYXRoIGNsYXNzPSJiIiBkPSJNMzI5LjEsOTAuM0E5LjE1LDkuMTUsMCwwLDAsMzI5LDkyYTE1LDE1LDAsMCwwLDE1LDE1djYxYTE2LDE2LDAsMCwxLTE2LDE2SDE2YTE1LjY2LDE1LjY2LDAsMCwxLTExLjUtNUExNS41OSwxNS41OSwwLDAsMSwwLDE2OFYxMDdhMTUsMTUsMCwwLDAsMTEuOC01LjcsMTUsMTUsMCwwLDAsMy4xLTcuNkE5LjcsOS43LDAsMCwwLDE1LDkyLDE1LDE1LDAsMCwwLDAsNzdWMTZBMTYsMTYsMCwwLDEsMTYsMEgzMjhhMTYsMTYsMCwwLDEsOC44LDIuNywxNy43LDE3LjcsMCwwLDEsNC4yLDQsMTUuNDIsMTUuNDIsMCwwLDEsMyw5LjNWNzdhMTUsMTUsMCwwLDAtMTEuNyw1LjZBMTQuNjUsMTQuNjUsMCwwLDAsMzI5LjEsOTAuM1oiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iYyIgZD0iTTg0LjQsNjQuM2ExNC4yNCwxNC4yNCwwLDAsMS0uNSwxLjZjLS4xLjItLjEuNC0uMi41YTUuMzYsNS4zNiwwLDAsMS0uNSwxLjEsMywzLDAsMCwxLS40LjhjLS40LjktLjgsMS43LTEuMiwyLjVoMGMtMy42LDcuMS03LjEsMTUtNy40LDE3LjgsNS40LDkuNiw2LjIsMTYuOSw1LjgsMTkuOC0uNiw0LTUuNiw1LjgtMTEuOCw1LjhoLS4zYy01LjgsMC0xMi0yLTExLjktNS45cy45LTUuNiwyLjMtMTIuNWMuMi0xLC40LTUuOC42LTguNkg1OGMtLjgsMC0xLjUtLjEtMi0uMSwyLTEuNiwyLjgtMy41LDIuNy01YTUuOTMsNS45MywwLDAsMS0zLjEuNyw4LjYsOC42LDAsMCwxLTEuNi0uMWMyLjYtMy40LDEuOS02LjYuNS05LjktLjctMS43LTEuNi0zLjMtMi4zLTVBMjEuOSwyMS45LDAsMCwxLDUxLDY0LjVhMTguNjgsMTguNjgsMCwwLDEsLjktMTIuM0ExNy4yNCwxNy4yNCwwLDAsMSw2Ny43LDQyYTIwLjA3LDIwLjA3LDAsMCwxLDQuMi41LDIuOTIsMi45MiwwLDAsMCwuOS4yYy4yLDAsLjMuMS41LjFsLjkuM2EzLjU1LDMuNTUsMCwwLDEsLjkuNGMuMy4yLjcuMywxLC41cy43LjQsMSwuNi42LjQsMSwuN2ExMy40NCwxMy40NCwwLDAsMSwxLjQsMS4xLDE4LjQ2LDE4LjQ2LDAsMCwxLDMuMSwzLjdBMTgsMTgsMCwwLDEsODQuNCw2NC4zWiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJkIiBkPSJNODAsNzFhNDMuODcsNDMuODcsMCwwLDEtNiw4LjhjLS44LjktMS40LjMtMS4zLS4yLjItMS4zLjItMy4xLTEuNi0yLjgtLjguMS0xLjcsMS4zLS43LDMuMy4xLjIuMS43LS42LjMtNC0xLjctNi4xLTUuNy00LjgtMTAuNWExMS41NiwxMS41NiwwLDAsMSw1LjctNi41YzQuMi0yLjMsOC43LTEuOCwxMC4yLjhDODEuNyw2NS42LDgxLjcsNjcuOSw4MCw3MVoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZCIgZD0iTTc2LjMsNjkuMWExLjMyLDEuMzIsMCwwLDEtLjUtMS41di0uMWgtLjFhMS4yNCwxLjI0LDAsMCwxLTEuNS41aC0uMXYuMWExLjMyLDEuMzIsMCwwLDEsLjUsMS41di4xaC4xYTEuNTgsMS41OCwwLDAsMSwxLjYtLjZabS0xLjctMi43YS4zLjMsMCwxLDAtLjMuM0EuMzIuMzIsMCwwLDAsNzQuNiw2Ni40Wm0tMi40LDMuMmEuOC44LDAsMSwwLC44LjhBLjg2Ljg2LDAsMCwwLDcyLjIsNjkuNlptLjEtMS40aDBhMS4xOSwxLjE5LDAsMCwxLS4zLTEuMWgwYTEsMSwwLDAsMS0xLC40aDBhMSwxLDAsMCwxLC4zLDEuMWgwQTEsMSwwLDAsMSw3Mi4zLDY4LjJabTMuNS0yMi44Yy00LjQtMi41LTkuMi0yLjQtMTAuOC40cy43LDcsNS4xLDkuNiw5LjIsMi40LDEwLjgtLjRTODAuMiw0OCw3NS44LDQ1LjRaTTU3LjEsNTAuMWMtMy4xLDAtNS43LDQuMS01LjcsOS4xczIuNSw5LjEsNS43LDkuMSw1LjctNC4xLDUuNy05LjFTNjAuMyw1MC4xLDU3LjEsNTAuMVoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48ZWxsaXBzZSBjbGFzcz0iZSIgY3g9IjczLjM1IiBjeT0iNDkuNjMiIHJ4PSIzLjgiIHJ5PSI2LjYiIHRyYW5zZm9ybT0idHJhbnNsYXRlKC02LjMxIDkxLjMzKSByb3RhdGUoLTYwKSIvPjxlbGxpcHNlIGNsYXNzPSJlIiBjeD0iNzMuNjkiIGN5PSI2OC45MSIgcng9IjcuMSIgcnk9IjQuMSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTIzLjExIDQzLjQ3KSByb3RhdGUoLTI2LjcxKSIvPjxlbGxpcHNlIGNsYXNzPSJlIiBjeD0iNTYuMyIgY3k9IjU4LjkiIHJ4PSIzLjkiIHJ5PSI2LjgiIHRyYW5zZm9ybT0idHJhbnNsYXRlKC0zLjQ2IDYuNTEpIHJvdGF0ZSgtMy40NikiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTU3LjcsMTA1LjhjNC4xLTEsNy45LTEuNCwxMi40LTksMS4yLTEuOS0uOCwxMS4yLTEwLjgsMTEuMkExLjU0LDEuNTQsMCwwLDEsNTcuNywxMDUuOFoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTcxLjIsOTcuMWMxLjUsOC4yLjgsMTQuMS01LDE0LjctNi4xLjYtOC40LTIuMS04LjQtMi4xLDUuMS40LDgtMS4zLDkuNi0zczQtNy41LDMuOC05LjYiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTYwLjEsOTQuM2MuMSwxLjYuNyw0LjkuMyw2LjRhNi4xOCw2LjE4LDAsMCwxLTIuMywzLjVaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImYiIGQ9Ik02Mi4yLDg2LjRjLTEsMi44LTEuOSwxMS40LjcsMTEuNywxLjQuMi0uMi0xLjYuNy0yLjJzMi4zLS44LDIuNC42LTEuNywyLjEtLjgsMi4zYTMuMDksMy4wOSwwLDAsMCwzLjEtMS41LDIxLjU3LDIxLjU3LDAsMCwwLDEuNS0zLjVzLTIuNC01LjYtNS43LTguOFoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTU1LjIsNDkuMmMyLjItMy40LDYuMi00LjYsMTAuNS01LjgsMCwwLTQuNCwxLjYtMyw3LjQsMCwwLTMuMy0zLjktNy41LTEuNiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJmIiBkPSJNODIuOCw1My44YzEuOSwzLjUsMSw3LjYsMCwxMiwwLDAsLjctNC42LTUtNi4yLDAsMCw1LTEsNS01LjgiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTczLjgsNTkuNWExMS4xMywxMS4xMywwLDAsMC04LjcsNC44LDE2LjQxLDE2LjQxLDAsMCwwLS40LTkuOSwyMS43LDIxLjcsMCwwLDAsOS4xLDUuMSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJmIiBkPSJNNTQuNyw2OS44YzQuOCwxLjMsNC4xLDEuMyw4LjEtMS4zLS40LDEuOS0xLjUsNS44LDMuMiwxMi4yLDEwLjMsOC4yLDEyLjQsMjQuNiwxMi40LDI0LjYuNCw2LjgtNS41LDcuNS0xMC4yLDcuMyw2LjQtMi42LDUtNy43LDUtMTAuNi0uMy0xMC4xLTcuOC0xNy45LTcuOC0xNy45bC0xLjItMS43Yy0xLjMsMy40LTUuMSwzLjQtNS4xLDMuNCwyLjYtMi44LDEuMy03LjQsMS4zLTcuNC0uMywzLTQuMiwzLjMtNC4yLDMuMywzLTMuNS0uNS0xMC43LS41LTEwLjdaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PGNpcmNsZSBjbGFzcz0iZiIgY3g9IjYzLjIiIGN5PSI1NS4xIiByPSIwLjYiLz48Y2lyY2xlIGNsYXNzPSJmIiBjeD0iNzYuNiIgY3k9IjYyLjYiIHI9IjAuNiIvPjxjaXJjbGUgY2xhc3M9ImYiIGN4PSI2My41IiBjeT0iNzAiIHI9IjAuNiIvPjxjaXJjbGUgY2xhc3M9ImYiIGN4PSI2NC4zIiBjeT0iNjguNSIgcj0iMC40Ii8+PGNpcmNsZSBjbGFzcz0iZiIgY3g9Ijc1LjEiIGN5PSI2Mi41IiByPSIwLjQiLz48Y2lyY2xlIGNsYXNzPSJmIiBjeD0iNjQiIGN5PSI1Ni40IiByPSIwLjQiLz48cGF0aCBjbGFzcz0iYyIgZD0iTTY0LjQsOTIuNGgtLjFsLS4xLS4xLjEtLjFhMi4xOSwyLjE5LDAsMCwwLDEuNC0uOCwxLjg1LDEuODUsMCwwLDAsLjcuMmMuMSwwLC4yLjEuMy4xYTQuMTMsNC4xMywwLDAsMCwxLjEuN3YuMWwtLjEuMWMtLjIsMC0uMy4xLS40LjFsLS42LjNoMGExLjksMS45LDAsMCwwLS43LDEuMWwtLjEuMWgwVjk0YTIuNDcsMi40NywwLDAsMC0uNC0uOSw1LjU1LDUuNTUsMCwwLDAtLjgtLjZDNjQuNSw5Mi41LDY0LjQsOTIuNSw2NC40LDkyLjRaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImciIGQ9Ik01OC4yLDU5LjFhLjQ1LjQ1LDAsMCwxLDAtLjUuMjguMjgsMCwxLDEsLjQuNC4yNS4yNSwwLDAsMS0uNC4xWiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJnIiBkPSJNNTUuMyw1OC41YS4zLjMsMCwxLDEsLjMtLjNjLjEuMi0uMS4zLS4zLjNaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImgiIGQ9Ik01NS42LDU1LjlhLjcuNywwLDEsMSwuNy43Ljg0Ljg0LDAsMCwxLS43LS43IiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PGcgY2xhc3M9ImkiPjxyZWN0IGNsYXNzPSJoIiB4PSI1NS42IiB5PSI1NS4yIiB3aWR0aD0iMS40IiBoZWlnaHQ9IjEuNCIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTAuNTMgMy41NCkgcm90YXRlKC0wLjU0KSIvPjwvZz48cGF0aCBjbGFzcz0iZyIgZD0iTTU3LjgsNjEuNWgwYTEuOTQsMS45NCwwLDAsMC0yLjEuN2gtLjF2LS4xYTEuNzUsMS43NSwwLDAsMC0uNi0yVjYwaC4xYTEuODUsMS44NSwwLDAsMCwyLS43aC4xdi4xYTEuNjYsMS42NiwwLDAsMCwuNiwyLjFaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImciIGQ9Ik03Ni40LDUxLjNoMGExLjUyLDEuNTIsMCwwLDAtMS42LjloLS4xdi0uMWExLjU1LDEuNTUsMCwwLDAtLjgtMS42di0uMUg3NGExLjU0LDEuNTQsMCwwLDAsMS42LS45aC4xdi4xYTEuNDEsMS40MSwwLDAsMCwuNywxLjdaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImgiIGQ9Ik03MC4zLDQ4LjRhLjQxLjQxLDAsMSwxLC41LjMuMzUuMzUsMCwwLDEtLjUtLjMiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48ZyBjbGFzcz0iaiI+PHJlY3QgY2xhc3M9ImgiIHg9IjcwLjIiIHk9IjQ3LjgiIHdpZHRoPSIxIiBoZWlnaHQ9IjEiIHRyYW5zZm9ybT0idHJhbnNsYXRlKC03LjYyIDE2LjY5KSByb3RhdGUoLTEwLjUpIi8+PC9nPjxwYXRoIGNsYXNzPSJoIiBkPSJNNzAuNiw1MC4yYzAtLjEuMi0uMS41LDBhLjY2LjY2LDAsMCwxLC41LS40LjguOCwwLDAsMSwxLC42di4zYTEuMjQsMS4yNCwwLDAsMSwuMy4yYzAsLjEtLjIuMS0uNCwwYS42Ni42NiwwLDAsMS0uNS40LjguOCwwLDAsMS0xLS42di0uM2MtLjMsMC0uNC0uMS0uNC0uMiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxnIGNsYXNzPSJrIj48cmVjdCBjbGFzcz0iaCIgeD0iNzAuNTMiIHk9IjQ5LjIyIiB3aWR0aD0iMi40IiBoZWlnaHQ9IjIuNyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMy4xMyAxMDguMykgcm90YXRlKC03My43NykiLz48L2c+PHBhdGggY2xhc3M9ImciIGQ9Ik03NC42LDY2LjRhLjMuMywwLDEsMS0uMy0uM0EuMjcuMjcsMCwwLDEsNzQuNiw2Ni40WiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJnIiBkPSJNNzMsNzAuNGEuOC44LDAsMSwxLS44LS44QS44Ni44NiwwLDAsMSw3Myw3MC40WiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJnIiBkPSJNNzYuMyw2OS4yaDBhMS41MSwxLjUxLDAsMCwwLTEuNi42aC0uMXYtLjFhMS4yOCwxLjI4LDAsMCwwLS41LTEuNXYtLjFoLjFhMS4yNCwxLjI0LDAsMCwwLDEuNS0uNWguMXYuMWExLjQxLDEuNDEsMCwwLDAsLjUsMS41WiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJnIiBkPSJNNzIuNCw2OC4yaDBhLjkuOSwwLDAsMC0xLjEuNGgwYTEuMTMsMS4xMywwLDAsMC0uMy0xLjFoMGMuNC4xLjksMCwxLS40aDBhMSwxLDAsMCwwLC40LDEuMVoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iaCIgZD0iTTk1LjMsMTMxLjloMGMtMy4xLDAtNC41LDIuMS01LDQuNy0uOCw1LDEuNyw2LjUsNC45LDYuNWgwYzMuMiwwLDUuOC0xLjUsNC45LTYuNS0uNC0yLjYtMS44LTQuNy00LjgtNC43bTAsMTAuMWgwYy0xLjcsMC0zLTEuMi0yLjYtNS4yLjItMi4xLDEtMy43LDIuNi0zLjdoMGMxLjYsMCwyLjMsMS42LDIuNiwzLjdDOTguMywxNDAuNyw5Ni45LDE0Miw5NS4zLDE0MlptMTYuNy00LjhhMi42LDIuNiwwLDAsMCwyLjEtMi41LDIuMjgsMi4yOCwwLDAsMC0xLTEuOSw0LjI0LDQuMjQsMCwwLDAtMi42LS44aC0uMWE0LjI0LDQuMjQsMCwwLDAtMi42LjgsMi4xNywyLjE3LDAsMCwwLTEsMS45LDIuNiwyLjYsMCwwLDAsMi4xLDIuNXMtMywuNC0zLDIuN2MwLDIuNywzLjEsMy4xLDQuNiwzLjFzNC42LS40LDQuNi0zLjFDMTE1LDEzNy42LDExMiwxMzcuMiwxMTIsMTM3LjJabS4xLDQuNWEyLDIsMCwwLDEtMS42LjYsMS44NCwxLjg0LDAsMCwxLTEuNi0uNiwyLjE1LDIuMTUsMCwwLDEtLjQtMS42YzAtLjYuMy0yLjIsMS44LTIuNHYtLjhjLS43LS4xLTEuNC0uNy0xLjQtMiwwLTEuNywxLjEtMiwxLjctMmExLjc2LDEuNzYsMCwwLDEsMS43LDIsMS43OSwxLjc5LDAsMCwxLTEuMywydi45YzEuNC4zLDEuNiwxLjksMS43LDIuNEEzLjM5LDMuMzksMCwwLDEsMTEyLjEsMTQxLjdaTTMwLjUsMTM1YzAtMi42LTIuOS0yLjYtNS0yLjZIMjAuNnYxMC40aDIuMnYtOS42aDIuN2MuNiwwLDIuNCwwLDIuNCwxLjgsMCwxLjQtMy4xLDMuMS00LjYsMy45djEuN2MuNy0uMywxLjctLjgsMi4yLTFsMi43LDMuM2gyLjRsLTMuNS00LjFDMjkuNCwxMzcuNCwzMC41LDEzNi4yLDMwLjUsMTM1Wm0xMC4xLTIuNmgtMnMuMS43LjEsMWE1Niw1NiwwLDAsMSwuNSw2LDIuNjgsMi42OCwwLDAsMS0yLjcsMi44aDBhMi42OCwyLjY4LDAsMCwxLTIuNy0yLjgsNTYsNTYsMCwwLDEsLjUtNmMwLS4yLjEtMSwuMS0xaC0yYTUuNzYsNS43NiwwLDAsMS0uMiwxYzAsLjMtLjgsNC4xLS44LDUuNCwwLDIuNiwxLjksNC4yLDUuMSw0LjJoMGMzLjEsMCw1LTEuNiw1LTQuMmEzNy40MSwzNy40MSwwLDAsMC0uOC01LjRDNDAuNywxMzMuMSw0MC42LDEzMi40LDQwLjYsMTMyLjRabTIyLDEwLjVoMi4yVjEzMi40SDYyLjZabTI1LjYtOS42Yy0xLjctMS44LTYuMS0xLjctNy4yLjVhMi43MiwyLjcyLDAsMCwwLC4xLDIuNmwuOS0uNGEyLjI4LDIuMjgsMCwwLDEsMS43LTMsMi4zLDIuMywwLDAsMSwyLjgsMi44Yy0uOCwyLjEtNC42LDUtNi4yLDYuMXYuN2g5LjF2LTEuM0g4My4yQzg2LjIsMTQwLjIsOTEuNCwxMzYuNiw4OC4yLDEzMy4zWm0xNC42LS41YTQuNDYsNC40NiwwLDAsMS0xLjYuM3YuN2guM2EuODguODgsMCwwLDEsLjkuOHY4LjFoMi4yVjEzMi4zaC0uOUEyLjA2LDIuMDYsMCwwLDEsMTAyLjgsMTMyLjhabS01My40LDQuNWExNi40MiwxNi40MiwwLDAsMC0yLjItMSwxOC4zMiwxOC4zMiwwLDAsMS0xLjctLjcsMi40MSwyLjQxLDAsMCwxLS44LS42LDEuMDgsMS4wOCwwLDAsMS0uMy0uNywxLjA1LDEuMDUsMCwwLDEsLjUtLjksMywzLDAsMCwxLDEuNS0uNCw3LjQ1LDcuNDUsMCwwLDEsMy41LjhsLjYtLjhhNy45LDcuOSwwLDAsMC00LjEtLjksMy41OSwzLjU5LDAsMCwwLTMuMywxLjYsMi43OCwyLjc4LDAsMCwwLDEsMy41LDI2LjY1LDI2LjY1LDAsMCwwLDMuMSwxLjZoLjFhMy42LDMuNiwwLDAsMSwuOS41LDEuMjEsMS4yMSwwLDAsMSwuNS41LDEuMzksMS4zOSwwLDAsMS0uNCwxLjksMi40MSwyLjQxLDAsMCwxLTEuNS40LDE4LjM4LDE4LjM4LDAsMCwxLTQuMS0uN2wtLjUuOWExNi41MywxNi41MywwLDAsMCw0LjguOGMyLjcsMCw0LjEtMS4zLDQuNC0yLjRDNTEuNywxMzkuMyw1MS4xLDEzOC4xLDQ5LjQsMTM3LjNabTkuNywwYTE2LjQyLDE2LjQyLDAsMCwwLTIuMi0xLDE4LjMyLDE4LjMyLDAsMCwxLTEuNy0uNywyLjQxLDIuNDEsMCwwLDEtLjgtLjYsMS4wOCwxLjA4LDAsMCwxLS4zLS43LDEuMDUsMS4wNSwwLDAsMSwuNS0uOSwzLDMsMCwwLDEsMS41LS40LDcuNDUsNy40NSwwLDAsMSwzLjUuOGwuNi0uOGE3LjksNy45LDAsMCwwLTQuMS0uOSwzLjU5LDMuNTksMCwwLDAtMy4zLDEuNiwyLjc4LDIuNzgsMCwwLDAsMSwzLjUsMjAuMTMsMjAuMTMsMCwwLDAsMy4xLDEuNkg1N2EzLjYsMy42LDAsMCwxLC45LjUsMS4yMSwxLjIxLDAsMCwxLC41LjUsMS4zOSwxLjM5LDAsMCwxLS40LDEuOSwyLjQxLDIuNDEsMCwwLDEtMS41LjQsMTguMzgsMTguMzgsMCwwLDEtNC4xLS43bC0uNS45YTE2LjUzLDE2LjUzLDAsMCwwLDQuOC44YzIuNywwLDQuMS0xLjMsNC40LTIuNEEzLDMsMCwwLDAsNTkuMSwxMzcuM1ptMTQuNi00LjlINzEuNmMtLjkuOS03LjMsOC44LTQuNywxMC40LDEuOCwxLjEsNS4xLTEsNi42LTIuMWwtLjYtMWMtMS4xLjktMy4yLDItMy45LDEuMi0xLjEtMSwyLjctNy4zLDIuNy03LjMuNCwxLjMsMi41LDcsMyw4bC42LDEuMWgyLjNsLS42LTEuMkE1Mi4zMyw1Mi4zMywwLDAsMSw3My43LDEzMi40WiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJoIiBkPSJNNTIsMTI0LjFsLTEuNyw0LjdoMS40bC4yLS42aDEuNmwuMi42aDEuNWwtMS43LTQuN0g1Mm0uMiwzLjEuNi0xLjkuNiwxLjlabTEwLjQtMy4xLTEsNC43SDYwbC0uNy0zLjZoMGwtLjYsMy42SDU3LjFsLTEtNC43aDEuM2wuNiwzLjZoMGwuNi0zLjZoMS42bC43LDMuNmgwbC42LTMuNlptLTE3LjUsMGgxLjV2NC43SDQ1LjFabS00LjEsMGgzLjZsLS40LDFINDIuNXYuOWgxLjRsLS40LDFoLTF2MS43SDQxWm05LjUsMS45LS40LDFoLTF2MS43SDQ3LjZWMTI0aDMuNmwtLjQsMUg0OXYuOWgxLjVabTM4LjctMS45aDEuM1YxMjdjMCwxLjMtLjgsMS45LTIuMSwxLjlhMS44NCwxLjg0LDAsMCwxLTIuMS0xLjl2LTIuOWgxLjN2Mi43YzAsLjYuMiwxLjEuOCwxLjFzLjgtLjUuOC0xLjF2LTIuN1ptLTExLjYsMEg3NS45djQuN2gxLjdjMS42LDAsMi44LS42LDIuOC0yLjRTNzkuMywxMjQuMSw3Ny42LDEyNC4xWm0uMSwzLjhoLS41VjEyNWguNWExLjM0LDEuMzQsMCwwLDEsMS41LDEuNFE3OSwxMjcuOSw3Ny43LDEyNy45Wm04LjItLjIuMSwxYTUuMjEsNS4yMSwwLDAsMS0xLjQuMmMtMS4zLDAtMi43LS42LTIuNy0yLjQsMC0xLjYsMS4xLTIuNCwyLjctMi40YTYuNzUsNi43NSwwLDAsMSwxLjQuMmwtLjEsMWEyLjY2LDIuNjYsMCwwLDAtMS4yLS4zLDEuNDIsMS40MiwwLDAsMC0xLjUsMS41LDEuNSwxLjUsMCwwLDAsMS42LDEuNUM4NS4yLDEyNy45LDg1LjYsMTI3LjgsODUuOSwxMjcuN1ptNi42LTMuNkg5MXY0LjdoMS4zdi0xLjZoLjVjMS4yLDAsMS45LS42LDEuOS0xLjVDOTQuNiwxMjQuNiw5My45LDEyNC4xLDkyLjUsMTI0LjFabS4xLDIuMWgtLjNWMTI1aC4zYy40LDAsLjguMi44LjZTOTMsMTI2LjIsOTIuNiwxMjYuMlptLTE5LjIsMS43aDEuOXYuOUg3Mi4xdi00LjdoMS4zWm0tMi44LTEuNGgwYTEuMTgsMS4xOCwwLDAsMCwuOS0xLjJjMC0uOC0uNy0xLjItMS41LTEuMkg2Ny44djQuN0g2OXYtMS45aC4zYy41LDAsLjYuMi45LDFsLjMuOGgxLjNsLS41LTEuM0M3MSwxMjYuOSw3MSwxMjYuNiw3MC42LDEyNi41Wm0tMS4zLS41SDY5di0xaC4zYy41LDAsLjkuMS45LjVTNjkuNywxMjYsNjkuMywxMjZaTTY1LDEyNGEyLjIxLDIuMjEsMCwwLDAtMi40LDIuNCwyLjE2LDIuMTYsMCwwLDAsMi40LDIuNCwyLjIxLDIuMjEsMCwwLDAsMi40LTIuNEEyLjI2LDIuMjYsMCwwLDAsNjUsMTI0Wm0wLDMuOWMtLjgsMC0xLjEtLjctMS4xLTEuNXMuMy0xLjUsMS4xLTEuNSwxLjEuNywxLjEsMS41UzY1LjcsMTI3LjksNjUsMTI3LjlaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PGcgY2xhc3M9ImwiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9Im4iPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjMuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0ibyI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iNyIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0icCI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTAuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0icSI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTQiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9InIiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjE3LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9InMiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjIxIiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJ0Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIyNC41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJ1Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIyOCIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0idiI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMzEuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0idyI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMzUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9IngiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjQyIiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJ5Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIzOC41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJ6Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI0NSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWEiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjQ4LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFiIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI1MiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWMiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjU1LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFkIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI1OSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWUiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjYyLjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFmIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI2NiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWciPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjY5LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFoIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI3MyIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWkiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9Ijc2LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFqIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI4MCIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWsiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9Ijg3IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhbCI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iODMuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYW0iPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjEzNiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYW4iPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjEzOS41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhbyI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTQzIiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhcCI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTQ2LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFxIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNTAiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFyIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNTMuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYXMiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjE1NyIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYXQiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjE2MC41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhdSI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTY0IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhdiI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTY3LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImF3Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNzEiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImF4Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNzgiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImF5Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNzQuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYXoiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjkxIiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJiYSI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iOTQuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYmIiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9Ijk4IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJiYyI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTAxLjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJkIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMDUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJlIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMDguNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYmYiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjExMiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYmciPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjExNS41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJiaCI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTE5IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJiaSI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTIyLjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJqIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMjYiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJrIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMzMiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJsIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMjkuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48L3N2Zz4=);
                  border-radius: 15px;
                  flex-direction: column;
                  background-size: contain;
                  width: 100%;
                  background-repeat: no-repeat;
                  height: 52.7vw;
                  padding-left: auto;
                  padding-right: auto;
                  background-position: center;
                  background-attachment: fixed;
                }

                .ticket_inner{
                  flex-shrink: 1;
                  padding-left: 10.5em;
                  padding-top: 2.5em;
                }
                </xhtml:style>
                                <script type="text/javascript">//
                (function() {
                    'use strict'

                    function GeneralizedTime(generalizedTime) {
                        this.rawData = generalizedTime;
                    }

                    GeneralizedTime.prototype.getYear = function () {
                        return parseInt(this.rawData.substring(0, 4), 10);
                    }

                    GeneralizedTime.prototype.getMonth = function () {
                        return parseInt(this.rawData.substring(4, 6), 10) - 1;
                    }

                    GeneralizedTime.prototype.getDay = function () {
                        return parseInt(this.rawData.substring(6, 8), 10)
                    },

                    GeneralizedTime.prototype.getHours = function () {
                        return parseInt(this.rawData.substring(8, 10), 10)
                    },

                    GeneralizedTime.prototype.getMinutes = function () {
                        var minutes = parseInt(this.rawData.substring(10, 12), 10)
                        if (minutes) return minutes
                        return 0
                    },

                    GeneralizedTime.prototype.getSeconds = function () {
                        var seconds = parseInt(this.rawData.substring(12, 14), 10)
                        if (seconds) return seconds
                        return 0
                    },

                    GeneralizedTime.prototype.getMilliseconds = function () {
                        var startIdx
                        if (time.indexOf('.') !== -1) {
                            startIdx = this.rawData.indexOf('.') + 1
                        } else if (time.indexOf(',') !== -1) {
                            startIdx = this.rawData.indexOf(',') + 1
                        } else {
                            return 0
                        }

                        var stopIdx = time.length - 1
                        var fraction = '0' + '.' + time.substring(startIdx, stopIdx)
                        var ms = parseFloat(fraction) * 1000
                        return ms
                    },

                    GeneralizedTime.prototype.getTimeZone = function () {
                        let time = this.rawData;
                        var length = time.length
                        var symbolIdx
                        if (time.charAt(length - 1 ) === 'Z') return 0
                        if (time.indexOf('+') !== -1) {
                            symbolIdx = time.indexOf('+')
                        } else if (time.indexOf('-') !== -1) {
                            symbolIdx = time.indexOf('-')
                        } else {
                            return NaN
                        }

                        var minutes = time.substring(symbolIdx + 2)
                        var hours = time.substring(symbolIdx + 1, symbolIdx + 2)
                        var one = (time.charAt(symbolIdx) === '+') ? 1 : -1

                        var intHr = one * parseInt(hours, 10) * 60 * 60 * 1000
                        var intMin = one * parseInt(minutes, 10) * 60 * 1000
                        var ms = minutes ? intHr + intMin : intHr
                        return ms
                    }

                    if (typeof exports === 'object') {
                        module.exports = GeneralizedTime
                    } else if (typeof define === 'function' &amp;amp;&amp;amp; define.amd) {
                        define(GeneralizedTime)
                    } else {
                        window.GeneralizedTime = GeneralizedTime
                    }
                }())

                class Token {
                    constructor(tokenInstance) {
                        this.props = tokenInstance
                    }

                    formatGeneralizedTimeToDate(str) {
                        const d = new GeneralizedTime(str)
                        return new Date(d.getYear(), d.getMonth(), d.getDay(), d.getHours(), d.getMinutes(), d.getSeconds()).toLocaleDateString()
                    }
                    formatGeneralizedTimeToTime(str) {
                        const d = new GeneralizedTime(str)
                        return new Date(d.getYear(), d.getMonth(), d.getDay(), d.getHours(), d.getMinutes(), d.getSeconds()).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})
                    }

                    render() {
                        let time;
                        let date;
                        if (this.props.time == null) {
                            time = ""
                            date = ""
                        } else {
                            time = this.formatGeneralizedTimeToTime(this.props.time.generalizedTime)
                            date = this.props.time == null ? "": this.formatGeneralizedTimeToDate(this.props.time.generalizedTime)
                        }
                        return `
                        &lt;div class="ticket"&gt;
                          &lt;div class="ticket_inner"&gt;

                            &lt;div class="country_container"&gt;
                              &lt;span class="tbml-country"&gt;${this.props._count}x ${this.props.countryA} vs ${this.props.countryB}&lt;/span&gt;
                            &lt;/div&gt;

                            &lt;div class="datetime_container"&gt;
                              &lt;span class="tbml-date"&gt;${date} | ${time}&lt;/span&gt;
                            &lt;/div&gt;

                            &lt;div class="venue_container"&gt;
                                &lt;span class="tbml-venue"&gt;${this.props.venue} | ${this.props.locality}&lt;/span&gt;
                            &lt;/div&gt;

                            &lt;div class="category_container"&gt;
                              &lt;span class="tbml-category"&gt;${this.props.category}, M${this.props.match}&lt;/span&gt;
                            &lt;/div&gt;

                          &lt;/div&gt;
                        &lt;/div&gt;
                        `;
                    }
                }

                web3.tokens.dataChanged = (oldTokens, updatedTokens, tokenCardId) =&gt; {
                    const currentTokenInstance = updatedTokens.currentInstance;
                    document.getElementById(tokenCardId).innerHTML = new Token(currentTokenInstance).render();
                };
                //
                </script>
                            </ts:item-view>
                            <ts:view xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
                                <xhtml:style type="text/css">.tbml-count {
                  font-family: "SourceSansPro";
                  font-weight: bolder;
                  font-size: x-large;
                  color: white;
                }
                .tbml-country{
                  font-family: "SourceSansPro";
                  font-weight: bolder;
                  font-size: x-large;
                  color: white;
                }
                .tbml-date {
                  font-family: "SourceSansPro";
                  font-size: small;
                  color: white;
                }
                .tbml-time {
                  font-family: "SourceSansPro";
                  font-size: small;
                  color: white;
                }
                .tbml-venue {
                  font-family: "SourceSansPro";
                  font-size: small;
                  color: white;
                }
                .tbml-category {
                  font-family: "SourceSansPro";
                  font-size: small;
                  color: white;
                }

                .country_container{
                  padding-bottom: 1.6em;
                }
                .datetime_container{
                  padding-bottom: 0.5em;
                }
                .venue_container{
                  padding-bottom: 0.5em;
                }
                .category_container{
                  padding-bottom: 0.5em;
                }

                html {
                }
                body {
                  padding: 0px;
                  margin: 0px;
                }
                div {
                  margin: 0px;
                  padding: 0px;
                }
                .data-icon {
                  height:16px;
                  vertical-align: middle
                }

                .ticket{
                  background-image: url(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB2aWV3Qm94PSIwIDAgMzQ0IDE5MCI+PGRlZnM+PHN0eWxlPi5he2ZpbGw6bm9uZTt9LmIsLmd7ZmlsbC1ydWxlOmV2ZW5vZGQ7fS5ie2ZpbGw6dXJsKCNhKTt9LmN7ZmlsbDojZTBjMzhhO30uZHtmaWxsOiMyMzFmMjA7fS5le2ZpbGw6IzAwNmNhMzt9LmZ7ZmlsbDojZDAxYTIxO30uZywuaHtmaWxsOiNmZmY7fS5pe2NsaXAtcGF0aDp1cmwoI2IpO30uantjbGlwLXBhdGg6dXJsKCNjKTt9Lmt7Y2xpcC1wYXRoOnVybCgjZCk7fS5se2NsaXAtcGF0aDp1cmwoI2UpO30ubXtjbGlwLXBhdGg6dXJsKCNmKTt9Lm57Y2xpcC1wYXRoOnVybCgjZyk7fS5ve2NsaXAtcGF0aDp1cmwoI2kpO30ucHtjbGlwLXBhdGg6dXJsKCNrKTt9LnF7Y2xpcC1wYXRoOnVybCgjbSk7fS5ye2NsaXAtcGF0aDp1cmwoI28pO30uc3tjbGlwLXBhdGg6dXJsKCNxKTt9LnR7Y2xpcC1wYXRoOnVybCgjcyk7fS51e2NsaXAtcGF0aDp1cmwoI3UpO30udntjbGlwLXBhdGg6dXJsKCN3KTt9Lnd7Y2xpcC1wYXRoOnVybCgjeSk7fS54e2NsaXAtcGF0aDp1cmwoI2FhKTt9Lnl7Y2xpcC1wYXRoOnVybCgjYWMpO30uentjbGlwLXBhdGg6dXJsKCNhZSk7fS5hYXtjbGlwLXBhdGg6dXJsKCNhZyk7fS5hYntjbGlwLXBhdGg6dXJsKCNhaSk7fS5hY3tjbGlwLXBhdGg6dXJsKCNhayk7fS5hZHtjbGlwLXBhdGg6dXJsKCNhbSk7fS5hZXtjbGlwLXBhdGg6dXJsKCNhbyk7fS5hZntjbGlwLXBhdGg6dXJsKCNhcSk7fS5hZ3tjbGlwLXBhdGg6dXJsKCNhcyk7fS5haHtjbGlwLXBhdGg6dXJsKCNhdSk7fS5haXtjbGlwLXBhdGg6dXJsKCNhdyk7fS5hantjbGlwLXBhdGg6dXJsKCNheSk7fS5ha3tjbGlwLXBhdGg6dXJsKCNiYSk7fS5hbHtjbGlwLXBhdGg6dXJsKCNiYyk7fS5hbXtjbGlwLXBhdGg6dXJsKCNiZSk7fS5hbntjbGlwLXBhdGg6dXJsKCNiZyk7fS5hb3tjbGlwLXBhdGg6dXJsKCNiaSk7fS5hcHtjbGlwLXBhdGg6dXJsKCNiayk7fS5hcXtjbGlwLXBhdGg6dXJsKCNibSk7fS5hcntjbGlwLXBhdGg6dXJsKCNibyk7fS5hc3tjbGlwLXBhdGg6dXJsKCNicSk7fS5hdHtjbGlwLXBhdGg6dXJsKCNicyk7fS5hdXtjbGlwLXBhdGg6dXJsKCNidSk7fS5hdntjbGlwLXBhdGg6dXJsKCNidyk7fS5hd3tjbGlwLXBhdGg6dXJsKCNieSk7fS5heHtjbGlwLXBhdGg6dXJsKCNjYSk7fS5heXtjbGlwLXBhdGg6dXJsKCNjYyk7fS5hentjbGlwLXBhdGg6dXJsKCNjZSk7fS5iYXtjbGlwLXBhdGg6dXJsKCNjZyk7fS5iYntjbGlwLXBhdGg6dXJsKCNjaSk7fS5iY3tjbGlwLXBhdGg6dXJsKCNjayk7fS5iZHtjbGlwLXBhdGg6dXJsKCNjbSk7fS5iZXtjbGlwLXBhdGg6dXJsKCNjbyk7fS5iZntjbGlwLXBhdGg6dXJsKCNjcSk7fS5iZ3tjbGlwLXBhdGg6dXJsKCNjcyk7fS5iaHtjbGlwLXBhdGg6dXJsKCNjdSk7fS5iaXtjbGlwLXBhdGg6dXJsKCNjdyk7fS5iantjbGlwLXBhdGg6dXJsKCNjeSk7fS5ia3tjbGlwLXBhdGg6dXJsKCNkYSk7fS5ibHtjbGlwLXBhdGg6dXJsKCNkYyk7fTwvc3R5bGU+PGxpbmVhckdyYWRpZW50IGlkPSJhIiB4MT0iNDkuOTciIHkxPSItMzAuMDMiIHgyPSIyODcuNDIiIHkyPSIyMDcuNDIiIGdyYWRpZW50VHJhbnNmb3JtPSJtYXRyaXgoMSwgMCwgMCwgLTEsIDAsIDE4NCkiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj48c3RvcCBvZmZzZXQ9IjAiIHN0b3AtY29sb3I9IiMwMDJjNmQiLz48c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiMwMDY4YjIiLz48L2xpbmVhckdyYWRpZW50PjxjbGlwUGF0aCBpZD0iYiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PHBhdGggY2xhc3M9ImEiIGQ9Ik01NS42LDU1LjkxYS43LjcsMCwwLDEsLjctLjcxLjY4LjY4LDAsMCwxLC43LjcuNjcuNjcsMCwwLDEtLjY5LjcuODUuODUsMCwwLDEtLjcxLS42OSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48cGF0aCBjbGFzcz0iYSIgZD0iTTcwLjMyLDQ4LjQ3YS41Ni41NiwwLDAsMSwuMjEtLjU0LjUzLjUzLDAsMCwxLC41NC4yLjU0LjU0LDAsMCwxLS4yLjU1LjM1LjM1LDAsMCwxLS41NS0uMjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iZCIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PHBhdGggY2xhc3M9ImEiIGQ9Ik03MS4wOSw1MS41MmMtLjEsMCwwLS4yMi4xNC0uNDhhLjY3LjY3LDAsMCwxLS4yNS0uNTkuODEuODEsMCwwLDEsLjg2LS43OWwuMjkuMDhhMS4zNSwxLjM1LDAsMCwxLC4yNy0uMjNjLjEsMCwwLC4yMi0uMTEuMzlhLjY1LjY1LDAsMCwxLC4yNC41OS43OS43OSwwLDAsMS0uODUuNzlsLS4yOS0uMDhjLS4wOC4yOC0uMjEuMzUtLjMuMzIiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iZSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMyIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJmIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48cmVjdCBjbGFzcz0iYSIgeD0iMTI4LjMiIHk9Ii0yIiB3aWR0aD0iMiIgaGVpZ2h0PSIxODQiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iZyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNi41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImkiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjEwIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImsiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjEzLjUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0ibSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTciIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0ibyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMjAuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJxIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIyNCIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJzIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIyNy41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9InUiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjMxIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9InciIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjM0LjUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0ieSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMzgiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYWEiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjQ1IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImFjIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI0MS41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImFlIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI0OCIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJhZyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNTEuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJhaSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNTUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYWsiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjU4LjUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYW0iIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjYyIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImFvIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI2NS41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImFxIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI2OSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJhcyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNzIuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJhdSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iNzYiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYXciIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9Ijc5LjUiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iYXkiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjgzIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJhIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI5MCIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJiYyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iODYuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJiZSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTM5IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJnIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNDIuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJiaSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTQ2IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJrIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNDkuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJibSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTUzIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJvIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNTYuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJicSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTYwIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJzIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNjMuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJidSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTY3IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImJ3IiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxNzAuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJieSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTc0IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNhIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxODEiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iY2MiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjE3Ny41IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNlIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSI5NCIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjZyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iOTcuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjaSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTAxIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNrIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMDQuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjbSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTA4IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNvIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMTEuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjcSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTE1IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImNzIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMTguNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjdSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTIyIiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImN3IiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMjUuNSIgcj0iMSIvPjwvY2xpcFBhdGg+PGNsaXBQYXRoIGlkPSJjeSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSI+PGNpcmNsZSBjbGFzcz0iYSIgY3g9IjEyOS4zIiBjeT0iMTI5IiByPSIxIi8+PC9jbGlwUGF0aD48Y2xpcFBhdGggaWQ9ImRhIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIj48Y2lyY2xlIGNsYXNzPSJhIiBjeD0iMTI5LjMiIGN5PSIxMzYiIHI9IjEiLz48L2NsaXBQYXRoPjxjbGlwUGF0aCBpZD0iZGMiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiPjxjaXJjbGUgY2xhc3M9ImEiIGN4PSIxMjkuMyIgY3k9IjEzMi41IiByPSIxIi8+PC9jbGlwUGF0aD48L2RlZnM+PHRpdGxlPmJhY2tncm91bmRfcmVkZWVtZWRfZW1wdHk8L3RpdGxlPjxwYXRoIGNsYXNzPSJiIiBkPSJNMzI5LjEsOTAuM0E5LjE1LDkuMTUsMCwwLDAsMzI5LDkyYTE1LDE1LDAsMCwwLDE1LDE1djYxYTE2LDE2LDAsMCwxLTE2LDE2SDE2YTE1LjY2LDE1LjY2LDAsMCwxLTExLjUtNUExNS41OSwxNS41OSwwLDAsMSwwLDE2OFYxMDdhMTUsMTUsMCwwLDAsMTEuOC01LjcsMTUsMTUsMCwwLDAsMy4xLTcuNkE5LjcsOS43LDAsMCwwLDE1LDkyLDE1LDE1LDAsMCwwLDAsNzdWMTZBMTYsMTYsMCwwLDEsMTYsMEgzMjhhMTYsMTYsMCwwLDEsOC44LDIuNywxNy43LDE3LjcsMCwwLDEsNC4yLDQsMTUuNDIsMTUuNDIsMCwwLDEsMyw5LjNWNzdhMTUsMTUsMCwwLDAtMTEuNyw1LjZBMTQuNjUsMTQuNjUsMCwwLDAsMzI5LjEsOTAuM1oiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iYyIgZD0iTTg0LjQsNjQuM2ExNC4yNCwxNC4yNCwwLDAsMS0uNSwxLjZjLS4xLjItLjEuNC0uMi41YTUuMzYsNS4zNiwwLDAsMS0uNSwxLjEsMywzLDAsMCwxLS40LjhjLS40LjktLjgsMS43LTEuMiwyLjVoMGMtMy42LDcuMS03LjEsMTUtNy40LDE3LjgsNS40LDkuNiw2LjIsMTYuOSw1LjgsMTkuOC0uNiw0LTUuNiw1LjgtMTEuOCw1LjhoLS4zYy01LjgsMC0xMi0yLTExLjktNS45cy45LTUuNiwyLjMtMTIuNWMuMi0xLC40LTUuOC42LTguNkg1OGMtLjgsMC0xLjUtLjEtMi0uMSwyLTEuNiwyLjgtMy41LDIuNy01YTUuOTMsNS45MywwLDAsMS0zLjEuNyw4LjYsOC42LDAsMCwxLTEuNi0uMWMyLjYtMy40LDEuOS02LjYuNS05LjktLjctMS43LTEuNi0zLjMtMi4zLTVBMjEuOSwyMS45LDAsMCwxLDUxLDY0LjVhMTguNjgsMTguNjgsMCwwLDEsLjktMTIuM0ExNy4yNCwxNy4yNCwwLDAsMSw2Ny43LDQyYTIwLjA3LDIwLjA3LDAsMCwxLDQuMi41LDIuOTIsMi45MiwwLDAsMCwuOS4yYy4yLDAsLjMuMS41LjFsLjkuM2EzLjU1LDMuNTUsMCwwLDEsLjkuNGMuMy4yLjcuMywxLC41cy43LjQsMSwuNi42LjQsMSwuN2ExMy40NCwxMy40NCwwLDAsMSwxLjQsMS4xLDE4LjQ2LDE4LjQ2LDAsMCwxLDMuMSwzLjdBMTgsMTgsMCwwLDEsODQuNCw2NC4zWiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJkIiBkPSJNODAsNzFhNDMuODcsNDMuODcsMCwwLDEtNiw4LjhjLS44LjktMS40LjMtMS4zLS4yLjItMS4zLjItMy4xLTEuNi0yLjgtLjguMS0xLjcsMS4zLS43LDMuMy4xLjIuMS43LS42LjMtNC0xLjctNi4xLTUuNy00LjgtMTAuNWExMS41NiwxMS41NiwwLDAsMSw1LjctNi41YzQuMi0yLjMsOC43LTEuOCwxMC4yLjhDODEuNyw2NS42LDgxLjcsNjcuOSw4MCw3MVoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZCIgZD0iTTc2LjMsNjkuMWExLjMyLDEuMzIsMCwwLDEtLjUtMS41di0uMWgtLjFhMS4yNCwxLjI0LDAsMCwxLTEuNS41aC0uMXYuMWExLjMyLDEuMzIsMCwwLDEsLjUsMS41di4xaC4xYTEuNTgsMS41OCwwLDAsMSwxLjYtLjZabS0xLjctMi43YS4zLjMsMCwxLDAtLjMuM0EuMzIuMzIsMCwwLDAsNzQuNiw2Ni40Wm0tMi40LDMuMmEuOC44LDAsMSwwLC44LjhBLjg2Ljg2LDAsMCwwLDcyLjIsNjkuNlptLjEtMS40aDBhMS4xOSwxLjE5LDAsMCwxLS4zLTEuMWgwYTEsMSwwLDAsMS0xLC40aDBhMSwxLDAsMCwxLC4zLDEuMWgwQTEsMSwwLDAsMSw3Mi4zLDY4LjJabTMuNS0yMi44Yy00LjQtMi41LTkuMi0yLjQtMTAuOC40cy43LDcsNS4xLDkuNiw5LjIsMi40LDEwLjgtLjRTODAuMiw0OCw3NS44LDQ1LjRaTTU3LjEsNTAuMWMtMy4xLDAtNS43LDQuMS01LjcsOS4xczIuNSw5LjEsNS43LDkuMSw1LjctNC4xLDUuNy05LjFTNjAuMyw1MC4xLDU3LjEsNTAuMVoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48ZWxsaXBzZSBjbGFzcz0iZSIgY3g9IjczLjM1IiBjeT0iNDkuNjMiIHJ4PSIzLjgiIHJ5PSI2LjYiIHRyYW5zZm9ybT0idHJhbnNsYXRlKC02LjMxIDkxLjMzKSByb3RhdGUoLTYwKSIvPjxlbGxpcHNlIGNsYXNzPSJlIiBjeD0iNzMuNjkiIGN5PSI2OC45MSIgcng9IjcuMSIgcnk9IjQuMSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTIzLjExIDQzLjQ3KSByb3RhdGUoLTI2LjcxKSIvPjxlbGxpcHNlIGNsYXNzPSJlIiBjeD0iNTYuMyIgY3k9IjU4LjkiIHJ4PSIzLjkiIHJ5PSI2LjgiIHRyYW5zZm9ybT0idHJhbnNsYXRlKC0zLjQ2IDYuNTEpIHJvdGF0ZSgtMy40NikiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTU3LjcsMTA1LjhjNC4xLTEsNy45LTEuNCwxMi40LTksMS4yLTEuOS0uOCwxMS4yLTEwLjgsMTEuMkExLjU0LDEuNTQsMCwwLDEsNTcuNywxMDUuOFoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTcxLjIsOTcuMWMxLjUsOC4yLjgsMTQuMS01LDE0LjctNi4xLjYtOC40LTIuMS04LjQtMi4xLDUuMS40LDgtMS4zLDkuNi0zczQtNy41LDMuOC05LjYiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTYwLjEsOTQuM2MuMSwxLjYuNyw0LjkuMyw2LjRhNi4xOCw2LjE4LDAsMCwxLTIuMywzLjVaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImYiIGQ9Ik02Mi4yLDg2LjRjLTEsMi44LTEuOSwxMS40LjcsMTEuNywxLjQuMi0uMi0xLjYuNy0yLjJzMi4zLS44LDIuNC42LTEuNywyLjEtLjgsMi4zYTMuMDksMy4wOSwwLDAsMCwzLjEtMS41LDIxLjU3LDIxLjU3LDAsMCwwLDEuNS0zLjVzLTIuNC01LjYtNS43LTguOFoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTU1LjIsNDkuMmMyLjItMy40LDYuMi00LjYsMTAuNS01LjgsMCwwLTQuNCwxLjYtMyw3LjQsMCwwLTMuMy0zLjktNy41LTEuNiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJmIiBkPSJNODIuOCw1My44YzEuOSwzLjUsMSw3LjYsMCwxMiwwLDAsLjctNC42LTUtNi4yLDAsMCw1LTEsNS01LjgiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iZiIgZD0iTTczLjgsNTkuNWExMS4xMywxMS4xMywwLDAsMC04LjcsNC44LDE2LjQxLDE2LjQxLDAsMCwwLS40LTkuOSwyMS43LDIxLjcsMCwwLDAsOS4xLDUuMSIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJmIiBkPSJNNTQuNyw2OS44YzQuOCwxLjMsNC4xLDEuMyw4LjEtMS4zLS40LDEuOS0xLjUsNS44LDMuMiwxMi4yLDEwLjMsOC4yLDEyLjQsMjQuNiwxMi40LDI0LjYuNCw2LjgtNS41LDcuNS0xMC4yLDcuMyw2LjQtMi42LDUtNy43LDUtMTAuNi0uMy0xMC4xLTcuOC0xNy45LTcuOC0xNy45bC0xLjItMS43Yy0xLjMsMy40LTUuMSwzLjQtNS4xLDMuNCwyLjYtMi44LDEuMy03LjQsMS4zLTcuNC0uMywzLTQuMiwzLjMtNC4yLDMuMywzLTMuNS0uNS0xMC43LS41LTEwLjdaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PGNpcmNsZSBjbGFzcz0iZiIgY3g9IjYzLjIiIGN5PSI1NS4xIiByPSIwLjYiLz48Y2lyY2xlIGNsYXNzPSJmIiBjeD0iNzYuNiIgY3k9IjYyLjYiIHI9IjAuNiIvPjxjaXJjbGUgY2xhc3M9ImYiIGN4PSI2My41IiBjeT0iNzAiIHI9IjAuNiIvPjxjaXJjbGUgY2xhc3M9ImYiIGN4PSI2NC4zIiBjeT0iNjguNSIgcj0iMC40Ii8+PGNpcmNsZSBjbGFzcz0iZiIgY3g9Ijc1LjEiIGN5PSI2Mi41IiByPSIwLjQiLz48Y2lyY2xlIGNsYXNzPSJmIiBjeD0iNjQiIGN5PSI1Ni40IiByPSIwLjQiLz48cGF0aCBjbGFzcz0iYyIgZD0iTTY0LjQsOTIuNGgtLjFsLS4xLS4xLjEtLjFhMi4xOSwyLjE5LDAsMCwwLDEuNC0uOCwxLjg1LDEuODUsMCwwLDAsLjcuMmMuMSwwLC4yLjEuMy4xYTQuMTMsNC4xMywwLDAsMCwxLjEuN3YuMWwtLjEuMWMtLjIsMC0uMy4xLS40LjFsLS42LjNoMGExLjksMS45LDAsMCwwLS43LDEuMWwtLjEuMWgwVjk0YTIuNDcsMi40NywwLDAsMC0uNC0uOSw1LjU1LDUuNTUsMCwwLDAtLjgtLjZDNjQuNSw5Mi41LDY0LjQsOTIuNSw2NC40LDkyLjRaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImciIGQ9Ik01OC4yLDU5LjFhLjQ1LjQ1LDAsMCwxLDAtLjUuMjguMjgsMCwxLDEsLjQuNC4yNS4yNSwwLDAsMS0uNC4xWiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJnIiBkPSJNNTUuMyw1OC41YS4zLjMsMCwxLDEsLjMtLjNjLjEuMi0uMS4zLS4zLjNaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImgiIGQ9Ik01NS42LDU1LjlhLjcuNywwLDEsMSwuNy43Ljg0Ljg0LDAsMCwxLS43LS43IiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PGcgY2xhc3M9ImkiPjxyZWN0IGNsYXNzPSJoIiB4PSI1NS42IiB5PSI1NS4yIiB3aWR0aD0iMS40IiBoZWlnaHQ9IjEuNCIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTAuNTMgMy41NCkgcm90YXRlKC0wLjU0KSIvPjwvZz48cGF0aCBjbGFzcz0iZyIgZD0iTTU3LjgsNjEuNWgwYTEuOTQsMS45NCwwLDAsMC0yLjEuN2gtLjF2LS4xYTEuNzUsMS43NSwwLDAsMC0uNi0yVjYwaC4xYTEuODUsMS44NSwwLDAsMCwyLS43aC4xdi4xYTEuNjYsMS42NiwwLDAsMCwuNiwyLjFaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImciIGQ9Ik03Ni40LDUxLjNoMGExLjUyLDEuNTIsMCwwLDAtMS42LjloLS4xdi0uMWExLjU1LDEuNTUsMCwwLDAtLjgtMS42di0uMUg3NGExLjU0LDEuNTQsMCwwLDAsMS42LS45aC4xdi4xYTEuNDEsMS40MSwwLDAsMCwuNywxLjdaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PHBhdGggY2xhc3M9ImgiIGQ9Ik03MC4zLDQ4LjRhLjQxLjQxLDAsMSwxLC41LjMuMzUuMzUsMCwwLDEtLjUtLjMiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48ZyBjbGFzcz0iaiI+PHJlY3QgY2xhc3M9ImgiIHg9IjcwLjIiIHk9IjQ3LjgiIHdpZHRoPSIxIiBoZWlnaHQ9IjEiIHRyYW5zZm9ybT0idHJhbnNsYXRlKC03LjYyIDE2LjY5KSByb3RhdGUoLTEwLjUpIi8+PC9nPjxwYXRoIGNsYXNzPSJoIiBkPSJNNzAuNiw1MC4yYzAtLjEuMi0uMS41LDBhLjY2LjY2LDAsMCwxLC41LS40LjguOCwwLDAsMSwxLC42di4zYTEuMjQsMS4yNCwwLDAsMSwuMy4yYzAsLjEtLjIuMS0uNCwwYS42Ni42NiwwLDAsMS0uNS40LjguOCwwLDAsMS0xLS42di0uM2MtLjMsMC0uNC0uMS0uNC0uMiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxnIGNsYXNzPSJrIj48cmVjdCBjbGFzcz0iaCIgeD0iNzAuNTMiIHk9IjQ5LjIyIiB3aWR0aD0iMi40IiBoZWlnaHQ9IjIuNyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMy4xMyAxMDguMykgcm90YXRlKC03My43NykiLz48L2c+PHBhdGggY2xhc3M9ImciIGQ9Ik03NC42LDY2LjRhLjMuMywwLDEsMS0uMy0uM0EuMjcuMjcsMCwwLDEsNzQuNiw2Ni40WiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJnIiBkPSJNNzMsNzAuNGEuOC44LDAsMSwxLS44LS44QS44Ni44NiwwLDAsMSw3Myw3MC40WiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJnIiBkPSJNNzYuMyw2OS4yaDBhMS41MSwxLjUxLDAsMCwwLTEuNi42aC0uMXYtLjFhMS4yOCwxLjI4LDAsMCwwLS41LTEuNXYtLjFoLjFhMS4yNCwxLjI0LDAsMCwwLDEuNS0uNWguMXYuMWExLjQxLDEuNDEsMCwwLDAsLjUsMS41WiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJnIiBkPSJNNzIuNCw2OC4yaDBhLjkuOSwwLDAsMC0xLjEuNGgwYTEuMTMsMS4xMywwLDAsMC0uMy0xLjFoMGMuNC4xLjksMCwxLS40aDBhMSwxLDAsMCwwLC40LDEuMVoiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAgMykiLz48cGF0aCBjbGFzcz0iaCIgZD0iTTk1LjMsMTMxLjloMGMtMy4xLDAtNC41LDIuMS01LDQuNy0uOCw1LDEuNyw2LjUsNC45LDYuNWgwYzMuMiwwLDUuOC0xLjUsNC45LTYuNS0uNC0yLjYtMS44LTQuNy00LjgtNC43bTAsMTAuMWgwYy0xLjcsMC0zLTEuMi0yLjYtNS4yLjItMi4xLDEtMy43LDIuNi0zLjdoMGMxLjYsMCwyLjMsMS42LDIuNiwzLjdDOTguMywxNDAuNyw5Ni45LDE0Miw5NS4zLDE0MlptMTYuNy00LjhhMi42LDIuNiwwLDAsMCwyLjEtMi41LDIuMjgsMi4yOCwwLDAsMC0xLTEuOSw0LjI0LDQuMjQsMCwwLDAtMi42LS44aC0uMWE0LjI0LDQuMjQsMCwwLDAtMi42LjgsMi4xNywyLjE3LDAsMCwwLTEsMS45LDIuNiwyLjYsMCwwLDAsMi4xLDIuNXMtMywuNC0zLDIuN2MwLDIuNywzLjEsMy4xLDQuNiwzLjFzNC42LS40LDQuNi0zLjFDMTE1LDEzNy42LDExMiwxMzcuMiwxMTIsMTM3LjJabS4xLDQuNWEyLDIsMCwwLDEtMS42LjYsMS44NCwxLjg0LDAsMCwxLTEuNi0uNiwyLjE1LDIuMTUsMCwwLDEtLjQtMS42YzAtLjYuMy0yLjIsMS44LTIuNHYtLjhjLS43LS4xLTEuNC0uNy0xLjQtMiwwLTEuNywxLjEtMiwxLjctMmExLjc2LDEuNzYsMCwwLDEsMS43LDIsMS43OSwxLjc5LDAsMCwxLTEuMywydi45YzEuNC4zLDEuNiwxLjksMS43LDIuNEEzLjM5LDMuMzksMCwwLDEsMTEyLjEsMTQxLjdaTTMwLjUsMTM1YzAtMi42LTIuOS0yLjYtNS0yLjZIMjAuNnYxMC40aDIuMnYtOS42aDIuN2MuNiwwLDIuNCwwLDIuNCwxLjgsMCwxLjQtMy4xLDMuMS00LjYsMy45djEuN2MuNy0uMywxLjctLjgsMi4yLTFsMi43LDMuM2gyLjRsLTMuNS00LjFDMjkuNCwxMzcuNCwzMC41LDEzNi4yLDMwLjUsMTM1Wm0xMC4xLTIuNmgtMnMuMS43LjEsMWE1Niw1NiwwLDAsMSwuNSw2LDIuNjgsMi42OCwwLDAsMS0yLjcsMi44aDBhMi42OCwyLjY4LDAsMCwxLTIuNy0yLjgsNTYsNTYsMCwwLDEsLjUtNmMwLS4yLjEtMSwuMS0xaC0yYTUuNzYsNS43NiwwLDAsMS0uMiwxYzAsLjMtLjgsNC4xLS44LDUuNCwwLDIuNiwxLjksNC4yLDUuMSw0LjJoMGMzLjEsMCw1LTEuNiw1LTQuMmEzNy40MSwzNy40MSwwLDAsMC0uOC01LjRDNDAuNywxMzMuMSw0MC42LDEzMi40LDQwLjYsMTMyLjRabTIyLDEwLjVoMi4yVjEzMi40SDYyLjZabTI1LjYtOS42Yy0xLjctMS44LTYuMS0xLjctNy4yLjVhMi43MiwyLjcyLDAsMCwwLC4xLDIuNmwuOS0uNGEyLjI4LDIuMjgsMCwwLDEsMS43LTMsMi4zLDIuMywwLDAsMSwyLjgsMi44Yy0uOCwyLjEtNC42LDUtNi4yLDYuMXYuN2g5LjF2LTEuM0g4My4yQzg2LjIsMTQwLjIsOTEuNCwxMzYuNiw4OC4yLDEzMy4zWm0xNC42LS41YTQuNDYsNC40NiwwLDAsMS0xLjYuM3YuN2guM2EuODguODgsMCwwLDEsLjkuOHY4LjFoMi4yVjEzMi4zaC0uOUEyLjA2LDIuMDYsMCwwLDEsMTAyLjgsMTMyLjhabS01My40LDQuNWExNi40MiwxNi40MiwwLDAsMC0yLjItMSwxOC4zMiwxOC4zMiwwLDAsMS0xLjctLjcsMi40MSwyLjQxLDAsMCwxLS44LS42LDEuMDgsMS4wOCwwLDAsMS0uMy0uNywxLjA1LDEuMDUsMCwwLDEsLjUtLjksMywzLDAsMCwxLDEuNS0uNCw3LjQ1LDcuNDUsMCwwLDEsMy41LjhsLjYtLjhhNy45LDcuOSwwLDAsMC00LjEtLjksMy41OSwzLjU5LDAsMCwwLTMuMywxLjYsMi43OCwyLjc4LDAsMCwwLDEsMy41LDI2LjY1LDI2LjY1LDAsMCwwLDMuMSwxLjZoLjFhMy42LDMuNiwwLDAsMSwuOS41LDEuMjEsMS4yMSwwLDAsMSwuNS41LDEuMzksMS4zOSwwLDAsMS0uNCwxLjksMi40MSwyLjQxLDAsMCwxLTEuNS40LDE4LjM4LDE4LjM4LDAsMCwxLTQuMS0uN2wtLjUuOWExNi41MywxNi41MywwLDAsMCw0LjguOGMyLjcsMCw0LjEtMS4zLDQuNC0yLjRDNTEuNywxMzkuMyw1MS4xLDEzOC4xLDQ5LjQsMTM3LjNabTkuNywwYTE2LjQyLDE2LjQyLDAsMCwwLTIuMi0xLDE4LjMyLDE4LjMyLDAsMCwxLTEuNy0uNywyLjQxLDIuNDEsMCwwLDEtLjgtLjYsMS4wOCwxLjA4LDAsMCwxLS4zLS43LDEuMDUsMS4wNSwwLDAsMSwuNS0uOSwzLDMsMCwwLDEsMS41LS40LDcuNDUsNy40NSwwLDAsMSwzLjUuOGwuNi0uOGE3LjksNy45LDAsMCwwLTQuMS0uOSwzLjU5LDMuNTksMCwwLDAtMy4zLDEuNiwyLjc4LDIuNzgsMCwwLDAsMSwzLjUsMjAuMTMsMjAuMTMsMCwwLDAsMy4xLDEuNkg1N2EzLjYsMy42LDAsMCwxLC45LjUsMS4yMSwxLjIxLDAsMCwxLC41LjUsMS4zOSwxLjM5LDAsMCwxLS40LDEuOSwyLjQxLDIuNDEsMCwwLDEtMS41LjQsMTguMzgsMTguMzgsMCwwLDEtNC4xLS43bC0uNS45YTE2LjUzLDE2LjUzLDAsMCwwLDQuOC44YzIuNywwLDQuMS0xLjMsNC40LTIuNEEzLDMsMCwwLDAsNTkuMSwxMzcuM1ptMTQuNi00LjlINzEuNmMtLjkuOS03LjMsOC44LTQuNywxMC40LDEuOCwxLjEsNS4xLTEsNi42LTIuMWwtLjYtMWMtMS4xLjktMy4yLDItMy45LDEuMi0xLjEtMSwyLjctNy4zLDIuNy03LjMuNCwxLjMsMi41LDcsMyw4bC42LDEuMWgyLjNsLS42LTEuMkE1Mi4zMyw1Mi4zMywwLDAsMSw3My43LDEzMi40WiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAzKSIvPjxwYXRoIGNsYXNzPSJoIiBkPSJNNTIsMTI0LjFsLTEuNyw0LjdoMS40bC4yLS42aDEuNmwuMi42aDEuNWwtMS43LTQuN0g1Mm0uMiwzLjEuNi0xLjkuNiwxLjlabTEwLjQtMy4xLTEsNC43SDYwbC0uNy0zLjZoMGwtLjYsMy42SDU3LjFsLTEtNC43aDEuM2wuNiwzLjZoMGwuNi0zLjZoMS42bC43LDMuNmgwbC42LTMuNlptLTE3LjUsMGgxLjV2NC43SDQ1LjFabS00LjEsMGgzLjZsLS40LDFINDIuNXYuOWgxLjRsLS40LDFoLTF2MS43SDQxWm05LjUsMS45LS40LDFoLTF2MS43SDQ3LjZWMTI0aDMuNmwtLjQsMUg0OXYuOWgxLjVabTM4LjctMS45aDEuM1YxMjdjMCwxLjMtLjgsMS45LTIuMSwxLjlhMS44NCwxLjg0LDAsMCwxLTIuMS0xLjl2LTIuOWgxLjN2Mi43YzAsLjYuMiwxLjEuOCwxLjFzLjgtLjUuOC0xLjF2LTIuN1ptLTExLjYsMEg3NS45djQuN2gxLjdjMS42LDAsMi44LS42LDIuOC0yLjRTNzkuMywxMjQuMSw3Ny42LDEyNC4xWm0uMSwzLjhoLS41VjEyNWguNWExLjM0LDEuMzQsMCwwLDEsMS41LDEuNFE3OSwxMjcuOSw3Ny43LDEyNy45Wm04LjItLjIuMSwxYTUuMjEsNS4yMSwwLDAsMS0xLjQuMmMtMS4zLDAtMi43LS42LTIuNy0yLjQsMC0xLjYsMS4xLTIuNCwyLjctMi40YTYuNzUsNi43NSwwLDAsMSwxLjQuMmwtLjEsMWEyLjY2LDIuNjYsMCwwLDAtMS4yLS4zLDEuNDIsMS40MiwwLDAsMC0xLjUsMS41LDEuNSwxLjUsMCwwLDAsMS42LDEuNUM4NS4yLDEyNy45LDg1LjYsMTI3LjgsODUuOSwxMjcuN1ptNi42LTMuNkg5MXY0LjdoMS4zdi0xLjZoLjVjMS4yLDAsMS45LS42LDEuOS0xLjVDOTQuNiwxMjQuNiw5My45LDEyNC4xLDkyLjUsMTI0LjFabS4xLDIuMWgtLjNWMTI1aC4zYy40LDAsLjguMi44LjZTOTMsMTI2LjIsOTIuNiwxMjYuMlptLTE5LjIsMS43aDEuOXYuOUg3Mi4xdi00LjdoMS4zWm0tMi44LTEuNGgwYTEuMTgsMS4xOCwwLDAsMCwuOS0xLjJjMC0uOC0uNy0xLjItMS41LTEuMkg2Ny44djQuN0g2OXYtMS45aC4zYy41LDAsLjYuMi45LDFsLjMuOGgxLjNsLS41LTEuM0M3MSwxMjYuOSw3MSwxMjYuNiw3MC42LDEyNi41Wm0tMS4zLS41SDY5di0xaC4zYy41LDAsLjkuMS45LjVTNjkuNywxMjYsNjkuMywxMjZaTTY1LDEyNGEyLjIxLDIuMjEsMCwwLDAtMi40LDIuNCwyLjE2LDIuMTYsMCwwLDAsMi40LDIuNCwyLjIxLDIuMjEsMCwwLDAsMi40LTIuNEEyLjI2LDIuMjYsMCwwLDAsNjUsMTI0Wm0wLDMuOWMtLjgsMC0xLjEtLjctMS4xLTEuNXMuMy0xLjUsMS4xLTEuNSwxLjEuNywxLjEsMS41UzY1LjcsMTI3LjksNjUsMTI3LjlaIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDMpIi8+PGcgY2xhc3M9ImwiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9Im4iPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjMuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0ibyI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iNyIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0icCI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTAuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0icSI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTQiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9InIiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjE3LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9InMiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjIxIiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJ0Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIyNC41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJ1Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIyOCIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0idiI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMzEuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0idyI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMzUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9IngiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjQyIiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJ5Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIzOC41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJ6Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI0NSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWEiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjQ4LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFiIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI1MiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWMiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjU1LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFkIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI1OSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWUiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjYyLjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFmIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI2NiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWciPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjY5LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFoIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI3MyIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWkiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9Ijc2LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFqIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSI4MCIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYWsiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9Ijg3IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhbCI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iODMuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYW0iPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjEzNiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYW4iPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjEzOS41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhbyI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTQzIiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhcCI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTQ2LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFxIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNTAiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImFyIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNTMuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYXMiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjE1NyIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYXQiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjE2MC41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhdSI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTY0IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJhdiI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTY3LjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImF3Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNzEiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImF4Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNzgiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImF5Ij48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxNzQuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYXoiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjkxIiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJiYSI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iOTQuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYmIiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9Ijk4IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJiYyI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTAxLjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJkIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMDUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJlIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMDguNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYmYiPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjExMiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48ZyBjbGFzcz0iYmciPjxnIGNsYXNzPSJtIj48cmVjdCBjbGFzcz0iaCIgeD0iMTIzLjMiIHk9IjExNS41IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJiaCI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTE5IiB3aWR0aD0iMTIiIGhlaWdodD0iMTIiLz48L2c+PC9nPjxnIGNsYXNzPSJiaSI+PGcgY2xhc3M9Im0iPjxyZWN0IGNsYXNzPSJoIiB4PSIxMjMuMyIgeT0iMTIyLjUiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJqIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMjYiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJrIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMzMiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIvPjwvZz48L2c+PGcgY2xhc3M9ImJsIj48ZyBjbGFzcz0ibSI+PHJlY3QgY2xhc3M9ImgiIHg9IjEyMy4zIiB5PSIxMjkuNSIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEyIi8+PC9nPjwvZz48L3N2Zz4=);
                  border-radius: 15px;
                  flex-direction: column;
                  background-size: contain;
                  width: 100%;
                  background-repeat: no-repeat;
                  height: 52.7vw;
                  padding-left: auto;
                  padding-right: auto;
                  background-position: center;
                  background-attachment: fixed;
                }

                .ticket_inner{
                  flex-shrink: 1;
                  padding-left: 10.5em;
                  padding-top: 2.5em;
                }
                </xhtml:style>
                                <script type="text/javascript">//
                (function() {
                    'use strict'

                    function GeneralizedTime(generalizedTime) {
                        this.rawData = generalizedTime;
                    }

                    GeneralizedTime.prototype.getYear = function () {
                        return parseInt(this.rawData.substring(0, 4), 10);
                    }

                    GeneralizedTime.prototype.getMonth = function () {
                        return parseInt(this.rawData.substring(4, 6), 10) - 1;
                    }

                    GeneralizedTime.prototype.getDay = function () {
                        return parseInt(this.rawData.substring(6, 8), 10)
                    },

                    GeneralizedTime.prototype.getHours = function () {
                        return parseInt(this.rawData.substring(8, 10), 10)
                    },

                    GeneralizedTime.prototype.getMinutes = function () {
                        var minutes = parseInt(this.rawData.substring(10, 12), 10)
                        if (minutes) return minutes
                        return 0
                    },

                    GeneralizedTime.prototype.getSeconds = function () {
                        var seconds = parseInt(this.rawData.substring(12, 14), 10)
                        if (seconds) return seconds
                        return 0
                    },

                    GeneralizedTime.prototype.getMilliseconds = function () {
                        var startIdx
                        if (time.indexOf('.') !== -1) {
                            startIdx = this.rawData.indexOf('.') + 1
                        } else if (time.indexOf(',') !== -1) {
                            startIdx = this.rawData.indexOf(',') + 1
                        } else {
                            return 0
                        }

                        var stopIdx = time.length - 1
                        var fraction = '0' + '.' + time.substring(startIdx, stopIdx)
                        var ms = parseFloat(fraction) * 1000
                        return ms
                    },

                    GeneralizedTime.prototype.getTimeZone = function () {
                        let time = this.rawData;
                        var length = time.length
                        var symbolIdx
                        if (time.charAt(length - 1 ) === 'Z') return 0
                        if (time.indexOf('+') !== -1) {
                            symbolIdx = time.indexOf('+')
                        } else if (time.indexOf('-') !== -1) {
                            symbolIdx = time.indexOf('-')
                        } else {
                            return NaN
                        }

                        var minutes = time.substring(symbolIdx + 2)
                        var hours = time.substring(symbolIdx + 1, symbolIdx + 2)
                        var one = (time.charAt(symbolIdx) === '+') ? 1 : -1

                        var intHr = one * parseInt(hours, 10) * 60 * 60 * 1000
                        var intMin = one * parseInt(minutes, 10) * 60 * 1000
                        var ms = minutes ? intHr + intMin : intHr
                        return ms
                    }

                    if (typeof exports === 'object') {
                        module.exports = GeneralizedTime
                    } else if (typeof define === 'function' &amp;amp;&amp;amp; define.amd) {
                        define(GeneralizedTime)
                    } else {
                        window.GeneralizedTime = GeneralizedTime
                    }
                }())

                class Token {
                    constructor(tokenInstance) {
                        this.props = tokenInstance
                    }

                    formatGeneralizedTimeToDate(str) {
                        const d = new GeneralizedTime(str)
                        return new Date(d.getYear(), d.getMonth(), d.getDay(), d.getHours(), d.getMinutes(), d.getSeconds()).toLocaleDateString()
                    }
                    formatGeneralizedTimeToTime(str) {
                        const d = new GeneralizedTime(str)
                        return new Date(d.getYear(), d.getMonth(), d.getDay(), d.getHours(), d.getMinutes(), d.getSeconds()).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})
                    }

                    render() {
                        let time;
                        let date;
                        if (this.props.time == null) {
                            time = ""
                            date = ""
                        } else {
                            time = this.formatGeneralizedTimeToTime(this.props.time.generalizedTime)
                            date = this.props.time == null ? "": this.formatGeneralizedTimeToDate(this.props.time.generalizedTime)
                        }
                        return `
                        &lt;div class="ticket"&gt;
                          &lt;div class="ticket_inner"&gt;

                            &lt;div class="country_container"&gt;
                              &lt;span class="tbml-country"&gt;${this.props._count}x ${this.props.countryA} vs ${this.props.countryB}&lt;/span&gt;
                            &lt;/div&gt;

                            &lt;div class="datetime_container"&gt;
                              &lt;span class="tbml-date"&gt;${date} | ${time}&lt;/span&gt;
                            &lt;/div&gt;

                            &lt;div class="venue_container"&gt;
                                &lt;span class="tbml-venue"&gt;${this.props.venue} | ${this.props.locality}&lt;/span&gt;
                            &lt;/div&gt;

                            &lt;div class="category_container"&gt;
                              &lt;span class="tbml-category"&gt;${this.props.category}, M${this.props.match}&lt;/span&gt;
                            &lt;/div&gt;

                          &lt;/div&gt;
                        &lt;/div&gt;
                        `;
                    }
                }

                web3.tokens.dataChanged = (oldTokens, updatedTokens, tokenCardId) =&gt; {
                    const currentTokenInstance = updatedTokens.currentInstance;
                    document.getElementById(tokenCardId).innerHTML = new Token(currentTokenInstance).render();
                };
                //
                </script>
                            </ts:view>
                        </ts:card>
                    </ts:cards>

                    <ts:ordering>
                        <ts:order bitmask="FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" name="default">
                            <ts:byName field="locality"></ts:byName>
                            <ts:byValue field="match"></ts:byValue>
                            <ts:byValue field="number"></ts:byValue>
                        </ts:order>
                        <ts:order bitmask="FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" name="concise">
                            <ts:byValue field="match"></ts:byValue>
                            <ts:byValue field="category"></ts:byValue>
                            <ts:byValue field="number"></ts:byValue>
                        </ts:order>
                    </ts:ordering>

                        <!--
                    There are 64 matches (1-64), each has up to 16 ticket classes,
                    within each class, there are less than 65536 tickets.  A compact
                    format identifier would consist of 26 bits:

                    [6] [4] [16]

                    Representing:

                        Match ID: 1-64
                        Class: 1-16
                        Seats: 0-65536

                    These are represented by 7 hex codes. Therefore 0x40F0481 means
                    the final match (64th), class F (highest) ticket number 1153. But
                    we didn't end up using this compatct form.

                    Information about a match, like Venue, City, Date, which team
                    against which, can all be looked up by MatchID. There are
                    advantages and disadvantages in encoding them by a look up table
                    or by a bit field.

                    The advantage of storing them as a bit field is that one can
                    enquiry the range of it in the market queue server without the
                    server kowing the meaning of the bitfields. Furthermore it make
                    the android and ios library which accesses the XML file a bit
                    easier to write, but at the cost that the ticket issuing
                    (authorisation) server is a bit more complicated.

                    For now we decide to use bit-fields.  The fields, together with
                    its bitwidth or byte-width are represented in this table:

                    Fields:           City,   Venue,  Date,   TeamA,  TeamB,  Match, Category
                    Maximum, 2018:    11,     12,     32,     32,     32,     64,    16
                    Maximum, all time:64,     64,     64,     32,     32,     64,    64
                    Bitwidth:         6,      6,      6,      5,      5,      6,     6
                    Bytewidth:        1,      1,      4,      3,      3,      1,     1,

                    In practise, because this XML file is used in 3 to 4 places
                    (authorisation server, ios, android, potentially market-queue),
                    Weiwu thought that it helps the developers if we use byte-fields
                    instead of bit-fields.
                    1.3.6.1.4.1.1466.115.121.1.15 is DirectoryString
                    1.3.6.1.4.1.1466.115.121.1.24 is GeneralisedTime
                    1.3.6.1.4.1.1466.115.121.1.27 is Integer
                  -->
                        <ts:attribute name="locality" oid="2.5.4.7">
                            <ts:type><ts:syntax>1.3.6.1.4.1.1466.115.121.1.15</ts:syntax></ts:type>
                            <ts:label>
                                <ts:string xml:lang="en">City</ts:string>
                                <ts:string xml:lang="zh">城市</ts:string>
                                <ts:string xml:lang="es">Ciudad</ts:string>
                                <ts:string xml:lang="ru">город</ts:string>
                            </ts:label>
                            <ts:origins>
                                <ts:token-id as="uint" bitmask="00000000000000000000000000000000FF000000000000000000000000000000">
                                    <ts:mapping>
                                        <ts:option key="1">
                                            <ts:value xml:lang="ru">Москва́</ts:value>
                                            <ts:value xml:lang="en">Moscow</ts:value>
                                            <ts:value xml:lang="zh">莫斯科</ts:value>
                                            <ts:value xml:lang="es">Moscú</ts:value>
                                        </ts:option>
                                        <ts:option key="2">
                                            <ts:value xml:lang="ru">Санкт-Петербу́рг</ts:value>
                                            <ts:value xml:lang="en">Saint Petersburg</ts:value>
                                            <ts:value xml:lang="zh">圣彼得堡</ts:value>
                                            <ts:value xml:lang="es">San Petersburgo</ts:value>
                                        </ts:option>
                                        <ts:option key="3">
                                            <ts:value xml:lang="ru">сочи</ts:value>
                                            <ts:value xml:lang="en">Sochi</ts:value>
                                            <ts:value xml:lang="zh">索契</ts:value>
                                            <ts:value xml:lang="es">Sochi</ts:value>
                                        </ts:option>
                                        <ts:option key="4">
                                            <ts:value xml:lang="ru">екатеринбург</ts:value>
                                            <ts:value xml:lang="en">Ekaterinburg</ts:value>
                                            <ts:value xml:lang="zh">叶卡捷琳堡</ts:value>
                                            <ts:value xml:lang="es">Ekaterinburg</ts:value>
                                        </ts:option>
                                        <ts:option key="5">
                                            <ts:value xml:lang="ru">Саранск</ts:value>
                                            <ts:value xml:lang="en">Saransk</ts:value>
                                            <ts:value xml:lang="zh">萨兰斯克</ts:value>
                                            <ts:value xml:lang="es">Saransk</ts:value>
                                        </ts:option>
                                        <ts:option key="6">
                                            <ts:value xml:lang="ru">казань</ts:value>
                                            <ts:value xml:lang="en">Kazan</ts:value>
                                            <ts:value xml:lang="zh">喀山</ts:value>
                                            <ts:value xml:lang="es">Kazan</ts:value>
                                        </ts:option>
                                        <ts:option key="7">
                                            <ts:value xml:lang="ru">Нижний Новгород</ts:value>
                                            <ts:value xml:lang="en">Nizhny Novgorod</ts:value>
                                            <ts:value xml:lang="zh">下诺夫哥罗德</ts:value>
                                            <ts:value xml:lang="es">Nizhny Novgorod</ts:value>
                                        </ts:option>
                                        <ts:option key="8">
                                            <ts:value xml:lang="ru">Ростов-на-Дону</ts:value>
                                            <ts:value xml:lang="en">Rostov-on-Don</ts:value>
                                            <ts:value xml:lang="zh">顿河畔罗斯托夫</ts:value>
                                            <ts:value xml:lang="es">Rostov-on-Don</ts:value>
                                        </ts:option>
                                        <ts:option key="9">
                                            <ts:value xml:lang="ru">Самара</ts:value>
                                            <ts:value xml:lang="en">Samara</ts:value>
                                            <ts:value xml:lang="zh">萨马拉</ts:value>
                                            <ts:value xml:lang="es">Samara</ts:value>
                                        </ts:option>
                                        <ts:option key="10">
                                            <ts:value xml:lang="ru">Волгоград</ts:value>
                                            <ts:value xml:lang="en">Volgograd</ts:value>
                                            <ts:value xml:lang="zh">伏尔加格勒</ts:value>
                                            <ts:value xml:lang="es">Volgogrado</ts:value>
                                        </ts:option>
                                        <ts:option key="11">
                                            <ts:value xml:lang="ru">Калининград</ts:value>
                                            <ts:value xml:lang="en">Kaliningrad</ts:value>
                                            <ts:value xml:lang="zh">加里宁格勒</ts:value>
                                            <ts:value xml:lang="es">Kaliningrad</ts:value>
                                        </ts:option>
                                    </ts:mapping>
                                </ts:token-id>
                            </ts:origins>
                        </ts:attribute>

                        <ts:attribute name="venue">
                            <ts:type><ts:syntax>1.3.6.1.4.1.1466.115.121.1.15</ts:syntax></ts:type>
                            <ts:label>
                                <ts:string xml:lang="en">Venue</ts:string>
                                <ts:string xml:lang="zh">场馆</ts:string>
                                <ts:string xml:lang="es">Lugar</ts:string>
                                <ts:string xml:lang="ru">место встречи</ts:string>
                            </ts:label>
                            <ts:origins>
                                <ts:token-id as="uint" bitmask="0000000000000000000000000000000000FF0000000000000000000000000000">
                                    <ts:mapping>
                                        <ts:option key="1">
                                            <ts:value xml:lang="ru">Стадион Калининград</ts:value>
                                            <ts:value xml:lang="en">Kaliningrad Stadium</ts:value>
                                            <ts:value xml:lang="zh">加里宁格勒体育场</ts:value>
                                            <ts:value xml:lang="es">Estadio de Kaliningrado</ts:value>
                                        </ts:option>
                                        <ts:option key="2">
                                            <ts:value xml:lang="ru">Екатеринбург Арена</ts:value>
                                            <ts:value xml:lang="en">Volgograd Arena</ts:value>
                                            <ts:value xml:lang="zh">伏尔加格勒体育场</ts:value>
                                            <ts:value xml:lang="es">Volgogrado Arena</ts:value>
                                        </ts:option>
                                        <ts:option key="3">
                                            <ts:value xml:lang="ru">Казань Арена</ts:value>
                                            <ts:value xml:lang="en">Ekaterinburg Arena</ts:value>
                                            <ts:value xml:lang="zh">加里宁格勒体育场</ts:value>
                                            <ts:value xml:lang="es">Ekaterimburgo Arena</ts:value>
                                        </ts:option>
                                        <ts:option key="4">
                                            <ts:value xml:lang="ru">Мордовия Арена</ts:value>
                                            <ts:value xml:lang="en">Fisht Stadium</ts:value>
                                            <ts:value xml:lang="zh">费什体育场</ts:value>
                                            <ts:value xml:lang="es">Estadio Fisht</ts:value>
                                        </ts:option>
                                        <ts:option key="5">
                                            <ts:value xml:lang="ru">Ростов Арена</ts:value>
                                            <ts:value xml:lang="en">Kazan Arena</ts:value>
                                            <ts:value xml:lang="zh">喀山体育场</ts:value>
                                            <ts:value xml:lang="es">Kazan Arena</ts:value>
                                        </ts:option>
                                        <ts:option key="6">
                                            <ts:value xml:lang="ru">Самара Арена</ts:value>
                                            <ts:value xml:lang="en">Nizhny Novgorod Stadium</ts:value>
                                            <ts:value xml:lang="zh">下诺夫哥罗德体育场</ts:value>
                                            <ts:value xml:lang="es">Estadio de Nizhni Novgorod</ts:value>
                                        </ts:option>
                                        <ts:option key="7">
                                            <ts:value xml:lang="ru">Стадион Калининград</ts:value>
                                            <ts:value xml:lang="en">Luzhniki Stadium</ts:value>
                                            <ts:value xml:lang="zh">卢日尼基体育场</ts:value>
                                            <ts:value xml:lang="es">Estadio Luzhniki</ts:value>
                                        </ts:option>
                                        <ts:option key="8">
                                            <ts:value xml:lang="ru">Стадион Лужники</ts:value>
                                            <ts:value xml:lang="en">Samara Arena</ts:value>
                                            <ts:value xml:lang="zh">萨马拉体育场</ts:value>
                                            <ts:value xml:lang="es">Samara Arena</ts:value>
                                        </ts:option>
                                        <ts:option key="9">
                                            <ts:value xml:lang="ru">Стадион Нижний Новгород</ts:value>
                                            <ts:value xml:lang="en">Rostov Arena</ts:value>
                                            <ts:value xml:lang="zh">罗斯托夫体育场</ts:value>
                                            <ts:value xml:lang="es">Rostov Arena</ts:value>
                                        </ts:option>
                                        <ts:option key="10">
                                            <ts:value xml:lang="ru">Стадион Спартак</ts:value>
                                            <ts:value xml:lang="en">Spartak Stadium</ts:value>
                                            <ts:value xml:lang="zh">斯巴达克体育场</ts:value>
                                            <ts:value xml:lang="es">Estadio del Spartak</ts:value>
                                        </ts:option>
                                        <ts:option key="11">
                                            <ts:value xml:lang="ru">Стадион Санкт-Петербург</ts:value>
                                            <ts:value xml:lang="en">Saint Petersburg Stadium</ts:value>
                                            <ts:value xml:lang="zh">圣彼得堡体育场</ts:value>
                                            <ts:value xml:lang="es">Estadio de San Petersburgo</ts:value>
                                        </ts:option>
                                        <ts:option key="12">
                                            <ts:value xml:lang="ru">Стадион Фишт</ts:value>
                                            <ts:value xml:lang="en">Mordovia Arena</ts:value>
                                            <ts:value xml:lang="zh">莫多维亚体育场</ts:value>
                                            <ts:value xml:lang="es">Mordovia Arena</ts:value>
                                        </ts:option>
                                    </ts:mapping>
                                </ts:token-id>
                            </ts:origins>
                        </ts:attribute>

                        <ts:attribute name="countryA">
                            <ts:type><ts:syntax>1.3.6.1.4.1.1466.115.121.1.26</ts:syntax></ts:type>
                            <!-- Intentionally avoid using countryName
                         (SYNTAX 1.3.6.1.4.1.1466.115.121.1.11) per RFC 4519
                             CountryName is two-characters long, not 3-characters.
                         -->
                            <ts:label>
                                <ts:string xml:lang="en">Team A</ts:string>
                                <ts:string xml:lang="zh">甲队</ts:string>
                                <ts:string xml:lang="es">Equipo A</ts:string>
                            </ts:label>
                            <ts:origins>
                                <ts:token-id as="utf8" bitmask="00000000000000000000000000000000000000000000FFFFFF00000000000000"></ts:token-id>
                            </ts:origins>
                        </ts:attribute>

                        <ts:attribute name="countryB">
                            <ts:type><ts:syntax>1.3.6.1.4.1.1466.115.121.1.26</ts:syntax></ts:type>
                            <ts:label>
                                <ts:string xml:lang="en">Team B</ts:string>
                                <ts:string xml:lang="zh">乙队</ts:string>
                                <ts:string xml:lang="es">Equipo B</ts:string>
                            </ts:label>
                            <ts:origins>
                                <ts:token-id as="utf8" bitmask="00000000000000000000000000000000000000000000000000FFFFFF00000000"></ts:token-id>
                            </ts:origins>
                        </ts:attribute>

                        <ts:attribute name="match">
                            <ts:type><ts:syntax>1.3.6.1.4.1.1466.115.121.1.27</ts:syntax></ts:type>
                            <ts:label>
                                <ts:string xml:lang="en">Match</ts:string>
                                <ts:string xml:lang="zh">场次</ts:string>
                                <ts:string xml:lang="es">Evento</ts:string>
                            </ts:label>
                            <ts:origins>
                                <ts:token-id as="utf8" bitmask="00000000000000000000000000000000000000000000000000000000FF000000"></ts:token-id>
                            </ts:origins>
                        </ts:attribute>

                        <ts:attribute name="category">
                            <ts:type><ts:syntax>1.3.6.1.4.1.1466.115.121.1.15</ts:syntax></ts:type>
                            <ts:label>
                                <ts:string xml:lang="en">Cat</ts:string>
                                <ts:string xml:lang="zh">等级</ts:string>
                                <ts:string xml:lang="es">Cat</ts:string>
                            </ts:label>
                            <ts:origins>
                                <ts:token-id as="uint" bitmask="0000000000000000000000000000000000000000000000000000000000FF0000">
                                    <ts:mapping>
                                        <ts:option key="1">
                                            <ts:value xml:lang="en">Category 1</ts:value>
                                            <ts:value xml:lang="zh">一类票</ts:value>
                                        </ts:option>
                                        <ts:option key="2">
                                            <ts:value xml:lang="en">Category 2</ts:value>
                                            <ts:value xml:lang="zh">二类票</ts:value>
                                        </ts:option>
                                        <ts:option key="3">
                                            <ts:value xml:lang="en">Category 3</ts:value>
                                            <ts:value xml:lang="zh">三类票</ts:value>
                                        </ts:option>
                                        <ts:option key="4">
                                            <ts:value xml:lang="en">Category 4</ts:value>
                                            <ts:value xml:lang="zh">四类票</ts:value>
                                        </ts:option>
                                        <ts:option key="5">
                                            <ts:value xml:lang="en">Match Club</ts:value>
                                            <ts:value xml:lang="zh">俱乐部坐席</ts:value>
                                        </ts:option>
                                        <ts:option key="6">
                                            <ts:value xml:lang="en">Match House Premier</ts:value>
                                            <ts:value xml:lang="zh">比赛之家坐席</ts:value>
                                        </ts:option>
                                        <ts:option key="7">
                                            <ts:value xml:lang="en">MATCH PAVILION</ts:value>
                                            <ts:value xml:lang="zh">款待大厅坐席</ts:value>
                                        </ts:option>
                                        <ts:option key="8">
                                            <ts:value xml:lang="en">MATCH BUSINESS SEAT</ts:value>
                                            <ts:value xml:lang="zh">商务坐席</ts:value>
                                        </ts:option>
                                        <ts:option key="9">
                                            <ts:value xml:lang="en">MATCH SHARED SUITE</ts:value>
                                            <ts:value xml:lang="zh">公共包厢</ts:value>
                                        </ts:option>
                                        <ts:option key="10">
                                            <ts:value xml:lang="en">TSARSKY LOUNGE</ts:value>
                                            <ts:value xml:lang="zh">特拉斯基豪华包厢</ts:value>
                                        </ts:option>
                                        <ts:option key="11">
                                            <ts:value xml:lang="en">MATCH PRIVATE SUITE</ts:value>
                                            <ts:value xml:lang="zh">私人包厢</ts:value>
                                        </ts:option>
                                    </ts:mapping>
                                </ts:token-id>
                            </ts:origins>
                        </ts:attribute>
                        <ts:attribute name="time">
                            <ts:type><ts:syntax>1.3.6.1.4.1.1466.115.121.1.24</ts:syntax></ts:type>
                            <ts:label>
                                <ts:string xml:lang="en">Time</ts:string>
                                <ts:string xml:lang="zh">时间</ts:string>
                                <ts:string xml:lang="es">Tiempo</ts:string>
                                <ts:string xml:lang="ru">время</ts:string>
                            </ts:label>
                            <ts:origins>
                                <ts:token-id as="uint" bitmask="000000000000000000000000000000000000FFFFFFFF00000000000000000000">
                                    <ts:mapping>
                                        <!-- $ TZ=Europe/Moscow date -d @1528988400 +%Y%m%d%H%M%S%z -->
                                        <ts:option key="1528988400">
                                            <ts:value>20180614180000+0300</ts:value>
                                        </ts:option>
                                        <!-- $ TZ=Europe/Moscow date -d @1529074800 +%Y%m%d%H%M%S%z -->
                                        <ts:option key="1529074800">
                                            <ts:value>20180615180000+0300</ts:value>
                                        </ts:option>
                                        <!-- $ TZ=Europe/Moscow date -d @1529420400 +%Y%m%d%H%M%S%z -->
                                        <ts:option key="1529420400">
                                            <ts:value>20180619180000+0300</ts:value>
                                        </ts:option>
                                        <!-- $ TZ=Europe/Moscow date -d @1529431200 +%Y%m%d%H%M%S%z -->
                                        <ts:option key="1529431200">
                                            <ts:value>20180619210000+0300</ts:value>
                                        </ts:option>
                                        <!-- $ TZ=Europe/Moscow date -d @1530900000 +%Y%m%d%H%M%S%z -->
                                        <ts:option key="1530900000">
                                            <ts:value>20180706210000+0300</ts:value>
                                        </ts:option>
                                        <!-- $ TZ=Europe/Moscow date -d @1531576800 +%Y%m%d%H%M%S%z -->
                                        <ts:option key="1531576800">
                                            <ts:value>20180714170000+0300</ts:value>
                                        </ts:option>
                                    </ts:mapping>
                                </ts:token-id>
                            </ts:origins>
                        </ts:attribute>

                        <ts:attribute name="numero">
                            <ts:type><ts:syntax>1.3.6.1.4.1.1466.115.121.1.27</ts:syntax></ts:type>
                            <ts:label>
                                <ts:string>№</ts:string>
                            </ts:label>
                            <ts:origins>
                                <ts:token-id as="uint" bitmask="000000000000000000000000000000000000000000000000000000000000FFFF"></ts:token-id>
                            </ts:origins>
                        </ts:attribute>

                </ts:token>
            """
        let contractAddress = AlphaWallet.Address(string: "0xA66A3F08068174e8F005112A8b2c7A507a822335")!
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore(), networkService: FakeNetworkService(), blockchainsProvider: BlockchainsProvider.make(servers: [.main]))

        store[contractAddress] = xml
        let xmlHandler = XMLHandler(contract: contractAddress, tokenType: .erc20, assetDefinitionStore: store)
        let tokenId = BigUInt("0000000000000000000000000000000002000000000000000000000000000000", radix: 16)!
        let server: RPCServer = .main
        let token = xmlHandler.getToken(name: "Some name", symbol: "Some symbol", fromTokenIdOrEvent: .tokenId(tokenId: tokenId), index: 1, inWallet: .make(), server: server, tokenType: TokenType.erc875, assetDefinitionStore: store)
        let values = token.values

        XCTAssertEqual(values["locality"]?.stringValue, "Saint Petersburg")
    }
    // swiftlint:enable function_body_length

    func testNoAssetDefinition() {
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore(), networkService: FakeNetworkService(), blockchainsProvider: BlockchainsProvider.make(servers: [.main]))
        let xmlHandler = XMLHandler(contract: Constants.nullAddress, tokenType: .erc875, assetDefinitionStore: store)
        let tokenId = BigUInt("0000000000000000000000000000000002000000000000000000000000000000", radix: 16)!
        let server: RPCServer = .main
        let token = xmlHandler.getToken(name: "Some name", symbol: "Some symbol", fromTokenIdOrEvent: .tokenId(tokenId: tokenId), index: 1, inWallet: .make(), server: server, tokenType: TokenType.erc721, assetDefinitionStore: store)
        let values = token.values
        XCTAssertTrue(values.isEmpty)
    }

    func testXPathNamePrefixing() {
        XCTAssertEqual("".addToXPath(namespacePrefix: "tb1:"), "")
        XCTAssertEqual("/part1/part2/part3".addToXPath(namespacePrefix: "tb1:"), "/tb1:part1/tb1:part2/tb1:part3")
        XCTAssertEqual("part1/part2/part3".addToXPath(namespacePrefix: "tb1:"), "tb1:part1/tb1:part2/tb1:part3")
    }
}
// swiftlint:enable type_body_length
