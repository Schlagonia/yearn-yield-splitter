// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategyInterface} from "src/interfaces/IStrategyInterface.sol";

contract MultiClaimer {
    using SafeERC20 for IERC20;

    address public immutable owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function claim(address[] memory _vaults) external {
        for (uint256 i = 0; i < _vaults.length; i++) {
            _claim(_vaults[i], msg.sender);
        }
    }

    function _claim(address _vault, address _user) internal {
        address[] memory rewards = IStrategyInterface(_vault).getRewardTokens();

        try IStrategyInterface(_vault).getRewardFor(_user) {} catch {
            return;
        }

        for (uint256 i = 0; i < rewards.length; i++) {
            address reward = rewards[i];

            uint256 balance = IERC20(reward).balanceOf(address(this));

            if (balance == 0) continue;

            IERC20(reward).safeTransfer(_user, balance);
        }
    }

    function rescue(address _token) external {
        require(msg.sender == owner, "MultiClaimer: not owner");

        IERC20(_token).safeTransfer(
            msg.sender,
            IERC20(_token).balanceOf(address(this))
        );
    }
}
