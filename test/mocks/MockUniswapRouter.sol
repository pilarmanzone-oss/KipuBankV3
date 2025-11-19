// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockUniswapRouter
 * @author Pilar
 * @notice This contract simulates a minimal subset of the Uniswap V2 Router
 *         strictly for testing KipuBankV3. It intentionally **does NOT**
 *         implement real AMM pricing, reserves, swaps, liquidity, or fee logic.
 *
 * @dev The mock focuses on:
 *
 *      - Validating that swap paths have at least 2 addresses.
 *      - Accepting ETH input via payable functions.
 *      - Returning fixed/mock output values.
 *      - Reverting using specific custom errors to support Foundry tests.
 *
 *      It is not a real AMM and must NEVER be used in production.
 */
contract MockUniswapRouter {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a provided swap path does not contain at least
     *         two token addresses.
     */
    error InvalidPath();

    /**
     * @notice Thrown if ETH is required but none is provided.
     */
    error MissingETHValue();

    /**
     * @notice Thrown when attempting to support tokens without approving
     *         or without proper balances. This mock only reverts for
     *         structural testing.
     */
    error UnsupportedToken();

    /**
     * @notice Thrown when WETH address is zero in constructor.
     */
    error ZeroWETHAddress();


    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mock WETH address for path validation. Can be any non-zero value.
    address public immutable WETH;

    /// @notice Configurable swap result for testing. When set to non-zero, overrides default mock rates.
    uint256 public swapResult;

    /**
     * @notice Mock constructor storing a dummy WETH address.
     * @param _weth Any valid address to act as mock WETH.
     */
    constructor(address _weth) {
        if (_weth == address(0)) revert ZeroWETHAddress();
        WETH = _weth;
    }


    /*//////////////////////////////////////////////////////////////
                        INTERNAL VALIDATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Ensures a swap path is valid (length ≥ 2).
     * @param path Array of token addresses.
     */
    function _validatePath(address[] memory path) internal pure {
        if (path.length < 2) revert InvalidPath();
    }


    /*//////////////////////////////////////////////////////////////
                        TEST CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a custom swap result for testing purposes.
     * @dev When swapResult is non-zero, all swap functions will return this value
     *      instead of using their default mock conversion rates.
     * @param _result The amount to return as the swap output (amounts[1]).
     */
    function setSwapResult(uint256 _result) external {
        swapResult = _result;
    }


    /*//////////////////////////////////////////////////////////////
                        MOCK SWAP IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Simulates a swap from ETH → token.
     *
     * @dev Requirements:
     *      - `msg.value > 0`, otherwise reverts with MissingETHValue.
     *      - `path.length >= 2`, otherwise reverts with InvalidPath.
     *      - Returns a *mocked* output amount (no pricing logic).
     *      - Parameters amountOutMin, to, and deadline are ignored in this mock.
     *
     * @param path Swap path (must contain at least 2 entries).
     *
     * @return amounts Mocked output array (contains constant fixed values).
     */
    function swapExactETHForTokens(
        uint, /* amountOutMin */
        address[] calldata path,
        address, /* to */
        uint /* deadline */
    )
        external
        payable
        returns (uint[] memory amounts)
    {
        if (msg.value == 0) revert MissingETHValue();
        _validatePath(path);

        // Mock output: returns fixed 2 elements
        amounts = new uint[](2);
        amounts[0] = msg.value;
        // Use swapResult if set, otherwise use default mock rate
        amounts[1] = swapResult > 0 ? swapResult : msg.value * 2000;
    }

    /**
     * @notice Simulates a swap from token → token.
     *
     * @dev Requirements:
     *      - `path.length >= 2`, otherwise reverts with InvalidPath.
     *      - Ignores allowance/approval checks (mock behavior).
     *      - Returns fixed mocked output.
     *      - Parameters amountOutMin, to, and deadline are ignored in this mock.
     *
     * @param amountIn Amount of input tokens.
     * @param path Swap path.
     *
     * @return amounts Mock result array (size = 2).
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint, /* amountOutMin */
        address[] calldata path,
        address, /* to */
        uint /* deadline */
    )
        external
        view
        returns (uint[] memory amounts)
    {
        _validatePath(path);

        amounts = new uint[](2);
        amounts[0] = amountIn;
        // Use swapResult if set, otherwise use default mock rate
        amounts[1] = swapResult > 0 ? swapResult : amountIn * 1000;
    }

    /**
     * @notice Simulates a swap from token → ETH.
     *
     * @dev Requirements:
     *      - `path.length >= 2`, otherwise revert.
     *      - Parameters amountOutMin, to, and deadline are ignored in this mock.
     *
     * @param amountIn Amount of input tokens.
     * @param path Token-to-WETH path.
     *
     * @return amounts Mock result array.
     */
    function swapExactTokensForETH(
        uint amountIn,
        uint, /* amountOutMin */
        address[] calldata path,
        address, /* to */
        uint /* deadline */
    )
        external
        view
        returns (uint[] memory amounts)
    {
        _validatePath(path);

        amounts = new uint[](2);
        amounts[0] = amountIn;
        // Use swapResult if set, otherwise use default mock rate
        amounts[1] = swapResult > 0 ? swapResult : amountIn / 2000;
    }


    /*//////////////////////////////////////////////////////////////
                              MOCK HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns a constant simulated price quote.
     *
     * @dev Not related to Uniswap's real quoting logic.
     *      All parameters are ignored in this mock implementation.
     *
     * @return amountOut Always returns `42` (sentinel test value).
     */
    function quote(
        uint, /* amountIn */
        uint, /* reserveIn */
        uint  /* reserveOut */
    )
        public
        pure
        returns (uint amountOut)
    {
        return 42;
    }
}