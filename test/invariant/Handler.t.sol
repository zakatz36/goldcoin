// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {GCLiquidityPoolTest} from "../../src/GCLiquidityPoolTest.sol";
import {Goldcoin} from "../../src/Goldcoin.sol";

contract Handler is Test {
    GCLiquidityPoolTest public liquidityPool;
    Goldcoin public goldcoin;
    address[] public actors;
    uint256 public constant MAX_ACTORS = 10;

    constructor(GCLiquidityPoolTest _liquidityPool, Goldcoin _goldcoin, address[] memory _actors) {
        liquidityPool = _liquidityPool;
        goldcoin = _goldcoin;
        actors = _actors;
    }

    function stake(uint256 actorIndex, uint256 amount) public {
        actorIndex = bound(actorIndex, 0, MAX_ACTORS - 1);
        address actor = actors[actorIndex];

        // Ensure amount is not zero and actor has enough ETH
        amount = bound(amount, 1, address(actor).balance);

        vm.startPrank(actor);
        liquidityPool.stake{value: amount}();
        vm.stopPrank();
    }

    function withdraw(uint256 actorIndex, uint256 amount) public {
        actorIndex = bound(actorIndex, 0, MAX_ACTORS - 1);
        address actor = actors[actorIndex];

        // Get the actor's current stake
        uint256 currentStake = liquidityPool.getProviderStakes(actor);
        if (currentStake == 0) return;

        // Ensure amount is not zero and doesn't exceed current stake
        amount = bound(amount, 1, currentStake);

        vm.startPrank(actor);
        liquidityPool.withdraw(amount);
        vm.stopPrank();
    }

    function mint(uint256 actorIndex, uint256 amount) public {
        actorIndex = bound(actorIndex, 0, MAX_ACTORS - 1);
        address actor = actors[actorIndex];

        // Ensure amount is not zero and actor has enough ETH
        amount = bound(amount, 1, address(actor).balance);

        vm.startPrank(actor);
        goldcoin.mint{value: amount}();
        vm.stopPrank();
    }

    function burn(uint256 actorIndex, uint256 amount) public {
        actorIndex = bound(actorIndex, 0, MAX_ACTORS - 1);
        address actor = actors[actorIndex];

        // Get total available liquidity
        uint256 totalLiquidity = liquidityPool.getTotalProviderLiquidity() + liquidityPool.getTotalProtocolLiquidity();
        if (totalLiquidity == 0) return;

        // Ensure amount is not zero and doesn't exceed total liquidity
        amount = bound(amount, 1, totalLiquidity);

        vm.startPrank(actor);
        goldcoin.exchangeAndBurn(amount);
        vm.stopPrank();
    }

    function claimRewards(uint256 actorIndex) public {
        actorIndex = bound(actorIndex, 0, MAX_ACTORS - 1);
        address actor = actors[actorIndex];

        vm.startPrank(actor);
        liquidityPool.claimRewards();
        vm.stopPrank();
    }
}
