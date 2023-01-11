// Copyright © 2019 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class QRCodeValueParserTests: XCTestCase {
    func testEmptyString() {
        let result = AddressOrEip681Parser.from(string: "")

        XCTAssertNil(result)
    }

    func testJustAddressString() {
        let input = "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c"
        guard let result = AddressOrEip681Parser.from(string: input) else { return XCTFail("Can't parse address-only") }
        switch result {
        case .address(let address):
            XCTAssertTrue(address.sameContract(as: input))
        case .eip681:
            XCTFail("Can't parse address-only")
        }
    }

    func testInvalidJustAddressStringWithEip681Prefix() {
        let input = "pay-0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c"
        XCTAssertNil(AddressOrEip681Parser.from(string: input))
    }

    func testJustAddressString2() {
        let input = "0x6973dbabeb06dd60f1c50ed688fe11e742bc123e"
        guard let result = AddressOrEip681Parser.from(string: input) else { return XCTFail("Can't parse address-only") }
        switch result {
        case .address(let address):
            XCTAssertTrue(address.sameContract(as: input))
        case .eip681:
            XCTFail("Can't parse address-only")
        }
    }

    func testProtocolAndAddress() {
        guard let result = AddressOrEip681Parser.from(string: "ethereum:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, _, _, _):
            XCTAssertEqual(Eip681Parser.scheme, protocolName)
        }
    }

    func testEthereumAddress() {
        guard let result = AddressOrEip681Parser.from(string: "ethereum:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(_, let address, _, _):
            XCTAssertTrue(address.sameContract(as: "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c"))
        }
    }

    func testEthereumAddressWithValue() {
        guard let result = AddressOrEip681Parser.from(string: "ethereum:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c?value=1") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(_, let address, _, _):
            XCTAssertTrue(address.sameContract(as: "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c"))
        }
    }

    func testExtractChain() {
        guard let result = AddressOrEip681Parser.from(string: "ethereum:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c@3?value=1") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(_, _, _, let params):
            XCTAssertEqual("3", params["chainId"])
        }
    }

    func testOMGAddress() {
        guard let result = AddressOrEip681Parser.from(string: "omg:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, _, _):
            XCTAssertEqual("omg", protocolName)
            XCTAssertTrue(address.sameContract(as: "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c"))
        }
    }

    func testBancorAddress() {
        guard let result = AddressOrEip681Parser.from(string: "bancor:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, _, _):
            XCTAssertEqual("bancor", protocolName)
            XCTAssertTrue(address.sameContract(as: "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c"))
        }
    }

    func testParseData() {
        guard let result = AddressOrEip681Parser.from(string: "ethereum:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c?data=0x123") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, _, _, let params):
            XCTAssertEqual(Eip681Parser.scheme, protocolName)
            XCTAssertEqual(1, params.count)
            XCTAssertEqual("0x123", params["data"])
        }
    }
    
    func testParseMultipleValues() {
        guard let result = AddressOrEip681Parser.from(string: "ethereum:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c?data=0x123&amount=1.0") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, _, _, let params):
            XCTAssertEqual(Eip681Parser.scheme, protocolName)
            XCTAssertEqual(2, params.count)
            XCTAssertEqual("0x123", params["data"])
            XCTAssertEqual("1.0", params["amount"])
        }
    }

    func testParseCommaDecimalSeparator() {
        guard let result = AddressOrEip681Parser.from(string: "ethereum:0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c?data=0x123&amount=1,01") else { return XCTFail("Can't parse EIP 681") }
        switch result {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, _, _, let params):
            XCTAssertEqual(Eip681Parser.scheme, protocolName)
            XCTAssertEqual(2, params.count)
            XCTAssertEqual("0x123", params["data"])
            XCTAssertEqual("1,01", params["amount"])
        }
    }

    func testParseNativeCryptoSend() {
        guard let qrCodeValue = AddressOrEip681Parser.from(string: "ethereum:0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359?value=2.014e18") else { return XCTFail("Can't parse EIP 681") }
        switch qrCodeValue {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, let functionName, let params):
            switch Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse() {
            case .nativeCryptoSend(let chainId, let recipient, let amount):
                XCTAssertNil(chainId)
                XCTAssertTrue(recipient.sameContract(as: "0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359"))
                XCTAssertEqual(amount.rawValue, "2014000000000000000")
            case .erc20Send, .invalidOrNotSupported:
                XCTFail("Parsed as wrong EIP 681 type")
            }
        }
    }

    func testParseNativeCryptoSendWithScientificNotation() {
        guard let qrCodeValue = AddressOrEip681Parser.from(string: "ethereum:0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359?value=2.014e18") else { return XCTFail("Can't parse EIP 681") }
        switch qrCodeValue {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, let functionName, let params):
            switch Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse() {
            case .nativeCryptoSend(let chainId, let recipient, let amount):
                XCTAssertNil(chainId)
                XCTAssertTrue(recipient.sameContract(as: "0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359"))
                XCTAssertEqual(amount.rawValue, "2014000000000000000")
            case .erc20Send, .invalidOrNotSupported:
                XCTFail("Parsed as wrong EIP 681 type")
            }
        }
    }

    func testParseErc20Send() {
        guard let qrCodeValue = AddressOrEip681Parser.from(string: "ethereum:0x744d70fdbe2ba4cf95131626614a1763df805b9e/transfer?address=0x3d597789ea16054a084ac84ce87f50df9198f415&uint256=314e17") else { return XCTFail("Can't parse EIP 681") }
        switch qrCodeValue {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, let functionName, let params):
            switch Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse() {
            case .erc20Send(let contract, let chainId, let recipient, let amount):
                XCTAssertEqual(contract, AlphaWallet.Address(string: "0x744d70fdbe2ba4cf95131626614a1763df805b9e"))
                XCTAssertNil(chainId)
                XCTAssertTrue(recipient?.sameContract(as: "0x3d597789ea16054a084ac84ce87f50df9198f415") ?? false)
                XCTAssertEqual(amount.rawValue, "31400000000000000000")
            case .nativeCryptoSend, .invalidOrNotSupported:
                XCTFail("Parsed as wrong EIP 681 type")
            }
        }
    }

    func testParseErc20SendWithoutRecipient() {
        guard let qrCodeValue = AddressOrEip681Parser.from(string: "ethereum:0x60fa213f48cd0d83b54380108ccd03a6993247e0/transfer?uint256=1.5e18") else { return XCTFail("Can't parse EIP 681") }
        switch qrCodeValue {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, let functionName, let params):
            switch Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse() {
            case .erc20Send(let contract, let chainId, let recipient, let amount):
                XCTAssertEqual(contract, AlphaWallet.Address(string: "0x60fa213f48cd0d83b54380108ccd03a6993247e0"))
                XCTAssertNil(chainId)
                XCTAssertNil(recipient)
                XCTAssertEqual(amount.rawValue, "1500000000000000000")
            case .nativeCryptoSend, .invalidOrNotSupported:
                XCTFail("Parsed as wrong EIP 681 type")
            }
        }
    }

    func testParseNativeCryptoSendWithoutValue() {
        guard let qrCodeValue = AddressOrEip681Parser.from(string: "ethereum:0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359") else { return XCTFail("Can't parse EIP 681") }
        switch qrCodeValue {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, let functionName, let params):
            switch Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse() {
            case .nativeCryptoSend(let chainId, let recipient, let amount):
                XCTAssertNil(chainId)
                XCTAssertTrue(recipient.sameContract(as: "0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359"))
                XCTAssertEqual(amount.rawValue, "")
            case .erc20Send, .invalidOrNotSupported:
                XCTFail("Parsed as wrong EIP 681 type")
            }
        }
    }

    func testParseErc20SendWithoutAmount() {
        guard let qrCodeValue = AddressOrEip681Parser.from(string: "ethereum:0x744d70fdbe2ba4cf95131626614a1763df805b9e/transfer?address=0x3d597789ea16054a084ac84ce87f50df9198f415") else { return XCTFail("Can't parse EIP 681") }
        switch qrCodeValue {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, let functionName, let params):

            switch Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse() {
            case .erc20Send(let contract, let chainId, let recipient, let amount):
                XCTAssertEqual(contract, AlphaWallet.Address(string: "0x744d70fdbe2ba4cf95131626614a1763df805b9e"))
                XCTAssertNil(chainId)
                XCTAssertTrue(recipient?.sameContract(as: "0x3d597789ea16054a084ac84ce87f50df9198f415") ?? false)
                XCTAssertEqual(amount.rawValue, "")
            case .nativeCryptoSend, .invalidOrNotSupported:
                XCTFail("Parsed as wrong EIP 681 type")
            }
        }
    }

    func testParseInvalidNativeCryptoSend() {
        guard let qrCodeValue = AddressOrEip681Parser.from(string: "ethereum:0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359/foo?value=2.014e18") else { return XCTFail("Can't parse EIP 681") }
        switch qrCodeValue {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, let functionName, let params):
            switch Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse() {
            case .nativeCryptoSend, .erc20Send:
                XCTFail("Parsed as wrong EIP 681 type")
            case .invalidOrNotSupported:
                XCTAssert(true)
            }
        }
    }

    func testParseNativeCryptoSendWithoutValueWithEnsName() {
        guard let qrCodeValue = AddressOrEip681Parser.from(string: "ethereum:foo.eth") else { return XCTFail("Can't parse EIP 681") }
        switch qrCodeValue {
        case .address:
            XCTFail("Can't parse EIP 681")
        case .eip681(let protocolName, let address, let functionName, let params):
            switch Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse() {
            case .nativeCryptoSend(let chainId, let recipient, let amount):
                XCTAssertNil(chainId)
                XCTAssertTrue(recipient.stringValue == "foo.eth")
                XCTAssertEqual(amount.rawValue, "")
            case .erc20Send, .invalidOrNotSupported:
                XCTFail("Parsed as wrong EIP 681 type")
            }
        }
    }
}
