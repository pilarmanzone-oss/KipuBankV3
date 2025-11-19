// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @author Pilar
/// @notice A minimal ERC20 token implementation for testing purposes.
/// @dev Extends OpenZeppelin's ERC20 contract and allows external minting without access control.
///      This mock for local testing only, NOT to be used in production.
contract MockERC20 is ERC20 {
    /// @notice Custom decimals value for this mock token.
    uint8 private _decimals;

    /// @notice Deploys a new mock ERC20 token.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol (ticker) of the token.
    /// @param decimals_ The number of decimals to use for display and accounting.
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    /// @notice Mints new tokens to the specified address.
    /// @dev This function has no access control — any account can mint arbitrary amounts.
    ///      It is meant for testing and simulation in Foundry or Hardhat environments.
    /// @param to The address that will receive the newly minted tokens.
    /// @param amount The amount of tokens to mint (in smallest unit, e.g., wei).
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Returns the number of decimals used by this token.
    /// @dev Overrides the default OpenZeppelin ERC20 implementation to allow custom decimals.
    /// @return The number of decimals for this token.
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
