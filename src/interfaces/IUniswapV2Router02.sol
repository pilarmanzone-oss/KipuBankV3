// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Interface for Uniswap V2 Router02
/// @notice Defines the essential functions to interact with the Uniswap V2 Router or compatible protocols (e.g., SushiSwap).
interface IUniswapV2Router02 {
    /// @notice Returns the address of the associated Uniswap factory.
    /// @return The address of the factory contract.
    function factory() external view returns (address);

    /// @notice Returns the address of the Wrapped Ether (WETH) token used by the router.
    /// @return The address of the WETH contract.
    function WETH() external pure returns (address);

    /// @notice Adds liquidity to an ERC20 token pair.
    /// @param tokenA The address of the first token in the pair.
    /// @param tokenB The address of the second token in the pair.
    /// @param amountADesired The desired amount of token A to provide.
    /// @param amountBDesired The desired amount of token B to provide.
    /// @param amountAMin The minimum acceptable amount of token A to avoid slippage.
    /// @param amountBMin The minimum acceptable amount of token B to avoid slippage.
    /// @param to The address that will receive the liquidity (LP) tokens.
    /// @param deadline The timestamp after which the transaction will revert.
    /// @return amountA The final amount of token A provided.
    /// @return amountB The final amount of token B provided.
    /// @return liquidity The amount of LP tokens minted.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Swaps ETH for ERC20 tokens following a specified path.
    /// @param amountOutMin The minimum acceptable output amount.
    /// @param path The list of token addresses representing the swap route.
    /// @param to The address that will receive the output tokens.
    /// @param deadline The timestamp after which the transaction will revert.
    /// @return amounts An array of amounts transferred at each step of the swap.
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    /// @notice Swaps one ERC20 token for another.
    /// @param amountIn The amount of input tokens.
    /// @param amountOutMin The minimum acceptable output amount.
    /// @param path The list of token addresses representing the swap route.
    /// @param to The address that will receive the output tokens.
    /// @param deadline The timestamp after which the transaction will revert.
    /// @return amounts An array of amounts transferred at each step of the swap.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Calculates the expected output amounts for a given input amount and swap path.
    /// @param amountIn The amount of input tokens.
    /// @param path The list of token addresses representing the swap route.
    /// @return amounts An array of expected output amounts for each hop in the swap path.
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}
