// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

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

        //aave v1, v2
        case "0xba3D9687Cf50fE253cd2e1cFeEdE1d6787344Ed5", "0xFFC97d72E13E01096502Cb8Eb52dEe56f74DAD7B":  //    Aave: aAAVE Token V2
            return R.image.iconsTokensAAave()
        case "0xE1BA0FB44CCb0D11b80F92f4f8Ed94CA3fF51D00", "0x05Ec93c0365baAeAbF7AefFb0972ea7ECdD39CF1":  //    Aave: aBAT Token V2
            return R.image.iconsTokensABat()
        case "0x6Ee0f7BB50a54AB5253dA0667B0Dc2ee526C30a8", "0xA361718326c15715591c299427c62086F69923D9":  //    Aave: aBUSD Token V2
            return R.image.iconsTokensABusd()
        case "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d", "0x028171bCA77440897B824Ca71D1c56caC55b68A3":  //    Aave: aDAI Token V2
            return R.image.iconsTokensADai()
        case "0xaC6Df26a590F08dcC95D5a4705ae8abbc88509Ef":  //    Aave: aENJ Token V2
            return R.image.iconsTokensAEnj()
        case "0x9D91BE44C06d373a8a226E1f3b146956083803eB", "0x39C6b3e42d6A679d7D776778Fe880BC9487C2EDA":  //    Aave: aKNC Token V2
            return R.image.iconsTokensAKnc()
        case "0xA64BD6C70Cb9051F6A9ba1F163Fdc07E0DfB5F84", "0xa06bC25B5805d5F8d82847D191Cb4Af5A3e873E0":  //    Aave: aLINK Token V2
            return R.image.iconsTokensALink()
        case "0x6FCE4A401B6B80ACe52baAefE4421Bd188e76F6f", "0xa685a61171bb30d4072B338c80Cb7b2c865c873E":  //    Aave: aMANA Token V2
            return R.image.iconsTokensAMana()
        case "0x7deB5e830be29F91E298ba5FF1356BB7f8146998", "0xc713e5E149D5D0715DcD1c156a020976e7E56B88":  //    Aave: aMKR Token V2
            return R.image.iconsTokensAMkr()
        case "0xCC12AbE4ff81c9378D670De1b57F8e0Dd228D77a":  //    Aave: aREN Token V2
            return R.image.iconsTokensARep()
        case "0x328C4c80BC7aCa0834Db37e6600A6c49E12Da4DE", "0x35f6B052C598d933D69A4EEC4D04c73A191fE6c2":  //    Aave: aSNX Token V2
            return R.image.iconsTokensASnx()
        case "0x625aE63000f46200499120B906716420bd059240", "0x6C5024Cd4F8A59110119C56f8933403A539555EB":  //    Aave: aSUSD Token V2
            return R.image.iconsTokensASusd()
        case "0x4DA9b813057D04BAef4e5800E36083717b4a0341", "0x101cc05f4A51C0319f570d5E146a8C625198e636":  //    Aave: aTUSD Token V2
            return R.image.iconsTokensATusd()
        case "0xB9D7CB55f463405CDfBe4E90a6D2Df01C2B92BF1":  //    Aave: aUNI Token V2
            return R.image.iconsTokensAUniLinkEth()
        case "0x9bA00D6856a4eDF4665BcA2C2309936572473B7E", "0xBcca60bB61934080951369a648Fb03DF4F96263C":  //    Aave: aUSDC Token V2
            return R.image.iconsTokensAUsdc()
        case "0x71fc860F7D3A592A4a98740e39dB31d25db65ae8", "0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811":  //    Aave: aUSDT Token V2
            return R.image.iconsTokensAUsdt()
        case "0xFC4B8ED459e00e5400be803A9BB3954234FD50e3", "0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656":  //    Aave: aWBTC Token V2
            return R.image.iconsTokensAWbtc()
        case "0x030bA81f1c18d280636F32af80b9AAd02Cf0854e":  //    Aave: aWETH Token V2
            return R.image.iconsTokensAWeth()
        case "0x5165d24277cD063F5ac44Efd447B27025e888f37":  //    Aave: aYFI Token V2
            return R.image.iconsTokensAYfi()
        case "0x6Fb0855c404E09c47C3fBCA25f08d4E41f9F062f", "0xDf7FF54aAcAcbFf42dfe29DD6144A69b629f8C9e":  //    Aave: aZRX Token V2
            return R.image.iconsTokensA0X()

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
//        case "p-sai":
//            return R.image.tokenPsai()
//        case "p-eos":
//            return R.image.tokenPeos()

        //CoFiX
        case "0x1a23a6BfBAdB59fa563008c0fB7cf96dfCF34Ea1":
            return R.image.tokenCofi()
        case "0xb2b7BeDd7d7fc19804C7Dd4a4E8174C4c73C210d":
            return R.image.tokenCofix()

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
