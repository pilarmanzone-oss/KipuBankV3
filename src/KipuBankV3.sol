// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

/// @title Interface for Uniswap V2 Factory
/// @notice Minimal interface needed to check if a liquidity pair exists.
/// @dev Used to verify if a token has a direct pair with USDC before allowing swaps.
interface IUniswapV2Factory {
    /// @notice Returns the address of the pair contract for two tokens.
    /// @param tokenA Address of the first token.
    /// @param tokenB Address of the second token.
    /// @return pair Address of the pair contract (zero if not created).
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/// @title KipuBankV3
/// @author Pilar
/// @notice A DeFi Bank that accepts ETH, USDC, or any ERC20 token with a direct USDC pair on Uniswap V2.
/// @dev All deposits are converted to USDC (6 decimals) and stored as internal balances.
///      Uses AccessControl for admin authorization and ReentrancyGuard for secure withdrawals.
contract KipuBankV3 is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------------

    error InvalidAddress();
    error NotAdmin();
    error InvalidAmount();
    error CapExceeded();
    error AmountOutMinZero();
    error ZeroEth();
    error UnsupportedToken();
    error NoDirectPair();
    error ZeroUsdcOut();
    error InsufficientBalance();
    error TotalDepositedUnderflow();
    error TokenNotAllowed();
    error UseDepositEthAndSwap();
    error UnknownCall();

    // -----------------------------------------------------------------------
    // Constants & Immutables
    // -----------------------------------------------------------------------

    /// @notice Admin role (alias to DEFAULT_ADMIN_ROLE = 0x00)
    bytes32 public constant ADMIN_ROLE = 0x00;

    /// @notice USDC token address (6 decimals)
    address public immutable USDC;

    /// @notice Wrapped Ether address provided by the router
    address public immutable WETH;

    /// @notice Uniswap V2 router instance
    IUniswapV2Router02 public immutable UNISWAP_ROUTER;

    /// @notice Uniswap V2 factory instance
    IUniswapV2Factory public immutable UNISWAP_FACTORY;

    // -----------------------------------------------------------------------
    // Storage Variables
    // -----------------------------------------------------------------------

    /// @notice Internal USDC balances for each user
    mapping(address => uint256) public balancesUsdc;

    /// @notice Tokens allowed for deposit
    mapping(address => bool) public tokenAllowed;

    /// @notice Global bank cap (in USDC, 6 decimals)
    uint256 public bankCapUsd6;

    /// @notice Total USDC deposited (in USDC, 6 decimals)
    uint256 public totalDepositedUsd6;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event DepositConvertedToUsdc(address indexed user, address indexed srcToken, uint256 srcAmount, uint256 usdcReceived);
    event DirectDepositUsdc(address indexed user, uint256 usdcAmount);
    event WithdrawalUsdc(address indexed user, uint256 usdcAmount);
    event TokenAllowed(address token, bool allowed);
    event BankCapUpdated(uint256 oldCapUsd6, uint256 newCapUsd6);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /// @notice Initializes the contract with required addresses and initial settings.
    /// @param admin Address receiving admin privileges.
    /// @param usdcAddr Address of the USDC token.
    /// @param uniswapRouterAddr Address of the Uniswap V2 router.
    /// @param uniswapFactoryAddr Address of the Uniswap V2 factory.
    /// @param initialCapUsd6 Initial global deposit cap in USDC (6 decimals).
    constructor(
        address admin,
        address usdcAddr,
        address uniswapRouterAddr,
        address uniswapFactoryAddr,
        uint256 initialCapUsd6
    ) {
        if (
            admin == address(0) ||
            usdcAddr == address(0) ||
            uniswapRouterAddr == address(0) ||
            uniswapFactoryAddr == address(0)
        ) revert InvalidAddress();

        _grantRole(ADMIN_ROLE, admin);

        USDC = usdcAddr;
        UNISWAP_ROUTER = IUniswapV2Router02(uniswapRouterAddr);
        UNISWAP_FACTORY = IUniswapV2Factory(uniswapFactoryAddr);
        WETH = UNISWAP_ROUTER.WETH();
        bankCapUsd6 = initialCapUsd6;

        // Allow USDC by default
        tokenAllowed[USDC] = true;
    }

    // -----------------------------------------------------------------------
    // Modifiers & Internal Role Checks
    // -----------------------------------------------------------------------

    /// @dev Restricts access to admin-only functions.
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    /// @dev Internal helper for checking admin roles.
    function _onlyAdmin() internal view {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAdmin();
    }

    // -----------------------------------------------------------------------
    // Admin Functions
    // -----------------------------------------------------------------------

