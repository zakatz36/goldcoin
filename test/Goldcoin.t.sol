// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Goldcoin} from "../src/Goldcoin.sol";
import {GCLiquidityPool} from "../src/GCLiquidityPool.sol";
import {MockV3Aggregator} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {FullMath} from "../lib/v3-core/contracts/libraries/FullMath.sol";
import {DeployGoldcoin} from "../script/DeployGoldcoin.s.sol";
import {AggregatorV3Interface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract goldcoinSuite is Test {
    Goldcoin public goldcoin;
    GCLiquidityPool public liquidityPool;
    address public user = makeAddr("user");
    int256 public ethUsdPrice;
    int256 public goldUsdPrice;

    function setUp() public {
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(8, 1850 * 1e10);
        MockV3Aggregator goldUsdPriceFeed = new MockV3Aggregator(8, 2150 * 1e10);
        liquidityPool = new GCLiquidityPool();
        goldcoin = new Goldcoin(address(liquidityPool), address(ethUsdPriceFeed), address(goldUsdPriceFeed));

        // Get price feeds from the test contract
        (, ethUsdPrice,,,) = ethUsdPriceFeed.latestRoundData();
        (, goldUsdPrice,,,) = goldUsdPriceFeed.latestRoundData();

        // Fund user with ETH
        vm.deal(user, 5 ether);
    }

    function getRequiredWei(uint256 amount) internal view returns (uint256) {
        return FullMath.mulDiv(amount, uint256(goldUsdPrice), uint256(ethUsdPrice));
    }

    function testMint() public {
        // Calculate exact ETH needed for 1 GLD token using FullMath.mulDiv
        uint256 requiredWei = getRequiredWei(1e18);

        console.log("RequiredWei: ", requiredWei);

        // Mint with exact amount
        vm.startPrank(user);
        goldcoin.mint{value: requiredWei}();
        vm.stopPrank();

        // Check token balance
        uint256 balance = goldcoin.balanceOf(user);
        assertApproxEqAbs(balance, 1e18, 1e15); // Allow 0.1% deviation
        assertApproxEqAbs(user.balance, 5 ether - requiredWei, 1e15); // Check ETH balance
    }

    function testMintWithZeroETH() public {
        vm.startPrank(user);
        vm.expectRevert("Must send ETH to mint");
        goldcoin.mint{value: 0}();
        vm.stopPrank();
    }

    function testExchangeAndBurn() public {
        vm.stopPrank();
        vm.startPrank(user);
        assertEq(goldcoin.balanceOf(user), 0);
        assertEq(user.balance, 5 ether);
        goldcoin.mint{value: getRequiredWei(1e18)}();
        assertApproxEqAbs(goldcoin.balanceOf(user), 1e18, 1e15);
        assertApproxEqAbs(user.balance, 5 ether - getRequiredWei(1e18), 1e15);
        console.log("goldcoin balance", goldcoin.balanceOf(user));
        goldcoin.exchangeAndBurn(goldcoin.balanceOf(user));
        assertEq(goldcoin.balanceOf(user), 0);
        assertApproxEqAbs(user.balance, 5 ether, 1e15);
        vm.stopPrank();
    }
}
