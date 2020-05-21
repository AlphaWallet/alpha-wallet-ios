//
//  XMLHandlerTest.swift
//  AlphaWalletTests
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation
import XCTest
@testable import AlphaWallet
import BigInt

class XMLHandlerTest: XCTestCase {
    let tokenHex = "0x00000000000000000000000000000000fefe5ae99a3000000000000000010001".substring(from: 2)

    override func tearDown() {
        XMLHandler.invalidateAllContracts()
    }

    func testParser() {
        let assetDefinitionStore = AssetDefinitionStore()
        let token = XMLHandler(contract: Constants.nullAddress, assetDefinitionStore: assetDefinitionStore).getToken(
                name: "",
                symbol: "",
                fromTokenIdOrEvent: .tokenId(tokenId: BigUInt(tokenHex, radix: 16)!),
                index: UInt16(1),
                inWallet: .make(),
                server: .main,
                tokenType: TokenType.erc875
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

    func testExtractingAttributesWithNamespaceInXML() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <!DOCTYPE token  [
                <!ENTITY fifa.en SYSTEM "fifa.en.js">
                <!ENTITY style SYSTEM "shared.css">
                ]>
        <ts:token xmlns:ts="http://tokenscript.org/2020/06/tokenscript"
                  xmlns:ethereum="urn:ethereum:constantinople"
                  xmlns:xhtml="http://www.w3.org/1999/xhtml"
                  xmlns:xml="http://www.w3.org/XML/1998/namespace"
                  xsi:schemaLocation="http://tokenscript.org/2020/06/tokenscript http://tokenscript.org/2020/06/tokenscript.xsd"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                  custodian="false"
        >
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

            <ts:contract name="FIFA" interface="erc875">
                <ts:address network="1">0xA66A3F08068174e8F005112A8b2c7A507a822335</ts:address>
            </ts:contract>

            <ts:origins>
                <!-- Define the contract which holds the token that the user will use -->
                <ts:ethereum contract="FIFA"/>
            </ts:origins>

            <ts:cards>
                <ts:card type="token">
                    <ts:item-view xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
                        <xhtml:style type="text/css">&style;</xhtml:style>
                        <script type="text/javascript">&fifa.en;</script>
                    </ts:item-view>
                    <ts:view xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
                        <xhtml:style type="text/css">&style;</xhtml:style>
                        <script type="text/javascript">&fifa.en;</script>
                    </ts:view>
                </ts:card>
            </ts:cards>

            <ts:ordering>
                <ts:order bitmask="FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" name="default">
                    <ts:byName field="locality"/>
                    <ts:byValue field="match"/>
                    <ts:byValue field="number"/>
                </ts:order>
                <ts:order bitmask="FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" name="concise">
                    <ts:byValue field="match"/>
                    <ts:byValue field="category"/>
                    <ts:byValue field="number"/>
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
                <ts:attribute-type name="locality" oid="2.5.4.7" syntax="1.3.6.1.4.1.1466.115.121.1.15">
                    <ts:label>
                        <ts:string xml:lang="en">City</ts:string>
                        <ts:string xml:lang="zh">城市</ts:string>
                        <ts:string xml:lang="es">Ciudad</ts:string>
                        <ts:string xml:lang="ru">город</ts:string>
                    </ts:label>
                    <ts:origins>
                        <ts:token-id bitmask="00000000000000000000000000000000FF000000000000000000000000000000" as="uint">
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
                </ts:attribute-type>

                <ts:attribute-type name="venue" syntax="1.3.6.1.4.1.1466.115.121.1.15">
                    <ts:label>
                        <ts:string xml:lang="en">Venue</ts:string>
                        <ts:string xml:lang="zh">场馆</ts:string>
                        <ts:string xml:lang="es">Lugar</ts:string>
                        <ts:string xml:lang="ru">место встречи</ts:string>
                    </ts:label>
                    <ts:origins>
                        <ts:token-id bitmask="0000000000000000000000000000000000FF0000000000000000000000000000" as="uint">
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
                </ts:attribute-type>

                <ts:attribute-type name="countryA" syntax="1.3.6.1.4.1.1466.115.121.1.26">
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
                        <ts:token-id bitmask="00000000000000000000000000000000000000000000FFFFFF00000000000000" as="utf8"/>
                    </ts:origins>
                </ts:attribute-type>

                <ts:attribute-type name="countryB" syntax="1.3.6.1.4.1.1466.115.121.1.26">
                    <ts:label>
                        <ts:string xml:lang="en">Team B</ts:string>
                        <ts:string xml:lang="zh">乙队</ts:string>
                        <ts:string xml:lang="es">Equipo B</ts:string>
                    </ts:label>
                    <ts:origins>
                        <ts:token-id bitmask="00000000000000000000000000000000000000000000000000FFFFFF00000000" as="utf8"/>
                    </ts:origins>
                </ts:attribute-type>

                <ts:attribute-type name="match" syntax="1.3.6.1.4.1.1466.115.121.1.27">
                    <ts:label>
                        <ts:string xml:lang="en">Match</ts:string>
                        <ts:string xml:lang="zh">场次</ts:string>
                        <ts:string xml:lang="es">Evento</ts:string>
                    </ts:label>
                    <ts:origins>
                        <ts:token-id bitmask="00000000000000000000000000000000000000000000000000000000FF000000" as="utf8"/>
                    </ts:origins>
                </ts:attribute-type>

                <ts:attribute-type name="category" syntax="1.3.6.1.4.1.1466.115.121.1.15">
                    <ts:label>
                        <ts:string xml:lang="en">Cat</ts:string>
                        <ts:string xml:lang="zh">等级</ts:string>
                        <ts:string xml:lang="es">Cat</ts:string>
                    </ts:label>
                    <ts:origins>
                        <ts:token-id bitmask="0000000000000000000000000000000000000000000000000000000000FF0000" as="uint">
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
                </ts:attribute-type>
                <ts:attribute-type name="time" syntax="1.3.6.1.4.1.1466.115.121.1.24">
                    <ts:label>
                        <ts:string xml:lang="en">Time</ts:string>
                        <ts:string xml:lang="zh">时间</ts:string>
                        <ts:string xml:lang="es">Tiempo</ts:string>
                        <ts:string xml:lang="ru">время</ts:string>
                    </ts:label>
                    <ts:origins>
                        <ts:token-id bitmask="000000000000000000000000000000000000FFFFFFFF00000000000000000000" as="uint">
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
                </ts:attribute-type>

                <ts:attribute-type name="numero" syntax="1.3.6.1.4.1.1466.115.121.1.27">
                    <ts:label>
                        <ts:string>№</ts:string>
                    </ts:label>
                    <ts:origins>
                        <ts:token-id bitmask="000000000000000000000000000000000000000000000000000000000000FFFF" as="uint"/>
                    </ts:origins>
                </ts:attribute-type>

        </ts:token>

        """
        let contractAddress = AlphaWallet.Address(string: "0xA66A3F08068174e8F005112A8b2c7A507a822335")!
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        store[contractAddress] = xml
        let xmlHandler = XMLHandler(contract: contractAddress, assetDefinitionStore: store)
        let tokenId = BigUInt("0000000000000000000000000000000002000000000000000000000000000000", radix: 16)!
        let server: RPCServer = .main
        let token = xmlHandler.getToken(name: "Some name", symbol: "Some symbol", fromTokenIdOrEvent: .tokenId(tokenId: tokenId), index: 1, inWallet: .make(), server: server, tokenType: TokenType.erc875)
        let values = token.values
        XCTAssertEqual(values["locality"]?.stringValue, "Saint Petersburg")
    }

    func testNoAssetDefinition() {
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        let xmlHandler = XMLHandler(contract: Constants.nullAddress, assetDefinitionStore: store)
        let tokenId = BigUInt("0000000000000000000000000000000002000000000000000000000000000000", radix: 16)!
        let server: RPCServer = .main
        let token = xmlHandler.getToken(name: "Some name", symbol: "Some symbol", fromTokenIdOrEvent: .tokenId(tokenId: tokenId), index: 1, inWallet: .make(), server: server, tokenType: TokenType.erc721)
        let values = token.values
        XCTAssertTrue(values.isEmpty)
    }

    func testXPathNamePrefixing() {
        XCTAssertEqual("".addToXPath(namespacePrefix: "tb1:"), "")
        XCTAssertEqual("/part1/part2/part3".addToXPath(namespacePrefix: "tb1:"), "/tb1:part1/tb1:part2/tb1:part3")
        XCTAssertEqual("part1/part2/part3".addToXPath(namespacePrefix: "tb1:"), "tb1:part1/tb1:part2/tb1:part3")
    }
}
