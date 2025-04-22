// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {ITokenizedStaker} from "@periphery/Bases/Staker/ITokenizedStaker.sol";

interface IStrategyInterface is ITokenizedStaker {
    // State variables
    function vault() external view returns (address);

    function want() external view returns (address);

    function rewardHandler() external view returns (address);

    function auction() external view returns (address);

    // Core functions
    function claimRewards() external;

    function balanceOfVault() external view returns (uint256);

    function valueOfVault() external view returns (uint256);

    function vaultsMaxWithdraw() external view returns (uint256);

    function setAuction(address _auction) external;
}
