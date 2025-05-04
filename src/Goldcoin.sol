// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {FullMath} from "../lib/v3-core/contracts/libraries/FullMath.sol";
import {GCLiquidityPool} from "./GCLiquidityPool.sol";

/**
 * @title Goldcoin
 * @dev An ERC20 token backed by gold price, with minting and burning functionality
 * @notice This contract:
 * - Uses Chainlink price feeds for ETH/USD and Gold/USD
 * - Allows minting tokens with ETH based on current gold price
 * - Allows burning tokens to redeem ETH
 * - Integrates with GCLiquidityPool for liquidity management
 */
contract Goldcoin is ERC20, Ownable {
    // Constants
    uint256 private constant PRICE_FEED_DECIMALS = 8;
    uint256 private constant TOKEN_DECIMALS = 18;
    uint256 private constant MIN_MINT_AMOUNT = 0;

    // State variables
    address public immutable s_ethUsdPriceFeed;
    address public immutable s_goldUsdPriceFeed;
    GCLiquidityPool public immutable s_liquidityPool;
    address[] internal s_goldcoinOwners;

    /**
     * @dev Initializes the contract with price feeds and liquidity pool
     * @param _liquidityPool Address of the GCLiquidityPool contract
     * @param _ethUsdPriceFeed Address of the ETH/USD price feed
     * @param _goldUsdPriceFeed Address of the Gold/USD price feed
     */
    constructor(address _liquidityPool, address _ethUsdPriceFeed, address _goldUsdPriceFeed)
        ERC20("Goldcoin", "GLD")
        Ownable(msg.sender)
    {
        s_ethUsdPriceFeed = _ethUsdPriceFeed;
        s_goldUsdPriceFeed = _goldUsdPriceFeed;
        s_liquidityPool = GCLiquidityPool(_liquidityPool);
        s_liquidityPool.setGoldcoinAddress();
    }

    /**
     * @dev Gets the current gold price in USD from Chainlink
     * @return The current gold price in USD (8 decimals)
     */
    function getGoldUsdPrice() private view returns (uint256) {
        (, int256 goldUsdPriceRaw,,,) = AggregatorV3Interface(s_goldUsdPriceFeed).latestRoundData();
        return uint256(goldUsdPriceRaw);
    }

    /**
     * @dev Gets the current ETH price in USD from Chainlink
     * @return The current ETH price in USD (8 decimals)
     */
    function getEthUsdPrice() private view returns (uint256) {
        (, int256 ethUsdPriceRaw,,,) = AggregatorV3Interface(s_ethUsdPriceFeed).latestRoundData();
        return uint256(ethUsdPriceRaw);
    }

    /**
     * @dev Mints new Goldcoin tokens in exchange for ETH
     * @notice The amount of tokens minted is based on current gold and ETH prices
     * @notice Requires non-zero ETH value to be sent
     */
    function mint() external payable {
        require(msg.value > MIN_MINT_AMOUNT, "Must send ETH to mint");

        // Get Chainlink prices (both are 8 decimals)
        uint256 ethUsdPrice = getEthUsdPrice();
        uint256 goldUsdPrice = getGoldUsdPrice();

        require(ethUsdPrice > 0 && goldUsdPrice > 0, "Invalid price data");

        // Convert ETH sent (in wei) to USD (18 decimals)
        uint256 usdSent = FullMath.mulDiv(msg.value, ethUsdPrice, 10 ** TOKEN_DECIMALS);
        console.log("usdSent:", usdSent);

        // Calculate how much gold that buys in ounces (in 1e18 units)
        uint256 tokensToMint = FullMath.mulDiv(usdSent, 10 ** TOKEN_DECIMALS, goldUsdPrice);

        console.log("tokensToMint (1e18 = 1 oz):", tokensToMint);

        // Mint tokens (1e18 units = 1 oz)
        _mint(msg.sender, tokensToMint);
        s_liquidityPool.handleMint{value: msg.value}();
    }

    /**
     * @dev Burns Goldcoin tokens and returns equivalent ETH value
     * @param amount The amount of Goldcoin tokens to burn
     * @notice Requires sufficient token balance
     */
    function exchangeAndBurn(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        s_liquidityPool.handleBurn(getGoldcoinInWei(amount), msg.sender);
        _burn(msg.sender, amount);
    }

    /**
     * @dev Converts Goldcoin amount to equivalent ETH value in wei
     * @param amount The amount of Goldcoin tokens
     * @return The equivalent ETH value in wei
     */
    function getGoldcoinInWei(uint256 amount) public view returns (uint256) {
        // First convert goldcoin amount to USD value
        uint256 usdValue = FullMath.mulDiv(amount, getGoldUsdPrice(), 10 ** TOKEN_DECIMALS);
        // Then convert USD value to ETH (wei)
        return FullMath.mulDiv(usdValue, 10 ** TOKEN_DECIMALS, getEthUsdPrice());
    }
}
