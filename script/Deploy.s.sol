// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {YearnYieldSplitterFactory} from "../src/YearnYieldSplitterFactory.sol";
import {console2} from "forge-std/console2.sol";
import {IStrategyInterface} from "../src/interfaces/IStrategyInterface.sol";

contract Deploy is Script {

    address public management = 0xBe7c7efc1ef3245d37E3157F76A512108D6D7aE6;
    address public performanceFeeRecipient = 0x1f399808fE52d0E960CAB84b6b54d5707ab27c8a;
    address public keeper = 0x1b5f15DCb82d25f91c65b53CEe151E8b9fBdD271; //0xC29cbdcf5843f8550530cc5d627e1dd3007EF231;
    address public emergencyAdmin = 0xBe7c7efc1ef3245d37E3157F76A512108D6D7aE6;

    struct Pairs {
        address vault;
        address want;
    }

    function run() public {
        vm.startBroadcast();

        Pairs[] memory toDeploy = getToDeploy();

        YearnYieldSplitterFactory _factory = new YearnYieldSplitterFactory(
            management,
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );

        console2.log("Factory deployed to", address(_factory));

        for(uint256 i = 0; i < toDeploy.length; ++i) {
            address vault = toDeploy[i].vault;
            address want = toDeploy[i].want;
            address strategy = _factory.newYieldSplitter(vault, want);
            console2.log(
                "Deployed strategy for %s vault and %s want to %s",
                IStrategyInterface(vault).symbol(),
                IStrategyInterface(want).symbol(),
                strategy
            );
            //console2.log("Address : ", strategy);
        }

        vm.stopBroadcast();
    }

    function getToDeploy() public view returns (Pairs[] memory _toDeploy) {
        _toDeploy = new Pairs[](6);

        _toDeploy[0] = Pairs({
            vault: 0xE007CA01894c863d7898045ed5A3B4Abf0b18f37,
            want: 0x80c34BD3A3569E126e7055831036aa7b212cB159
        });

        _toDeploy[1] = Pairs({
            vault: 0xAa0362eCC584B985056E47812931270b99C91f9d,
            want: 0x80c34BD3A3569E126e7055831036aa7b212cB159
        });

        _toDeploy[2] = Pairs({
            vault: 0x80c34BD3A3569E126e7055831036aa7b212cB159,
            want: 0xE007CA01894c863d7898045ed5A3B4Abf0b18f37
        });

        _toDeploy[3] = Pairs({
            vault: 0x80c34BD3A3569E126e7055831036aa7b212cB159,
            want: 0xAa0362eCC584B985056E47812931270b99C91f9d
        });

        _toDeploy[4] = Pairs({
            vault: 0xE007CA01894c863d7898045ed5A3B4Abf0b18f37,
            want: 0xAa0362eCC584B985056E47812931270b99C91f9d
        });

        _toDeploy[5] = Pairs({
            vault: 0xAa0362eCC584B985056E47812931270b99C91f9d,
            want: 0xE007CA01894c863d7898045ed5A3B4Abf0b18f37
        });
    }
}