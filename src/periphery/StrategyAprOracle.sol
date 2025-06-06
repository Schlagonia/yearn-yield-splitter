// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IStrategyInterface} from "../interfaces/IStrategyInterface.sol";
import {AprOracle} from "@periphery/AprOracle/AprOracle.sol";

contract StrategyAprOracle {

    AprOracle public constant CORE_APR_ORACLE =
        AprOracle(0x1981AD9F44F2EA9aDd2dC4AD7D075c102C70aF92);

    /**
     * @notice Will return the expected Apr of a strategy post a debt change.
     * @dev _delta is a signed integer so that it can also represent a debt
     * decrease.
     *
     * This should return the annual expected return at the current timestamp
     * represented as 1e18.
     *
     *      ie. 10% == 1e17
     *
     * _delta will be == 0 to get the current apr.
     *
     * This will potentially be called during non-view functions so gas
     * efficiency should be taken into account.
     *
     * @param _strategy The token to get the apr for.
     * @param _delta The difference in debt.
     * @return . The expected apr for the strategy represented as 1e18.
     */
    function aprAfterDebtChange(address _strategy, int256 _delta)
        external
        view
        returns (uint256)
    {
        address vault = IStrategyInterface(_strategy).vault();
        return CORE_APR_ORACLE.getStrategyApr(vault, _delta);
    }
}
