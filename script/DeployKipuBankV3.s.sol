// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";

/// @title Deployment Script for KipuBankV3
/// @notice Deploys the KipuBankV3 contract using Foundry scripts.
/// @dev Reads environment variables for PRIVATE_KEY and ADMIN_ADDRESS.
///      Designed for deployment on Sepolia or compatible EVM networks.
contract DeployKipuBankV3 is Script {
    /// @notice Executes the deployment transaction for KipuBankV3.
    /// @dev Loads deployment configuration from environment variables.
    ///      - PRIVATE_KEY: private key of the deployer
    ///      - ADMIN_ADDRESS: admin wallet for contract initialization
    function run() external {
        // Load deployer private key from environment (e.g. export PRIVATE_KEY=0x...)
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // Load admin address from environment
        address admin = 0xFF81866da6caDCb11b10b204661c951C03FCCbEE;

        // Sepolia addresses (public)
        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        address router = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
        address factory = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;

        // Set bankCap: example 1,000,000 USDC = 1_000_000 * 10^6
        uint256 cap = 1_000_000 * 10 ** 6;

        // Deploy KipuBankV3
        KipuBankV3 bank = new KipuBankV3(admin, usdc, router, factory, cap);

        console.log("KipuBankV3 deployed at:", address(bank));

        vm.stopBroadcast();
    }
}
