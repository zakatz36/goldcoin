// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockV3Aggregator} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract PriceConfig is Script {
    struct NetworkConfig {
        address ethUsdPriceFeed;
        address goldUsdPriceFeed;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        // Mainnet
        networkConfigs[1] = NetworkConfig({
            ethUsdPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            goldUsdPriceFeed: 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6
        });

        // Sepolia
        networkConfigs[11155111] = NetworkConfig({
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            goldUsdPriceFeed: 0x7b219F57a8e9C7303204Af681e9fA69d17ef626f
        });

        // Anvil (Local chain)
        MockV3Aggregator ethUsdMock = new MockV3Aggregator(8, 1850 * 1e10);
        MockV3Aggregator goldUsdMock = new MockV3Aggregator(8, 2150 * 1e10);

        networkConfigs[31337] =
            NetworkConfig({ethUsdPriceFeed: address(ethUsdMock), goldUsdPriceFeed: address(goldUsdMock)});
    }

    function getConfig(uint256 chainId) public view returns (NetworkConfig memory) {
        return networkConfigs[chainId];
    }
}
