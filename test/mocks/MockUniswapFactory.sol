// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockUniswapFactory
/// @author Pilar
/// @notice Minimal mock implementation of the Uniswap V2 Factory for testing purposes.
/// @dev Allows developers to manually register token pairs and retrieve them, mimicking
///      the behavior of a Uniswap factory contract in a controlled test environment.
contract MockUniswapFactory {
    /// @notice Mapping of encoded token pair keys to their corresponding pair contract address.
    mapping(bytes32 => address) public pairs;

    /// @notice Manually sets a pair address for a given pair of tokens.
    /// @dev Stores the mapping in both directions (A→B and B→A) to simulate Uniswap behavior.
    ///      This function is intended for use in test environments only.
    /// @param a The address of the first token.
    /// @param b The address of the second token.
    /// @param pair The address of the liquidity pair contract associated with tokens A and B.
    function setPair(address a, address b, address pair) external {
        bytes32 k = _key(a, b);
        pairs[k] = pair;
        // Also register the reverse pair mapping
        pairs[_key(b, a)] = pair;
    }

    /// @notice Returns the address of the pair associated with two given tokens.
    /// @param tokenA The address of the first token.
    /// @param tokenB The address of the second token.
    /// @return The address of the corresponding pair contract, or address(0) if not set.
    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[_key(tokenA, tokenB)];
    }

    /// @notice Computes the unique key representing a token pair.
    /// @dev Uses the keccak256 hash of the concatenated token addresses.
    /// @param a The address of the first token.
    /// @param b The address of the second token.
    /// @return A bytes32 hash representing the unique key for the token pair.
    function _key(address a, address b) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a, b));
    }
}
