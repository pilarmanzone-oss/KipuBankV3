// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

/// @title Counter Deployment Script
/// @notice This script deploys the `Counter` contract to the target network.
/// @dev Uses Foundry's `vm.startBroadcast()` to broadcast transactions.
contract CounterScript is Script {
    /// @notice Instance of the deployed Counter contract.
    Counter public counter;

    /// @notice Sets up the script environment before deployment.
    /// @dev This function is called automatically by Foundry before `run()`.
    function setUp() public {}

    /// @notice Deploys a new Counter contract instance.
    /// @dev Broadcasts the transaction using Foundry's cheatcodes.
    function run() public {
        vm.startBroadcast();

        counter = new Counter();

        vm.stopBroadcast();
    }
}
