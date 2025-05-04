// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {GCLiquidityPoolTest} from "../../src/GCLiquidityPoolTest.sol";
import {Goldcoin} from "../../src/Goldcoin.sol";
import {Handler} from "./Handler.t.sol";
import {DeployGoldcoin} from "../../script/DeployGoldcoin.s.sol";
import {MockV3Aggregator} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract Invariant is StdInvariant, Test {
    GCLiquidityPoolTest public liquidityPool;
    Goldcoin public goldcoin;
    Handler public handler;
    address[] public actors;
    uint256 public constant MAX_ACTORS = 10;

    function setUp() public {
        liquidityPool = new GCLiquidityPoolTest();
        goldcoin = new Goldcoin(
            address(liquidityPool),
            address(new MockV3Aggregator(8, 1850 * 1e10)),
            address(new MockV3Aggregator(8, 2150 * 1e10))
        );

        // Create test actors
        for (uint256 i = 0; i < MAX_ACTORS; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            actors.push(actor);
            vm.deal(actor, 100 ether);
        }

        // Create handler
        handler = new Handler(liquidityPool, goldcoin, actors);

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = handler.stake.selector;
        selectors[1] = handler.withdraw.selector;
        selectors[2] = handler.mint.selector;
        selectors[3] = handler.burn.selector;
        selectors[4] = handler.claimRewards.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_liquidity_ratio() public view {
        uint256 totalProviderLiquidity = liquidityPool.getTotalProviderLiquidity();
        uint256 totalStaked = liquidityPool.getTotalStaked();

        // The invariant: totalProviderLiquidity >= (4/5) * totalLiquidity
        // This ensures no more than 20% of total liquidity is ever sent out
        assert(totalProviderLiquidity >= (totalStaked * 4) / 5);
    }

    function invariant_rewards_distribution() public {
        for (uint256 i = 0; i < liquidityPool.getProviderList().length; i++) {
            (uint256 providerRewards, uint256 totalRewards, uint256 totalStaked) =
                liquidityPool.previewRewards(liquidityPool.getProviderList()[i]);
            assertEq(
                providerRewards,
                (totalRewards * liquidityPool.getProviderStake(liquidityPool.getProviderList()[i])) / totalStaked
            );
        }
    }
}
