// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {GCLiquidityPool} from "../src/GCLiquidityPool.sol";
import {Goldcoin} from "../src/Goldcoin.sol";
import {PriceConfig} from "./PriceConfig.s.sol";
import {MockV3Aggregator} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract DeployGoldcoin is Script {
    function run() external returns (GCLiquidityPool, Goldcoin) {
        PriceConfig priceConfig = new PriceConfig();
        // Start broadcasting transactions
        vm.startBroadcast();

        // Get network configuration
        PriceConfig.NetworkConfig memory networkConfig = priceConfig.getConfig(block.chainid);

        // Deploy GCLiquidityPool
        GCLiquidityPool liquidityPool = new GCLiquidityPool();

        // Deploy Goldcoin with the liquidity pool and price feed addresses
        Goldcoin goldcoin =
            new Goldcoin(address(liquidityPool), networkConfig.ethUsdPriceFeed, networkConfig.goldUsdPriceFeed);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        return (liquidityPool, goldcoin);
    }
}
