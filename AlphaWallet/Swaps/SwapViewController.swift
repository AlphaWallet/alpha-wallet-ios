// Copyright © 2022 Stormbird PTE. LTD.

import UIKit
//hhh remove
import APIKit
//hhh remove?
import BigInt
//hhh remove
import JSONRPCKit
import PromiseKit

protocol SwapViewControllerDelegate: class {
    func promptToSwap(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt , toToken: TokenToSwap, toAmount: BigUInt, in viewController: SwapViewController)
    func promptForErc20Approval(token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt, in viewController: SwapViewController) -> Promise<EthereumTransaction.Id>
}

//hhh1 this is just used for development
class SwapViewController: UIViewController {
    private let wallet: AlphaWallet.Address
    //hhh fromChain needs to be passed in from UI
    private let server: RPCServer = .polygon
    private let tokenSwapper: TokenSwapper

    weak var delegate: SwapViewControllerDelegate?

    init(wallet: AlphaWallet.Address, tokenSwapper: TokenSwapper) {
        self.wallet = wallet
        self.tokenSwapper = tokenSwapper

        super.init(nibName: nil, bundle: nil)
        self.view.backgroundColor = UIColor.green

        let fetchChains = UIButton(type: .system)
        fetchChains.frame = CGRect(x: 100, y: 100, width: 100, height: 40)
        fetchChains.setTitle("Fetch Chains", for: .normal)
        fetchChains.addTarget(self, action: #selector(SwapViewController.fetchChains), for: .touchUpInside)
        view.addSubview(fetchChains)

        let fetchTokens = UIButton(type: .system)
        fetchTokens.frame = CGRect(x: 100, y: 150, width: 100, height: 40)
        fetchTokens.setTitle("Fetch Tokens", for: .normal)
        fetchTokens.addTarget(self, action: #selector(SwapViewController.fetchSupportedTokens), for: .touchUpInside)
        view.addSubview(fetchTokens)

        let swap = UIButton(type: .system)
        swap.frame = CGRect(x: 100, y: 200, width: 100, height: 40)
        swap.setTitle("Swap", for: .normal)
        swap.addTarget(self, action: #selector(SwapViewController.swap), for: .touchUpInside)
        view.addSubview(swap)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func swap() {
        let wallet = wallet
        let server = server
        let nativeToken = Constants.nativeCryptoAddressInDatabase
        let fromAmount: BigUInt = BigUInt("1000000000000000")!
        //let fromAmount: BigUInt = BigUInt("1000000000")! //hhh for USDT. Decimals smaller
        let fromToken1 = nativeToken
        //let fromToken1 = Matic.wethToken
        let toToken1 = Matic.usdcToken

        //let fromToken1 = Mainnet.maticToken
        //let fromToken1 = Mainnet.usdtToken
        //let toToken1 = nativeToken

        let fromSymbol: String = "ETH"
        let fromDecimals: Int = 18
        let toSymbol: String = "DAI"
        let toDecimals: Int = 18

        //hhh get from li.fi and user's choice
        let fromToken = TokenToSwap(address: fromToken1, server: server, symbol: fromSymbol, decimals: fromDecimals)
        let toToken = TokenToSwap(address: toToken1, server: server, symbol: toSymbol, decimals: toDecimals)

        firstly {
            tokenSwapper.fetchSwapQuote(fromToken: fromToken, toToken: toToken, wallet: wallet, fromAmount: fromAmount)
            //hhh remove
        }.get { swapQuote in
            NSLog("xxx spender: \(swapQuote.estimate.spender)")
        }.then { swapQuote in
            Erc20.hasEnoughAllowance(server: server, tokenAddress: fromToken.address, owner: wallet, spender: swapQuote.estimate.spender, amount: fromAmount).map { (swapQuote, $0.hasEnough, $0.shortOf) }
        }.then { swapQuote, isApproved, shortOf -> Promise<SwapQuote> in
            NSLog("xxx spender: \(swapQuote.estimate.spender) approved? \(isApproved) short of? \(shortOf)")
            if isApproved {
                return Promise.value(swapQuote)
            } else {
                return self.promptApproval(unsignedSwapTransaction: swapQuote.unsignedSwapTransaction, token: fromToken.address, server: server, owner: wallet, spender: swapQuote.estimate.spender, amount: shortOf).map { isApproved in
                    if isApproved {
                        return swapQuote
                    } else {
                        throw SwapError.userCancelledApproval
                    }
                }
            }
        }.done { [weak self] swapQuote in
            guard let strongSelf = self else { return }
            NSLog("xxx approved or not required to approved. Result unsigned transaction: \(swapQuote.unsignedSwapTransaction)")
            strongSelf.delegate?.promptToSwap(unsignedTransaction: swapQuote.unsignedSwapTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: swapQuote.estimate.toAmount, in: strongSelf)
        }.catch { error in
            infoLog("[Swap] Error while swapping. Error: \(error)")
            if let error = error as? SwapError {
                //hhh1 handle in actual UI. Swap being cancelled is in delegate, not here
                switch error {
                case .userCancelledApproval:
                    //hhh1 handle in actual UI
                    NSLog("xxx userCancelledApproval")
                case .approveTransactionNotCompleted:
                    //hhh1 handle in actual UI
                    NSLog("xxx approveTransactionNotCompleted")
                case .unableToBuildSwapUnsignedTransactionFromSwapProvider:
                    //hhh1 handle in actual UI
                    NSLog("xxx unableToBuildSwapUnsignedTransactionFromSwapProvider")
                case .unknownError:
                    self.displayError(error: error)
                    NSLog("xxx unknownError")
                }
            } else {
                NSLog("xxx other error: \(error)")
                self.displayError(error: error)
            }
        }
    }

    @objc func fetchSupportedTokens() {
        firstly {
            tokenSwapper.fetchSupportedTokens(forServer: server)
        }.done { swapPairs in
            NSLog("xxx tokens: \(swapPairs)")
            NSLog("xxx fromTokens count: \(swapPairs.fromTokens.count)")
            for each in swapPairs.fromTokens {
                let toTokens = swapPairs.getToTokens(forFromToken: each)
                for eachToToken in toTokens {
                    //NSLog("xxx from \(each.address.eip55String) to \(eachToToken.address.eip55String)")
                }
            }
        }.catch { error in
            NSLog("xxx error: \(error)")
        }
    }

    @objc func fetchChains() {
        tokenSwapper.start()
    }

    private func promptApproval(unsignedSwapTransaction: UnsignedSwapTransaction, token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> Promise<Bool> {
        NSLog("xxx promptApproval() because not approved or not enough. spender: \(spender.eip55String) amount: \(amount)")
        guard let delegate = delegate else {
            return Promise(error: SwapError.unknownError)
        }

        return firstly {
            delegate.promptForErc20Approval(token: token, server: server, owner: owner, spender: spender, amount: amount, in: self)
        }.then { transactionId -> Promise<Bool> in
            //hhh0 We don't handle long pending nicely or failed transactions. Need a UI to ask user to speed up etc?
            NSLog("xxx waiting for approval confirmation…")
            return firstly {
                EthereumTransaction.waitTillCompleted(transactionId: transactionId, server: server)
            }.map {
                NSLog("xxx approval confirmed")
                return true
            }.recover { error -> Promise<Bool> in
                if error is EthereumTransaction.NotCompletedYet {
                    NSLog("xxx error while waiting for approval confirmation: \(error) we map it to \(SwapError.approveTransactionNotCompleted) ")
                    throw SwapError.approveTransactionNotCompleted
                } else if let error = error as? SwapError {
                    switch error {
                    case .userCancelledApproval:
                        return .value(false)
                    case .unableToBuildSwapUnsignedTransactionFromSwapProvider, .approveTransactionNotCompleted, .unknownError:
                        throw error
                    }
                }
                //Exists to make compiler happy
                return .value(false)
            }
        }
    }
}