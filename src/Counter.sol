// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title Counter Contract
/// @notice A simple example contract that allows storing and incrementing a number.
/// @dev Demonstrates basic state updates and public visibility.
contract Counter {
    /// @notice The stored number.
    uint256 public number;

    /// @notice Sets the stored number to a new value.
    /// @param newNumber The value to set as the current number.
    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    /// @notice Increments the stored number by one.
    function increment() public {
        number++;
    }
}
