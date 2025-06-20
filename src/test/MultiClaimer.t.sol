// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import {MultiClaimer} from "../periphery/MultiClaimer.sol";

contract MultiClaimerTest is Setup {
    MultiClaimer public multiClaimer;
    IStrategyInterface public strategy2;

    address public owner = address(0x123);
    address public user1 = address(0x456);
    address public user2 = address(0x789);

    function setUp() public override {
        super.setUp();

        // Deploy MultiClaimer
        multiClaimer = new MultiClaimer(owner);

        // Deploy a second strategy with different vault/want combination
        // Use a different vault and want token to avoid "Strategy already deployed" error
        ERC20 differentVault = ERC20(
            0xAe7d8Db82480E6d8e3873ecbF22cf17b3D8A7308
        ); // usdc-2
        ERC20 differentWant = ERC20(tokenAddrs["WETH"]);

        strategy2 = IStrategyInterface(
            address(
                strategyFactory.newYieldSplitter(
                    address(differentVault),
                    address(differentWant)
                )
            )
        );

        vm.prank(management);
        strategy2.acceptManagement();

        // Label addresses for better traces
        vm.label(address(multiClaimer), "MultiClaimer");
        vm.label(owner, "Owner");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
    }

    function test_constructor() public {
        assertEq(multiClaimer.owner(), owner, "Owner not set correctly");
    }

    function test_claim_singleVault() public {
        uint256 depositAmount = 1000e6;

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user1, depositAmount);

        // Set MultiClaimer as claim recipient for user1
        vm.prank(user1);
        strategy.setClaimForSelf(address(multiClaimer));

        // Simulate rewards by airdropping want tokens to reward handler
        uint256 rewardAmount = 10e18;
        airdrop(want, address(strategy.rewardHandler()), rewardAmount);

        // Claim rewards through the strategy first
        vm.prank(keeper);
        strategy.claimRewards();

        // Skip time to unlock profits
        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = want.balanceOf(user1);

        // Claim rewards using MultiClaimer
        vm.prank(user1);
        address[] memory vaults = new address[](1);
        vaults[0] = address(strategy);
        multiClaimer.claim(vaults);

        uint256 balanceAfter = want.balanceOf(user1);
        assertGt(
            balanceAfter,
            balanceBefore,
            "Should have claimed some rewards"
        );
        assertEq(
            want.balanceOf(address(multiClaimer)),
            0,
            "MultiClaimer should not hold tokens"
        );
    }

    function test_claim_multipleVaults() public {
        uint256 depositAmount = 1000e6;

        // Deposit into both strategies
        mintAndDepositIntoStrategy(strategy, user1, depositAmount);
        mintAndDepositIntoStrategy(strategy2, user1, depositAmount);

        // Set MultiClaimer as claim recipient for user1 on both strategies
        vm.prank(user1);
        strategy.setClaimForSelf(address(multiClaimer));
        vm.prank(user1);
        strategy2.setClaimForSelf(address(multiClaimer));

        // Simulate rewards for both strategies
        uint256 rewardAmount1 = 10e18;
        uint256 rewardAmount2 = 15e18;
        airdrop(want, address(strategy.rewardHandler()), rewardAmount1);
        airdrop(
            ERC20(strategy2.want()),
            address(strategy2.rewardHandler()),
            rewardAmount2
        );

        // Claim rewards through the strategies first
        vm.prank(keeper);
        strategy.claimRewards();
        vm.prank(keeper);
        strategy2.claimRewards();

        // Skip time to unlock profits
        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = want.balanceOf(user1);
        uint256 balanceBefore2 = ERC20(strategy2.want()).balanceOf(user1);

        // Claim rewards from both vaults using MultiClaimer
        vm.prank(user1);
        address[] memory vaults = new address[](2);
        vaults[0] = address(strategy);
        vaults[1] = address(strategy2);
        multiClaimer.claim(vaults);

        uint256 balanceAfter = want.balanceOf(user1);
        uint256 balanceAfter2 = ERC20(strategy2.want()).balanceOf(user1);
        assertGt(
            balanceAfter,
            balanceBefore,
            "Should have claimed rewards from first vault"
        );
        assertGt(
            balanceAfter2,
            balanceBefore2,
            "Should have claimed rewards from second vault"
        );
    }

    function test_claim_noRewards() public {
        uint256 depositAmount = 1000e6;

        // Deposit into strategy but don't add any rewards
        mintAndDepositIntoStrategy(strategy, user1, depositAmount);

        // Set MultiClaimer as claim recipient for user1
        vm.prank(user1);
        strategy.setClaimForSelf(address(multiClaimer));

        uint256 balanceBefore = want.balanceOf(user1);

        // Try to claim rewards
        vm.prank(user1);
        address[] memory vaults = new address[](1);
        vaults[0] = address(strategy);
        multiClaimer.claim(vaults);

        uint256 balanceAfter = want.balanceOf(user1);
        assertEq(
            balanceAfter,
            balanceBefore,
            "Should not have claimed any rewards"
        );
    }

    function test_claim_emptyVaultArray() public {
        uint256 balanceBefore = want.balanceOf(user1);

        // Try to claim with empty array
        vm.prank(user1);
        address[] memory vaults = new address[](0);
        multiClaimer.claim(vaults);

        uint256 balanceAfter = want.balanceOf(user1);
        assertEq(
            balanceAfter,
            balanceBefore,
            "Should not have claimed any rewards"
        );
    }

    function test_rescue_owner() public {
        uint256 rescueAmount = 1000e18;

        // Airdrop tokens to MultiClaimer
        airdrop(want, address(multiClaimer), rescueAmount);

        uint256 ownerBalanceBefore = want.balanceOf(owner);

        // Owner should be able to rescue tokens
        vm.prank(owner);
        multiClaimer.rescue(address(want));

        uint256 ownerBalanceAfter = want.balanceOf(owner);
        assertEq(
            ownerBalanceAfter - ownerBalanceBefore,
            rescueAmount,
            "Owner should receive rescued tokens"
        );
        assertEq(
            want.balanceOf(address(multiClaimer)),
            0,
            "MultiClaimer should have no tokens left"
        );
    }

    function test_rescue_nonOwner() public {
        uint256 rescueAmount = 1000e18;

        // Airdrop tokens to MultiClaimer
        airdrop(want, address(multiClaimer), rescueAmount);

        // Non-owner should not be able to rescue tokens
        vm.prank(user1);
        vm.expectRevert("MultiClaimer: not owner");
        multiClaimer.rescue(address(want));

        // Tokens should still be in MultiClaimer
        assertEq(
            want.balanceOf(address(multiClaimer)),
            rescueAmount,
            "Tokens should not be rescued"
        );
    }

    function test_claim_largeNumberOfVaults() public {
        uint256 numVaults = 2;
        address[] memory vaults = new address[](numVaults);
        uint256 depositAmount = 1000e6;
        uint256 rewardAmount = 5e18;

        // Use existing strategies
        vaults[0] = address(strategy);
        vaults[1] = address(strategy2);

        // Deposit into all strategies
        mintAndDepositIntoStrategy(strategy, user1, depositAmount);
        mintAndDepositIntoStrategy(strategy2, user1, depositAmount);

        // Set MultiClaimer as claim recipient for user1 on both strategies
        vm.prank(user1);
        strategy.setClaimForSelf(address(multiClaimer));
        vm.prank(user1);
        strategy2.setClaimForSelf(address(multiClaimer));

        // Add rewards to all strategies
        airdrop(want, address(strategy.rewardHandler()), rewardAmount);
        airdrop(
            ERC20(strategy2.want()),
            address(strategy2.rewardHandler()),
            rewardAmount
        );

        // Claim rewards through strategies
        vm.prank(keeper);
        strategy.claimRewards();
        vm.prank(keeper);
        strategy2.claimRewards();

        // Skip time to unlock profits
        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = want.balanceOf(user1);
        uint256 balanceBefore2 = ERC20(strategy2.want()).balanceOf(user1);

        // Claim from all vaults
        vm.prank(user1);
        multiClaimer.claim(vaults);

        uint256 balanceAfter = want.balanceOf(user1);
        uint256 balanceAfter2 = ERC20(strategy2.want()).balanceOf(user1);
        assertGt(balanceAfter, balanceBefore, "Should claim from first vault");
        assertGt(
            balanceAfter2,
            balanceBefore2,
            "Should claim from second vault"
        );
    }

    function test_claim_withRealRewards() public {
        uint256 depositAmount = 1000e6;

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user1, depositAmount);

        skip(10);

        // Set MultiClaimer as claim recipient for user1
        vm.prank(user1);
        strategy.setClaimForSelf(address(multiClaimer));

        // Simulate vault rewards
        uint256 wantRewards = ((depositAmount * 5) / 1000) * 1e12; // 0.5% rewards
        airdrop(want, address(strategy.rewardHandler()), wantRewards);

        // Report profit to generate rewards
        vm.prank(keeper);
        strategy.report();

        // Skip time to unlock profits
        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = want.balanceOf(user1);

        // Claim rewards using MultiClaimer
        vm.prank(user1);
        address[] memory vaults = new address[](1);
        vaults[0] = address(strategy);
        multiClaimer.claim(vaults);

        uint256 balanceAfter = want.balanceOf(user1);
        assertGt(
            balanceAfter,
            balanceBefore,
            "Should have claimed real rewards"
        );
    }
}
