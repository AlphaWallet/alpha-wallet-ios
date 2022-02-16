# High level about AlphaWallet apps

This is intentionally kept not specific to iOS and Android, but for both AlphaWallet apps

# Keys and addresses

- Supports multiple seeds and "raw" private keys
    - A limitation is only the 0th address of each seed is available in the app
    - The address generated from each seed is always the 0th Ethereum mainnet address (i.e. we always use the coin type = Ethereum mainnet (60), e.g the user can't access the 0th Ropsten address). See [BIP44](https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki#Coin_type)
- Supports multiple-chains concurrently. App bundles about 30 chains and users can add more manually

## WalletConnect v1

A "proxy" server-client protocol that in theory allows dapps that support it to be used with any wallet by initiating a connection through scanning a QR code. Eg [https://example.walletconnect.org](https://example.walletconnect.org/)

## WalletConnect v2

Coming soon. There is onging work on iOS to implement their beta SDK.

## Accessing nodes and data

Infura and a few similar providers to make calls and post transactions against nodes

Etherscan and a few similar providers to query data derived from nodes or aggregated from it. eg. transaction history

We also use OpenSea API to access NFT data. This is richer than Etherscan's for NFTs.

## Dapp Browser

This is a native webview with the web3.js provider JavaScript injected so dapps can access the user wallets. The JavaScript provider code delegates calls by the dapp to the app native code to perform actions like returning the wallet address, signing a transaction, etc

## TokenScript

There is some support for TokenScript. Basically a way to read an XML file which describes the actions a token offers and how it can be presented. This is currently available in a limited form in the apps.

## ENS

[Ethereum Name Service](https://ens.domains) has a similar goal as DNS. The most basic functionality provided by ENS is mapping from a readable name to an address and the reverse mapping. eg. vitalik.eth ↔ 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045.

## EIPs

[Ethereum Improvement Proposals](https://eips.ethereum.org) and the [Github repo](https://github.com/ethereum/EIPs/) describes many standards that are implemented by the wallet. Eg. [EIP55](https://eips.ethereum.org/EIPS/eip-55) describes an algorithm to compute the uppercase and lowercase combinations for an Ethereum address such that it acts like a checksum.
