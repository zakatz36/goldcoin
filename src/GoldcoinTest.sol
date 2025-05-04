// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Goldcoin} from "./Goldcoin.sol";

contract goldcoin is Goldcoin {
    constructor(address _liquidityPool, address _ethUsdPriceFeed, address _goldUsdPriceFeed)
        Goldcoin(_liquidityPool, _ethUsdPriceFeed, _goldUsdPriceFeed)
    {}

    // Getters for private variables
    function getEthUsdPriceFeed() public view returns (address) {
        return address(s_ethUsdPriceFeed);
    }

    function getGoldUsdPriceFeed() public view returns (address) {
        return address(s_goldUsdPriceFeed);
    }

    function getLiquidityPool() public view returns (address) {
        return address(s_liquidityPool);
    }

    function getGoldcoinOwners() public view returns (address[] memory) {
        return s_goldcoinOwners;
    }
}
