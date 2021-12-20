# AlphaWallet - Advanced, Open Source Ethereum Mobile Wallet & dApp Browser for iOS

[![Build Status](https://travis-ci.com/AlphaWallet/alpha-wallet-ios.svg?branch=master)](https://github.com/AlphaWallet/alpha-wallet-ios/tree/master)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg )](https://GitHub.com/AlphaWallet/alpha-wallet-ios/graphs/commit-activity)
[![GitHub contributors](https://img.shields.io/github/contributors/AlphaWallet/alpha-wallet-ios.svg)](https://github.com/AlphaWallet/alpha-wallet-ios/graphs/contributors)
[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/AlphaWallet/alpha-wallet-ios/blob/master/LICENSE)
[![codecov](https://codecov.io/gh/AlphaWallet/alpha-wallet-ios/branch/master/graph/badge.svg )](https://codecov.io/gh/AlphaWallet/alpha-wallet-ios)

AlphaWallet is an open source programmable blockchain apps platform. It's compatible with tokenisation framework TokenScript, offering businesses and their users in-depth token interaction, a clean white label user experience and advanced security options. Supports all Ethereum based networks.

AlphaWallet and TokenScript have been used by tokenisation projects like FIFA and UEFA’s [blockchain tickets](https://apps.apple.com/au/app/shankai/id1492559481), Bartercard’s [Qoin ecommerce ecosystem](https://apps.apple.com/au/app/qoin-wallet/id1483718254), several Automobiles’ [car ownership portal](https://github.com/AlphaWallet/TokenScript-Examples/tree/master/examples/Karma) and many more.

⭐ Star us on GitHub — it helps!

[![alphawallet open source wallet ios preview](/resources/alphawallet-open-source-ethereum-wallet.jpg)](https://alphawallet.com/)

<a href='https://itunes.apple.com/us/app/alphawallet/id1358230430?ls=1&mt=8'><img alt='Get AlphaWallet Open Source Wallet on Apple Store' src='/resources/download-app-store-button.svg' height="60"/></a>

## About AlphaWallet - Features

Easy to use and secure open source Ethereum wallet for iOS and Android, with native ERC20, ERC721 and ERC875 support. AlphaWallet supports all Ethereum based networks: Ethereum, xDai, Ethereum Classic, Artis, POA, Ropsten, Goerli, Kovan, Rinkeby and Sokol.

- Beginner Friendly
- Secure Enclave Security
- Web3 dApp Browser
- TokenScript Enabled
- Interact with DeFi, DAO and Games with SmartTokens
- No hidden fees or tech background needed

### AlphaWallet Is A Token Wallet

AlphaWallet's focus is to provide an interface to interact with Ethereum Tokens in an intuitive, simple and full featured manner. This is what sets us aside from other open source ethereum wallets.

### Select Use Cases

- [Bartercard Qoin](https://play.google.com/store/apps/details?id=com.qoin.wallet&hl=en)
- [FIFA and UEFA’s blockchain tickets](https://apps.apple.com/au/app/shankai/id1492559481)
- [Car Ownership portal](https://github.com/AlphaWallet/TokenScript-Examples/tree/master/examples/Karma)

### Full TokenScript Support

With TokenScript, you can extend your Token’s capabilities to become "smart" and secure, enabling a mobile-native user experience :iphone:

“SmartTokens” are traditional fungible and non fungible tokens that are extended with business logic, run natively inside the app and come with signed code to prevent tampering or phishing. It allows you to realise rich functions that Dapps previously struggled to implement. With SmartTokens you can get your token on iOS and Android in real time without the need to build your own ethereum wallet.

AlphaWallet is the “browser” for users to access these SmartTokens. You can get the most out of your use case implementation... without leaving the wallet.

Visit [TokenScript Documentation](https://github.com/AlphaWallet/TokenScript) or see [TokenScript Examples](https://github.com/AlphaWallet/TokenScript-Examples) to learn what you can do with it.

### Philosophy

AlphaWallet is founded by blockchain geeks, business professionals who believe blockchain technology will have a massive impact on the future and change the landscape of technology in general.

We are committed to connecting businesses and consumers with the new digital economic infrastructure through tokenisation. Tokenised rights can be traded on the market and integrated across systems, forming a Frictionless Market and allowing limitless integration with the web.

We want to give businesses the whitelabel tools they need to develop their ethereum wallets, and join the tokenised economy.

# Getting Started

1. [Download  Xcode 13](https://developer.apple.com/download/more/)
2. Clone this repository
3. Run `make bootstrap` to install tools and dependencies.
4. Open the AlphaWallet.xcworkspace file to begin.

If you get a "Bundle does not exist. Please install bundle." error, please consult with your macOS guru because a vital part of your system is missing.

This makefile has been tested to run on "Monterey"-12.0.1. It will not work on "Catalina" or "Big Sur".

### Updating GemFile or Podfile

After the Gemfile is updated, run `make install_gems` to update the gems in the vendor/bundle directory.

After the Podfile is updated, run `make install_pods` to update the pods in the Pods directory.

### Add your token to AlphaWallet

If you’d like to include TokenScript and extend your token functionalities, please refer to [TokenScript](https://github.com/AlphaWallet/TokenScript).

### Add dApp to the “Discover dApps” section in the browser

Submit a PR to the following file:
https://github.com/AlphaWallet/alpha-wallet-ios/blob/master/AlphaWallet/Browser/ViewModel/Dapps.swift


### Replace API Keys

API keys are stored in the file `AlphaWallet/Settings/Types/Constants+Credentials.swift`. You can replace the keys for your own build. Tell git to ignore changes to that file by running:

```
git update-index --assume-unchanged AlphaWallet/Settings/Types/Constants+Credentials.swift
```

Undo this with:

```
git update-index --no-assume-unchanged AlphaWallet/Settings/Types/Constants+Credentials.swift
```

## How to Contribute

You can submit feedback and report bugs as Github issues. Please be sure to include your operating system, device, version number, and steps to reproduce reported bugs.

All contibutions welcome.

### Request or submit a feature :postbox:

Would you like to request a feature? Please get in touch with us [Telegram](https://t.me/AlphaWalletGroup), [Twitter](https://twitter.com/AlphaWallet) or through our [community forums](https://community.tokenscript.org/).

If you’d like to contribute code with a Pull Request, please make sure to follow code submission guidelines.

### Spread the word :hatched_chick:

We want to connect businesses and consumers with the new digital economic infrastructure, where everyone can benefit from technology-enabled free markets. Help us spread the word:

<a href="http://www.linkedin.com/shareArticle?mini=true&amp;url=https://github.com/AlphaWallet/alpha-wallet-ios"><img src=/resources/share_linkedin-btn.svg height="35" alt="share on linkedin"></a>
<a href="https://twitter.com/share?url=https://github.com/AlphaWallet/alpha-wallet-ios&amp;text=Open%20Source%20Wallet%20for%iOS&amp;hashtags=alphawallet"><img src=/resources/share_tweet-btn.svg height="35" alt="share on twitter"></a>
<a href="https://t.me/share/url?url=https://github.com/AlphaWallet/alpha-wallet-ios&text=Check%20this%20out!"><img src=/resources/share_telegram-btn.svg height="35" alt="share on telegram"></a>
<a href="mailto:?Subject=open source alphawallet for iOS&amp;Body=Found%20this%20one,%20check%20it%20out!%20 https://github.com/AlphaWallet/alpha-wallet-ios"><img src=/resources/share_mail-btn.svg height="35" alt="send via email"></a>
<a href="http://reddit.com/submit?url=https://github.com/AlphaWallet/alpha-wallet-ios&amp;title=Open%20Source%20AlphaWallet%20for%iOS"><img src=/resources/share_reddit-btn.svg height="35" alt="share on reddit"></a>
<a href="http://www.facebook.com/sharer.php?u=https://github.com/AlphaWallet/alpha-wallet-ios"><img src=/resources/share_facebook-btn.svg height="35" alt="share on facebook"></a>

To learn more about us, please check our Blog or join the conversation:
- [Blog](https://medium.com/alphawallet)
- [Telegram](https://t.me/AlphaWalletGroup)
- [Twitter](https://twitter.com/AlphaWallet)
- [Facebook](https://www.facebook.com/AlphaWallet)
- [LinkedIn](https://www.linkedin.com/company/alphawallet/)
- [Community forum](https://community.tokenscript.org/)

## Contributors
Thank you to all the contributors! You are awesome.

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="http://hboon.com"><img src="https://avatars1.githubusercontent.com/u/56189?v=4" width="100px;" alt=""/><br /><sub><b>Hwee-Boon Yar</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=hboon" title="Code">💻</a></td>
    <td align="center"><a href="https://www.alphawallet.com"><img src="https://avatars2.githubusercontent.com/u/16630514?v=4" width="100px;" alt=""/><br /><sub><b>James Sangalli</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=James-Sangalli" title="Code">💻</a></td>
    <td align="center"><img src="https://avatars.githubusercontent.com/u/55975226?v=4" width="100px;" alt=""/><br /><sub><b>Vladyslav Shepitko</b></sub><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=vladyslav-iosdev" title="Code">💻</a></td>
    <td align="center"><a href="https://colourfreak.com"><img src="https://avatars.githubusercontent.com/u/51817359?v=4" width="100px;" alt=""/><br /><sub><b>Tomek Nowak</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=colourfreak" title="Design">💻</a></td>
    <td align="center"><a href=aslan-apps.com"><img src="https://avatars3.githubusercontent.com/u/2621082?v=4" width="100px;" alt=""/><br /><sub><b>Oguzhan Gungor</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=ocgungor" title="Code">💻</a></td>
    <td align="center"><a href="http://gordiichuk.com/"><img src="https://avatars3.githubusercontent.com/u/3758731?v=4" width="100px;" alt=""/><br /><sub><b>Oleg Gordiichuk</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=OlegGordiichuk" title="Code">💻</a></td>
    <td align="center"><a href="https://alphawallet.com/"><img src="https://avatars0.githubusercontent.com/u/33795543?v=4" width="100px;" alt=""/><br /><sub><b>Victor Zhang</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=zhangzhongnan928" title="Code">💻</a></td>
  </tr>
  <tr>
    <td align="center"><a href="https://twitter.com/vikmeup"><img src="https://avatars0.githubusercontent.com/u/1641795?v=4" width="100px;" alt=""/><br /><sub><b>Viktor Radchenko</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=vikmeup" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/michaelScoff"><img src="https://avatars0.githubusercontent.com/u/32179653?v=4" width="100px;" alt=""/><br /><sub><b>Michael Scoff</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=michaelScoff" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/rip32700"><img src="https://avatars1.githubusercontent.com/u/15885971?v=4" width="100px;" alt=""/><br /><sub><b>Philipp Rieger</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=rip32700" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/alejandro-isaza"><img src="https://avatars3.githubusercontent.com/u/167236?v=4" width="100px;" alt=""/><br /><sub><b>Alejandro Isaza</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=alejandro-isaza" title="Code">💻</a></td>
    <td align="center"><a href="https://wenqixiang.com/"><img src="https://avatars1.githubusercontent.com/u/943683?v=4" width="100px;" alt=""/><br /><sub><b>Qixiang</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=bootingman" title="Code">💻</a></td>
    <td align="center"><a href="https://twitter.com/hewigovens"><img src="https://avatars3.githubusercontent.com/u/360470?v=4" width="100px;" alt=""/><br /><sub><b>hewig</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=hewigovens" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/MillerApps"><img src="https://avatars2.githubusercontent.com/u/3836934?v=4" width="100px;" alt=""/><br /><sub><b>Tyler Miller</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=MillerApps" title="Code">💻</a></td>
  </tr>
  <tr>
    <td align="center"><a href="http://knowyouralgorithms.wordpress.com/"><img src="https://avatars3.githubusercontent.com/u/3628920?v=4" width="100px;" alt=""/><br /><sub><b>Marat Subkhankulov</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=maratsubkhankulov" title="Code">💻</a></td>
    <td align="center"><a href="https://www.lovincyrus.com/"><img src="https://avatars3.githubusercontent.com/u/1021101?v=4" width="100px;" alt=""/><br /><sub><b>Cyrus Goh</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=lovincyrus" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/colourful-land"><img src="https://avatars3.githubusercontent.com/u/548435?v=4" width="100px;" alt=""/><br /><sub><b>Weiwu Zhang</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=colourful-land" title="Code">💻</a></td>
    <td align="center"><a href="https://kamuelafranco.com/"><img src="https://avatars3.githubusercontent.com/u/2804336?v=4" width="100px;" alt=""/><br /><sub><b>Kamuela Franco</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=KamuelaFranco" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/mishfit"><img src="https://avatars0.githubusercontent.com/u/817064?v=4" width="100px;" alt=""/><br /><sub><b>Mish Ochu</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=mishfit" title="Code">💻</a></td>
    <td align="center"><a href="http://medium.com/@james.zaki"><img src="https://avatars3.githubusercontent.com/u/939603?v=4" width="100px;" alt=""/><br /><sub><b>James Zaki</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=jzaki" title="Code">💻</a></td>
    <td align="center"><a href="http://www.lucastoledo.co"><img src="https://avatars3.githubusercontent.com/u/17125002?v=4" width="100px;" alt=""/><br /><sub><b>Lucas Toledo</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=hellolucas" title="Code">💻</a></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/vladi8556"><img src="https://avatars0.githubusercontent.com/u/14859488?v=4" width="100px;" alt=""/><br /><sub><b>vladi8556</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=vladi8556" title="Code">💻</a></td>
    <td align="center"><a href="http://vmiroshnikov.com/"><img src="https://avatars3.githubusercontent.com/u/902950?v=4" width="100px;" alt=""/><br /><sub><b>Victor Miroshnikov</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=superduper" title="Code">💻</a></td>
    <td align="center"><a href="https://swolfe.me/"><img src="https://avatars0.githubusercontent.com/u/7443178?v=4" width="100px;" alt=""/><br /><sub><b>Steven Wolfe</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=s32x" title="Code">💻</a></td>
    <td align="center"><a href="https://multisender.app/"><img src="https://avatars0.githubusercontent.com/u/9360827?v=4" width="100px;" alt=""/><br /><sub><b>Roman Storm</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=rstormsf" title="Code">💻</a></td>
    <td align="center"><a href="http://sugartin.info/"><img src="https://avatars1.githubusercontent.com/u/708425?v=4" width="100px;" alt=""/><br /><sub><b>Nimit</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=nimitparekh2020" title="Code">💻</a></td>
    <td align="center"><a href="http://www.kerrmarin.com/"><img src="https://avatars0.githubusercontent.com/u/2995710?v=4" width="100px;" alt=""/><br /><sub><b>Kerr Marin Miller</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=kerrmarin" title="Code">💻</a></td>
    <td align="center"><a href="https://1inch.exchange/"><img src="https://avatars2.githubusercontent.com/u/762226?v=4" width="100px;" alt=""/><br /><sub><b>Sergej Kunz</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=deacix" title="Code">💻</a></td>
  </tr>
  <tr>
    <td align="center"><a href="https://mohsen.dev/"><img src="https://avatars1.githubusercontent.com/u/2979743?v=4" width="100px;" alt=""/><br /><sub><b>Mohsen</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=coybit" title="Code">💻</a></td>
    <td align="center"><a href="https://www.bidali.com/"><img src="https://avatars3.githubusercontent.com/u/7315?v=4" width="100px;" alt=""/><br /><sub><b>Cory Smith</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=corymsmith" title="Code">💻</a></td>
    <td align="center"><a href="https://dolomite.io/"><img src="https://avatars3.githubusercontent.com/u/13280244?v=4" width="100px;" alt=""/><br /><sub><b>Corey Caplan</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=coreycaplan3" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/bejavu"><img src="https://avatars3.githubusercontent.com/u/10231448?v=4" width="100px;" alt=""/><br /><sub><b>Tal Beja</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=bejavu" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/asoong"><img src="https://avatars0.githubusercontent.com/u/3453571?v=4" width="100px;" alt=""/><br /><sub><b>Alex Soong</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=asoong" title="Code">💻</a></td>
    <td align="center"><a href="https://antsankov.com/"><img src="https://avatars3.githubusercontent.com/u/2533512?v=4" width="100px;" alt=""/><br /><sub><b>Alex Tsankov</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=antsankov" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/TamirTian"><img src="https://avatars2.githubusercontent.com/u/20901836?v=4" width="100px;" alt=""/><br /><sub><b>TamirTian</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=TamirTian" title="Code">💻</a></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/LingTian"><img src="https://avatars1.githubusercontent.com/u/4249432?v=4" width="100px;" alt=""/><br /><sub><b>Ling</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=LingTian" title="Code">💻</a></td>
    <td align="center"><a href="https://destiner.io/"><img src="https://avatars1.githubusercontent.com/u/4247901?v=4" width="100px;" alt=""/><br /><sub><b>Timur Badretdinov</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=Destiner" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/BorisButakov"><img src="https://avatars1.githubusercontent.com/u/35042417?v=4" width="100px;" alt=""/><br /><sub><b></b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=BorisButakov" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/2at2"><img src="https://avatars0.githubusercontent.com/u/3911535?v=4" width="100px;" alt=""/><br /><sub><b>Stanislav Strebul</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=2at2" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/SpasiboKojima"><img src="https://avatars2.githubusercontent.com/u/34808650?v=4" width="100px;" alt=""/><br /><sub><b>Andrew</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=SpasiboKojima" title="Code">💻</a></td>
    <td align="center"><a href="http://petergrassberger.com/"><img src="https://avatars1.githubusercontent.com/u/666289?v=4" width="100px;" alt=""/><br /><sub><b>Peter Grassberger</b></sub></a><br /><a href="https://github.com/AlphaWallet/alpha-wallet-ios/commits?author=PeterTheOne" title="Code">💻</a></td>
  </tr>
</table>


## License
AlphaWallet iOS is available under the [MIT license](https://github.com/AlphaWallet/alpha-wallet-ios/blob/master/LICENSE). Free for commercial and non-commercial use.
