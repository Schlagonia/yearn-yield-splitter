// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

contract RewardHandler {
    using SafeERC20 for ERC20;

    address public immutable want;

    address public strategy;

    constructor(address _want) {
        want = _want;
    }

    function claimRewards() external {
        uint256 balance = ERC20(want).balanceOf(address(this));
        if (balance == 0) return;
        ERC20(want).forceApprove(strategy, balance);
        IStrategyInterface(strategy).notifyRewardAmount(want, balance);
    }

    function initialize(address _strategy) external {
        require(strategy == address(0), "Already initialized");
        require(IStrategyInterface(_strategy).want() == want, "bad want");
        strategy = _strategy;
    }
}
