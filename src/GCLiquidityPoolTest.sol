// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {GCLiquidityPool} from "./GCLiquidityPool.sol";

contract GCLiquidityPoolTest is GCLiquidityPool {
    constructor() GCLiquidityPool() {}

    // Getters for private variables
    function getTotalProtocolLiquidity() public view returns (uint256) {
        return s_totalProtocolLiquidity;
    }

    function getTotalProviderLiquidity() public view returns (uint256) {
        return s_totalProviderLiquidity;
    }

    function getTotalStaked() public view returns (uint256) {
        return s_totalStaked;
    }

    function getAccRewardPerShare() public view returns (uint256) {
        return s_accRewardPerShare;
    }

    function getProviderStakes(address provider) public view returns (uint256) {
        return s_providers[provider].stakeAmount;
    }

    function getRewardDebt(address provider) public view returns (uint256) {
        return s_providers[provider].rewardDebt;
    }

    function getPendingRewards(address provider) public view returns (uint256) {
        return s_providers[provider].pendingRewards;
    }

    function getRewardPercentage() public pure returns (uint256) {
        return REWARD_PERCENTAGE;
    }

    function getRewardInterval() public pure returns (uint256) {
        return REWARD_INTERVAL;
    }

    function getProviderListLength() public view returns (uint256) {
        return s_providerList.length;
    }

    function getProviderList() public view returns (address[] memory) {
        return s_providerList;
    }

    function getProviderStake(address provider) public view returns (uint256) {
        return s_providers[provider].stakeAmount;
    }

    function getProviderAtIndex(uint256 index) public view returns (address) {
        return s_providerList[index];
    }

    // Expose internal function for testing
    function updateRewards(address providerAddress) public {
        _updateRewards(providerAddress);
    }
}
