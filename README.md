# AlphaWallet - An advanced Ethereum mobile wallet

[![Build Status](https://travis-ci.com/AlphaWallet/alpha-wallet-ios.svg?branch=master)](https://travis-ci.com/AlphaWallet/alpha-wallet-ios.svg?branch=master)
[![codecov](https://codecov.io/gh/AlphaWallet/alpha-wallet-ios/branch/master/graph/badge.svg)](https://codecov.io/gh/AlphaWallet/alpha-wallet-ios)

[<img src="https://alphawallet.com/wp-content/uploads/2020/03/aw_coverphoto-comp.jpg" width="347" height="434">](https://alphawallet.com/)

[<img src=resources/app-store-badge.png height="88">](https://itunes.apple.com/us/app/alphawallet/id1358230430?ls=1&mt=8)

## Getting Started

1. [Download](https://developer.apple.com/xcode/download/) the Xcode 9 and above release.
2. Clone this repository and get the submodules with: git submodule init && git submodule update.
3. Run `make bootstrap` to install tools and dependencies.

## Replace API Keys

API keys are stored in the file `AlphaWallet/Settings/Types/Constants+Credentials.swift`. You can replace the keys for your own build. Tell git to ignore changes to that file by running:

```
git update-index --assume-unchanged AlphaWallet/Settings/Types/Constants+Credentials.swift
```

Undo this with:

```
git update-index --no-assume-unchanged AlphaWallet/Settings/Types/Constants+Credentials.swift
```

## Contributing

The best way to submit feedback and report bugs is to open a GitHub issue.
Please be sure to include your operating system, device, version number, and
steps to reproduce reported bugs. 

## Add your DApp to "Discover DApps" sections in AlphaWallet

Submit a PR for each of the files below:

For Android:
<https://github.com/AlphaWallet/alpha-wallet-android/blob/master/app/src/main/assets/dapps_list.json>

For iOS:
<https://github.com/AlphaWallet/alpha-wallet-ios/blob/master/AlphaWallet/Browser/ViewModel/Dapps.swift>

## Build your own mobile blockchain app
white label blockchain wallet

## License
AlphaWallet iOS is available under the MIT license. Free for commercial and non-commercial use.
