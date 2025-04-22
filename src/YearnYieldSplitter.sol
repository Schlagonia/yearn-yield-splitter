// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RewardHandler} from "./RewardHandler.sol";

import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";
import {TokenizedStaker, ERC20} from "@periphery/Bases/Staker/TokenizedStaker.sol";
import {Auction} from "@periphery/Auctions/Auction.sol";
import {AuctionFactory} from "@periphery/Auctions/AuctionFactory.sol";

contract YearnYieldSplitter is TokenizedStaker {
    using SafeERC20 for ERC20;

    IStrategyInterface public immutable vault;

    address public immutable want;

    address public immutable rewardHandler;

    Auction public auction;

    constructor(
        address _asset,
        string memory _name,
        address _vault,
        address _want,
        address _rewardHandler,
        address _management
    ) TokenizedStaker(_asset, _name) {
        asset.forceApprove(_vault, type(uint256).max);
        vault = IStrategyInterface(_vault);
        want = _want;
        rewardHandler = _rewardHandler;

        _addReward(want, rewardHandler, 1 days);

        auction = Auction(
            AuctionFactory(0xCfA510188884F199fcC6e750764FAAbE6e56ec40)
                .createNewAuction(
                    address(_want),
                    address(rewardHandler), // Reward Handler is the recipient
                    address(this), // gov
                    1 days,
                    10_000
                )
        );

        auction.enable(address(asset));
        auction.transferGovernance(_management);
    }

    /*//////////////////////////////////////////////////////////////
                NEEDED TO BE OVERRIDDEN BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Can deploy up to '_amount' of 'asset' in the yield source.
     *
     * This function is called at the end of a {deposit} or {mint}
     * call. Meaning that unless a whitelist is implemented it will
     * be entirely permissionless and thus can be sandwiched or otherwise
     * manipulated.
     *
     * @param _amount The amount of 'asset' that the strategy can attempt
     * to deposit in the yield source.
     */
    function _deployFunds(uint256 _amount) internal override {
        vault.deposit(_amount, address(this));
    }

    /**
     * @dev Should attempt to free the '_amount' of 'asset'.
     *
     * NOTE: The amount of 'asset' that is already loose has already
     * been accounted for.
     *
     * This function is called during {withdraw} and {redeem} calls.
     * Meaning that unless a whitelist is implemented it will be
     * entirely permissionless and thus can be sandwiched or otherwise
     * manipulated.
     *
     * Should not rely on asset.balanceOf(address(this)) calls other than
     * for diff accounting purposes.
     *
     * Any difference between `_amount` and what is actually freed will be
     * counted as a loss and passed on to the withdrawer. This means
     * care should be taken in times of illiquidity. It may be better to revert
     * if withdraws are simply illiquid so not to realize incorrect losses.
     *
     * @param _amount, The amount of 'asset' to be freed.
     */
    function _freeFunds(uint256 _amount) internal override {
        // Use previewWithdraw to round up.
        uint256 shares = vault.previewWithdraw(_amount);
        shares = Math.min(shares, balanceOfVault());

        vault.redeem(shares, address(this), address(this));
    }

    /**
     * @dev Internal function to harvest all rewards, redeploy any idle
     * funds and return an accurate accounting of all funds currently
     * held by the Strategy.
     *
     * This should do any needed harvesting, rewards selling, accrual,
     * redepositing etc. to get the most accurate view of current assets.
     *
     * NOTE: All applicable assets including loose assets should be
     * accounted for in this function.
     *
     * Care should be taken when relying on oracles or swap values rather
     * than actual amounts as all Strategy profit/loss accounting will
     * be done based on this returned value.
     *
     * This can still be called post a shutdown, a strategist can check
     * `TokenizedStrategy.isShutdown()` to decide if funds should be
     * redeployed or simply realize any profits/losses.
     *
     * @return _totalAssets A trusted and accurate account for the total
     * amount of 'asset' the strategy currently holds including idle funds.
     */
    function _harvestAndReport()
        internal
        override
        returns (uint256 _totalAssets)
    {
        // Claim and notify pending rewards.
        claimRewards();

        _totalAssets = TokenizedStrategy.totalAssets();

        // Settle if already taken but not done.
        if (auction.isActive(address(asset))) {
            if (auction.available(address(asset)) == 0) {
                auction.settle(address(asset));
            } else {
                // If still active just return.
                return _totalAssets;
            }
        }

        uint256 looseAssets = balanceOfAsset();
        uint256 currentAssets = looseAssets + valueOfVault();
        uint256 profit;
        if (currentAssets > _totalAssets) {
            profit = currentAssets - _totalAssets;

            if (profit > looseAssets) {
                _freeFunds(profit - looseAssets);
            }

            // Adjust for any rounding losses on withdraw.
            profit = Math.min(profit, balanceOfAsset());

            // If no profit return
        } else {
            return _totalAssets;
        }

        // Fees
        uint256 fee = (profit * TokenizedStrategy.performanceFee()) / 10_000;
        asset.safeTransfer(TokenizedStrategy.performanceFeeRecipient(), fee);

        // Kick next auction
        asset.safeTransfer(address(auction), profit - fee);
        auction.kick(address(asset));
    }

    function claimRewards() public {
        RewardHandler(rewardHandler).claimRewards();
    }

    function balanceOfVault() public view returns (uint256) {
        return vault.balanceOf(address(this));
    }

    function balanceOfAsset() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function valueOfVault() public view virtual returns (uint256) {
        return vault.convertToAssets(balanceOfVault());
    }

    function vaultsMaxWithdraw() public view virtual returns (uint256) {
        return vault.convertToAssets(vault.maxRedeem(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                    OPTIONAL TO OVERRIDE BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the max amount of `asset` that can be withdrawn.
     * @dev Defaults to an unlimited amount for any address. But can
     * be overridden by strategists.
     *
     * This function will be called before any withdraw or redeem to enforce
     * any limits desired by the strategist. This can be used for illiquid
     * or sandwichable strategies.
     *
     *   EX:
     *       return asset.balanceOf(yieldSource);
     *
     * This does not need to take into account the `_owner`'s share balance
     * or conversion rates from shares to assets.
     *
     * @param . The address that is withdrawing from the strategy.
     * @return . The available amount that can be withdrawn in terms of `asset`
     */
    function availableWithdrawLimit(
        address /*_owner*/
    ) public view override returns (uint256) {
        return balanceOfAsset() + vaultsMaxWithdraw();
    }

    /**
     * @notice Gets the max amount of `asset` that an address can deposit.
     * @dev Defaults to an unlimited amount for any address. But can
     * be overridden by strategists.
     *
     * This function will be called before any deposit or mints to enforce
     * any limits desired by the strategist. This can be used for either a
     * traditional deposit limit or for implementing a whitelist etc.
     *
     *   EX:
     *      if(isAllowed[_owner]) return super.availableDepositLimit(_owner);
     *
     * This does not need to take into account any conversion rates
     * from shares to assets. But should know that any non max uint256
     * amounts may be converted to shares. So it is recommended to keep
     * custom amounts low enough as not to cause overflow when multiplied
     * by `totalSupply`.
     *
     * @param . The address that is depositing into the strategy.
     * @return . The available amount the `_owner` can deposit in terms of `asset`
     */
    function availableDepositLimit(address _owner)
        public
        view
        override
        returns (uint256)
    {
        return vault.maxDeposit(address(this));
    }

    /**
     * @dev Optional function for a strategist to override that will
     * allow management to manually withdraw deployed funds from the
     * yield source if a strategy is shutdown.
     *
     * This should attempt to free `_amount`, noting that `_amount` may
     * be more than is currently deployed.
     *
     * NOTE: This will not realize any profits or losses. A separate
     * {report} will be needed in order to record any profit/loss. If
     * a report may need to be called after a shutdown it is important
     * to check if the strategy is shutdown during {_harvestAndReport}
     * so that it does not simply re-deploy all funds that had been freed.
     *
     * EX:
     *   if(freeAsset > 0 && !TokenizedStrategy.isShutdown()) {
     *       depositFunds...
     *    }
     *
     * @param _amount The amount of asset to attempt to free.
     */
    function _emergencyWithdraw(uint256 _amount) internal override {
        _freeFunds(Math.min(_amount, vaultsMaxWithdraw()));
    }

    function setAuction(address _auction) external onlyManagement {
        require(Auction(_auction).want() == want, "Invalid want");
        (, uint64 scaler, ) = Auction(_auction).auctions(address(asset));
        require(scaler != 0, "asset not enabled");

        auction = Auction(_auction);
    }
}
