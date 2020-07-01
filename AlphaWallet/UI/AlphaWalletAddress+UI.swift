// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

extension AlphaWallet.Address {
    var tokenImage: UIImage? {
        switch eip55String {
        case "0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643":
            return R.image.tokenCdai()
        case "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359":
            return R.image.tokenDai()
        case "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2":
            return R.image.tokenWeth()
        case "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599":
            return R.image.tokenWbtc()
        case "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48":
            return R.image.tokenUsdc()
        case "0x493C57C4763932315A328269E1ADaD09653B9081":
            return R.image.tokenIdai()

        //p_tokens
        case "0x47421D4D41196475cd9f84cC3FCDA056BA6Bde64":
            return R.image.tokenPdai()
        case "0x5228a22e72ccC52d415EcFd199F99D0665E7733b":
            return R.image.tokenPbtc()
        case "0xf53AD2c6851052A81B42133467480961B2321C09":
            return R.image.tokenPeth()
        case "0x429D83Bb0DCB8cdd5311e34680ADC8B12070a07f":
            return R.image.tokenPltc()
        case "0xea5c61205fB4A255Af041E8350AAA9343C516E55":
            return R.image.tokenPusdt()
        
//        case "":
//            return R.image.tokenPeos()
//        case "":
//            return R.image.ps

        //other
        case "0xbd31496feb604F9eC6a1C78c3371f8cFd220f5F2":
            return R.image.tokenTeo()
        case "0x86Fa049857E0209aa7D9e616F7eb3b3B78ECfdb0":
            return R.image.tokenEos()
        case "0x04abEdA201850aC0124161F037Efd70c74ddC74C":
            return R.image.tokenNest()
        case "0x514910771AF9Ca656af840dff83E8264EcF986CA":
            return R.image.tokenLink()
        case "0x5401b9687a08b15CFca344EdEc7c1486bDaf9e32":
            return R.image.ethSmall()

        //s_tokens
        case "0xbBC455cb4F1B9e4bFC4B73970d360c8f032EfEE6":
            return R.image.tokenSlink()
        case "0x261EfCdD24CeA98652B9700800a13DfBca4103fF":
            return R.image.tokenSxau()
        case "0x757de3ac6B830a931eF178C6634c5C551773155c":
            return R.image.tokenSnikkei()
        case "0x5e74C9036fb86BD7eCdcb084a0673EFc32eA31cb":
            return R.image.tokenSeth()
        case "0xC14103C2141E842e228FBaC594579e798616ce7A":
            return R.image.tokenSltc()
        case "0xe36E2D3c7c34281FA3bC737950a68571736880A1":
            return R.image.tokenSada()
        case "0xe1aFe1Fd76Fd88f78cBf599ea1846231B8bA3B6B":
            return R.image.tokenSdefi()
        case "0x5299d6F7472DCc137D7f3C4BcfBBB514BaBF341A":
            return R.image.tokenSxmr()
        case "0x2e59005c5c0f0a4D77CcA82653d48b46322EE5Cd":
            return R.image.tokenSxtz()
        case "0xfE18be6b3Bd88A2D2A7f928d00292E7a9963CfC6":
            return R.image.tokenSbtc()
        case "0x57Ab1ec28D129707052df4dF418D58a2D46d5f51":
            return R.image.tokenSusd()
        case "0x0F83287FF768D1c1e17a42F44d644D7F22e8ee1d":
            return R.image.tokenSchf()
        case "0xF6b1C627e95BFc3c1b4c9B825a032Ff0fBf3e07d":
            return R.image.tokenSjpy()
        case "0xD71eCFF9342A5Ced620049e616c5035F1dB98620":
            return R.image.tokenSeur()
        case "0x97fe22E7341a0Cd8Db6F6C021A24Dc8f4DAD855F":
            return R.image.tokenSgbp()
        case "0xF48e200EAF9906362BB1442fca31e0835773b8B4":
            return R.image.tokenSaud()
        default:
            return nil
        }
    }
}
