// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

/// @title Interface for Uniswap V2 Factory
/// @notice Defines the minimal function needed to check if a liquidity pair exists.
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
/// @notice DeFi Bank that accepts ETH, USDC, or any ERC20 token directly exchangeable with USDC on Uniswap V2.
/// @dev All deposits are automatically converted to USDC and credited to the user's internal USDC balance (6 decimals). Implemented with Foundry.
///      Uses OpenZeppelin’s AccessControl for role management and ReentrancyGuard for withdrawal protection.
contract KipuBankV3 is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------
    // Constants & immutables
    // ---------------------------

    /// @notice admin role (alias to DEFAULT_ADMIN_ROLE)
    bytes32 public constant ADMIN_ROLE = 0x00; // DEFAULT_ADMIN_ROLE is 0x00 in OpenZeppelin

    /// @notice USDC token address (6 decimals)
    address public immutable USDC;

    /// @notice Wrapped Ether address (WETH)
    address public immutable WETH;

    /// @notice Uniswap V2 Router
    IUniswapV2Router02 public immutable UNISWAP_ROUTER;

    /// @notice Uniswap V2 Factory
    IUniswapV2Factory public immutable UNISWAP_FACTORY;

    // ---------------------------
    // Storage
    // ---------------------------

    /// @notice Balances in USDC (6 decimals): user → amountUsdc
    mapping(address => uint256) public balancesUsdc;

    /// @notice tokens allowed to deposit (you can restrict which tokens are allowed)
    mapping(address => bool) public tokenAllowed;

    /// @notice cap in USDC base units (6 decimals)
    uint256 public bankCapUsd6;

    /// @notice current total deposited (USDC base units, 6 decimals)
    uint256 public totalDepositedUsd6;

    // ---------------------------
    // Events
    // ---------------------------

    /// @notice Emitted when a deposit (ETH or ERC20) is converted to USDC.
    /// @param user Address of the user that makes the deposit.
    /// @param srcToken Source token (0x0 for ETH).
    /// @param srcAmount Original amount deposited.
    /// @param usdcReceived Amount of USDC received after swap.
    event DepositConvertedToUsdc(address indexed user, address indexed srcToken, uint256 srcAmount, uint256 usdcReceived);

    /// @notice Emitted when a direct USDC deposit occurs.
    /// @param user User address.
    /// @param usdcAmount Amount deposited in USDC.
    event DirectDepositUsdc(address indexed user, uint256 usdcAmount);

    /// @notice Emitted when a withdrawal in USDC is made.
    /// @param user User address.
    /// @param usdcAmount Amount withdrawn.
    event WithdrawalUsdc(address indexed user, uint256 usdcAmount);

    /// @notice Emitted when a token’s allowed status changes.
    /// @param token Token address.
    /// @param allowed New permit status.
    event TokenAllowed(address token, bool allowed);

    /// @notice Emitted when the bank cap (límite) changes.
    /// @param oldCapUsd6 Previous cap value.
    /// @param newCapUsd6 New cap value.
    event BankCapUpdated(uint256 oldCapUsd6, uint256 newCapUsd6);

    // ---------------------------
    // Constructor
    // ---------------------------

    /// @notice Initializes the contract with primary addresses and initial limit.
    /// @param admin Address that receives admin role.
    /// @param usdcAddr Address of USDC token (6 decimals).
    /// @param uniswapRouterAddr Address of Uniswap V2 router.
    /// @param uniswapFactoryAddr Address of Uniswap V2 Factory.
    /// @param initialCapUsd6 Initial bank cap in USDC units (6 decimals).
    constructor(
        address admin,
        address usdcAddr,
        address uniswapRouterAddr,
        address uniswapFactoryAddr,
        uint256 initialCapUsd6
    ) {
        require(
            admin != address(0) &&
            usdcAddr != address(0) &&
            uniswapRouterAddr != address(0) &&
            uniswapFactoryAddr != address(0),
            "Invalid addresses"
        );

        _grantRole(ADMIN_ROLE, admin);

        USDC = usdcAddr;
        UNISWAP_ROUTER = IUniswapV2Router02(uniswapRouterAddr);
        UNISWAP_FACTORY = IUniswapV2Factory(uniswapFactoryAddr);
        // WETH from router (works for UniswapV2-compatible routers)
        WETH = IUniswapV2Router02(uniswapRouterAddr).WETH();
        bankCapUsd6 = initialCapUsd6;
    }

    // ---------------------------
    // Modifiers
    // ---------------------------

    /// @dev Restrict function to admin role.
    // Use the internal function '_onlyAdmin()' to verify the role (so that only accounts with ADMIN_ROLE can execute certain functions).
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    /// @dev Checks if msg.sender has admin role.
    function _onlyAdmin() internal view {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
    }

    // ---------------------------
    // Admin functions
    // ---------------------------

    /// @notice Sets whether a token is allowed (or not) for deposits.
    /// @param token Token address.
    /// @param allowed Boolean value (true = allowed, false = disallowed).
    /// @notice Returns true if token is supported (has a UniswapV2 pair with USDC) or is USDC itself.
    function setTokenAllowed(address token, bool allowed) external onlyAdmin {
        tokenAllowed[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    /// @notice Update bank cap (USDC base units)
    /// @param newCap New cap in USDC (6 decimals).
    function setBankCapUsd6(uint256 newCap) external onlyAdmin {
        emit BankCapUpdated(bankCapUsd6, newCap);
        bankCapUsd6 = newCap;
    }

    /// @dev Returns true if the token is supported (pair exists with USDC or token is USDC).
    /// @param token Token address to verify.
    /// @return bool True if token supported.
    function _isTokenSupported(address token) internal view returns (bool) {
        if (token == USDC) return true;
        address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(token, USDC);
        return pair != address(0);
    }

    // ---------------------------
    // Deposit functions
    // ---------------------------

    /// @notice Deposits USDC directly (user must approve contract).
    /// @param amountUsdc Amount in USDC base units (6 decimals).
    function depositUsdc(uint256 amountUsdc) external nonReentrant {
        require(amountUsdc > 0, "Zero deposit");
        // check cap first
        uint256 newTotal = totalDepositedUsd6 + amountUsdc;
        require(newTotal <= bankCapUsd6, "Cap exceeded");
        // transfer USDC in
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amountUsdc);
        // update accounting
        totalDepositedUsd6 = newTotal;
        balancesUsdc[msg.sender] += amountUsdc;

        emit DirectDepositUsdc(msg.sender, amountUsdc);
    }

    /// @notice Deposit ETH; will be swapped to USDC via Uniswap V2 (path WETH -> USDC)
    /// @param amountOutMin Minimum USDC out expected (to protect slippage). 
    function depositEthAndSwap(uint256 amountOutMin) external payable nonReentrant {
        require(amountOutMin > 0, "amountOutMin must be > 0");
        require(msg.value > 0, "Zero ETH");

        // build path: WETH -> USDC
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        // perform swap (ETH -> USDC)
        uint256 deadline = block.timestamp + 300;
        uint[] memory amounts = UNISWAP_ROUTER.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 usdcReceived = amounts[1]; // in USDC base units (6 decimals)
        // enforce bank cap before crediting
        _acceptUsdcDeposit(usdcReceived);

        balancesUsdc[msg.sender] += usdcReceived;
        emit DepositConvertedToUsdc(msg.sender, address(0), msg.value, usdcReceived);
    }

    /// @notice Deposit ERC20 token (non-USDC), which will be converted to USDC using Uniswap V2.
    /// @param token Token address to deposit.
    /// @param amount Token amount to deposit (in token decimals).
    /// @param amountOutMin Minimum USDC to receive (for slippage protection).
    function depositTokenAndSwap(address token, uint256 amount, uint256 amountOutMin) external nonReentrant {
        require(amountOutMin > 0, "amountOutMin must be > 0");
        require(amount > 0, "Zero deposit");
        require(token != address(0), "Zero token");
        require(_isTokenSupported(token), "Unsupported token");

        if (token == USDC) {
            IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);
            uint256 newTotal = totalDepositedUsd6 + amount;
            require(newTotal <= bankCapUsd6, "Cap exceeded");
            totalDepositedUsd6 = newTotal;
            balancesUsdc[msg.sender] += amount;
            emit DirectDepositUsdc(msg.sender, amount);
            return;
        }

        // Ensure pair exists token <-> USDC on Uniswap V2
        address pair = UNISWAP_FACTORY.getPair(token, USDC);
        require(pair != address(0), "No direct pair with USDC");

        // pull tokens in
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // approve router
        IERC20(token).safeIncreaseAllowance(address(UNISWAP_ROUTER), amount);

        // build path: token -> USDC
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = USDC;

        uint256 deadline = block.timestamp + 300;
        uint[] memory amounts = UNISWAP_ROUTER.swapExactTokensForTokens(
            amount,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 usdcReceived = amounts[1];
        // check cap and update BEFORE crediting user balances
        _acceptUsdcDeposit(usdcReceived);

        balancesUsdc[msg.sender] += usdcReceived;
        emit DepositConvertedToUsdc(msg.sender, token, amount, usdcReceived);
    }

    /// @dev Internal helper to enforce cap and update total deposits.
    /// @param usdcAmount Amount received in USDC.
    function _acceptUsdcDeposit(uint256 usdcAmount) internal {
        require(usdcAmount > 0, "Zero USDC out");
        uint256 newTotal = totalDepositedUsd6 + usdcAmount;
        require(newTotal <= bankCapUsd6, "Cap exceeded");
        totalDepositedUsd6 = newTotal;
    }

    // ---------------------------
    // Withdrawals (USDC only)
    // ---------------------------

    /// @notice Withdraw USDC credited balance.
    /// @param amountUsdc Amount of USDC to withdraw (6 decimals).
    function withdrawUsdc(uint256 amountUsdc) external nonReentrant {
        require(amountUsdc > 0, "Zero withdraw");

        uint256 userBal = balancesUsdc[msg.sender];
        require(amountUsdc <= userBal, "Insufficient balance");

    // --- EFFECTS: Update status BEFORE any external interaction ---
        balancesUsdc[msg.sender] = userBal - amountUsdc;
    // Protect totalDepositedUsd6 against underflow
        require(amountUsdc <= totalDepositedUsd6, "TotalDeposited underflow");
        totalDepositedUsd6 -= amountUsdc;

    // --- INTERACTIONS: Transfer at the end ---
    // SafeERC20 safeTransfer used for compatibility with non-standard tokens
        IERC20(USDC).safeTransfer(msg.sender, amountUsdc);
        emit WithdrawalUsdc(msg.sender, amountUsdc);
    }

    // ---------------------------
    // View functions
    // ---------------------------

    /// @notice Get USDC balance for a user.
    /// @param user User address.
    /// @return uint256 User balance in USDC (6 decimal places).
    function balanceOfUsdc(address user) external view returns (uint256) {
        return balancesUsdc[user];
    }

    // ---------------------------
    // Receive/Fallback 
    // ---------------------------

    /// @notice Block direct ETH transfers.
    receive() external payable {
        revert("Use depositEthAndSwap");
    }

    /// @notice Fallback for unknown calls.
    fallback() external payable {
        revert("Unknown call");
    }
}
