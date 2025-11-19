// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {KipuBankV3} from "../src/KipuBankV3.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @title MaliciousUSDC & ReentrantHelper (test helpers)
/// @author Pilar
/// @notice Test helpers used to verify reentrancy protection in KipuBankV3.
/// @dev These contracts are intentionally malicious / adversarial and must only be used in test environments.
 
/// @notice MaliciousUSDC — a mock token that attempts to reenter the bank during `transfer`.
/// @dev When transferring to the designated `attacker` address, this token will call
///      `withdrawUsdc(...)` on the configured `bankAddress`. This is used to assert that
///      KipuBankV3 correctly protects withdraws with ReentrancyGuard. This contract deliberately
///      does not catch reverts — tests expect the ReentrancyGuard revert to bubble up.
contract MaliciousUSDC is MockERC20 {
    /// @notice Address that will receive malicious callbacks.
    address public attacker;

    /// @notice Address of the KipuBankV3 instance that the token will attempt to attack.
    address payable public bankAddress;

    /// @notice Construct a malicious ERC20 token with custom decimals.
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param decimals_ Token decimals (e.g., 6 for USDC).
    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockERC20(name_, symbol_, decimals_) {}

    /// @notice Sets the address that will be treated as the attacker recipient.
    /// @param _attacker Address that will receive the special callback during `transfer`.
    /// @dev Only for tests — no access control is provided.
    function setAttacker(address _attacker) external {
        attacker = _attacker;
    }

    /// @notice Sets the bank address that will be called during the malicious callback.
    /// @param _bank The payable address of the KipuBankV3 instance under test.
    /// @dev Only for tests — no access control is provided.
    function setBankAddress(address payable _bank) external {
        bankAddress = _bank;
    }

    /// @notice Override of ERC20 `transfer` that attempts a reentrant withdraw when the recipient is `attacker`.
    /// @dev Calls the parent `transfer` first (so balances are updated), then if `to == attacker`
    ///      calls `withdrawUsdc(amount)` on the preconfigured `bankAddress` to attempt reentrancy.
    ///      Tests should configure `bankAddress` to point to the instance under test and
    ///      set `attacker` to the helper contract that will trigger further actions.
    /// @param to Recipient address.
    /// @param amount Amount to transfer (in token smallest units).
    /// @return bool True if the underlying ERC20 transfer succeeded.
    function transfer(address to, uint256 amount) public override returns (bool) {
        bool ok = super.transfer(to, amount);

        // If the recipient is the attacker and a bank is configured, call withdraw on the bank.
        // This is intentionally vulnerable for testing ReentrancyGuard behavior.
        if (to == attacker && bankAddress != payable(address(0))) {
            // Intentionally call withdraw on the target bank to attempt reentrancy.
            KipuBankV3(bankAddress).withdrawUsdc(amount);
        }

        return ok;
    }
}

/// @title ReentrantHelper
/// @notice Small helper contract that interacts with KipuBankV3 to facilitate reentrancy tests.
/// @dev Typical flow:
///      1) Mint malicious tokens to ReentrantHelper (done by test).
///      2) Approve the bank and call `depositToBank(...)` to fund the bank with malicious tokens.
///      3) Call `triggerWithdraw(...)` to call `withdrawUsdc(...)` on the bank — the malicious token's
///         `transfer` will callback into the bank during the withdrawal if configured.
contract ReentrantHelper {
    /// @notice Reference to the bank under test.
    KipuBankV3 public bank;

    /// @notice ERC20 token used as (malicious) USDC in tests.
    MockERC20 public usdc;

    /// @param _bank The KipuBankV3 instance to interact with.
    /// @param usdcAddr The address of the mock USDC token contract.
    constructor(KipuBankV3 _bank, address usdcAddr) {
        bank = _bank;
        usdc = MockERC20(usdcAddr);
    }

    /// @notice Approves the bank and deposits `amount` of the mock USDC into the bank.
    /// @dev The caller must hold `amount` tokens; tests typically `mint` tokens to this helper first.
    /// @param amount Amount to deposit (USDC base units; 6 decimals in typical tests).
    function depositToBank(uint256 amount) external {
        // Approve bank to pull tokens and deposit
        usdc.approve(address(bank), amount);
        bank.depositUsdc(amount);
    }

    /// @notice Triggers a withdraw call on the bank.
    /// @dev If the underlying token is configured to callback (MaliciousUSDC), this will cause a
    ///      reentrancy attempt during the token transfer.
    /// @param amount Amount to withdraw (USDC base units).
    function triggerWithdraw(uint256 amount) external {
        bank.withdrawUsdc(amount);
    }
}
