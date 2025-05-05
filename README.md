# Goldcoin

[Audit Report](audit/report.pdf)

## About
Goldcoin is a completely decentralized, **hypothetical**, gold-backed stablecoin exchange protocol created by Zach Katz. Goldcoin is pegged to the price of one ounce of gold 1:1 and features a liquidity pool where liquidity providers receive 50 basis points of their total relative staked value for each Goldcoin minted. Liquidity is staked in ETH, not Goldcoin, and thanks to this, holders of Goldcoin can exchange their holdings back for ETH.


## Goldcoin Liquidity Pool
The Goldcoin liquidity pool provides added liquidity to the exchange by incentivizing liquidity providers with 0.5% of the amount of Goldcoin minted, divided by their stake in the liquidity pool at the time of the mint. This supports the decentralization of the protocol.

NOTE: Rewards are calculated and distributed on demand (or once every 30 days via Chainlink Automation) in an accrual based fashion, while maintaining an accurate reflection of providers' ownership stake over time. This nuance drastically improves gas efficiency and accounts for much of the architectural complexity of the protocol.

### Invariants
1. No more than 20% of provider liquidity should ever be distributed

   > totalProviderLiquidity >= (totalStaked * 4) / 5
2. An individual provider's rewards are equal to the sum of all transcations multiplied by the percent of their providership in the pool at the time of the transaction, and multiplied again by .05

   > providerRewards = 0.05 * ∑(mintValue * individualStaked/totalStaked), where '∑' means for all mints


## Audit Scope Details

* Commit Hash: 50b45847a8ff52d8d1502b4a63318f30b253d8c4
* In Scope: 
    ```
    ./src/
    #-- Goldcoin.sol
    #-- GCLiquidityPool.sol
    ```
* Solc Version: 0.8.20
* Chain(s) to deploy contract to: Ethereum

### Roles
*Users:* Can mint and exchange/burn Goldcoin

*Liquidity Providers:* Stake ETH for a proportional .05% reward on the amount of Goldcoin minted. Can stake, withdraw, and claim rewards.


## Additional Notes

Goldcoin is a project created by Zach Katz for educational and demonstrative purposes, complete with an audit report and invariant testing. It is, to the best of his knowledge, not based off of any other existing protocol or copied from any existing source. It serves as a medium for Zach to synthesize and showcase his nascent learnings in blockchain development and security auditing, and as such is incomplete and likely rife with flaws in both architecture and security. 

Feedback on the project is most welcome, thanks for stopping by.


