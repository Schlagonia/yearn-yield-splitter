// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

contract OperationTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_setupStrategyOK() public {
        console2.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.vault(), address(vault));
        assertEq(strategy.want(), address(want));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertTrue(strategy.rewardHandler() != address(0));
        assertTrue(strategy.auction() != address(0));
    }

    function test_operation(uint256 _amount) public {
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

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertEq(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);
        uint256 wantBalanceBefore = want.balanceOf(user);
        assertGt(strategy.earned(user, address(want)), 0, "!earned");

        // Withdraw all funds
        vm.prank(user);
        strategy.exit();

        assertGt(want.balanceOf(user), wantBalanceBefore, "!want balance");
        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_rewardHandling() public {
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

        // Check reward handler balance after claim
        assertEq(
            want.balanceOf(address(strategy.rewardHandler())),
            wantRewards
        );

        // Check auction balance
        assertEq(want.balanceOf(strategy.auction()), 0);

        // Claim rewards
        strategy.claimRewards();

        // Check reward handler balance after claim
        assertEq(want.balanceOf(address(strategy.rewardHandler())), 0);

        // Check auction balance after claim
        assertEq(want.balanceOf(strategy.auction()), 0);
    }

    function test_auctionUpdate() public {
        address newAuction = address(0x1234);

        // Try to set auction as non-management
        vm.prank(user);
        vm.expectRevert("!management");
        strategy.setAuction(newAuction);

        vm.mockCall(
            newAuction,
            abi.encodeWithSignature("want()"),
            abi.encode(address(asset))
        );

        // Set auction as management
        vm.prank(management);
        vm.expectRevert("Invalid want");
        strategy.setAuction(newAuction);

        // Create a valid auction
        address validAuction = address(0x1235);
        vm.mockCall(
            validAuction,
            abi.encodeWithSignature("want()"),
            abi.encode(address(want))
        );
        vm.mockCall(
            validAuction,
            abi.encodeWithSignature("auctions(address)"),
            abi.encode(0, 1e18, 0)
        );
        vm.mockCall(
            validAuction,
            abi.encodeWithSignature("receiver()"),
            abi.encode(address(strategy.rewardHandler()))
        );

        vm.prank(management);
        strategy.setAuction(validAuction);

        assertEq(strategy.auction(), validAuction);
    }

    function test_tendTrigger(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        (bool trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Skip some time
        skip(2 days);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Simulate rewards
        uint256 wantRewards = 10e18;
        airdrop(want, address(strategy.rewardHandler()), wantRewards);
        strategy.claimRewards();

        vm.prank(keeper);
        strategy.report();

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Unlock Profits
        skip(strategy.profitMaxUnlockTime());

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(user);
        strategy.exit();

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);
    }
}
