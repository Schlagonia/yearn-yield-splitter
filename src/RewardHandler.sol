// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {Clonable} from "@periphery/utils/Clonable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

contract RewardHandler is Clonable {
    using SafeERC20 for ERC20;

    address public want;

    address public strategy;

    constructor() {
        original = address(this);
        strategy = address(1);
    }

    function clone() external returns (address) {
        return _clone();
    }

    function claimRewards() external {
        require(msg.sender == strategy, "not strategy");
        uint256 balance = ERC20(want).balanceOf(address(this));
        if (balance == 0) return;
        ERC20(want).forceApprove(strategy, balance);
        IStrategyInterface(strategy).notifyRewardAmount(want, balance);
    }

    function initialize(address _strategy) external {
        require(strategy == address(0), "Already initialized");
        require(_strategy != address(0), "bad strategy");

        address _want = IStrategyInterface(_strategy).want();

        want = _want;
        strategy = _strategy;
    }
}
