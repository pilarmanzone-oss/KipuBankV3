// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/// @title MockUniswapRouter
/// @author Pilar (adapted)
/// @notice Minimal mock of the Uniswap V2 Router for testing purposes.
/// @dev This contract simulates swap behavior by minting mock USDC tokens instead of performing real swaps.
///      It is used exclusively for local and unit testing environments.
contract MockUniswapRouter {
    /// @notice Address of the mock USDC token used for simulated swaps.
    address public immutable USDC;

    /// @notice The pre-set amount of USDC that will be "returned" in the next swap.
    /// @dev Used to simulate predictable swap outcomes during tests.
    uint256 public nextUsdcOut;

    /// @notice Initializes the mock router with the mock USDC address.
    /// @param usdc_ The address of the mock USDC token contract.
    constructor(address usdc_) {
        USDC = usdc_;
    }

    /// @notice Sets the simulated output amount of USDC for the next swap.
    /// @dev This function is called by tests to control the output value.
    /// @param usdcOut The amount of USDC to mint on the next simulated swap.
    function setSwapResult(uint256 usdcOut) external {
        nextUsdcOut = usdcOut;
    }

    /// @notice Simulates a token-to-token swap (e.g., DAI → USDC).
    /// @dev This mock does not pull tokens from the caller. Instead, it directly mints
    ///      the pre-set amount of mock USDC to the recipient address (`to`).
    ///      The parameters `amountOutMin` and `deadline` are kept only for
    ///      compatibility with the real Uniswap V2 Router interface.
    /// @param amountIn The amount of the input token (ignored by the mock).
    /// @param path The swap path (token addresses); only the length is used in this mock.
    /// @param to The recipient of the minted USDC tokens.
    /// @return amounts An array with the input and output token amounts.
    function swapExactTokensForTokens(
        uint amountIn,
        uint /* amountOutMin */,
        address[] calldata path,
        address to,
        uint /* deadline */
    ) external returns (uint[] memory amounts) {
        MockERC20(USDC).mint(to, nextUsdcOut);

        amounts = new uint256[](path.length + 1);
        amounts[0] = amountIn;
        amounts[1] = nextUsdcOut;
    }

    /// @notice Receives native ETH transfers.
    receive() external payable {}

    /// @notice Simulates a swap from ETH to tokens (e.g., ETH → USDC).
    /// @param path The swap path (must contain at least 2 addresses).
    /// @param to The recipient address of the minted USDC.
    /// @return amounts An array with the input ETH value and simulated USDC output.
    function swapExactEthForTokens(
        uint /* amountOutMin */,
        address[] calldata path,
        address to,
        uint /* deadline */
    ) external payable returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");

        MockERC20(USDC).mint(to, nextUsdcOut);

        amounts = new uint256[](2); 
        amounts[0] = msg.value;
        amounts[1] = nextUsdcOut;
    }

    /// @notice Simulates the Uniswap V2 `swapExactETHForTokens` function.
    /// @param amountOutMin The minimum acceptable output amount (unused).
    /// @param path The swap path (must contain at least 2 addresses).
    /// @param to The recipient address of the minted USDC.
    /// @param deadline The transaction deadline (unused in mock).
    /// @return amounts An array with input ETH and simulated USDC output.
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");

        MockERC20(USDC).mint(to, nextUsdcOut);

        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = nextUsdcOut;
    }

    /// @notice Returns a mock WETH address used for testing.
    function WETH() external pure returns (address) {
        return address(0xC0FFee);
    }
}
