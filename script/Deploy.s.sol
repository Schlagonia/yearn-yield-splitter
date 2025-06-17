// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {YearnYieldSplitterFactory} from "../src/YearnYieldSplitterFactory.sol";
import {console} from "forge-std/console.sol";
import {IStrategyInterface} from "../src/interfaces/IStrategyInterface.sol";

contract Deploy is Script {

    address public management = 0x1b5f15DCb82d25f91c65b53CEe151E8b9fBdD271;

    address public vault = 0x639bCcF37CC0415812A6f110CFCa33127a81c0e9;
    address public usdc = 0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36;

    function run() public {
        vm.startBroadcast();

        YearnYieldSplitterFactory _factory = new YearnYieldSplitterFactory(
            management,
            management,
            management,
            management
        );

        console.log("Factory deployed to", address(_factory));

        IStrategyInterface _splitter = IStrategyInterface(_factory.newYieldSplitter(vault, usdc));

        console.log("Splitter deployed to", address(_splitter));

        _splitter.acceptManagement();

        vm.stopBroadcast();
    }
}