// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {RewardHandler} from "./RewardHandler.sol";
import {YearnYieldSplitter, ERC20} from "./YearnYieldSplitter.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";
import {Auction} from "@periphery/Auctions/Auction.sol";
import {AuctionFactory} from "@periphery/Auctions/AuctionFactory.sol";

contract YearnYieldSplitterFactory {
    event NewYieldSplitter(
        address indexed strategy,
        address indexed vault,
        address indexed want
    );

    AuctionFactory public constant AUCTION_FACTORY =
        AuctionFactory(0xCfA510188884F199fcC6e750764FAAbE6e56ec40);

    address public immutable emergencyAdmin;

    address public management;
    address public performanceFeeRecipient;
    address public keeper;

    /// @notice Track the deployments. asset => pool => strategy
    mapping(address => mapping(address => address)) public deployments;

    constructor(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) {
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }

    /**
     * @notice Deploy a new Strategy.
     * @param _vault The vault to use for the yield source.
     * @param _want The token to turn the yield in to.
     * @return . The address of the new strategy.
     */
    function newYieldSplitter(address _vault, address _want)
        external
        virtual
        returns (address)
    {
        require(
            deployments[_vault][_want] == address(0),
            "Strategy already deployed"
        );
        require(_vault != _want, "bad pair");

        address _asset = IStrategyInterface(_vault).asset();

        string memory _name = string.concat(
            "Yearn ",
            ERC20(_vault).symbol(),
            " to ",
            ERC20(_want).symbol(),
            " Yield Splitter"
        );

        RewardHandler _rewardHandler = new RewardHandler(_want);

        // tokenized strategies available setters.
        IStrategyInterface _newStrategy = IStrategyInterface(
            address(
                new YearnYieldSplitter(
                    _asset,
                    _name,
                    _vault,
                    _want,
                    address(_rewardHandler)
                )
            )
        );

        _rewardHandler.initialize(address(_newStrategy));

        Auction _auction = Auction(
            AUCTION_FACTORY.createNewAuction(
                address(_want),
                address(_rewardHandler), // Reward Handler is the recipient
                address(this), // gov
                1 days,
                10_000
            )
        );

        _auction.enable(address(_asset));
        _auction.transferGovernance(management);

        _newStrategy.setAuction(address(_auction));

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);

        _newStrategy.setKeeper(keeper);

        _newStrategy.setPendingManagement(management);

        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewYieldSplitter(address(_newStrategy), _vault, _want);

        deployments[_vault][_want] = address(_newStrategy);
        return address(_newStrategy);
    }

    function setAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper
    ) external {
        require(msg.sender == management, "!management");
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
    }

    function isDeployedStrategy(address _strategy)
        external
        view
        returns (bool)
    {
        address _want = IStrategyInterface(_strategy).want();
        address _vault = IStrategyInterface(_strategy).vault();
        return deployments[_vault][_want] == _strategy;
    }
}
