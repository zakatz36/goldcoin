// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GCLiquidityPoolTest} from "../src/GCLiquidityPoolTest.sol";
import {Goldcoin} from "../src/Goldcoin.sol";
import {MockV3Aggregator} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

/**
 * @title GCLiquidityPoolTestSuite
 * @dev Test suite for GCLiquidityPool contract
 */
contract GCLiquidityPoolTestSuite is Test {
    GCLiquidityPoolTest public liquidityPool;
    Goldcoin public goldcoin;
    address public provider1 = makeAddr("provider1");
    address public provider2 = makeAddr("provider2");
    address public user = makeAddr("user");

    /**
     * @dev Sets up the test environment
     * - Deploys a new GCLiquidityPool contract
     * - Funds test accounts with ETH
     */
    function setUp() public {
        liquidityPool = new GCLiquidityPoolTest();
        goldcoin = new Goldcoin(
            address(liquidityPool),
            address(new MockV3Aggregator(8, 1850 * 1e10)),
            address(new MockV3Aggregator(8, 2150 * 1e10))
        );

        // Fund providers with ETH
        vm.deal(provider1, 10 ether);
        vm.deal(provider2, 10 ether);
        vm.deal(user, 5 ether);
    }

    /**
     * @dev Tests basic staking functionality
     * - Provider stakes 1 ETH
     * - Verifies stake amount and total liquidity
     */
    function testStake() public {
        vm.startPrank(provider1);
        uint256 stakeAmount = 1 ether;
        liquidityPool.stake{value: stakeAmount}();
        vm.stopPrank();

        assertEq(liquidityPool.getProviderStakes(provider1), stakeAmount);
        assertEq(liquidityPool.getTotalProviderLiquidity(), stakeAmount);
    }

    /**
     * @dev Tests staking with zero ETH
     * - Verifies that staking with zero ETH reverts
     */
    function testStakeWithZeroETH() public {
        vm.startPrank(provider1);
        vm.expectRevert("Must send ETH to stake");
        liquidityPool.stake{value: 0}();
        vm.stopPrank();
    }

    /**
     * @dev Tests multiple providers staking
     * - First provider stakes 1 ETH
     * - Second provider stakes 2 ETH
     * - Verifies individual and total stakes
     */
    function testMultipleStakes() public {
        // First provider stakes
        vm.startPrank(provider1);
        liquidityPool.stake{value: 1 ether}();
        vm.stopPrank();

        // Second provider stakes
        vm.startPrank(provider2);
        liquidityPool.stake{value: 2 ether}();
        vm.stopPrank();

        assertEq(liquidityPool.getProviderStakes(provider1), 1 ether);
        assertEq(liquidityPool.getProviderStakes(provider2), 2 ether);
        assertEq(liquidityPool.getTotalProviderLiquidity(), 3 ether);
    }

    /**
     * @dev Tests withdrawal functionality
     * - Provider stakes 2 ETH
     * - Withdraws 1 ETH
     * - Verifies remaining stake and balance
     */
    function testWithdraw() public {
        // First stake
        vm.startPrank(provider1);
        liquidityPool.stake{value: 2 ether}();

        // Then withdraw
        uint256 withdrawAmount = 1 ether;
        liquidityPool.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(liquidityPool.getProviderStakes(provider1), 1 ether);
        assertEq(liquidityPool.getTotalProviderLiquidity(), 1 ether);
        assertEq(provider1.balance, 9 ether); // 10 - 2 + 1 = 9
    }

    /**
     * @dev Tests withdrawal with insufficient balance
     * - Provider stakes 1 ETH
     * - Attempts to withdraw 2 ETH
     * - Verifies transaction reverts
     */
    function testWithdrawInsufficientBalance() public {
        vm.startPrank(provider1);
        liquidityPool.stake{value: 1 ether}();

        vm.expectRevert("Insufficient balance");
        liquidityPool.withdraw(2 ether);
        vm.stopPrank();
    }

    /**
     * @dev Tests claiming rewards functionality
     * - Provider stakes and generates rewards
     * - Claims rewards
     * - Verifies balance increase and pending rewards reset
     */
    function testClaimRewards() public {
        // Setup: Stake and generate rewards
        vm.startPrank(provider1);
        liquidityPool.stake{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(user);
        goldcoin.mint{value: 1 ether}();
        vm.stopPrank();

        // Claim rewards
        vm.startPrank(provider1);
        uint256 initialBalance = provider1.balance;
        liquidityPool.claimRewards();
        vm.stopPrank();

        // Calculate expected reward (0.5% of 1 ether)
        uint256 expectedReward = (1 ether * liquidityPool.getRewardPercentage()) / 10000;

        assertEq(provider1.balance, initialBalance + expectedReward);
    }

    /**
     * @dev Tests claiming rewards when none are available
     * - Attempts to claim rewards without staking
     * - Verifies transaction reverts
     */
    function testClaimRewardsNoRewards() public {
        vm.startPrank(provider1);
        vm.expectRevert("No rewards");
        liquidityPool.claimRewards();
        vm.stopPrank();
    }

    /**
     * @dev Tests burn functionality
     * - Provider adds liquidity
     * - Simulates minting
     * - Tests burning tokens
     * - Verifies balance increase
     */
    function testHandleBurn() public {
        // Setup: Add some liquidity
        vm.startPrank(provider1);
        liquidityPool.stake{value: 10 ether}();
        vm.stopPrank();

        vm.startPrank(user);
        goldcoin.mint{value: 2 ether}();
        vm.stopPrank();

        // Test burn
        vm.startPrank(user);
        uint256 burnAmount = 1 ether;
        uint256 initialBalance = user.balance;
        goldcoin.exchangeAndBurn(burnAmount);
        vm.stopPrank();
        console.log("user balance", user.balance);
        console.log("initial balance", initialBalance);
        console.log("burn amount", burnAmount);

        assertEq(user.balance, initialBalance + goldcoin.getGoldcoinInWei(burnAmount));
    }

    /**
     * @dev Tests provider removal when balance reaches zero
     * - Provider stakes and then withdraws all funds
     * - Verifies provider is removed from active providers list
     */
    function testProviderRemovalOnZeroBalance() public {
        vm.startPrank(provider1);
        liquidityPool.stake{value: 1 ether}();
        liquidityPool.withdraw(1 ether);
        vm.stopPrank();

        assertEq(liquidityPool.getProviderStakes(provider1), 0);
        assertEq(liquidityPool.getTotalProviderLiquidity(), 0);
        assertEq(liquidityPool.getProviderListLength(), 0);
    }

    /**
     * @dev Tests Chainlink Automation checkUpkeep function
     * - Verifies upkeep is needed after reward interval
     * - Verifies upkeep is not needed before interval
     */
    function testCheckUpkeep() public {
        // Initially, upkeep should not be needed
        (bool upkeepNeeded,) = liquidityPool.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // Fast forward past reward interval
        vm.warp(block.timestamp + liquidityPool.getRewardInterval() + 1);

        // Now upkeep should be needed
        (upkeepNeeded,) = liquidityPool.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    /**
     * @dev Tests Chainlink Automation performUpkeep function
     * - Sets up providers and rewards
     * - Triggers upkeep after interval
     * - Verifies rewards are distributed
     */
    function testPerformUpkeep() public {
        // Setup: Add providers and generate rewards
        vm.startPrank(provider1);
        liquidityPool.stake{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(provider2);
        liquidityPool.stake{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(user);
        goldcoin.mint{value: 1 ether}();
        vm.stopPrank();

        // Fast forward past reward interval
        vm.warp(block.timestamp + liquidityPool.getRewardInterval() + 1);

        // Perform upkeep
        liquidityPool.performUpkeep("");

        // Verify rewards were distributed
        assertEq(liquidityPool.getPendingRewards(provider1), 0);
        assertEq(liquidityPool.getPendingRewards(provider2), 0);
    }

    /**
     * @dev Tests multiple reward distributions
     * - Verifies rewards are properly distributed and balances updated
     */
    function testMultipleRewardDistributions() public {
        vm.startPrank(provider1);
        liquidityPool.stake{value: 1 ether}();
        vm.stopPrank();

        // First distribution
        vm.startPrank(user);
        goldcoin.mint{value: 1 ether}();
        vm.stopPrank();

        // Second distribution
        vm.startPrank(user);
        goldcoin.mint{value: 1 ether}();
        vm.stopPrank();

        // Calculate expected total reward (0.5% of 2 ether)
        uint256 expectedReward = (2 ether * liquidityPool.getRewardPercentage()) / 10000;

        // Record provider1's balance before distribution
        uint256 balanceBefore = address(provider1).balance;

        // Fast forward past reward interval and distribute rewards
        vm.warp(block.timestamp + liquidityPool.getRewardInterval() + 1);
        liquidityPool.performUpkeep("");

        console.log("accRewardPerShare", liquidityPool.getAccRewardPerShare());

        // Verify pending rewards were reset
        assertEq(liquidityPool.getAccRewardPerShare(), 0);
        assertEq(liquidityPool.getPendingRewards(provider1), 0);

        // Verify provider received the rewards
        assertEq(address(provider1).balance - balanceBefore, expectedReward);
    }

    /**
     * @dev Tests reward distribution with no providers
     * - Verifies protocol keeps fees when no providers exist
     */
    function testRewardDistributionNoProviders() public {
        vm.startPrank(user);
        goldcoin.mint{value: 1 ether}();
        vm.stopPrank();

        // All minted value should go to protocol liquidity
        assertEq(liquidityPool.getTotalProtocolLiquidity(), 1 ether);
    }

    /**
     * @dev Tests provider list management
     * - Verifies provider list updates correctly when adding/removing providers
     */
    function testProviderListManagement() public {
        // Add first provider
        vm.startPrank(provider1);
        liquidityPool.stake{value: 1 ether}();
        vm.stopPrank();

        assertEq(liquidityPool.getProviderListLength(), 1);
        assertEq(liquidityPool.getProviderAtIndex(0), provider1);

        // Add second provider
        vm.startPrank(provider2);
        liquidityPool.stake{value: 1 ether}();
        vm.stopPrank();

        assertEq(liquidityPool.getProviderListLength(), 2);
        assertEq(liquidityPool.getProviderAtIndex(1), provider2);

        // Remove first provider
        vm.startPrank(provider1);
        liquidityPool.withdraw(1 ether);
        vm.stopPrank();

        assertEq(liquidityPool.getProviderListLength(), 1);
        assertEq(liquidityPool.getProviderAtIndex(0), provider2);
    }
}
