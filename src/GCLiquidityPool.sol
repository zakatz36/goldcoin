// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AutomationCompatible} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/AutomationCompatible.sol";
import {console} from "forge-std/console.sol";

/**
 * @title GCLiquidityPool
 * @dev A liquidity pool contract for Goldcoin that manages staking, rewards, and token burning
 * @notice This contract handles:
 * - ETH staking by liquidity providers
 * - Reward distribution from minting fees
 * - Token burning and ETH redemption
 */
contract GCLiquidityPool is AutomationCompatible {
    /**
     * @dev Struct to store liquidity provider information
     * @param stakeAmount The amount of ETH staked by the provider
     * @param rewardDebt The amount of rewards already paid to the provider
     * @param pendingRewards The amount of rewards pending to be claimed
     * @param providerIndexPlusOne The index of the provider in the providerList, +1 so 0 is not a valid index
     * @param isProvider Boolean indicating if the address is a provider
     */
    struct ProviderInfo {
        uint256 stakeAmount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 providerIndexPlusOne;
        bool isProvider;
    }

    // Constants
    uint256 internal constant REWARD_PERCENTAGE = 50; // 0.5% in basis points (5/1000)
    uint256 internal constant REWARD_INTERVAL = 30 days;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_STAKE_AMOUNT = 0;
    uint256 private constant MAX_WITHDRAWAL_PERCENTAGE = 800; // 80% in basis points
    uint256 private constant BASIS_POINTS = 1000;

    // State variables
    uint256 internal s_totalProtocolLiquidity;
    uint256 internal s_totalProviderLiquidity;
    uint256 internal s_lastRewardTimestamp;
    uint256 internal s_totalStaked;

    uint256 internal s_accRewardPerShare;

    address private s_goldcoinAddress;
    bool private s_goldcoinAddressSet;

    // Mapping to track provider information
    mapping(address => ProviderInfo) internal s_providers;
    address[] internal s_providerList;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount);

    constructor() {}

    /**
     * @dev Handles minting of new tokens and distributes rewards
     * @notice Called when new tokens are minted, distributes 0.5% of minted value as rewards
     */
    function handleMint() external payable {
        require(msg.sender == s_goldcoinAddress);
        uint256 amountToDistribute = (msg.value * REWARD_PERCENTAGE) / 10000;
        s_totalProtocolLiquidity += msg.value - amountToDistribute;
        if (s_totalStaked > 0) {
            s_accRewardPerShare += (amountToDistribute * PRECISION) / s_totalStaked;
            emit RewardsDistributed(amountToDistribute);
        } else {
            // If no stakers, protocol keeps the fee
            s_totalProtocolLiquidity += amountToDistribute;
        }
    }

    /**
     * @dev Handles burning of tokens and returns ETH to the burner
     * @param amount The amount of ETH to return
     * @param burner The address that burned the tokens
     * @notice Requires that no more than 20% of provider liquidity is ever sent out of the contract
     */
    function handleBurn(uint256 amount, address burner) external {
        require(msg.sender == s_goldcoinAddress, "Not authorized");

        if (
            (
                s_totalProtocolLiquidity < amount
                    && s_totalProviderLiquidity - amount < (s_totalStaked * MAX_WITHDRAWAL_PERCENTAGE) / BASIS_POINTS
            )
        ) {
            revert("Insufficient liquidity");
        }

        if (s_totalProtocolLiquidity >= amount) {
            s_totalProtocolLiquidity -= amount;
        } else {
            s_totalProviderLiquidity -= amount - s_totalProtocolLiquidity;
            s_totalProtocolLiquidity = 0;
        }
        (bool success,) = payable(burner).call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev Allows users to stake ETH in the liquidity pool
     * @notice Requires non-zero ETH value to be sent
     */
    function stake() external payable {
        require(msg.value > MIN_STAKE_AMOUNT, "Must send ETH to stake");

        _updateRewards(msg.sender);

        ProviderInfo storage provider = s_providers[msg.sender];
        provider.stakeAmount += msg.value;
        s_totalStaked += msg.value;
        s_totalProviderLiquidity += msg.value;
        provider.rewardDebt = (provider.stakeAmount * s_accRewardPerShare) / PRECISION;

        if (!provider.isProvider) {
            provider.isProvider = true;
            s_providerList.push(msg.sender);
            provider.providerIndexPlusOne = s_providerList.length;
        }

        emit Staked(msg.sender, msg.value);
    }

    /**
     * @dev Allows users to withdraw their staked ETH
     * @param amount The amount of ETH to withdraw
     * @notice Requires sufficient staked balance
     */
    function withdraw(uint256 amount) external {
        ProviderInfo storage withdrawProvider = s_providers[msg.sender];
        require(withdrawProvider.stakeAmount >= amount, "Insufficient balance");

        _updateRewards(msg.sender);

        withdrawProvider.stakeAmount -= amount;
        s_totalStaked -= amount;
        s_totalProviderLiquidity -= amount;
        withdrawProvider.rewardDebt = (withdrawProvider.stakeAmount * s_accRewardPerShare) / PRECISION;

        // If provider's balance is now zero, remove them from the provider list
        if (withdrawProvider.stakeAmount == 0) {
            address lastProvider = s_providerList[s_providerList.length - 1];

            if (msg.sender != lastProvider) {
                // Move the last provider to the withdrawing provider's position
                s_providerList[withdrawProvider.providerIndexPlusOne - 1] = lastProvider;
                // Update the moved provider's index
                s_providers[lastProvider].providerIndexPlusOne = withdrawProvider.providerIndexPlusOne;
            }

            s_providerList.pop();

            // Mark the provider as removed
            withdrawProvider.isProvider = false;
            withdrawProvider.providerIndexPlusOne = 0;
        }

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Allows users to claim their pending rewards
     * @notice Requires non-zero pending rewards
     */
    function claimRewards() external {
        _updateRewards(msg.sender);

        ProviderInfo storage provider = s_providers[msg.sender];
        uint256 reward = provider.pendingRewards;
        require(reward > 0, "No rewards");

        provider.pendingRewards = 0;
        (bool success,) = payable(msg.sender).call{value: reward}("");
        require(success, "Transfer failed");

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Checks if upkeep is needed for reward distribution
     * @return upkeepNeeded Whether upkeep is needed
     * @return Data to be passed to performUpkeep (unused)
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = (block.timestamp - s_lastRewardTimestamp) > REWARD_INTERVAL;
        return (upkeepNeeded, "");
    }

    /**
     * @dev Performs the upkeep by distributing rewards to all providers
     * @notice Can only be called when the reward interval has passed
     */
    function performUpkeep(bytes calldata) external override {
        require((block.timestamp - s_lastRewardTimestamp) > REWARD_INTERVAL, "Too early");
        console.log("distributing rewards");
        s_lastRewardTimestamp = block.timestamp;
        _distributeRewards();
    }

    function setGoldcoinAddress() external {
        require(!s_goldcoinAddressSet, "Goldcoin address already set");
        s_goldcoinAddress = msg.sender;
        s_goldcoinAddressSet = true;
    }

    /**
     * @dev Internal function to distribute rewards to all active providers
     * @notice Only called once a month by Chainlink Automation
     */
    function _distributeRewards() internal {
        for (uint256 i = 0; i < s_providerList.length; i++) {
            address providerAddress = s_providerList[i];
            _updateRewards(providerAddress);
            ProviderInfo storage provider = s_providers[providerAddress];
            uint256 reward = provider.pendingRewards;
            if (reward > 0) {
                (bool success,) = payable(providerAddress).call{value: reward}("");
                require(success, "Transfer failed");
                provider.pendingRewards = 0;
            }
        }
        s_lastRewardTimestamp = block.timestamp;
        s_accRewardPerShare = 0;
    }

    /**
     * @dev Internal function to update rewards for a provider
     * @param providerAddress The address of the provider to update rewards for
     * @notice Calculates and updates the provider's pending rewards based on their stake
     */
    function _updateRewards(address providerAddress) internal {
        ProviderInfo storage provider = s_providers[providerAddress];
        uint256 accumulated = (provider.stakeAmount * s_accRewardPerShare) / PRECISION;
        uint256 owed = accumulated - provider.rewardDebt;
        provider.pendingRewards += owed;
        provider.rewardDebt = accumulated;
    }

    // FOR INVARIANT TESTING PURPOSES ONLY
    function previewRewards(address providerAddress) external returns (uint256, uint256, uint256) {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < s_providerList.length; i++) {
            _updateRewards(s_providerList[i]);
            providerAddress = s_providerList[i];
            ProviderInfo storage provider = s_providers[providerAddress];
            totalRewards += provider.pendingRewards;
        }

        return (s_providers[providerAddress].pendingRewards, totalRewards, s_totalStaked);
    }
}
