pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

contract ShutdownTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_shutdownCanWithdraw(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");
        assertGt(vault.balanceOf(address(strategy)), 0, "!vault balance");

        // Earn Interest
        skip(2 days);

        // Simulate vault rewards
        uint256 wantRewards = ((_amount * 5) / 1000) * 1e12; // 0.5% rewards
        airdrop(want, address(strategy.rewardHandler()), wantRewards);

        // Shutdown the strategy
        vm.prank(emergencyAdmin);
        strategy.shutdownStrategy();

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Make sure we can still withdraw the full amount
        uint256 balanceBefore = asset.balanceOf(user);
        uint256 wantBalanceBefore = want.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.exit();

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_emergencyWithdraw_maxUint(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");
        assertGt(vault.balanceOf(address(strategy)), 0, "!vault balance");

        // Earn Interest
        skip(2 days);

        // Simulate vault rewards
        uint256 wantRewards = ((_amount * 5) / 1000) * 1e12; // 0.5% rewards
        airdrop(want, address(strategy.rewardHandler()), wantRewards);

        // Shutdown the strategy
        vm.prank(emergencyAdmin);
        strategy.shutdownStrategy();

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // should be able to pass uint 256 max and not revert.
        vm.prank(emergencyAdmin);
        strategy.emergencyWithdraw(type(uint256).max);

        // Make sure we can still withdraw the full amount
        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.exit();
        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_shutdownRewardHandling() public {
        uint256 _amount = 1000e6;

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // Simulate vault rewards
        uint256 wantRewards = 10e18;
        airdrop(want, address(strategy.rewardHandler()), wantRewards);

        // Check reward handler balance
        assertEq(
            want.balanceOf(address(strategy.rewardHandler())),
            wantRewards
        );

        // Shutdown the strategy
        vm.prank(emergencyAdmin);
        strategy.shutdownStrategy();

        // Check reward handler balance after shutdown
        assertEq(
            want.balanceOf(address(strategy.rewardHandler())),
            wantRewards
        );

        // Claim rewards after shutdown
        strategy.claimRewards();

        // Check reward handler balance after claim
        assertEq(want.balanceOf(address(strategy.rewardHandler())), 0);

        // Check auction balance after claim
        assertEq(want.balanceOf(strategy.auction()), 0);
    }
}