    /// @notice Enables or disables a token for deposit.
    /// @param token Token address to update.
    /// @param allowed Whether the token is allowed (true) or blocked (false).
    function setTokenAllowed(address token, bool allowed) external onlyAdmin {
        tokenAllowed[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    /// @notice Updates the maximum allowed total USDC deposits.
    /// @param newCap New cap in USDC (6 decimals).
    function setBankCapUsd6(uint256 newCap) external onlyAdmin {
        emit BankCapUpdated(bankCapUsd6, newCap);
        bankCapUsd6 = newCap;
    }

    /// @dev Checks if a token has a Uniswap V2 pair with USDC.
    /// @param token Token address to check.
    /// @return True if token is supported.
    function _isTokenSupported(address token) internal view returns (bool) {
        if (token == USDC) return true;
        return UNISWAP_FACTORY.getPair(token, USDC) != address(0);
    }

    // -----------------------------------------------------------------------
    // Deposit Functions
    // -----------------------------------------------------------------------

    /// @notice Deposits USDC directly (no swap).
    /// @param amountUsdc Amount to deposit in USDC (6 decimals).
    function depositUsdc(uint256 amountUsdc) external nonReentrant {
        if (!tokenAllowed[USDC]) revert TokenNotAllowed();
        if (amountUsdc == 0) revert InvalidAmount();

        uint256 newTotal = totalDepositedUsd6 + amountUsdc;
        if (newTotal > bankCapUsd6) revert CapExceeded();

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amountUsdc);

        totalDepositedUsd6 = newTotal;
        balancesUsdc[msg.sender] += amountUsdc;

        emit DirectDepositUsdc(msg.sender, amountUsdc);
    }

    /// @notice Deposits ETH, swapping it to USDC through Uniswap V2.
    /// @param amountOutMin Minimum USDC expected (slippage protection).
    function depositEthAndSwap(uint256 amountOutMin) external payable nonReentrant {
        if (!tokenAllowed[USDC]) revert TokenNotAllowed();
        if (amountOutMin == 0) revert AmountOutMinZero();
        if (msg.value == 0) revert ZeroEth();

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        uint256 deadline = block.timestamp + 300;
        uint256[] memory amounts = UNISWAP_ROUTER.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 usdcReceived = amounts[1];
        _acceptUsdcDeposit(usdcReceived);

        balancesUsdc[msg.sender] += usdcReceived;
        emit DepositConvertedToUsdc(msg.sender, address(0), msg.value, usdcReceived);
    }

    /// @notice Deposits an ERC20 token and swaps it to USDC.
    /// @param token Token to deposit.
    /// @param amount Amount to deposit.
    /// @param amountOutMin Minimum USDC expected.
    function depositTokenAndSwap(address token, uint256 amount, uint256 amountOutMin)
        external
        nonReentrant
    {
        if (!tokenAllowed[token]) revert TokenNotAllowed();
        if (token == address(0)) revert UnsupportedToken();
        if (amount == 0) revert InvalidAmount();
        if (amountOutMin == 0) revert AmountOutMinZero();
        if (!_isTokenSupported(token)) revert UnsupportedToken();

        // Case: direct USDC
        if (token == USDC) {
            IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);
            uint256 newTotal = totalDepositedUsd6 + amount;
            if (newTotal > bankCapUsd6) revert CapExceeded();

            totalDepositedUsd6 = newTotal;
            balancesUsdc[msg.sender] += amount;
            emit DirectDepositUsdc(msg.sender, amount);
            return;
        }

        // Verify direct token/USDC pair exists
        address pair = UNISWAP_FACTORY.getPair(token, USDC);
        if (pair == address(0)) revert NoDirectPair();

        // Transfer token to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).safeIncreaseAllowance(address(UNISWAP_ROUTER), amount);

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = USDC;

        uint256 deadline = block.timestamp + 300;
        uint256[] memory amounts = UNISWAP_ROUTER.swapExactTokensForTokens(
            amount,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 usdcReceived = amounts[1];
        _acceptUsdcDeposit(usdcReceived);

        balancesUsdc[msg.sender] += usdcReceived;
        emit DepositConvertedToUsdc(msg.sender, token, amount, usdcReceived);
    }

    /// @dev Internal helper for updating stored USDC and enforcing cap.
    /// @param usdcAmount Amount of USDC received.
    function _acceptUsdcDeposit(uint256 usdcAmount) internal {
        if (usdcAmount == 0) revert ZeroUsdcOut();
        uint256 newTotal = totalDepositedUsd6 + usdcAmount;
        if (newTotal > bankCapUsd6) revert CapExceeded();
        totalDepositedUsd6 = newTotal;
    }

    // -----------------------------------------------------------------------
    // Withdrawals
    // -----------------------------------------------------------------------

    /// @notice Withdraws available USDC.
    /// @param amountUsdc Amount to withdraw (6 decimals).
    function withdrawUsdc(uint256 amountUsdc) external nonReentrant {
        if (!tokenAllowed[USDC]) revert TokenNotAllowed();
        if (amountUsdc == 0) revert InvalidAmount();

        uint256 userBal = balancesUsdc[msg.sender];
        if (amountUsdc > userBal) revert InsufficientBalance();

        balancesUsdc[msg.sender] = userBal - amountUsdc;

        if (amountUsdc > totalDepositedUsd6) revert TotalDepositedUnderflow();
        totalDepositedUsd6 -= amountUsdc;

        IERC20(USDC).safeTransfer(msg.sender, amountUsdc);
        emit WithdrawalUsdc(msg.sender, amountUsdc);
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------

    /// @notice Returns the internal USDC balance for a user.
    /// @param user User address.
    /// @return Balance in USDC (6 decimals).
    function balanceOfUsdc(address user) external view returns (uint256) {
        return balancesUsdc[user];
    }

    // -----------------------------------------------------------------------
    // Receive & Fallback
    // -----------------------------------------------------------------------

    /// @notice Reject direct ETH transfers.
    receive() external payable {
        revert UseDepositEthAndSwap();
    }

    /// @notice Fallback for unknown function calls.
    fallback() external payable {
        revert UnknownCall();
    }
}